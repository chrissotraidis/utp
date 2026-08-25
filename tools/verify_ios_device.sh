#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

device_tmp_dir="$(mktemp -d)"
trap 'rm -r "$device_tmp_dir"' EXIT
device_json="$device_tmp_dir/physical-ios-devices.json"

if ! xcrun devicectl list devices --timeout 10 \
  --filter "hardwareProperties.platform BEGINSWITH 'iOS' OR hardwareProperties.platform BEGINSWITH 'iPadOS'" \
  --json-output "$device_json" >/dev/null 2>&1; then
  echo "device_gate=blocked reason=devicectl_failed" >&2
  exit 3
fi

device_count="$(jq -r '.result.devices | length' "$device_json")"
requested_device="${DEVICE_UDID:-}"
if [[ -n "$requested_device" ]]; then
  matched_count="$(jq --arg identifier "$requested_device" '[.result.devices[] | select(.identifier == $identifier)] | length' "$device_json")"
  [[ "$matched_count" == "1" ]] || { echo "device_gate=blocked reason=requested_device_not_connected" >&2; exit 3; }
  device_identifier="$requested_device"
elif [[ "$device_count" == "1" ]]; then
  device_identifier="$(jq -r '.result.devices[0].identifier' "$device_json")"
elif [[ "$device_count" == "0" ]]; then
  echo "device_gate=blocked reason=no_physical_ios_ipados_device" >&2
  exit 3
else
  echo "device_gate=blocked reason=multiple_devices_set_DEVICE_UDID" >&2
  exit 3
fi

[[ -n "${DEVELOPMENT_TEAM:-}" ]] || { echo "device_gate=blocked reason=set_DEVELOPMENT_TEAM" >&2; exit 4; }

./tools/run_ios_device.sh --install

evidence_stamp="$(date -u +%Y-%m-%dT%H%M%SZ)"
evidence_dir="build/device-evidence/${evidence_stamp}-g2"
mkdir -p "$evidence_dir"
g2_run_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"

xcrun devicectl device process launch --device "$device_identifier" \
  --terminate-existing \
  com.ut99apple.client \
  -UT99G2SmokeTest \
  "-UT99G2RunID=$g2_run_id"

copy_from_container() {
  local source="$1"
  local destination="$2"
  xcrun devicectl device copy from \
    --device "$device_identifier" \
    --domain-type appDataContainer \
    --domain-identifier com.ut99apple.client \
    --source "$source" \
    --destination "$destination" \
    >/dev/null 2>&1
}

for attempt in $(seq 1 30); do
  if copy_from_container \
    "Library/Application Support/Unreal Tournament/UT99-g2-smoke.log" \
    "$evidence_dir/UT99-g2-smoke.log"; then
    break
  fi
  sleep 1
done

copy_from_container \
  "Library/Application Support/Unreal Tournament/UT99-host-metal-smoke.log" \
  "$evidence_dir/UT99-host-metal-smoke.log"
copy_from_container \
  "Library/Application Support/Unreal Tournament/UT99-import-transaction-smoke.log" \
  "$evidence_dir/UT99-import-transaction-smoke.log"
copy_from_container \
  "Library/Application Support/Unreal Tournament/UT99-diagnostics-smoke.log" \
  "$evidence_dir/UT99-diagnostics-smoke.log"
copy_from_container \
  "Library/Application Support/Unreal Tournament/UT99-diagnostics-smoke.zip" \
  "$evidence_dir/UT99-diagnostics-smoke.zip"

grep -q 'passed=true' "$evidence_dir/UT99-g2-smoke.log"
grep -q "runID=$g2_run_id" "$evidence_dir/UT99-g2-smoke.log"
grep -q 'presented=true' "$evidence_dir/UT99-host-metal-smoke.log"
grep -q 'passed=true' "$evidence_dir/UT99-import-transaction-smoke.log"
grep -q 'exported=true' "$evidence_dir/UT99-diagnostics-smoke.log"
unzip -t "$evidence_dir/UT99-diagnostics-smoke.zip" >"$evidence_dir/diagnostics-unzip.txt"

app="build/ios-device-app/Build/Products/Debug-iphoneos/UT99Apple.app"
binary_sha="$(shasum -a 256 "$app/UT99Apple" | awk '{print $1}')"
jq -n \
  --arg timestamp "$evidence_stamp" \
  --arg host "$(sw_vers -productVersion) $(uname -m)" \
  --arg xcode "$(xcodebuild -version | tr '\n' ';')" \
  --arg sdk "$(xcrun --sdk iphoneos --show-sdk-version)" \
  --arg g2_run_id "$g2_run_id" \
  --arg binary_sha256 "$binary_sha" \
  '{timestamp:$timestamp, host:$host, xcode:$xcode, ios_sdk:$sdk, physical_device_count:1, g2_run_id:$g2_run_id, app_binary_sha256:$binary_sha256}' \
  >"$evidence_dir/environment.json"

{
  echo "classification=AUTOMATED_PARTIAL"
  echo "host_metal=PASS"
  echo "import_transaction=PASS"
  echo "diagnostics_archive=PASS"
  echo "manual_required=physical screenshot, touch-control/menu taps, Files picker import, share-sheet export"
} >"$evidence_dir/RESULT.txt"

echo "device_gate=automated_partial evidence=$evidence_dir"
echo "Leave the host open. Capture a physical screenshot and manually verify touch controls, the three-dot menu, Files import, and share-sheet export before promoting G2."
