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

# ensure_gum: ensure the `gum` binary is available, installing it if possible.
ensure_gum() {
  command -v gum >/dev/null 2>&1 && return 0
  warn "gum no está instalado; intentando instalarlo…"
  local os; os="$(uname -s)"
  if [ "$os" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
    brew install gum && command -v gum >/dev/null 2>&1 && return 0
  fi
  if command -v go >/dev/null 2>&1; then
    local gopath
    gopath="$(go env GOPATH)"
    if GO111MODULE=on go install github.com/charmbracelet/gum@latest; then
      PATH="$gopath/bin:$PATH"; export PATH
      command -v gum >/dev/null 2>&1 && return 0
    fi
  fi
  die "no se pudo instalar gum automáticamente. Instálalo: https://github.com/charmbracelet/gum#installation"
}
