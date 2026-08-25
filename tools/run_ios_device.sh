#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

mode="${1:---check}"
case "$mode" in
  --check|--build|--install|--run) ;;
  *) echo "Usage: $0 [--check|--build|--install|--run]" >&2; exit 2 ;;
esac

device_tmp_dir="$(mktemp -d)"
trap 'rm -r "$device_tmp_dir"' EXIT
device_json="$device_tmp_dir/physical-ios-devices.json"

if ! xcrun devicectl list devices --timeout 10 \
  --filter "hardwareProperties.platform BEGINSWITH 'iOS' OR hardwareProperties.platform BEGINSWITH 'iPadOS'" \
  --json-output "$device_json" >/dev/null 2>&1; then
  echo "device_readiness=unavailable reason=devicectl_failed" >&2
  exit 3
fi

device_count="$(jq -r '.result.devices | length' "$device_json")"
requested_device="${DEVICE_UDID:-}"
if [[ -n "$requested_device" ]]; then
  matched_count="$(jq --arg identifier "$requested_device" '[.result.devices[] | select(.identifier == $identifier)] | length' "$device_json")"
  if [[ "$matched_count" != "1" ]]; then
    echo "device_readiness=blocked reason=requested_device_not_connected physical_ios_ipados_devices=$device_count" >&2
    exit 3
  fi
  device_identifier="$requested_device"
elif [[ "$device_count" == "1" ]]; then
  device_identifier="$(jq -r '.result.devices[0].identifier' "$device_json")"
elif [[ "$device_count" == "0" ]]; then
  echo "device_readiness=blocked reason=no_physical_ios_ipados_device physical_ios_ipados_devices=0" >&2
  exit 3
else
  echo "device_readiness=blocked reason=multiple_devices_set_DEVICE_UDID physical_ios_ipados_devices=$device_count" >&2
  exit 3
fi

team="${DEVELOPMENT_TEAM:-}"
if [[ -z "$team" ]]; then
  echo "device_readiness=blocked reason=set_DEVELOPMENT_TEAM physical_ios_ipados_devices=$device_count" >&2
  exit 4
fi

identity_count="$({ security find-identity -v -p codesigning 2>/dev/null || true; } | awk '/valid identities found/{print $1; found=1} END{if (!found) print 0}')"
if [[ ! "$identity_count" =~ ^[0-9]+$ ]] || (( identity_count == 0 )); then
  if [[ "$mode" == "--check" ]]; then
    echo "device_readiness=blocked reason=no_apple_development_identity physical_ios_ipados_devices=$device_count" >&2
    exit 4
  fi
  echo "device_signing_warning=no_local_identity; allowing Xcode automatic provisioning to attempt recovery" >&2
fi

echo "device_readiness=ready physical_ios_ipados_devices=$device_count signing_identities=$identity_count"
[[ "$mode" == "--check" ]] && exit 0

./tools/ensure_single_runtime.sh --clean
make ios-engine-real-artifact

derived_data="build/ios-device-app"
app="$derived_data/Build/Products/Debug-iphoneos/UT99Apple.app"
UT99_ENGINE_EMBED=1 xcodebuild \
  -project UT99Apple.xcodeproj \
  -scheme UT99Apple \
  -sdk iphoneos \
  -configuration Debug \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$derived_data" \
  -allowProvisioningUpdates \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$team" \
  build

./tools/verify_ios_package.sh "$app"
echo "device_build=$app"
[[ "$mode" == "--build" ]] && exit 0

xcrun devicectl device install app --device "$device_identifier" "$app"
echo "device_install=passed"
[[ "$mode" == "--install" ]] && exit 0

launch_args=()
if [[ "${UT99_DEVICE_AUTOSTART:-0}" == "1" ]]; then
  launch_args=(-UT99AutoStart -UT99AutoMatch -UT99TouchDefaultSmokeTest)
fi
xcrun devicectl device process launch --device "$device_identifier" \
  --terminate-existing \
  com.ut99apple.client \
  "${launch_args[@]}"
echo "device_launch=passed"
