#!/usr/bin/env bash
# Tool definition: maldet (Linux Malware Detect, rfxn/linux-malware-detect).
# Contract: TOOL_NAME, TOOL_DESC, tool_supported, tool_install.
#
# LMD is a Linux-only malware scanner. We install it from its git repository
# via the upstream ./install.sh, then drop a managed conf.maldet (with the
# alert email substituted) and monitor_paths, and enable the systemd service.
# The `destdir` argument is ignored (LMD installs into /usr/local/maldetect).
#
# Knobs:
#   MALDET_EMAIL          alert e-mail address (default noc@ayuda.la)
#   MALDET_DIR            install dir (default /usr/local/maldetect)
#   MALDET_SKIP_DEPS      skip apt installation of inotify-tools
#   MALDET_SKIP_UPDATE    skip `maldet -u` / `maldet -d`
#   MALDET_SKIP_SERVICE   skip systemctl enable --now maldet
#   MALDET_SKIP_VERIFY    skip the post-install verification

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
TOOL_NAME="maldet"
# shellcheck disable=SC2034
TOOL_DESC="Linux Malware Detect (LMD); solo Linux, requiere systemd"

MALDET_REPO_URL="https://github.com/rfxn/linux-malware-detect.git"

# tool_supported <os> <arch> -> 0 if supported. LMD is Linux-only.
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
  tool_supported "$os" "$arch" || die "maldet solo soporta Linux (no ${os}/${arch})"
  require_cmd git

  local maldir email host tmpl mon tmp
  maldir="${MALDET_DIR:-/usr/local/maldetect}"
  email="${MALDET_EMAIL:-noc@ayuda.la}"
  host="$(hostname 2>/dev/null || echo localhost)"
  tmpl="$_TOOL_DIR/maldet/conf.maldet"
  mon="$_TOOL_DIR/maldet/monitor_paths"
  [ -f "$tmpl" ] || die "plantilla de configuración no encontrada: $tmpl"
  [ -f "$mon" ]  || die "monitor_paths no encontrado: $mon"

  # Dependency: inotify-tools (Debian/Ubuntu).
  if [ -z "${MALDET_SKIP_DEPS:-}" ] && command -v apt-get >/dev/null 2>&1; then
    log "instalando dependencia inotify-tools"
    run_priv apt-get install -y inotify-tools \
      || warn "no se pudo instalar inotify-tools vía apt"
  fi

  # Clone and run the upstream installer.
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN EXIT
  log "clonando linux-malware-detect"
  git clone --depth 1 "$MALDET_REPO_URL" "$tmp/lmd" \
    || die "fallo al clonar linux-malware-detect"
  log "ejecutando install.sh de LMD"
  ( cd "$tmp/lmd" && run_priv bash ./install.sh ) \
    || die "fallo al instalar maldet"

  # Managed configuration.
  log "escribiendo configuración en ${maldir}"
  run_priv mkdir -p "$maldir"
  sed -e "s|{{EMAIL}}|${email}|g" -e "s|{{HOSTNAME}}|${host}|g" "$tmpl" \
    | run_priv tee "$maldir/conf.maldet" >/dev/null \
    || die "fallo al escribir conf.maldet"
  run_priv tee "$maldir/monitor_paths" >/dev/null < "$mon" \
    || die "fallo al escribir monitor_paths"
  ok "configuración aplicada (email: ${email})"

  # Update signatures and the LMD installation to their latest versions.
  if [ -z "${MALDET_SKIP_UPDATE:-}" ] && command -v maldet >/dev/null 2>&1; then
    log "actualizando firmas y versión de maldet"
    run_priv maldet -u || warn "maldet -u falló"
    run_priv maldet -d || warn "maldet -d falló"
  fi

  # Enable the systemd service.
  if [ -z "${MALDET_SKIP_SERVICE:-}" ] && command -v systemctl >/dev/null 2>&1; then
    log "habilitando el servicio systemd maldet"
    run_priv systemctl daemon-reload || warn "systemctl daemon-reload falló"
    run_priv systemctl enable --now maldet \
      || warn "no se pudo habilitar el servicio maldet"
  fi

  if [ -z "${MALDET_SKIP_VERIFY:-}" ]; then
    if command -v maldet >/dev/null 2>&1 && maldet --version >/dev/null 2>&1; then
      ok "maldet verificado: $(command -v maldet)"
    else
      warn "maldet instalado pero la verificación falló"
    fi
  fi
}
