#!/usr/bin/env bash
# Tool definition: acme.sh (acmesh-official/acme.sh).
# Contract: TOOL_NAME, TOOL_DESC, tool_supported, tool_install.
#
# acme.sh is a pure-shell ACME/Let's Encrypt client, not a release binary.
# We run its own `--install`, which sets up ~/.acme.sh, the shell alias and an
# auto-renew cron job. The `destdir` argument is therefore ignored (acme.sh is
# always installed per-user under $HOME/.acme.sh). Set ACME_SH_EMAIL to register
# an account email during install.

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
TOOL_NAME="acme.sh"
# shellcheck disable=SC2034
TOOL_DESC="ACME/Let's Encrypt client; instala con --install (~/.acme.sh + cron)"

ACME_REPO="acmesh-official/acme.sh"

# tool_supported <os> <arch> -> 0 if supported.
# acme.sh is pure POSIX shell, so every OS/arch we detect can run it.
tool_supported() {
  local os="$1" arch="$2"
  case "$os" in
    linux|darwin)
      case "$arch" in amd64|arm64|armv7|armv6|386) return 0 ;; esac ;;
  esac
  return 1
}

# acme_asset_url <version> -> source tarball URL for the given tag.
acme_asset_url() {
  local v="$1"
  echo "https://github.com/${ACME_REPO}/archive/refs/tags/${v}.tar.gz"
}

# tool_install <os> <arch> [destdir]
# destdir is accepted for contract compatibility but ignored: acme.sh installs
# itself into $HOME/.acme.sh.
tool_install() {
  # destdir accepted for contract compatibility but ignored (see header).
  # shellcheck disable=SC2034
  local os="$1" arch="$2" destdir="${3:-/usr/local/bin}"
  tool_supported "$os" "$arch" || die "acme.sh no soporta ${os}/${arch}"
  require_cmd tar

  local version url tmp
  version="$(latest_release "$ACME_REPO")"
  url="$(acme_asset_url "$version")"
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN EXIT

  log "descargando acme.sh v${version}"
  download_to "$url" "$tmp/acme.tar.gz"
  mkdir -p "$tmp/src"
  tar -xzf "$tmp/acme.tar.gz" -C "$tmp/src" --strip-components=1 \
    || die "fallo al descomprimir acme.sh"
  [ -f "$tmp/src/acme.sh" ] || die "no se encontró acme.sh en el archivo descargado"

  local args=(--install)
  if [ -n "${ACME_SH_EMAIL:-}" ]; then
    args+=(-m "$ACME_SH_EMAIL")
  else
    warn "ACME_SH_EMAIL no definido; acme.sh se instalará sin email de cuenta"
  fi

  log "ejecutando acme.sh --install (instala en ~/.acme.sh, configura cron)"
  ( cd "$tmp/src" && sh ./acme.sh "${args[@]}" ) \
    || die "fallo al instalar acme.sh"

  if [ -z "${ACME_SKIP_VERIFY:-}" ]; then
    if sh "$HOME/.acme.sh/acme.sh" --version >/dev/null 2>&1; then
      ok "acme.sh v${version} verificado (~/.acme.sh)"
    else
      warn "acme.sh instalado pero la verificación falló"
    fi
  fi
}
