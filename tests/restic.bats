#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/common.sh"
  source "$PROJECT_ROOT/lib/platform.sh"
  source "$PROJECT_ROOT/lib/github.sh"
  source "$PROJECT_ROOT/lib/installer.sh"
  source "$PROJECT_ROOT/tools/restic.sh"
}

@test "restic exposes required contract" {
  [ "$TOOL_NAME" = "restic" ]
  [ -n "$TOOL_DESC" ]
  declare -f tool_supported >/dev/null
  declare -f tool_install >/dev/null
}

@test "restic supports linux/amd64 and darwin/arm64" {
  run tool_supported linux amd64
  [ "$status" -eq 0 ]
  run tool_supported darwin arm64
  [ "$status" -eq 0 ]
}

@test "tool_install pipes the arreg.la script to bash" {
  export CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
  : > "$CURL_LOG"
  make_stub curl 'printf "%s\n" "$*" >> "'"$BATS_TEST_TMPDIR"'/curl.log"; echo ":"'
  RESTIC_SKIP_APT_PIN=1 RESTIC_SKIP_VERIFY=1 run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]
  grep -q "https://restic-install.arreg.la" "$CURL_LOG"
}
