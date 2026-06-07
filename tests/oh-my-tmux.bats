#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/common.sh"
  source "$PROJECT_ROOT/lib/platform.sh"
  source "$PROJECT_ROOT/lib/github.sh"
  source "$PROJECT_ROOT/lib/installer.sh"
  source "$PROJECT_ROOT/tools/oh-my-tmux.sh"
}

# Fake `git clone <url> <dest>` that materializes the repo files.
_stub_git() {
  make_stub git 'dest="${!#}"; mkdir -p "$dest"; printf "tmux conf\n" > "$dest/.tmux.conf"; printf "local conf\n" > "$dest/.tmux.conf.local"'
}

@test "oh-my-tmux exposes required contract" {
  [ "$TOOL_NAME" = "oh-my-tmux" ]
  [ -n "$TOOL_DESC" ]
  declare -f tool_supported >/dev/null
  declare -f tool_install >/dev/null
}

@test "oh-my-tmux is supported on linux and darwin" {
  run tool_supported linux amd64
  [ "$status" -eq 0 ]
  run tool_supported darwin arm64
  [ "$status" -eq 0 ]
}

@test "tool_install clones, symlinks and seeds the local config" {
  _stub_git
  make_stub tmux 'exit 0'
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home"

  OH_MY_TMUX_HOME="$home" OH_MY_TMUX_SKIP_INSTALL=1 \
    run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]

  [ -f "$home/.tmux/.tmux.conf" ]
  [ -L "$home/.tmux.conf" ]
  [ "$(readlink "$home/.tmux.conf")" = ".tmux/.tmux.conf" ]
  [ -f "$home/.tmux.conf.local" ]
  grep -q 'local conf' "$home/.tmux.conf.local"
}

@test "tool_install does not overwrite an existing .tmux.conf.local" {
  _stub_git
  make_stub tmux 'exit 0'
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home"
  printf 'MY CUSTOM LOCAL\n' > "$home/.tmux.conf.local"

  OH_MY_TMUX_HOME="$home" OH_MY_TMUX_SKIP_INSTALL=1 \
    run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]
  grep -q 'MY CUSTOM LOCAL' "$home/.tmux.conf.local"
}

@test "tool_install is idempotent (skips clone when ~/.tmux exists)" {
  _stub_git
  make_stub tmux 'exit 0'
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home"

  OH_MY_TMUX_HOME="$home" OH_MY_TMUX_SKIP_INSTALL=1 \
    run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]
  # Mark the repo to prove the second run does not re-clone over it.
  printf 'EDITED\n' >> "$home/.tmux/.tmux.conf"

  OH_MY_TMUX_HOME="$home" OH_MY_TMUX_SKIP_INSTALL=1 \
    run tool_install linux amd64 /usr/local/bin
  [ "$status" -eq 0 ]
  grep -q 'EDITED' "$home/.tmux/.tmux.conf"
}

@test "tool_install refuses an unsupported platform" {
  run tool_install plan9 amd64 /usr/local/bin
  [ "$status" -ne 0 ]
}
