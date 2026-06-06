#!/usr/bin/env bats

load test_helper

setup() { source "$PROJECT_ROOT/lib/common.sh"; }

@test "needs_bootstrap is true when tools dir absent" {
  run bash -c "
    source '$PROJECT_ROOT/lib/common.sh'
    SCRIPT_DIR='$BATS_TEST_TMPDIR/empty'
    mkdir -p \"\$SCRIPT_DIR\"
    source <(sed -n '/^needs_bootstrap()/,/^}/p' '$PROJECT_ROOT/install.sh')
    needs_bootstrap && echo YES || echo NO
  "
  [ "$output" = "YES" ]
}

@test "needs_bootstrap is false when tools dir present" {
  run bash -c "
    source '$PROJECT_ROOT/lib/common.sh'
    SCRIPT_DIR='$PROJECT_ROOT'
    source <(sed -n '/^needs_bootstrap()/,/^}/p' '$PROJECT_ROOT/install.sh')
    needs_bootstrap && echo YES || echo NO
  "
  [ "$output" = "NO" ]
}
