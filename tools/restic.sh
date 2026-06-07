#!/usr/bin/env bash
# Tool definition: restic (restic/restic) via the arreg.la install script.
# Contract: TOOL_NAME, TOOL_DESC, tool_supported, tool_install.
#
# Instead of downloading the binary ourselves, we run the canonical installer
# at https://restic-install.arreg.la, which detects OS/arch and drops the
# binary in place. On Debian/Ubuntu we also pin restic out of apt (so the
# manually installed binary is not shadowed/downgraded) and ensure bzip2 is
# present (restic release assets are .bz2). The `destdir` argument is ignored
# because the upstream script decides the install location.

# Ensure libs are available when sourced standalone (e.g. inside gum spin).
_TOOL_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"
# shellcheck source=/dev/null
[ -n "${C_RED+x}" ]      || source "$_TOOL_LIB/common.sh"
# shellcheck source=/dev/null
declare -f detect_os >/dev/null   || source "$_TOOL_LIB/platform.sh"
# shellcheck source=/dev/null
declare -f latest_release >/dev/null || source "$_TOOL_LIB/github.sh"
# shellcheck source=/dev/null
declare -f install_binary >/dev/null || source "$_TOOL_LIB/installer.sh"

# shellcheck disable=SC2034
TOOL_NAME="restic"
# shellcheck disable=SC2034
TOOL_DESC="Backup rápido, seguro y eficiente (restic-install.arreg.la)"

RESTIC_INSTALL_URL="https://restic-install.arreg.la"

# tool_supported <os> <arch> -> 0 if supported.
tool_supported() {
  local os="$1" arch="$2"
  case "$os" in
    linux)  case "$arch" in amd64|arm64|armv7|armv6|386) return 0 ;; esac ;;
    darwin) case "$arch" in amd64|arm64) return 0 ;; esac ;;
  esac
  return 1
}

# tool_install <os> <arch> [destdir]  (destdir ignored; see header)
tool_install() {
  # shellcheck disable=SC2034
  local os="$1" arch="$2" destdir="${3:-/usr/local/bin}"
  tool_supported "$os" "$arch" || die "restic no soporta ${os}/${arch}"
  require_cmd curl

  # Debian/Ubuntu: keep apt from shadowing the installed binary, and make sure
  # bzip2 is available to decompress the restic release asset.
  if [ -z "${RESTIC_SKIP_APT_PIN:-}" ] && command -v apt-get >/dev/null 2>&1; then
    log "configurando pin de apt para restic (Debian/Ubuntu)"
    printf '%s\n' "Package: restic" "Pin: release *" "Pin-Priority: -1" \
      | run_priv tee /etc/apt/preferences.d/restic >/dev/null \
      || warn "no se pudo escribir el pin de apt para restic"
    run_priv apt-get install -y bzip2 \
      || warn "no se pudo instalar bzip2 vía apt"
  fi

  log "instalando restic vía ${RESTIC_INSTALL_URL}"
  curl -fsSL "$RESTIC_INSTALL_URL" | bash || die "fallo al instalar restic"

  if [ -z "${RESTIC_SKIP_VERIFY:-}" ]; then
    if command -v restic >/dev/null 2>&1 && restic version >/dev/null 2>&1; then
      ok "restic verificado: $(command -v restic)"
    else
      warn "restic instalado pero la verificación falló"
    fi
  fi
}
