#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/common.sh"
  source "$PROJECT_ROOT/lib/platform.sh"
  source "$PROJECT_ROOT/lib/github.sh"
  source "$PROJECT_ROOT/lib/installer.sh"
  source "$PROJECT_ROOT/tools/bash-tuning.sh"
}

@test "bash-tuning exposes required contract" {
  [ "$TOOL_NAME" = "bash-tuning" ]
  [ -n "$TOOL_DESC" ]
  declare -f tool_supported >/dev/null
  declare -f tool_install >/dev/null
}

@test "bash-tuning is supported on linux but not darwin" {
  run tool_supported linux amd64
  [ "$status" -eq 0 ]
  run tool_supported darwin arm64
  [ "$status" -ne 0 ]
}

@test "tool_install writes the three dotfiles with markers and content" {
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home"
  BASH_TUNING_HOME="$home" run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]

  grep -qF 'install-tools bash tuning' "$home/.bashrc"
  grep -q 'HISTSIZE=100000' "$home/.bashrc"
  grep -q 'source "$HOME/.bash_functions"' "$home/.bashrc"

  grep -q "alias ip='ip -color'" "$home/.bash_aliases"
  grep -q "alias \.\.\.='cd ../..'" "$home/.bash_aliases"

  grep -q 'crearvenv()' "$home/.bash_functions"
  grep -q 'mygrants()' "$home/.bash_functions"
  # Runtime variables/escapes must be preserved literally (not expanded).
  grep -qF '.venv-${HOSTNAME}' "$home/.bash_functions"
  grep -qF 'SHOW GRANTS FOR' "$home/.bash_functions"
  grep -qF 's/\(GRANT .*\)/\1;/' "$home/.bash_functions"
}

@test "tool_install is idempotent (no duplicate blocks on re-run)" {
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home"
  BASH_TUNING_HOME="$home" run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]
  BASH_TUNING_HOME="$home" run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]

  local n
  n="$(grep -cF "$BASH_TUNING_BEGIN" "$home/.bashrc")"
  [ "$n" -eq 1 ]
  n="$(grep -cF "$BASH_TUNING_BEGIN" "$home/.bash_aliases")"
  [ "$n" -eq 1 ]
  n="$(grep -cF "$BASH_TUNING_BEGIN" "$home/.bash_functions")"
  [ "$n" -eq 1 ]
}

@test "tool_install preserves pre-existing user content" {
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home"
  printf 'export MY_CUSTOM=1\n' > "$home/.bashrc"
  BASH_TUNING_HOME="$home" run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]
  grep -q 'export MY_CUSTOM=1' "$home/.bashrc"
  grep -qF 'install-tools bash tuning' "$home/.bashrc"
}

@test "tool_install refuses darwin" {
  run tool_install darwin arm64 /usr/local/bin
  [ "$status" -ne 0 ]
}
