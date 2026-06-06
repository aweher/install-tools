#!/usr/bin/env bash
# Platform detection. Both functions accept an optional raw value as $1
# (defaults to uname output) so they are unit-testable.

# shellcheck source=/dev/null
[ -n "${C_RED+x}" ] || source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# detect_os [raw] -> linux|darwin (die on unsupported)
detect_os() {
  local raw="${1:-$(uname -s)}"
  case "$raw" in
    Linux)  echo "linux" ;;
    Darwin) echo "darwin" ;;
    *) die "sistema operativo no soportado: $raw" ;;
  esac
}

# detect_arch [raw] -> amd64|arm64|armv7|armv6|386 (die on unsupported)
detect_arch() {
  local raw="${1:-$(uname -m)}"
  case "$raw" in
    x86_64|amd64)   echo "amd64" ;;
    aarch64|arm64)  echo "arm64" ;;
    armv7l|armv7)   echo "armv7" ;;
    armv6l|armv6)   echo "armv6" ;;
    i386|i686|386)  echo "386" ;;
    *) die "arquitectura no soportada: $raw" ;;
  esac
}
