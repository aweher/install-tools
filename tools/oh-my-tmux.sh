#!/usr/bin/env bash
# Tool definition: oh-my-tmux — install the gpakosz/.tmux configuration.
# Contract: TOOL_NAME, TOOL_DESC, tool_supported, tool_install.
#
# Ensures tmux is installed (apt on Debian, brew on macOS), clones
# gpakosz/.tmux into ~/.tmux, symlinks ~/.tmux.conf and seeds ~/.tmux.conf.local
# (without overwriting an existing one). Writes to the invoking user's home (no
# sudo for the config itself); override with OH_MY_TMUX_HOME.
#
# Knobs:
#   OH_MY_TMUX_HOME   target home (default $HOME)
#   OH_MY_TMUX_SKIP_INSTALL   skip installing tmux (assume present)

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
TOOL_NAME="oh-my-tmux"
# shellcheck disable=SC2034
TOOL_DESC="Configuración de tmux gpakosz/.tmux (~/.tmux.conf + .local)"

OH_MY_TMUX_REPO="https://github.com/gpakosz/.tmux.git"

# tool_supported <os> <arch> -> 0 if supported. Pure config; works everywhere.
tool_supported() {
  local os="$1" arch="$2"
  case "$os" in
    linux)  case "$arch" in amd64|arm64|armv7|armv6|386) return 0 ;; esac ;;
    darwin) case "$arch" in amd64|arm64) return 0 ;; esac ;;
  esac
  return 1
}

# _oh_my_tmux_ensure_tmux: install tmux if missing (best-effort).
_oh_my_tmux_ensure_tmux() {
  command -v tmux >/dev/null 2>&1 && return 0
  [ -n "${OH_MY_TMUX_SKIP_INSTALL:-}" ] && return 0
  if command -v apt-get >/dev/null 2>&1; then
    log "instalando tmux (apt)"
    run_priv apt-get install -y tmux || warn "no se pudo instalar tmux vía apt"
  elif command -v brew >/dev/null 2>&1; then
    log "instalando tmux (brew)"
    brew install tmux || warn "no se pudo instalar tmux vía brew"
  else
    warn "tmux no está instalado y no encontré apt/brew; instálalo manualmente"
  fi
}

# tool_install <os> <arch> [destdir]  (destdir ignored; writes to $HOME)
tool_install() {
  # shellcheck disable=SC2034
  local os="$1" arch="$2" destdir="${3:-/usr/local/bin}"
  tool_supported "$os" "$arch" || die "oh-my-tmux no soporta ${os}/${arch}"
  require_cmd git

  local home repo
  home="${OH_MY_TMUX_HOME:-$HOME}"
  [ -n "$home" ] || die "no se pudo determinar el HOME destino"
  [ -d "$home" ] || die "el HOME destino no existe: $home"
  repo="$home/.tmux"

  _oh_my_tmux_ensure_tmux

  # Clone (skip if already present).
  if [ -d "$repo" ]; then
    log "ya existe ${repo} (omito git clone)"
  else
    log "clonando gpakosz/.tmux en ${repo}"
    git clone "$OH_MY_TMUX_REPO" "$repo" || die "fallo al clonar gpakosz/.tmux"
  fi
  [ -f "$repo/.tmux.conf" ] || die "no se encontró ${repo}/.tmux.conf"

  # Symlink ~/.tmux.conf -> .tmux/.tmux.conf (relative, idempotent).
  ln -sf ".tmux/.tmux.conf" "$home/.tmux.conf" || die "no se pudo crear el symlink ~/.tmux.conf"
  ok "symlink ${home}/.tmux.conf -> .tmux/.tmux.conf"

  # Seed ~/.tmux.conf.local without clobbering an existing one.
  if [ -e "$home/.tmux.conf.local" ]; then
    log "ya existe ${home}/.tmux.conf.local (no se sobrescribe)"
  elif [ -f "$repo/.tmux.conf.local" ]; then
    cp "$repo/.tmux.conf.local" "$home/.tmux.conf.local" \
      || die "no se pudo copiar .tmux.conf.local"
    ok "creado ${home}/.tmux.conf.local"
  else
    warn "no se encontró ${repo}/.tmux.conf.local"
  fi
}
