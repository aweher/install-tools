#!/usr/bin/env bash
# Tool definition: bash-tuning — apply an idempotent bash tuning to the
# current user's dotfiles. Contract: TOOL_NAME, TOOL_DESC, tool_supported,
# tool_install.
#
# Adds history settings to ~/.bashrc, a set of aliases to ~/.bash_aliases and
# helper functions to ~/.bash_functions. Each block is wrapped in marker
# comments and only appended when the marker is missing, so re-runs are safe
# and existing user content is never overwritten. Writes to the invoking user's
# home (no sudo). Override the target with BASH_TUNING_HOME.

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
TOOL_NAME="bash-tuning"
# shellcheck disable=SC2034
TOOL_DESC="Aplica tuning de bash (history, aliases, funciones) de forma idempotente"

BASH_TUNING_BEGIN="# >>> install-tools bash tuning >>>"
BASH_TUNING_END="# <<< install-tools bash tuning <<<"

# _bashtuning_apply <file> <content>
# Appends a marked block to <file> unless the marker is already present.
# Echoes "applied" or "present" so the caller can summarize.
_bashtuning_apply() {
  local file="$1" content="$2"
  if [ -f "$file" ] && grep -qF "$BASH_TUNING_BEGIN" "$file"; then
    log "ya presente: $file"
    return 0
  fi
  printf '\n%s\n%s\n%s\n' "$BASH_TUNING_BEGIN" "$content" "$BASH_TUNING_END" >> "$file" \
    || die "no se pudo escribir en $file"
  ok "tuning aplicado: $file"
  return 0
}

# tool_supported <os> <arch> -> 0 if supported. Aliases/functions assume
# GNU/Linux tooling (ip, GNU coreutils, mysql), so this is Linux-only.
tool_supported() {
  local os="$1" arch="$2"
  case "$os" in
    linux) case "$arch" in amd64|arm64|armv7|armv6|386) return 0 ;; esac ;;
  esac
  return 1
}

# tool_install <os> <arch> [destdir]  (destdir ignored; writes to $HOME)
tool_install() {
  # shellcheck disable=SC2034
  local os="$1" arch="$2" destdir="${3:-/usr/local/bin}"
  tool_supported "$os" "$arch" || die "bash-tuning solo soporta Linux (no ${os}/${arch})"

  local home
  home="${BASH_TUNING_HOME:-$HOME}"
  [ -n "$home" ] || die "no se pudo determinar el HOME destino"
  [ -d "$home" ] || die "el HOME destino no existe: $home"

  local bashrc_block aliases_block functions_block
  bashrc_block="$(cat <<'BLOCK'
export HISTTIMEFORMAT="%h %d %H:%M:%S "
[ -r "$HOME/.bash_functions" ] && source "$HOME/.bash_functions"
HISTSIZE=100000
HISTFILESIZE=200000
BLOCK
)"

  aliases_block="$(cat <<'BLOCK'
alias ip='ip -color'
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'
alias mv='mv --verbose'
alias usage10='du -hsx * | sort -rh | head -10'
alias bigdirs10='du -a | sort -n -r | head -n 5'
BLOCK
)"

  functions_block="$(cat <<'BLOCK'
crearvenv()
{
    python3 -m venv .venv-${HOSTNAME}
    source ./.venv-${HOSTNAME}/bin/activate
    pip install --upgrade pip
}

mygrants()
{
  mysql -B -N $@ -e "SELECT DISTINCT CONCAT(
    'SHOW GRANTS FOR \'', user, '\'@\'', host, '\';'
    ) AS query FROM mysql.user" | \
  mysql $@ | \
  sed 's/\(GRANT .*\)/\1;/;s/^\(Grants for .*\)/## \1 ##/;/##/{x;p;x;}'
}
BLOCK
)"

  log "aplicando tuning de bash en ${home}"
  _bashtuning_apply "$home/.bashrc"         "$bashrc_block"
  _bashtuning_apply "$home/.bash_aliases"   "$aliases_block"
  _bashtuning_apply "$home/.bash_functions" "$functions_block"
  ok "tuning de bash verificado en ${home}"
}
