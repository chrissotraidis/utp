#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
output="${UT99_DIAGNOSTICS_DIR:-$root/build/diagnostics/$stamp}"
mkdir -p "$output"

./tools/doctor.sh >"$output/doctor.txt" 2>&1 || true
git status --short >"$output/git-status.txt"
git rev-parse HEAD >"$output/git-commit.txt"
xcodebuild -version >"$output/xcode.txt"
xcrun --sdk iphoneos --show-sdk-version >"$output/iphoneos-sdk.txt"
xcrun simctl list devices >"$output/simulators.txt"
./tools/ensure_single_runtime.sh --check >"$output/runtime-check.txt" 2>&1 || true
if [[ -f build/local-package/manifest-diagnostic.json ]]; then
  cp build/local-package/manifest-diagnostic.json "$output/"
fi

archive="${output}.zip"
(cd "$(dirname "$output")" && zip -qry "$archive" "$(basename "$output")")
unzip -t "$archive" >"$output/archive-test.txt"
echo "diagnostics=PASS directory=$output archive=$archive"
