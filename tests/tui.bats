#!/usr/bin/env bats

load test_helper

setup() { source "$PROJECT_ROOT/lib/common.sh"; }

@test "ensure_gum succeeds when gum already present" {
  make_stub gum 'echo gum-stub'
  run ensure_gum
  [ "$status" -eq 0 ]
}

@test "run_tui installs the selected tool using gum stubs" {
  # gum choose -> echo selection; gum confirm -> success; gum spin -> run -- cmd
  make_stub gum 'case "$1" in
    choose) echo "chisel" ;;
    confirm) exit 0 ;;
    spin) shift; while [ "$1" != "--" ] && [ $# -gt 0 ]; do shift; done; shift; "$@" ;;
    style|format) shift; printf "%s\n" "$*" ;;
    *) exit 0 ;;
  esac'
  # Stub the actual install so no network is hit.
  make_stub curl 'dest=""; while [ $# -gt 0 ]; do [ "$1" = "-o" ] && { dest="$2"; shift; }; shift; done; [ -n "$dest" ] && printf BIN | gzip -c > "$dest"'
  destdir="$BATS_TEST_TMPDIR/bin"; mkdir -p "$destdir"
  run env INSTALL_TOOLS_DESTDIR="$destdir" CHISEL_SKIP_VERIFY=1 \
    bash "$PROJECT_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [ -x "$destdir/chisel" ]
}
