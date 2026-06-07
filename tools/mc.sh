#!/usr/bin/env bash
# Tool definition: minio client (mc) via the arreg.la install script.
# Contract: TOOL_NAME, TOOL_DESC, tool_supported, tool_install.
#
# Runs the canonical installer at https://minioclient-install.arreg.la, which
# detects OS/arch, downloads the client and installs it as the `m` command.
# The `destdir` argument is ignored because the upstream script decides the
# install location.

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
TOOL_NAME="mc"
# shellcheck disable=SC2034
TOOL_DESC="MinIO client; se instala como 'm' (minioclient-install.arreg.la)"

MC_INSTALL_URL="https://minioclient-install.arreg.la"

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
  tool_supported "$os" "$arch" || die "mc no soporta ${os}/${arch}"
  require_cmd curl

  log "instalando minio client (m) vía ${MC_INSTALL_URL}"
  curl -fsSL "$MC_INSTALL_URL" | bash || die "fallo al instalar minio client"

  if [ -z "${MC_SKIP_VERIFY:-}" ]; then
    if command -v m >/dev/null 2>&1 && m --version >/dev/null 2>&1; then
      ok "minio client verificado: $(command -v m)"
    else
      warn "minio client instalado pero la verificación falló"
    fi
  fi
}
