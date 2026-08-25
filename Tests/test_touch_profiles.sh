#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
output="$(mktemp -d)/touch-profile-tests"
xcrun swiftc \
  "$root/Sources/UT99Host/UT99TouchConfiguration.swift" \
  "$root/Sources/UT99Host/UT99TouchProfileStore.swift" \
  "$root/Tests/TouchProfileStoreTests.swift" \
  -o "$output"
"$output"
