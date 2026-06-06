#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/installer.sh"
}

@test "install_binary installs into a writable dir without privilege" {
  src="$BATS_TEST_TMPDIR/chisel"
  echo "#!/bin/sh" > "$src"
  destdir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$destdir"
  run install_binary "$src" chisel "$destdir"
  [ "$status" -eq 0 ]
  [ -x "$destdir/chisel" ]
}

@test "install_binary fails when source missing" {
  run install_binary "$BATS_TEST_TMPDIR/nope" chisel "$BATS_TEST_TMPDIR"
  [ "$status" -ne 0 ]
}
