#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$(mktemp -d /tmp/ut99-runtime-recovery-test.XXXXXX)"
trap 'rm -rf "$out"' EXIT

xcrun swiftc \
  "$root/Sources/UT99Host/UT99RuntimeRecovery.swift" \
  "$root/Tests/RuntimeRecoveryTests.swift" \
  -o "$out/runtime-recovery-tests"
"$out/runtime-recovery-tests"
