#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
cp "$root/Tests/DisplayGeometryTests.swift" "$temp_dir/main.swift"
xcrun swiftc \
  "$root/Sources/UT99Host/UT99DisplayGeometry.swift" \
  "$temp_dir/main.swift" \
  -o "$temp_dir/ut99-display-geometry-tests"
"$temp_dir/ut99-display-geometry-tests"
