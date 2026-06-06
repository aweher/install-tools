#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/common.sh"
}

@test "die exits non-zero and prints to stderr" {
  run bash -c "source '$PROJECT_ROOT/lib/common.sh'; die 'boom'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"boom"* ]]
}

@test "require_cmd succeeds for existing command" {
  run require_cmd bash
  [ "$status" -eq 0 ]
}

@test "require_cmd fails for missing command" {
  run require_cmd this_command_does_not_exist_xyz
  [ "$status" -ne 0 ]
  [[ "$output" == *"this_command_does_not_exist_xyz"* ]]
}
