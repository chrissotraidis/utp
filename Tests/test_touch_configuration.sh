#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
temp_dir="$(mktemp -d /tmp/ut99-touch-configuration-test.XXXXXX)"
trap 'rm -rf "$temp_dir"' EXIT

xcrun swiftc \
  "$root/Sources/UT99Host/UT99TouchConfiguration.swift" \
  "$root/Tests/TouchConfigurationTests.swift" \
  -o "$temp_dir/ut99-touch-configuration-tests"
"$temp_dir/ut99-touch-configuration-tests"
