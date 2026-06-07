#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/common.sh"
  source "$PROJECT_ROOT/lib/platform.sh"
  source "$PROJECT_ROOT/lib/github.sh"
  source "$PROJECT_ROOT/lib/installer.sh"
  source "$PROJECT_ROOT/tools/filebeat.sh"
}

@test "filebeat exposes required contract" {
  [ "$TOOL_NAME" = "filebeat" ]
  [ -n "$TOOL_DESC" ]
  declare -f tool_supported >/dev/null
  declare -f tool_install >/dev/null
}

@test "filebeat is supported on linux but not darwin" {
  run tool_supported linux amd64
  [ "$status" -eq 0 ]
  run tool_supported darwin arm64
  [ "$status" -ne 0 ]
}

@test "tool_install renders config, maps loghost and backs up the stock file" {
  make_stub sudo 'exec "$@"'
  make_stub filebeat 'exit 0'

  local fbdir="$BATS_TEST_TMPDIR/filebeat"
  local hosts="$BATS_TEST_TMPDIR/hosts"
  mkdir -p "$fbdir"
  printf 'STOCK\n' > "$fbdir/filebeat.yml"   # pretend apt installed a default
  : > "$hosts"

  FILEBEAT_DIR="$fbdir" FILEBEAT_HOSTS_FILE="$hosts" \
  FILEBEAT_SKIP_REPO=1 FILEBEAT_SKIP_SERVICE=1 FILEBEAT_SKIP_VERIFY=1 \
    run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]

  # New config written, output points at loghost:5044, no leftover placeholder.
  grep -q -- "- loghost:5044" "$fbdir/filebeat.yml"
  ! grep -q '{{GRAYLOG_HOST}}' "$fbdir/filebeat.yml"
  # ${path.config} preserved literally (not expanded).
  grep -q 'path: ${path.config}/modules.d/\*.yml' "$fbdir/filebeat.yml"
  # Stock file backed up.
  [ -f "$fbdir/filebeat.yml.000" ]
  grep -q 'STOCK' "$fbdir/filebeat.yml.000"
  # /etc/hosts mapping appended.
  grep -q '127.5.1.4 loghost' "$hosts"
}

@test "tool_install honors FILEBEAT_GRAYLOG_HOST and skips hosts mapping" {
  make_stub sudo 'exec "$@"'
  make_stub filebeat 'exit 0'

  local fbdir="$BATS_TEST_TMPDIR/filebeat"
  local hosts="$BATS_TEST_TMPDIR/hosts"
  : > "$hosts"

  FILEBEAT_DIR="$fbdir" FILEBEAT_HOSTS_FILE="$hosts" \
  FILEBEAT_GRAYLOG_HOST="graylog.example.com" \
  FILEBEAT_SKIP_REPO=1 FILEBEAT_SKIP_SERVICE=1 FILEBEAT_SKIP_VERIFY=1 \
    run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]
  grep -q -- "- graylog.example.com:5044" "$fbdir/filebeat.yml"
  # Custom host != loghost, so /etc/hosts is left untouched.
  ! grep -q 'loghost' "$hosts"
}

@test "tool_install refuses darwin" {
  run tool_install darwin arm64 /usr/local/bin
  [ "$status" -ne 0 ]
}
