#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

doctor_tmp_dir="$(mktemp -d)"
trap 'rm -r "$doctor_tmp_dir"' EXIT

tool_status() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf 'available'
  else
    printf 'unavailable'
  fi
}

signing_identity_count="$({ security find-identity -v -p codesigning 2>/dev/null || true; } | awk '/valid identities found/{print $1; found=1} END{if (!found) print 0}')"
project_team_count="$({ sed -n 's/.*DEVELOPMENT_TEAM = "\([^"]*\)".*/\1/p' UT99Apple.xcodeproj/project.pbxproj 2>/dev/null | grep -v '^$' || true; } | sort -u | wc -l | tr -d ' ')"

physical_device_json="$doctor_tmp_dir/physical-ios-devices.json"
if xcrun devicectl list devices --timeout 5 \
  --filter "hardwareProperties.platform BEGINSWITH 'iOS' OR hardwareProperties.platform BEGINSWITH 'iPadOS'" \
  --json-output "$physical_device_json" >/dev/null 2>&1; then
  physical_device_count="$(jq -r '.result.devices | length' "$physical_device_json" 2>/dev/null || printf 'unknown')"
else
  physical_device_count="unavailable"
fi

if [[ "$signing_identity_count" =~ ^[0-9]+$ ]] && (( signing_identity_count > 0 )) && (( project_team_count > 0 )); then
  signing_ready=yes
else
  signing_ready=no
fi

echo "UT99Apple doctor"
echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "host=$(sw_vers -productName) $(sw_vers -productVersion) $(uname -m)"
echo "xcode=$(xcodebuild -version 2>/dev/null | tr '\n' ';' || echo unavailable)"
echo "developer_dir=$(xcode-select -p 2>/dev/null || echo unavailable)"
echo "sdk=$(xcrun --sdk iphoneos --show-sdk-version 2>/dev/null || echo unavailable)"
echo "brew=$(brew --version 2>/dev/null | sed -n '1p' || echo unavailable)"
echo "python=$(python3 --version 2>&1)"
echo "uv=$(uv --version 2>/dev/null || echo unavailable)"
echo "required_tools=cmake:$(tool_status cmake),ninja:$(tool_status ninja),jq:$(tool_status jq),git:$(tool_status git),unzip:$(tool_status unzip),codesign:$(tool_status codesign),clang:$(tool_status clang)"
echo "disk=$(df -h . | tail -1 | awk '{print "available=" $4}')"
echo "signing_identity_count=$signing_identity_count"
echo "project_development_team_count=$project_team_count"
echo "device_signing_ready=$signing_ready"
echo "physical_ios_ipados_devices=$physical_device_count"
echo "booted_simulators=$(xcrun simctl list devices 2>/dev/null | awk '/Booted/{print}' | tr '\n' ';' || true)"
echo "prd=$(test -f docs/UT99_Apple_PRD.md && printf present || printf absent)"
echo "goal_loop=$(test -f docs/UT99_Agent_Goal_Loop.md && printf present || printf absent)"
echo "ref_ectopad=$(find ref -maxdepth 2 -iname '*ectopad*' -print -quit 2>/dev/null || true)"
echo "source_mirror_ectopad=$(test -d ../ectopad && printf ../ectopad || printf absent)"
echo "ref_v469e=$(find ref -maxdepth 3 -iname '*469e*' -print -quit 2>/dev/null || true)"
ref_data_input=$(find ref -type f \( -iname 'UT*.iso' -o -iname 'UT*.zip' -o -iname '*GOTY*' \) -print 2>/dev/null | head -5 | tr '\n' ';' || true)
prepared_data_pack=$(find build -maxdepth 2 -type f -name 'UT99Data.zip' -print -quit 2>/dev/null || true)
echo "game_data_ref=${ref_data_input:-absent}"
echo "game_data_pack=${prepared_data_pack:-absent}"
echo "git=$(git status --short --branch | tr '\n' ';')"
./tools/ensure_single_runtime.sh --check
