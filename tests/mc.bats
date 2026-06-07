#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/common.sh"
  source "$PROJECT_ROOT/lib/platform.sh"
  source "$PROJECT_ROOT/lib/github.sh"
  source "$PROJECT_ROOT/lib/installer.sh"
  source "$PROJECT_ROOT/tools/mc.sh"
}

@test "mc exposes required contract" {
  [ "$TOOL_NAME" = "mc" ]
  [ -n "$TOOL_DESC" ]
  declare -f tool_supported >/dev/null
  declare -f tool_install >/dev/null
}

@test "mc supports linux/amd64 and darwin/arm64" {
  run tool_supported linux amd64
  [ "$status" -eq 0 ]
  run tool_supported darwin arm64
  [ "$status" -eq 0 ]
}

@test "tool_install pipes the arreg.la minio script to bash" {
  export CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
  : > "$CURL_LOG"
  make_stub curl 'printf "%s\n" "$*" >> "'"$BATS_TEST_TMPDIR"'/curl.log"; echo ":"'
  MC_SKIP_VERIFY=1 run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]
  grep -q "https://minioclient-install.arreg.la" "$CURL_LOG"
}
