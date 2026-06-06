#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/github.sh"
}

@test "latest_release parses tag_name and strips leading v" {
  make_stub curl 'echo "{ \"tag_name\": \"v1.11.5\", \"other\": 1 }"'
  run latest_release jpillora/chisel
  [ "$status" -eq 0 ]
  [ "$output" = "1.11.5" ]
}

@test "latest_release fails when curl returns no tag" {
  make_stub curl 'echo "{}"'
  run latest_release jpillora/chisel
  [ "$status" -ne 0 ]
}

@test "download_to writes destination and fails on curl error" {
  make_stub curl 'dest=""; while [ $# -gt 0 ]; do [ "$1" = "-o" ] && { dest="$2"; shift; }; shift; done; echo data > "$dest"'
  run download_to "https://example.com/x.gz" "$BATS_TEST_TMPDIR/x.gz"
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/x.gz" ]
}

@test "download_to propagates curl failure" {
  make_stub curl 'exit 22'
  run download_to "https://example.com/x.gz" "$BATS_TEST_TMPDIR/y.gz"
  [ "$status" -ne 0 ]
}
