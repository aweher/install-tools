#!/usr/bin/env bats

load test_helper

@test "--help prints usage and exits 0" {
  run bash "$PROJECT_ROOT/install.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Uso:"* ]]
  [[ "$output" == *"--list"* ]]
}

@test "--list shows chisel" {
  run bash "$PROJECT_ROOT/install.sh" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"chisel"* ]]
}

@test "unknown tool name fails" {
  run bash "$PROJECT_ROOT/install.sh" not-a-real-tool
  [ "$status" -ne 0 ]
  [[ "$output" == *"not-a-real-tool"* ]]
}

@test "install <tool> honors INSTALL_TOOLS_DESTDIR" {
  make_stub curl 'url="${!#}"; dest=""; while [ $# -gt 0 ]; do [ "$1" = "-o" ] && { dest="$2"; shift; }; shift; done; case "$url" in *api.github.com*) echo "{\"tag_name\":\"v1.11.5\"}" ;; *) [ -n "$dest" ] && printf BIN | gzip -c > "$dest" ;; esac'
  destdir="$BATS_TEST_TMPDIR/bin"; mkdir -p "$destdir"
  run env INSTALL_TOOLS_DESTDIR="$destdir" CHISEL_SKIP_VERIFY=1 \
    bash "$PROJECT_ROOT/install.sh" chisel
  [ "$status" -eq 0 ]
  [ -x "$destdir/chisel" ]
}
