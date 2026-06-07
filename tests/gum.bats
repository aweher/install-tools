#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/common.sh"
  source "$PROJECT_ROOT/lib/platform.sh"
  source "$PROJECT_ROOT/lib/github.sh"
  source "$PROJECT_ROOT/lib/installer.sh"
}

@test "gum_asset_arch maps canonical arches to gum tokens" {
  [ "$(gum_asset_arch amd64)" = "x86_64" ]
  [ "$(gum_asset_arch arm64)" = "arm64" ]
  [ "$(gum_asset_arch armv7)" = "armv7" ]
  [ "$(gum_asset_arch armv6)" = "armv6" ]
  [ "$(gum_asset_arch 386)" = "i386" ]
}

@test "gum_asset_arch fails on unknown arch" {
  run gum_asset_arch sparc
  [ "$status" -ne 0 ]
}

@test "install_gum_binary downloads, extracts and installs gum" {
  # curl stub: JSON for the API, a real tar.gz (matching gum's layout) for the asset.
  make_stub curl 'url="${!#}"; dest=""; while [ $# -gt 0 ]; do [ "$1" = "-o" ] && { dest="$2"; shift; }; shift; done
    case "$url" in
      *api.github.com*) echo "{\"tag_name\":\"v0.17.0\"}" ;;
      *)
        d="$(mktemp -d)"; sub="gum_0.17.0_Linux_x86_64"; mkdir -p "$d/$sub"
        printf "#!/bin/sh\necho gum 0.17.0\n" > "$d/$sub/gum"; chmod +x "$d/$sub/gum"
        tar -czf "$dest" -C "$d" "$sub"
        ;;
    esac'
  # Force a known platform so the asset name is deterministic.
  detect_os()   { echo "linux"; }
  detect_arch() { echo "amd64"; }

  destdir="$BATS_TEST_TMPDIR/bin"; mkdir -p "$destdir"
  DESTDIR="$destdir" run install_gum_binary
  [ "$status" -eq 0 ]
  [ -x "$destdir/gum" ]
}
