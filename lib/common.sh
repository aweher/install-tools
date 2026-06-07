#!/usr/bin/env bash
# Common helpers: logging, command checks, privilege escalation, gum bootstrap.

# Colors (disabled if not a tty).
# shellcheck disable=SC2034
if [ -t 2 ]; then
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_BOLD=''; C_RESET=''
fi

log()  { printf '%s\n' "${C_BLUE}==>${C_RESET} $*" >&2; }
ok()   { printf '%s\n' "${C_GREEN}✓${C_RESET} $*" >&2; }
warn() { printf '%s\n' "${C_YELLOW}!${C_RESET} $*" >&2; }
die()  { printf '%s\n' "${C_RED}✗ $*${C_RESET}" >&2; exit 1; }

# require_cmd <name>: die if a command is missing.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "comando requerido no encontrado: $1"
}

# run_priv <cmd...>: run as current user if possible, else via sudo.
# Usage is decided by the caller (install_binary) based on writability.
run_priv() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    require_cmd sudo
    sudo "$@"
  fi
}

# gum_asset_arch <arch> -> arch token used in gum release asset names.
# Maps our canonical arch (from detect_arch) to charmbracelet/gum's naming.
gum_asset_arch() {
  case "$1" in
    amd64) echo "x86_64" ;;
    arm64) echo "arm64" ;;
    armv7) echo "armv7" ;;
    armv6) echo "armv6" ;;
    386)   echo "i386" ;;
    *) return 1 ;;
  esac
}

# install_gum_binary: download gum from its GitHub releases and install it into
# DESTDIR (default /usr/local/bin). Returns non-zero if the platform is
# unsupported. Relies on detect_os/detect_arch/latest_release/download_to/
# install_binary being sourced (they are, by the time ensure_gum is called).
install_gum_binary() {
  local os arch ghos gharch ver url tmp bin
  os="$(detect_os)"; arch="$(detect_arch)"
  case "$os" in
    linux)  ghos="Linux" ;;
    darwin) ghos="Darwin" ;;
    *) return 1 ;;
  esac
  gharch="$(gum_asset_arch "$arch")" || return 1
  ver="$(latest_release charmbracelet/gum)"
  url="https://github.com/charmbracelet/gum/releases/download/v${ver}/gum_${ver}_${ghos}_${gharch}.tar.gz"
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  log "descargando gum v${ver} (${ghos}/${gharch})"
  download_to "$url" "$tmp/gum.tar.gz"
  tar -xzf "$tmp/gum.tar.gz" -C "$tmp" || die "fallo al descomprimir gum"
  bin="$(find "$tmp" -type f -name gum | head -n1)"
  [ -n "$bin" ] || die "no se encontró el binario gum en el archivo descargado"
  install_binary "$bin" gum "${DESTDIR:-/usr/local/bin}"
}

# ensure_gum: ensure the `gum` binary is available, installing it if possible.
ensure_gum() {
  command -v gum >/dev/null 2>&1 && return 0
  warn "gum no está instalado; intentando instalarlo…"
  if command -v brew >/dev/null 2>&1; then
    brew install gum && command -v gum >/dev/null 2>&1 && return 0
  fi
  if install_gum_binary && command -v gum >/dev/null 2>&1; then
    return 0
  fi
  die "no se pudo instalar gum automáticamente. Instálalo: https://github.com/charmbracelet/gum#installation"
}
