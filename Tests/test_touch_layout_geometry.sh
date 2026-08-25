#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
temp_dir="$(mktemp -d)"
output="$temp_dir/ut99-touch-layout-tests"
cp "$root/Tests/TouchLayoutGeometryTests.swift" "$temp_dir/main.swift"
xcrun swiftc \
  "$root/Sources/UT99Host/UT99TouchLayoutGeometry.swift" \
  "$temp_dir/main.swift" \
  -o "$output"
"$output"
