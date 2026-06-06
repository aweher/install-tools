#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/common.sh"
  source "$PROJECT_ROOT/lib/platform.sh"
  source "$PROJECT_ROOT/lib/github.sh"
  source "$PROJECT_ROOT/lib/installer.sh"
  source "$PROJECT_ROOT/tools/chisel.sh"
}

@test "chisel exposes required contract" {
  [ "$TOOL_NAME" = "chisel" ]
  [ -n "$TOOL_DESC" ]
  declare -f tool_supported >/dev/null
  declare -f tool_install >/dev/null
}

@test "chisel supports linux/amd64 and darwin/arm64" {
  run tool_supported linux amd64
  [ "$status" -eq 0 ]
  run tool_supported darwin arm64
  [ "$status" -eq 0 ]
}

@test "chisel does not support darwin/armv7" {
  run tool_supported darwin armv7
  [ "$status" -ne 0 ]
}

@test "chisel_asset_url builds the expected .gz url" {
  run chisel_asset_url 1.11.5 linux amd64
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/jpillora/chisel/releases/download/v1.11.5/chisel_1.11.5_linux_amd64.gz" ]
}

@test "tool_install downloads, gunzips and installs into destdir" {
  make_stub curl 'dest=""; while [ $# -gt 0 ]; do [ "$1" = "-o" ] && { dest="$2"; shift; }; shift; done; if [ -n "$dest" ]; then printf "BIN" | gzip -c > "$dest"; fi'
  latest_release() { echo "1.11.5"; }
  destdir="$BATS_TEST_TMPDIR/bin"; mkdir -p "$destdir"
  CHISEL_SKIP_VERIFY=1 run tool_install linux amd64 "$destdir"
  [ "$status" -eq 0 ]
  [ -x "$destdir/chisel" ]
}
