#!/usr/bin/env bash
# Tool definition: serial-console — enable a serial console (getty + GRUB).
# Contract: TOOL_NAME, TOOL_DESC, tool_supported, tool_install.
#
# Linux only. For each serial port it enables a getty (systemd
# serial-getty@<port>.service, falling back to an upstart /etc/init/<port>.conf)
# and, optionally, points GRUB's console at the first serial port by editing
# GRUB_CMDLINE_LINUX in /etc/default/grub and regenerating the GRUB config. A
# reboot is required to fully apply the GRUB change. The `destdir` argument is
# ignored.
#
# Knobs:
#   SERIAL_PORTS          space-separated ports (default "ttyS0 ttyS1")
#   SERIAL_BAUD           baud rate (default 115200)
#   SERIAL_GRUB_FILE      grub defaults file (default /etc/default/grub)
#   SERIAL_INIT_DIR       upstart dir (default /etc/init)
#   SERIAL_FORCE_UPSTART  force the upstart code path (skip systemd)
#   SERIAL_SKIP_GETTY     write upstart conf but don't enable/start the getty
#   SERIAL_SKIP_GRUB      skip all GRUB handling
#   SERIAL_SKIP_GRUB_REGEN  edit /etc/default/grub but don't regenerate
#   SERIAL_SKIP_VERIFY    skip the dmesg verification

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
TOOL_NAME="serial-console"
# shellcheck disable=SC2034
TOOL_DESC="Habilita consola serie (getty systemd/upstart + GRUB); solo Linux"

# _serial_getty_port <port> <baud>: enable a getty for the port.
_serial_getty_port() {
  local port="$1" baud="$2"

  # Preferred: systemd.
  if [ -z "${SERIAL_FORCE_UPSTART:-}" ] && command -v systemctl >/dev/null 2>&1; then
    if [ -n "${SERIAL_SKIP_GETTY:-}" ]; then return 0; fi
    log "habilitando serial-getty@${port} (systemd)"
    run_priv systemctl enable --now "serial-getty@${port}.service" \
      || warn "no se pudo habilitar serial-getty@${port}"
    return 0
  fi

  # Fallback: upstart.
  if [ -n "${SERIAL_FORCE_UPSTART:-}" ] || command -v initctl >/dev/null 2>&1; then
    local initdir conf
    initdir="${SERIAL_INIT_DIR:-/etc/init}"
    conf="$initdir/${port}.conf"
    run_priv mkdir -p "$initdir"
    if [ -f "$conf" ]; then
      log "ya existe ${conf}"
    else
      log "creando ${conf} (upstart)"
      printf '%s\n' \
        "# ${port} - getty" \
        "#" \
        "# This service maintains a getty on ${port} from the point the system is" \
        "# started until it is shut down again." \
        "start on stopped rc RUNLEVEL=[12345]" \
        "stop on runlevel [!12345]" \
        "respawn" \
        "exec /sbin/getty -L ${baud} ${port} vt102" \
        | run_priv tee "$conf" >/dev/null || die "no se pudo escribir ${conf}"
    fi
    if [ -n "${SERIAL_SKIP_GETTY:-}" ]; then return 0; fi
    run_priv start "$port" || warn "no se pudo iniciar ${port} (upstart)"
    return 0
  fi

  warn "no se detectó systemd ni upstart; habilita el getty de ${port} manualmente"
}

# _serial_grub <port> <baud>: point GRUB's console at the serial port.
_serial_grub() {
  local port="$1" baud="$2"
  [ -n "${SERIAL_SKIP_GRUB:-}" ] && return 0

  local grubfile
  grubfile="${SERIAL_GRUB_FILE:-/etc/default/grub}"
  if [ ! -f "$grubfile" ]; then
    warn "no existe ${grubfile}; omito la configuración de GRUB"
    return 0
  fi

  local desired
  desired='GRUB_CMDLINE_LINUX="quiet console=tty0 console='"${port},${baud}"'"'

  # Back up the original once.
  if [ ! -f "${grubfile}.000" ]; then
    run_priv cp "$grubfile" "${grubfile}.000" || warn "no se pudo respaldar ${grubfile}"
  fi

  local content new
  content="$(cat "$grubfile")"
  if printf '%s\n' "$content" | grep -q '^GRUB_CMDLINE_LINUX='; then
    new="$(printf '%s\n' "$content" \
      | awk -v r="$desired" '/^GRUB_CMDLINE_LINUX=/{print r; next}{print}')"
  else
    new="${content}"$'\n'"${desired}"
  fi
  printf '%s\n' "$new" | run_priv tee "$grubfile" >/dev/null \
    || die "no se pudo escribir ${grubfile}"
  ok "GRUB_CMDLINE_LINUX configurado en ${grubfile}"

  [ -n "${SERIAL_SKIP_GRUB_REGEN:-}" ] && return 0
  if command -v update-grub >/dev/null 2>&1; then
    log "regenerando GRUB (update-grub)"
    run_priv update-grub || warn "update-grub falló"
  elif command -v grub2-mkconfig >/dev/null 2>&1; then
    log "regenerando GRUB (grub2-mkconfig)"
    run_priv grub2-mkconfig --output=/boot/grub2/grub.cfg || warn "grub2-mkconfig falló"
  elif command -v grub-mkconfig >/dev/null 2>&1; then
    log "regenerando GRUB (grub-mkconfig)"
    run_priv grub-mkconfig -o /boot/grub/grub.cfg || warn "grub-mkconfig falló"
  else
    warn "no se encontró update-grub/grub2-mkconfig; regenera GRUB manualmente"
  fi
}

# tool_supported <os> <arch> -> 0 if supported. Serial getty/GRUB is Linux-only.
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
  tool_supported "$os" "$arch" || die "serial-console solo soporta Linux (no ${os}/${arch})"

  local baud first
  baud="${SERIAL_BAUD:-115200}"
  local ports
  read -r -a ports <<< "${SERIAL_PORTS:-ttyS0 ttyS1}"
  [ "${#ports[@]}" -gt 0 ] || die "SERIAL_PORTS está vacío"
  first="${ports[0]}"

  log "configurando consola serie en: ${ports[*]} (baud ${baud})"
  local p
  for p in "${ports[@]}"; do
    _serial_getty_port "$p" "$baud"
  done

  _serial_grub "$first" "$baud"

  if [ -z "${SERIAL_SKIP_VERIFY:-}" ]; then
    if command -v dmesg >/dev/null 2>&1 && dmesg 2>/dev/null | grep -q "$first"; then
      ok "${first} detectado en dmesg"
    else
      warn "no se pudo verificar ${first} en dmesg (puede requerir reinicio)"
    fi
  fi

  log "reinicia la VM para aplicar GRUB y verifica con: dmesg | grep ttyS"
}
