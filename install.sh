#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

REPO_TARBALL="https://github.com/aweher/install-tools/archive/refs/heads/main.tar.gz"

# needs_bootstrap: true when we cannot find our lib/tools next to the script
# (e.g. run via `bash <(curl ...)`).
needs_bootstrap() {
  [ -z "$SCRIPT_DIR" ] || [ ! -d "$SCRIPT_DIR/tools" ] || [ ! -d "$SCRIPT_DIR/lib" ]
}

bootstrap_and_run() {
  command -v curl >/dev/null 2>&1 || { echo "curl requerido" >&2; exit 1; }
  command -v tar  >/dev/null 2>&1 || { echo "tar requerido" >&2; exit 1; }
  # tmp is intentionally NOT local: the EXIT trap below runs after this
  # function's frame is gone (e.g. when set -e aborts on inner failure), so a
  # local would be out of scope and `set -u` would crash on "$tmp".
  tmp=""
  trap 'if [ -n "${tmp:-}" ]; then rm -rf "$tmp"; fi' EXIT
  tmp="$(mktemp -d)"
  echo "==> descargando install-tools…" >&2
  curl -fsSL "$REPO_TARBALL" | tar -xz -C "$tmp" --strip-components=1 \
    || { echo "fallo al descargar el repo" >&2; exit 1; }
  # Re-exec the downloaded script with a real terminal for the TUI.
  if [ -e /dev/tty ]; then
    bash "$tmp/install.sh" "$@" < /dev/tty
  else
    bash "$tmp/install.sh" "$@"
  fi
  exit $?
}

if needs_bootstrap; then
  bootstrap_and_run "$@"
fi

# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/platform.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/github.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/installer.sh"

TOOLS_DIR="$SCRIPT_DIR/tools"
# DESTDIR honored for testing; defaults to /usr/local/bin.
DESTDIR="${INSTALL_TOOLS_DESTDIR:-/usr/local/bin}"

# list_tool_files -> prints each tools/*.sh path
list_tool_files() {
  local f
  for f in "$TOOLS_DIR"/*.sh; do
    [ -e "$f" ] && echo "$f"
  done
}

# tool_meta <file> : sources file in a subshell and echoes "name|desc"
tool_meta() {
  # shellcheck disable=SC1090
  ( source "$1"; echo "${TOOL_NAME}|${TOOL_DESC}" )
}

# find_tool_file <name> : echoes path of matching tool file, or empty
find_tool_file() {
  local want="$1" f name
  while IFS= read -r f; do
    # shellcheck disable=SC1090
    name="$( source "$f"; echo "$TOOL_NAME" )"
    if [ "$name" = "$want" ]; then echo "$f"; return 0; fi
  done < <(list_tool_files)
  return 1
}

cmd_list() {
  local os arch f meta name desc
  os="$(detect_os)"; arch="$(detect_arch)"
  printf '%s\n' "${C_BOLD}Herramientas disponibles (${os}/${arch}):${C_RESET}" >&2
  while IFS= read -r f; do
    meta="$(tool_meta "$f")"
    name="${meta%%|*}"; desc="${meta#*|}"
    # shellcheck disable=SC1090
    if ( source "$f"; tool_supported "$os" "$arch" ); then
      printf '  %-12s %s\n' "$name" "$desc"
    else
      printf '  %-12s %s (no soportada en %s/%s)\n' "$name" "$desc" "$os" "$arch"
    fi
  done < <(list_tool_files)
  return 0
}

cmd_install_one() {
  local name="$1" os arch file
  os="$(detect_os)"; arch="$(detect_arch)"
  file="$(find_tool_file "$name")" || die "herramienta desconocida: $name"
  # shellcheck disable=SC1090
  ( source "$file"; tool_install "$os" "$arch" "$DESTDIR" )
}

cmd_install_all() {
  local os arch f name
  os="$(detect_os)"; arch="$(detect_arch)"
  while IFS= read -r f; do
    # shellcheck disable=SC1090
    name="$( source "$f"; echo "$TOOL_NAME" )"
    # shellcheck disable=SC1090
    if ( source "$f"; tool_supported "$os" "$arch" ); then
      # shellcheck disable=SC1090
      ( source "$f"; tool_install "$os" "$arch" "$DESTDIR" ) || warn "falló: $name"
    else
      warn "omitida (no soportada): $name"
    fi
  done < <(list_tool_files)
}

usage() {
  cat >&2 <<EOF
${C_BOLD}install-tools${C_RESET} — instalador TUI de herramientas

Uso:
  ./install.sh                 Lanza el menú interactivo (TUI)
  ./install.sh <herramienta>   Instala una herramienta directamente
  ./install.sh --all           Instala todas las soportadas
  ./install.sh --list          Lista las herramientas disponibles
  ./install.sh -h | --help     Muestra esta ayuda
EOF
}

run_tui() {
  ensure_gum
  local os arch f name desc meta selectable=() selected
  os="$(detect_os)"; arch="$(detect_arch)"

  log "Plataforma detectada: ${C_BOLD}${os}/${arch}${C_RESET}"

  while IFS= read -r f; do
    meta="$(tool_meta "$f")"; name="${meta%%|*}"; desc="${meta#*|}"
    # shellcheck disable=SC1090
    if ( source "$f"; tool_supported "$os" "$arch" ); then
      # Display "name  desc"; the name is the first whitespace-delimited token.
      selectable+=("$(printf '%-12s %s' "$name" "$desc")")
    fi
  done < <(list_tool_files)

  [ "${#selectable[@]}" -gt 0 ] || die "no hay herramientas soportadas en ${os}/${arch}"

  selected="$(printf '%s\n' "${selectable[@]}" \
    | gum choose --no-limit --header="Selecciona herramientas a instalar:")" \
    || { warn "selección cancelada"; return 0; }

  [ -n "$selected" ] || { warn "no se seleccionó nada"; return 0; }

  gum confirm "¿Instalar: $(printf '%s\n' "$selected" | awk 'NF{print $1}' | tr '\n' ' ')?" \
    || { warn "cancelado"; return 0; }

  local line item file
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    item="${line%% *}"
    file="$(find_tool_file "$item")" || { warn "desconocida: $item"; continue; }
    # shellcheck disable=SC2016
    if gum spin --title="Instalando ${item}…" -- \
      bash -c 'source "$1"; tool_install "$2" "$3" "$4"' bash "$file" "$os" "$arch" "$DESTDIR"; then
      ok "$item instalado"
    else
      warn "$item falló"
    fi
  done <<< "$selected"
}

main() {
  require_cmd curl
  require_cmd gzip
  case "${1:-}" in
    -h|--help) usage ;;
    --list)    cmd_list ;;
    --all)     cmd_install_all ;;
    "")        run_tui ;;
    -*)        usage; die "opción desconocida: $1" ;;
    *)         cmd_install_one "$1" ;;
  esac
}

main "$@"
