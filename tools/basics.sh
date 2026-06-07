#!/usr/bin/env bash
# Tool definition: basics — install a curated set of base CLI/server tools.
# Contract: TOOL_NAME, TOOL_DESC, tool_supported, tool_install.
#
# Debian/Ubuntu only: installs a deduplicated package list via apt, sets vim as
# the default editor and activates liquidprompt for the current user. The
# `destdir` argument is ignored (apt decides paths).
#
# Knobs:
#   BASICS_SKIP_EDITOR    skip `update-alternatives --set editor`
#   BASICS_SKIP_PROMPT    skip `liquidprompt_activate`

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
TOOL_NAME="basics"
# shellcheck disable=SC2034
TOOL_DESC="Instalar herramientas básicas vía apt (git, vim, nmap, ripgrep, ufw, fail2ban…)"

# Deduplicated package set (mc here = Midnight Commander, distinct from the
# MinIO client installed by the `mc` tool as `m`).
BASICS_PACKAGES=(
  rpl ssh openssh-server net-tools rng-tools qemu-guest-agent
  git bat mc nmap unzip ncftp iftop aptitude haveged ufw locate
  snmp snmpd snmp-mibs-downloader fail2ban rkhunter logrotate
  iptraf-ng gnupg2 socat logcheck vim pigz pv screen
  python3-pip python3-venv thefuck liquidprompt ripgrep tmux
  tshark termshark magic-wormhole tree hwinfo lshw minicom
  libpam-google-authenticator libpam-pwquality swaks
)

# tool_supported <os> <arch> -> 0 if supported. apt is Debian/Ubuntu (Linux).
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
  tool_supported "$os" "$arch" || die "basics solo soporta Linux (no ${os}/${arch})"
  command -v apt-get >/dev/null 2>&1 || die "basics requiere apt (Debian/Ubuntu)"

  log "actualizando el índice de paquetes (apt-get update)"
  run_priv apt-get update || warn "apt-get update falló"

  log "instalando ${#BASICS_PACKAGES[@]} paquetes básicos…"
  if run_priv env DEBIAN_FRONTEND=noninteractive \
       apt-get install -y "${BASICS_PACKAGES[@]}"; then
    ok "paquetes básicos instalados"
  else
    warn "la instalación en bloque falló; reintentando paquete por paquete"
    local pkg failed=()
    for pkg in "${BASICS_PACKAGES[@]}"; do
      run_priv env DEBIAN_FRONTEND=noninteractive \
        apt-get install -y "$pkg" || failed+=("$pkg")
    done
    if [ "${#failed[@]}" -eq 0 ]; then
      ok "paquetes básicos instalados (tras reintento)"
    else
      warn "no se pudieron instalar: ${failed[*]}"
    fi
  fi

  # Make vim the default editor.
  if [ -z "${BASICS_SKIP_EDITOR:-}" ] \
     && command -v update-alternatives >/dev/null 2>&1 \
     && [ -x /usr/bin/vim.basic ]; then
    log "estableciendo vim como editor por defecto"
    run_priv update-alternatives --set editor /usr/bin/vim.basic \
      || warn "no se pudo establecer el editor por defecto"
  fi

  # Activate liquidprompt for the current user (best-effort, per-user).
  if [ -z "${BASICS_SKIP_PROMPT:-}" ] \
     && command -v liquidprompt_activate >/dev/null 2>&1; then
    log "activando liquidprompt"
    liquidprompt_activate || warn "no se pudo activar liquidprompt"
  fi
}
