#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/common.sh"
  source "$PROJECT_ROOT/lib/platform.sh"
  source "$PROJECT_ROOT/lib/github.sh"
  source "$PROJECT_ROOT/lib/installer.sh"
  source "$PROJECT_ROOT/tools/basics.sh"
}

@test "basics exposes required contract" {
  [ "$TOOL_NAME" = "basics" ]
  [ -n "$TOOL_DESC" ]
  declare -f tool_supported >/dev/null
  declare -f tool_install >/dev/null
}

@test "basics is supported on linux but not darwin" {
  run tool_supported linux amd64
  [ "$status" -eq 0 ]
  run tool_supported darwin arm64
  [ "$status" -ne 0 ]
}

@test "package list has no duplicates" {
  local dupes
  dupes="$(printf '%s\n' "${BASICS_PACKAGES[@]}" | sort | uniq -d)"
  [ -z "$dupes" ]
}

@test "tool_install runs apt-get update and installs the package set" {
  export APT_LOG="$BATS_TEST_TMPDIR/apt.log"
  : > "$APT_LOG"
  make_stub sudo 'exec "$@"'
  make_stub apt-get 'printf "%s\n" "$*" >> "'"$BATS_TEST_TMPDIR"'/apt.log"'

  run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]
  grep -q '^update' "$APT_LOG"
  grep -q 'install -y' "$APT_LOG"
  # A few representative packages must be part of the install invocation.
  grep -q 'ripgrep' "$APT_LOG"
  grep -q 'fail2ban' "$APT_LOG"
  grep -q 'vim' "$APT_LOG"
}

@test "tool_install refuses darwin" {
  run tool_install darwin arm64 /usr/local/bin
  [ "$status" -ne 0 ]
}

@test "tool_install dies without apt-get" {
  # Source first (absolute paths, no PATH needed), then blank PATH so apt-get
  # is not found. die uses only shell builtins, so it still works.
  run bash -c '
    source "'"$PROJECT_ROOT"'/lib/common.sh"
    source "'"$PROJECT_ROOT"'/lib/platform.sh"
    source "'"$PROJECT_ROOT"'/lib/github.sh"
    source "'"$PROJECT_ROOT"'/lib/installer.sh"
    source "'"$PROJECT_ROOT"'/tools/basics.sh"
    PATH="/nonexistent"
    tool_install linux amd64 /usr/local/bin'
  [ "$status" -ne 0 ]
}
