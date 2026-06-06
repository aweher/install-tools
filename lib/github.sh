#!/usr/bin/env bash
# GitHub release helpers.

# shellcheck source=/dev/null
[ -n "${C_RED+x}" ] || source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# latest_release <owner/repo> -> version without leading "v"
latest_release() {
  local repo="$1" json tag
  json="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest")" \
    || die "no se pudo consultar releases de ${repo}"
  tag="$(printf '%s' "$json" \
    | grep -m1 '"tag_name"' \
    | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')" || true
  if [ -z "$tag" ]; then
    local msg
    msg="$(printf '%s' "$json" | grep -m1 '"message"' \
      | sed -E 's/.*"message"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
    [ -n "$msg" ] && die "GitHub API (${repo}): ${msg}"
    die "no se encontró tag_name en releases de ${repo}"
  fi
  echo "${tag#v}"
}

# download_to <url> <dest>
download_to() {
  local url="$1" dest="$2"
  curl -fL --retry 3 -o "$dest" "$url" \
    || die "fallo al descargar: $url"
}
