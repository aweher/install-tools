#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/common.sh"
  source "$PROJECT_ROOT/lib/platform.sh"
  source "$PROJECT_ROOT/lib/github.sh"
  source "$PROJECT_ROOT/lib/installer.sh"
  source "$PROJECT_ROOT/tools/maldet.sh"
}

@test "maldet exposes required contract" {
  [ "$TOOL_NAME" = "maldet" ]
  [ -n "$TOOL_DESC" ]
  declare -f tool_supported >/dev/null
  declare -f tool_install >/dev/null
}

@test "maldet is supported on linux but not darwin" {
  run tool_supported linux amd64
  [ "$status" -eq 0 ]
  run tool_supported linux arm64
  [ "$status" -eq 0 ]
  run tool_supported darwin arm64
  [ "$status" -ne 0 ]
}

@test "tool_install clones, runs install.sh and writes managed config" {
  # Fake git clone: create the destination with a no-op install.sh.
  make_stub git 'dest="${!#}"; mkdir -p "$dest"; printf "#!/usr/bin/env bash\nexit 0\n" > "$dest/install.sh"; chmod +x "$dest/install.sh"'
  # Neutralize privilege escalation so writes go to our test dir.
  make_stub sudo 'exec "$@"'

  local maldir="$BATS_TEST_TMPDIR/maldetect"
  MALDET_DIR="$maldir" \
  MALDET_EMAIL="test@example.com" \
  MALDET_SKIP_DEPS=1 MALDET_SKIP_UPDATE=1 MALDET_SKIP_SERVICE=1 MALDET_SKIP_VERIFY=1 \
    run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]
  [ -f "$maldir/conf.maldet" ]
  [ -f "$maldir/monitor_paths" ]
  grep -q 'email_addr="test@example.com"' "$maldir/conf.maldet"
  # Placeholder tokens must be fully substituted.
  ! grep -q '{{EMAIL}}' "$maldir/conf.maldet"
  ! grep -q '{{HOSTNAME}}' "$maldir/conf.maldet"
  grep -q '/var/www' "$maldir/monitor_paths"
}

@test "tool_install refuses darwin" {
  run tool_install darwin arm64 /usr/local/bin
  [ "$status" -ne 0 ]
}
