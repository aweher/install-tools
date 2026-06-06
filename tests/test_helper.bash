# Shared bats setup. PROJECT_ROOT points at repo root.
PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
export PROJECT_ROOT

# make_stub <name> <body> : create an executable stub in a tmp bin on PATH.
make_stub() {
  local name="$1" body="$2"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/$name" <<EOF
#!/usr/bin/env bash
$body
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/$name"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}
