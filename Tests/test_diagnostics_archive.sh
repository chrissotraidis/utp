#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$(mktemp -d /tmp/ut99-diagnostics-archive-test.XXXXXX)"
trap 'rm -rf "$out"' EXIT

xcrun swiftc \
  "$root/Sources/UT99Host/UT99DiagnosticsArchive.swift" \
  "$root/Tests/DiagnosticsArchiveTests.swift" \
  -o "$out/diagnostics-archive-tests"
"$out/diagnostics-archive-tests" "$out/diagnostics.zip"
unzip -t "$out/diagnostics.zip"
test "$(unzip -Z1 "$out/diagnostics.zip" | wc -l | tr -d ' ')" = 2
unzip -Z1 "$out/diagnostics.zip" | grep -Fx 'diagnostics.txt'
unzip -Z1 "$out/diagnostics.zip" | grep -Fx 'recovery/UT99-last-failure.json'
unzip -p "$out/diagnostics.zip" diagnostics.txt | grep -F '<home>/Library'
! unzip -p "$out/diagnostics.zip" diagnostics.txt | grep -Eq 'abc123|seekrit'
