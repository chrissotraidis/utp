#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
udid="${SIM_UDID:-F05D2D40-0A01-47C9-9BD7-0C0E19F7512C}"
app="build/ios-shell/Build/Products/Debug-iphonesimulator/UT99Apple.app"
evidence="docs/evidence/ios-shell/2026-08-23-shell"

./tools/ensure_single_runtime.sh --clean
xcodebuild -project UT99Apple.xcodeproj -scheme UT99Apple -sdk iphonesimulator -configuration Debug -derivedDataPath build/ios-shell CODE_SIGNING_ALLOWED=NO build >/dev/null

cleanup() {
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
}
trap cleanup EXIT

xcrun simctl boot "$udid" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl install "$udid" "$app"
xcrun simctl launch "$udid" com.ut99apple.client
sleep 2
mkdir -p "$evidence"
xcrun simctl io "$udid" screenshot "$evidence/ut99apple-shell.png" >/dev/null
echo "Shell evidence: $evidence/ut99apple-shell.png"
