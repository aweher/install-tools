#!/usr/bin/env bats

load test_helper

setup() {
  source "$PROJECT_ROOT/lib/platform.sh"
}

@test "detect_os maps Linux" {
  [ "$(detect_os Linux)" = "linux" ]
}

@test "detect_os maps Darwin" {
  [ "$(detect_os Darwin)" = "darwin" ]
}

@test "detect_os fails on unknown" {
  run detect_os Plan9
  [ "$status" -ne 0 ]
}

@test "detect_arch maps x86_64 to amd64" {
  [ "$(detect_arch x86_64)" = "amd64" ]
}

@test "detect_arch maps aarch64 to arm64" {
  [ "$(detect_arch aarch64)" = "arm64" ]
}

@test "detect_arch maps arm64 to arm64" {
  [ "$(detect_arch arm64)" = "arm64" ]
}

@test "detect_arch maps armv7l to armv7" {
  [ "$(detect_arch armv7l)" = "armv7" ]
}

@test "detect_arch maps armv6l to armv6" {
  [ "$(detect_arch armv6l)" = "armv6" ]
}

@test "detect_arch maps i686 to 386" {
  [ "$(detect_arch i686)" = "386" ]
}

@test "detect_arch fails on unknown" {
  run detect_arch sparc
  [ "$status" -ne 0 ]
}
