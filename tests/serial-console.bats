#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/common.sh"
  source "$PROJECT_ROOT/lib/platform.sh"
  source "$PROJECT_ROOT/lib/github.sh"
  source "$PROJECT_ROOT/lib/installer.sh"
  source "$PROJECT_ROOT/tools/serial-console.sh"
}

@test "serial-console exposes required contract" {
  [ "$TOOL_NAME" = "serial-console" ]
  [ -n "$TOOL_DESC" ]
  declare -f tool_supported >/dev/null
  declare -f tool_install >/dev/null
}

@test "serial-console is supported on linux but not darwin" {
  run tool_supported linux amd64
  [ "$status" -eq 0 ]
  run tool_supported darwin arm64
  [ "$status" -ne 0 ]
}

@test "grub edit replaces GRUB_CMDLINE_LINUX, backs up once and is idempotent" {
  make_stub sudo 'exec "$@"'
  local grub="$BATS_TEST_TMPDIR/grub"
  printf 'GRUB_DEFAULT=0\nGRUB_CMDLINE_LINUX="quiet"\nGRUB_TIMEOUT=5\n' > "$grub"

  ( export SERIAL_GRUB_FILE="$grub" SERIAL_SKIP_GETTY=1 SERIAL_SKIP_GRUB_REGEN=1 \
      SERIAL_SKIP_VERIFY=1
    tool_install linux amd64 /usr/local/bin )

  grep -q '^GRUB_CMDLINE_LINUX="quiet console=tty0 console=ttyS0,115200"$' "$grub"
  # Other lines preserved.
  grep -q '^GRUB_DEFAULT=0$' "$grub"
  grep -q '^GRUB_TIMEOUT=5$' "$grub"
  # Backup holds the original.
  [ -f "$grub.000" ]
  grep -q '^GRUB_CMDLINE_LINUX="quiet"$' "$grub.000"

  # Second run: no duplicate line, backup untouched.
  ( export SERIAL_GRUB_FILE="$grub" SERIAL_SKIP_GETTY=1 SERIAL_SKIP_GRUB_REGEN=1 \
      SERIAL_SKIP_VERIFY=1
    tool_install linux amd64 /usr/local/bin )
  local n
  n="$(grep -c '^GRUB_CMDLINE_LINUX=' "$grub")"
  [ "$n" -eq 1 ]
  grep -q '^GRUB_CMDLINE_LINUX="quiet"$' "$grub.000"
}

@test "grub edit appends GRUB_CMDLINE_LINUX when missing" {
  make_stub sudo 'exec "$@"'
  local grub="$BATS_TEST_TMPDIR/grub"
  printf 'GRUB_DEFAULT=0\n' > "$grub"

  ( export SERIAL_GRUB_FILE="$grub" SERIAL_SKIP_GETTY=1 SERIAL_SKIP_GRUB_REGEN=1 \
      SERIAL_SKIP_VERIFY=1
    tool_install linux amd64 /usr/local/bin )
  grep -q '^GRUB_CMDLINE_LINUX="quiet console=tty0 console=ttyS0,115200"$' "$grub"
}

@test "upstart mode writes a getty conf per port" {
  make_stub sudo 'exec "$@"'
  local initdir="$BATS_TEST_TMPDIR/init"

  ( export SERIAL_FORCE_UPSTART=1 SERIAL_INIT_DIR="$initdir" SERIAL_SKIP_GETTY=1 \
      SERIAL_SKIP_GRUB=1 SERIAL_SKIP_VERIFY=1 SERIAL_PORTS="ttyS0 ttyS1"
    tool_install linux amd64 /usr/local/bin )

  [ -f "$initdir/ttyS0.conf" ]
  [ -f "$initdir/ttyS1.conf" ]
  grep -q '^# ttyS0 - getty$' "$initdir/ttyS0.conf"
  grep -q '^exec /sbin/getty -L 115200 ttyS0 vt102$' "$initdir/ttyS0.conf"
  grep -q '^exec /sbin/getty -L 115200 ttyS1 vt102$' "$initdir/ttyS1.conf"
}

@test "SERIAL_BAUD and SERIAL_PORTS are honored" {
  make_stub sudo 'exec "$@"'
  local initdir="$BATS_TEST_TMPDIR/init"
  local grub="$BATS_TEST_TMPDIR/grub"
  printf 'GRUB_CMDLINE_LINUX="quiet"\n' > "$grub"

  ( export SERIAL_FORCE_UPSTART=1 SERIAL_INIT_DIR="$initdir" SERIAL_SKIP_GETTY=1 \
      SERIAL_GRUB_FILE="$grub" SERIAL_SKIP_GRUB_REGEN=1 SERIAL_SKIP_VERIFY=1 \
      SERIAL_PORTS="ttyS1" SERIAL_BAUD=9600
    tool_install linux amd64 /usr/local/bin )

  grep -q '^exec /sbin/getty -L 9600 ttyS1 vt102$' "$initdir/ttyS1.conf"
  [ ! -f "$initdir/ttyS0.conf" ]
  # GRUB console uses the first (only) port at the chosen baud.
  grep -q '^GRUB_CMDLINE_LINUX="quiet console=tty0 console=ttyS1,9600"$' "$grub"
}

@test "tool_install refuses darwin" {
  run tool_install darwin arm64 /usr/local/bin
  [ "$status" -ne 0 ]
}
