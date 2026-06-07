#!/usr/bin/env bash
# Tool definition: snmpd (Net-SNMP agent with LibreNMS-friendly config).
# Contract: TOOL_NAME, TOOL_DESC, tool_supported, tool_install.
#
# Linux/Debian only. Installs snmp/snmpd/snmp-mibs-downloader, writes
# /etc/snmp/snmpd.conf and /etc/default/snmpd, fetches the LibreNMS `distro`
# extend script and enables the service. The community, sysLocation and
# sysContact values are resolved from env vars, otherwise prompted (when a TTY
# is available), otherwise defaulted. The `destdir` argument is ignored.
#
# Knobs:
#   SNMPD_COMMUNITY      rocommunity (default executeorder66)
#   SNMPD_SYSLOCATION    sysLocation (default "The Galaxy")
#   SNMPD_SYSCONTACT     sysContact  (default "NOC Ayuda.La <noc@ayuda.la>")
#   SNMPD_CONF_DIR       config dir (default /etc/snmp)
#   SNMPD_DEFAULT_FILE   defaults file (default /etc/default/snmpd)
#   SNMPD_SKIP_INSTALL   skip apt package install
#   SNMPD_SKIP_DISTRO    skip downloading the LibreNMS distro script
#   SNMPD_SKIP_SERVICE   skip systemctl enable/restart
#   SNMPD_SKIP_VERIFY    skip post-install verification

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
TOOL_NAME="snmpd"
# shellcheck disable=SC2034
TOOL_DESC="Agente Net-SNMP (snmpd) con config para LibreNMS; solo Linux"

SNMPD_DISTRO_URL="https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro"

# _snmpd_resolve <env-value> <label> <default> -> echoes the chosen value.
# Uses the env value if set, otherwise prompts on a TTY, otherwise the default.
_snmpd_resolve() {
  local cur="$1" label="$2" def="$3" ans
  if [ -n "$cur" ]; then printf '%s' "$cur"; return 0; fi
  if [ -t 0 ]; then
    read -r -p "${label} [${def}]: " ans
    printf '%s' "${ans:-$def}"
  else
    printf '%s' "$def"
  fi
}

# tool_supported <os> <arch> -> 0 if supported. Net-SNMP via apt is Linux-only.
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
  tool_supported "$os" "$arch" || die "snmpd solo soporta Linux (no ${os}/${arch})"

  local confdir deffile conftmpl deftmpl
  confdir="${SNMPD_CONF_DIR:-/etc/snmp}"
  deffile="${SNMPD_DEFAULT_FILE:-/etc/default/snmpd}"
  conftmpl="$_TOOL_DIR/snmpd/snmpd.conf"
  deftmpl="$_TOOL_DIR/snmpd/default"
  [ -f "$conftmpl" ] || die "plantilla no encontrada: $conftmpl"
  [ -f "$deftmpl" ]  || die "plantilla no encontrada: $deftmpl"

  # Resolve the configurable parameters.
  local community syslocation syscontact
  community="$(_snmpd_resolve "${SNMPD_COMMUNITY:-}" "Community SNMP (rocommunity)" "executeorder66")"
  syslocation="$(_snmpd_resolve "${SNMPD_SYSLOCATION:-}" "sysLocation" "The Galaxy")"
  syscontact="$(_snmpd_resolve "${SNMPD_SYSCONTACT:-}" "sysContact" "NOC Ayuda.La <noc@ayuda.la>")"
  log "config SNMP: sysLocation='${syslocation}' sysContact='${syscontact}' (community oculta)"

  # Packages.
  if [ -z "${SNMPD_SKIP_INSTALL:-}" ] && command -v apt-get >/dev/null 2>&1; then
    log "instalando snmp snmpd snmp-mibs-downloader"
    run_priv apt-get update || warn "apt-get update falló"
    run_priv env DEBIAN_FRONTEND=noninteractive \
      apt-get install -y snmp snmpd snmp-mibs-downloader \
      || die "fallo al instalar los paquetes snmp"
  fi

  # LibreNMS distro extend script.
  if [ -z "${SNMPD_SKIP_DISTRO:-}" ]; then
    local tmp
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN EXIT
    log "descargando el script distro de LibreNMS"
    download_to "$SNMPD_DISTRO_URL" "$tmp/distro"
    install_binary "$tmp/distro" distro /usr/local/bin
  fi

  # /etc/snmp/snmpd.conf (back up the stock file once, then render template).
  run_priv mkdir -p "$confdir"
  if [ -f "$confdir/snmpd.conf" ] && [ ! -f "$confdir/snmpd.conf.000" ]; then
    run_priv mv "$confdir/snmpd.conf" "$confdir/snmpd.conf.000"
  fi
  local content
  content="$(cat "$conftmpl")"
  content="${content//'{{COMMUNITY}}'/$community}"
  content="${content//'{{SYSLOCATION}}'/$syslocation}"
  content="${content//'{{SYSCONTACT}}'/$syscontact}"
  printf '%s\n' "$content" | run_priv tee "$confdir/snmpd.conf" >/dev/null \
    || die "fallo al escribir snmpd.conf"
  ok "escrito ${confdir}/snmpd.conf"

  # /etc/default/snmpd (back up once).
  run_priv mkdir -p "$(dirname "$deffile")"
  if [ -f "$deffile" ] && [ ! -f "${deffile}.000" ]; then
    run_priv mv "$deffile" "${deffile}.000"
  fi
  run_priv tee "$deffile" >/dev/null < "$deftmpl" \
    || die "fallo al escribir ${deffile}"
  ok "escrito ${deffile}"

  # Service.
  if [ -z "${SNMPD_SKIP_SERVICE:-}" ] && command -v systemctl >/dev/null 2>&1; then
    log "habilitando y reiniciando el servicio snmpd"
    run_priv systemctl enable snmpd  || warn "systemctl enable snmpd falló"
    run_priv systemctl restart snmpd || warn "systemctl restart snmpd falló"
  fi

  if [ -z "${SNMPD_SKIP_VERIFY:-}" ]; then
    if command -v snmpd >/dev/null 2>&1; then
      ok "snmpd verificado: $(command -v snmpd)"
    else
      warn "snmpd instalado pero la verificación falló"
    fi
  fi
}
