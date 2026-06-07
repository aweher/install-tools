#!/usr/bin/env bash
# Tool definition: filebeat (Elastic log shipper).
# Contract: TOOL_NAME, TOOL_DESC, tool_supported, tool_install.
#
# Filebeat is installed from Elastic's APT repository (Linux/Debian only), then
# pointed at a Graylog/Logstash host (default `loghost`, mapped in /etc/hosts).
# Config is rendered from a managed template and the `system` module + systemd
# service are enabled. The `destdir` argument is ignored (apt decides paths).
#
# Knobs:
#   FILEBEAT_GRAYLOG_HOST   logstash/graylog host (default loghost)
#   FILEBEAT_LOGHOST_IP     /etc/hosts IP for `loghost` (default 127.5.1.4)
#   FILEBEAT_ES_MAJOR       Elastic APT channel (default 7.x)
#   FILEBEAT_DIR            config dir (default /etc/filebeat)
#   FILEBEAT_HOSTS_FILE     hosts file (default /etc/hosts)
#   FILEBEAT_SKIP_REPO      skip APT key/repo setup and package install
#   FILEBEAT_SKIP_SERVICE   skip systemctl enable/start
#   FILEBEAT_SKIP_VERIFY    skip the post-install verification

# Ensure libs are available when sourced standalone (e.g. inside gum spin).
_TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_TOOL_LIB="$(cd "$_TOOL_DIR/../lib" && pwd)"
# shellcheck source=/dev/null
[ -n "${C_RED+x}" ]      || source "$_TOOL_LIB/common.sh"
# shellcheck source=/dev/null
declare -f detect_os >/dev/null   || source "$_TOOL_LIB/platform.sh"
# shellcheck source=/dev/null
declare -f latest_release >/dev/null || source "$_TOOL_LIB/github.sh"
# shellcheck source=/dev/null
declare -f install_binary >/dev/null || source "$_TOOL_LIB/installer.sh"

# shellcheck disable=SC2034
TOOL_NAME="filebeat"
# shellcheck disable=SC2034
TOOL_DESC="Shipper de logs de Elastic hacia Graylog/Logstash; solo Linux"

# tool_supported <os> <arch> -> 0 if supported. Elastic APT repo is Linux-only.
tool_supported() {
  local os="$1" arch="$2"
  case "$os" in
    linux) case "$arch" in amd64|arm64|armv7|armv6|386) return 0 ;; esac ;;
  esac
  return 1
}

# tool_install <os> <arch> [destdir]  (destdir ignored; see header)
tool_install() {
  # shellcheck disable=SC2034
  local os="$1" arch="$2" destdir="${3:-/usr/local/bin}"
  tool_supported "$os" "$arch" || die "filebeat solo soporta Linux (no ${os}/${arch})"
  require_cmd curl

  local fbdir hostsfile graylog loghost_ip es_major tmpl
  fbdir="${FILEBEAT_DIR:-/etc/filebeat}"
  hostsfile="${FILEBEAT_HOSTS_FILE:-/etc/hosts}"
  graylog="${FILEBEAT_GRAYLOG_HOST:-loghost}"
  loghost_ip="${FILEBEAT_LOGHOST_IP:-127.5.1.4}"
  es_major="${FILEBEAT_ES_MAJOR:-7.x}"
  tmpl="$_TOOL_DIR/filebeat/filebeat.yml"
  [ -f "$tmpl" ] || die "plantilla de configuración no encontrada: $tmpl"

  # Elastic APT repository + package install (Debian/Ubuntu).
  if [ -z "${FILEBEAT_SKIP_REPO:-}" ] && command -v apt-get >/dev/null 2>&1; then
    require_cmd gpg
    log "añadiendo la clave GPG de Elastic"
    curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch \
      | run_priv gpg --batch --yes --dearmor -o /usr/share/keyrings/elastic.gpg \
      || die "fallo al importar la clave GPG de Elastic"
    log "añadiendo el repositorio APT de Elastic (${es_major})"
    echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/${es_major}/apt stable main" \
      | run_priv tee "/etc/apt/sources.list.d/elastic-${es_major}.list" >/dev/null
    run_priv apt-get update || warn "apt-get update falló"
    run_priv apt-get install -y filebeat || die "fallo al instalar filebeat"
  fi

  # Map `loghost` in /etc/hosts (idempotent) when used as the destination.
  if [ -n "$loghost_ip" ] && [ "$graylog" = "loghost" ]; then
    if ! grep -qE "[[:space:]]loghost([[:space:]]|$)" "$hostsfile" 2>/dev/null; then
      log "mapeando loghost -> ${loghost_ip} en ${hostsfile}"
      printf '%s\n%s\n' '#' "${loghost_ip} loghost" \
        | run_priv tee -a "$hostsfile" >/dev/null \
        || warn "no se pudo actualizar ${hostsfile}"
    fi
  fi

  # Managed configuration (back up the stock file once).
  run_priv mkdir -p "$fbdir"
  if [ -f "$fbdir/filebeat.yml" ] && [ ! -f "$fbdir/filebeat.yml.000" ]; then
    run_priv mv "$fbdir/filebeat.yml" "$fbdir/filebeat.yml.000"
  fi
  log "escribiendo ${fbdir}/filebeat.yml (output -> ${graylog}:5044)"
  sed -e "s|{{GRAYLOG_HOST}}|${graylog}|g" "$tmpl" \
    | run_priv tee "$fbdir/filebeat.yml" >/dev/null \
    || die "fallo al escribir filebeat.yml"
  ok "configuración aplicada"

  # Enable the system module.
  if command -v filebeat >/dev/null 2>&1; then
    run_priv filebeat modules enable system || warn "no se pudo habilitar el módulo system"
  fi

  # Enable + start the systemd service.
  if [ -z "${FILEBEAT_SKIP_SERVICE:-}" ] && command -v systemctl >/dev/null 2>&1; then
    log "habilitando el servicio systemd filebeat"
    run_priv systemctl enable filebeat || warn "systemctl enable filebeat falló"
    run_priv systemctl start filebeat  || warn "systemctl start filebeat falló"
  fi

  if [ -z "${FILEBEAT_SKIP_VERIFY:-}" ]; then
    if command -v filebeat >/dev/null 2>&1 && filebeat version >/dev/null 2>&1; then
      ok "filebeat verificado: $(command -v filebeat)"
    else
      warn "filebeat instalado pero la verificación falló"
    fi
  fi
}
