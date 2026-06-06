#!/usr/bin/env bash
# Tool definition: chisel (jpillora/chisel).
# Contract: TOOL_NAME, TOOL_DESC, tool_supported, tool_install.

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
TOOL_NAME="chisel"
# shellcheck disable=SC2034
TOOL_DESC="Fast TCP/UDP tunnel over HTTP (jpillora/chisel)"

CHISEL_REPO="jpillora/chisel"

# tool_supported <os> <arch> -> 0 if supported
tool_supported() {
  local os="$1" arch="$2"
  case "$os" in
    linux)  case "$arch" in amd64|arm64|armv7|armv6|386) return 0 ;; esac ;;
    darwin) case "$arch" in amd64|arm64) return 0 ;; esac ;;
  esac
  return 1
}

# chisel_asset_url <version> <os> <arch> -> download URL
chisel_asset_url() {
  local v="$1" os="$2" arch="$3"
  echo "https://github.com/${CHISEL_REPO}/releases/download/v${v}/chisel_${v}_${os}_${arch}.gz"
}

# tool_install <os> <arch> [destdir]
tool_install() {
  local os="$1" arch="$2" destdir="${3:-/usr/local/bin}"
  tool_supported "$os" "$arch" || die "chisel no soporta ${os}/${arch}"

  local version url tmp
  version="$(latest_release "$CHISEL_REPO")"
  url="$(chisel_asset_url "$version" "$os" "$arch")"
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN EXIT

  log "descargando chisel v${version} (${os}/${arch})"
  download_to "$url" "$tmp/chisel.gz"
  gunzip -f "$tmp/chisel.gz" || die "fallo al descomprimir chisel"
  install_binary "$tmp/chisel" chisel "$destdir"

  if [ -z "${CHISEL_SKIP_VERIFY:-}" ]; then
    if "$destdir/chisel" --version >/dev/null 2>&1; then
      ok "chisel v${version} verificado"
    else
      warn "chisel instalado pero la verificación falló"
    fi
  fi
}
