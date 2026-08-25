#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

dmg="${UT99_V469E_DMG:-$root/ref/OldUnreal/OldUnreal-UTPatch469e-macOS.dmg}"
expected_sha="b6b3a1f462e4b702df0eecf90d663ef1f847cc36aadca1ec6dd35278d091fa0d"
destination="$root/build/macos-baseline/UnrealTournament.app"

[[ -f "$dmg" ]] || { echo "mac_baseline=blocked reason=missing_input path=$dmg run='make bootstrap'" >&2; exit 2; }
actual_sha="$(shasum -a 256 "$dmg" | awk '{print $1}')"
[[ "$actual_sha" == "$expected_sha" ]] || {
  echo "mac_baseline=failed reason=input_sha256_mismatch expected=$expected_sha actual=$actual_sha" >&2
  exit 1
}

verify_app() {
  local app="$1"
  local executable="$app/Contents/MacOS/UnrealTournament"
  [[ -x "$executable" ]] || return 1
  file "$executable" | grep -q 'arm64'
  plutil -lint "$app/Contents/Info.plist" >/dev/null
}

if verify_app "$destination"; then
  echo "mac_baseline=PASS reused=true dmg_sha256=$actual_sha app=$destination"
  exit 0
fi

[[ ! -e "$destination" ]] || {
  echo "mac_baseline=blocked reason=invalid_existing_output path=$destination" >&2
  exit 2
}

mount_point="$(mktemp -d "${TMPDIR:-/tmp}/ut99-v469e-mount.XXXXXX")"
staging="$(mktemp -d "${TMPDIR:-/tmp}/ut99-v469e-copy.XXXXXX")"
attached=false
cleanup() {
  if [[ "$attached" == true ]]; then hdiutil detach "$mount_point" -quiet || true; fi
  rm -rf "$mount_point" "$staging"
}
trap cleanup EXIT

hdiutil attach -readonly -nobrowse -mountpoint "$mount_point" "$dmg" -quiet
attached=true
source_app="$(find "$mount_point" -maxdepth 4 -type d -name UnrealTournament.app -print -quit)"
[[ -n "$source_app" ]] || { echo "mac_baseline=failed reason=app_not_found_in_dmg" >&2; exit 1; }
ditto "$source_app" "$staging/UnrealTournament.app"
verify_app "$staging/UnrealTournament.app" || { echo "mac_baseline=failed reason=copied_app_invalid" >&2; exit 1; }
mkdir -p "$(dirname "$destination")"
mv "$staging/UnrealTournament.app" "$destination"

echo "mac_baseline=PASS reused=false dmg_sha256=$actual_sha app=$destination"
