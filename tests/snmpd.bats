#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/common.sh"
  source "$PROJECT_ROOT/lib/platform.sh"
  source "$PROJECT_ROOT/lib/github.sh"
  source "$PROJECT_ROOT/lib/installer.sh"
  source "$PROJECT_ROOT/tools/snmpd.sh"
}

@test "snmpd exposes required contract" {
  [ "$TOOL_NAME" = "snmpd" ]
  [ -n "$TOOL_DESC" ]
  declare -f tool_supported >/dev/null
  declare -f tool_install >/dev/null
}

@test "snmpd is supported on linux but not darwin" {
  run tool_supported linux amd64
  [ "$status" -eq 0 ]
  run tool_supported darwin arm64
  [ "$status" -ne 0 ]
}

@test "_snmpd_resolve prefers env, then default when non-interactive" {
  run _snmpd_resolve "fromenv" "label" "thedefault"
  [ "$output" = "fromenv" ]
  # Non-interactive (no TTY under bats) falls back to the default.
  run _snmpd_resolve "" "label" "thedefault"
  [ "$output" = "thedefault" ]
}

@test "tool_install renders config from env params and writes defaults file" {
  make_stub sudo 'exec "$@"'
  local confdir="$BATS_TEST_TMPDIR/snmp"
  local deffile="$BATS_TEST_TMPDIR/default/snmpd"

  SNMPD_CONF_DIR="$confdir" SNMPD_DEFAULT_FILE="$deffile" \
  SNMPD_COMMUNITY="s3cr3t" \
  SNMPD_SYSLOCATION="Datacenter A" \
  SNMPD_SYSCONTACT="NOC Test <noc@test.io>" \
  SNMPD_SKIP_INSTALL=1 SNMPD_SKIP_DISTRO=1 SNMPD_SKIP_SERVICE=1 SNMPD_SKIP_VERIFY=1 \
    run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]

  grep -q '^rocommunity s3cr3t$' "$confdir/snmpd.conf"
  grep -q '^sysLocation Datacenter A$' "$confdir/snmpd.conf"
  grep -qF 'sysContact    NOC Test <noc@test.io>' "$confdir/snmpd.conf"
  # No leftover placeholders.
  ! grep -q '{{' "$confdir/snmpd.conf"
  # Static lines preserved.
  grep -qF 'extend distro /usr/local/bin/distro' "$confdir/snmpd.conf"
  # Defaults file written.
  grep -q '^SNMPDRUN=yes$' "$deffile"
}

@test "tool_install uses defaults when no env params provided" {
  make_stub sudo 'exec "$@"'
  local confdir="$BATS_TEST_TMPDIR/snmp"
  local deffile="$BATS_TEST_TMPDIR/default/snmpd"

  SNMPD_CONF_DIR="$confdir" SNMPD_DEFAULT_FILE="$deffile" \
  SNMPD_SKIP_INSTALL=1 SNMPD_SKIP_DISTRO=1 SNMPD_SKIP_SERVICE=1 SNMPD_SKIP_VERIFY=1 \
    run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]
  grep -q '^rocommunity executeorder66$' "$confdir/snmpd.conf"
  grep -q '^sysLocation The Galaxy$' "$confdir/snmpd.conf"
  grep -qF 'sysContact    NOC Ayuda.La <noc@ayuda.la>' "$confdir/snmpd.conf"
}

@test "tool_install backs up an existing snmpd.conf only once" {
  make_stub sudo 'exec "$@"'
  local confdir="$BATS_TEST_TMPDIR/snmp"
  local deffile="$BATS_TEST_TMPDIR/default/snmpd"
  mkdir -p "$confdir"
  printf 'ORIGINAL STOCK CONF\n' > "$confdir/snmpd.conf"

  # Two runs in subshells (env can't invoke a shell function).
  ( export SNMPD_CONF_DIR="$confdir" SNMPD_DEFAULT_FILE="$deffile" \
      SNMPD_SKIP_INSTALL=1 SNMPD_SKIP_DISTRO=1 SNMPD_SKIP_SERVICE=1 SNMPD_SKIP_VERIFY=1 \
      SNMPD_COMMUNITY="a"
    tool_install linux amd64 /usr/local/bin )
  ( export SNMPD_CONF_DIR="$confdir" SNMPD_DEFAULT_FILE="$deffile" \
      SNMPD_SKIP_INSTALL=1 SNMPD_SKIP_DISTRO=1 SNMPD_SKIP_SERVICE=1 SNMPD_SKIP_VERIFY=1 \
      SNMPD_COMMUNITY="b"
    tool_install linux amd64 /usr/local/bin )

  [ -f "$confdir/snmpd.conf.000" ]
  grep -q 'ORIGINAL STOCK CONF' "$confdir/snmpd.conf.000"
  grep -q '^rocommunity b$' "$confdir/snmpd.conf"
}

@test "tool_install refuses darwin" {
  run tool_install darwin arm64 /usr/local/bin
  [ "$status" -ne 0 ]
}
