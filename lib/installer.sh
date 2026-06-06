#!/usr/bin/env bash
# Binary installation into a destination dir (default /usr/local/bin).

# shellcheck source=/dev/null
[ -n "${C_RED+x}" ] || source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# install_binary <src> <name> [destdir]
# Uses run_priv (sudo) only when destdir is not writable by current user.
install_binary() {
  local src="$1" name="$2" destdir="${3:-/usr/local/bin}"
  [ -f "$src" ] || die "binario fuente no encontrado: $src"
  chmod +x "$src"
  if [ -w "$destdir" ] || { [ ! -e "$destdir" ] && [ -w "$(dirname "$destdir")" ]; }; then
    mkdir -p "$destdir"
    install -m 0755 "$src" "$destdir/$name"
  else
    run_priv mkdir -p "$destdir"
    run_priv install -m 0755 "$src" "$destdir/$name"
  fi
  ok "instalado: $destdir/$name"
}
