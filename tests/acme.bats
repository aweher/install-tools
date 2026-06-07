#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/common.sh"
  source "$PROJECT_ROOT/lib/platform.sh"
  source "$PROJECT_ROOT/lib/github.sh"
  source "$PROJECT_ROOT/lib/installer.sh"
  source "$PROJECT_ROOT/tools/acme.sh"
}

@test "acme.sh exposes required contract" {
  [ "$TOOL_NAME" = "acme.sh" ]
  [ -n "$TOOL_DESC" ]
  declare -f tool_supported >/dev/null
  declare -f tool_install >/dev/null
}

@test "acme.sh is supported on every OS/arch (pure shell)" {
  run tool_supported linux amd64
  [ "$status" -eq 0 ]
  run tool_supported darwin arm64
  [ "$status" -eq 0 ]
  run tool_supported linux armv6
  [ "$status" -eq 0 ]
  run tool_supported darwin amd64
  [ "$status" -eq 0 ]
}

@test "acme_asset_url builds the expected tarball url" {
  run acme_asset_url 3.1.3
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/acmesh-official/acme.sh/archive/refs/tags/3.1.3.tar.gz" ]
}

@test "tool_install downloads the tarball and runs acme.sh --install" {
  # Build a fake acme.sh source tree and tarball.
  mkdir -p "$BATS_TEST_TMPDIR/acme.sh-3.1.3"
  cat > "$BATS_TEST_TMPDIR/acme.sh-3.1.3/acme.sh" <<'SH'
#!/usr/bin/env sh
echo "fake acme.sh invoked with: $*" >> "$ACME_TEST_LOG"
SH
  chmod +x "$BATS_TEST_TMPDIR/acme.sh-3.1.3/acme.sh"
  tar -czf "$BATS_TEST_TMPDIR/acme.tar.gz" -C "$BATS_TEST_TMPDIR" acme.sh-3.1.3

  make_stub curl 'dest=""; while [ $# -gt 0 ]; do [ "$1" = "-o" ] && { dest="$2"; shift; }; shift; done; [ -n "$dest" ] && cp "'"$BATS_TEST_TMPDIR"'/acme.tar.gz" "$dest"'
  latest_release() { echo "3.1.3"; }

  export ACME_TEST_LOG="$BATS_TEST_TMPDIR/acme.log"
  : > "$ACME_TEST_LOG"
  ACME_SKIP_VERIFY=1 run tool_install linux amd64 "$BATS_TEST_TMPDIR/bin"
  [ "$status" -eq 0 ]
  grep -q -- "--install" "$ACME_TEST_LOG"
}

@test "tool_install passes -m when ACME_SH_EMAIL is set" {
  mkdir -p "$BATS_TEST_TMPDIR/acme.sh-3.1.3"
  cat > "$BATS_TEST_TMPDIR/acme.sh-3.1.3/acme.sh" <<'SH'
#!/usr/bin/env sh
echo "fake acme.sh invoked with: $*" >> "$ACME_TEST_LOG"
SH
  chmod +x "$BATS_TEST_TMPDIR/acme.sh-3.1.3/acme.sh"
  tar -czf "$BATS_TEST_TMPDIR/acme.tar.gz" -C "$BATS_TEST_TMPDIR" acme.sh-3.1.3

  make_stub curl 'dest=""; while [ $# -gt 0 ]; do [ "$1" = "-o" ] && { dest="$2"; shift; }; shift; done; [ -n "$dest" ] && cp "'"$BATS_TEST_TMPDIR"'/acme.tar.gz" "$dest"'
  latest_release() { echo "3.1.3"; }

  export ACME_TEST_LOG="$BATS_TEST_TMPDIR/acme.log"
  : > "$ACME_TEST_LOG"
  ACME_SH_EMAIL="me@example.com" ACME_SKIP_VERIFY=1 run tool_install linux amd64 "$BATS_TEST_TMPDIR/bin"
  [ "$status" -eq 0 ]
  grep -q -- "-m me@example.com" "$ACME_TEST_LOG"
}
