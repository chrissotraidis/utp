#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

mode="${UT99_PACKAGE_MODE:-signed}"
case "$mode" in
  signed|diagnostic) ;;
  *) echo "package_local=blocked reason=invalid_mode expected=signed_or_diagnostic" >&2; exit 2 ;;
esac

team="${DEVELOPMENT_TEAM:-}"
if [[ "$mode" == "signed" && -z "$team" ]]; then
  echo "package_local=blocked reason=set_DEVELOPMENT_TEAM mode=signed" >&2
  echo "For a non-installable packaging check, run: UT99_PACKAGE_MODE=diagnostic make package-local" >&2
  exit 4
fi

./tools/ensure_single_runtime.sh --clean
make ios-engine-real-artifact

output_dir="build/local-package"
mkdir -p "$output_dir"

if [[ "$mode" == "signed" ]]; then
  derived_data="build/ios-package-signed"
  UT99_ENGINE_EMBED=1 xcodebuild \
    -project UT99Apple.xcodeproj \
    -scheme UT99Apple \
    -sdk iphoneos \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$derived_data" \
    -allowProvisioningUpdates \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$team" \
    build
  app="$derived_data/Build/Products/Release-iphoneos/UT99Apple.app"
  ipa="$output_dir/UT99Apple-signed.ipa"
  installable=true
else
  derived_data="build/ios-package-diagnostic"
  UT99_ENGINE_EMBED=1 xcodebuild \
    -project UT99Apple.xcodeproj \
    -scheme UT99Apple \
    -sdk iphoneos \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build
  app="$derived_data/Build/Products/Release-iphoneos/UT99Apple.app"
  codesign --force --deep --sign - "$app" >/dev/null
  ipa="$output_dir/UT99Apple-diagnostic-ad-hoc.ipa"
  installable=false
fi

./tools/verify_ios_package.sh "$app"

if [[ -d "$app/UT99Data" ]]; then
  echo "package_local=failed reason=user_game_data_embedded" >&2
  exit 5
fi

signature_dump="$(codesign -dvv "$app" 2>&1 || true)"
if [[ "$mode" == "signed" ]]; then
  if grep -q '^Signature=adhoc' <<<"$signature_dump"; then
    echo "package_local=failed reason=adhoc_signature_in_signed_mode" >&2
    exit 5
  fi
  if [[ ! -f "$app/embedded.mobileprovision" ]]; then
    echo "package_local=failed reason=missing_embedded_provisioning_profile" >&2
    exit 5
  fi
else
  grep -q '^Signature=adhoc' <<<"$signature_dump" || {
    echo "package_local=failed reason=diagnostic_signature_not_adhoc" >&2
    exit 5
  }
fi

stage="$(mktemp -d "$output_dir/staging.XXXXXX")"
trap 'rm -r "$stage"' EXIT
mkdir -p "$stage/Payload"
ditto "$app" "$stage/Payload/UT99Apple.app"
rm -f "$ipa"
ditto -c -k --sequesterRsrc --keepParent "$stage/Payload" "$ipa"
unzip -t "$ipa" >"$output_dir/unzip-${mode}.txt"

archive_app="Payload/UT99Apple.app"
archive_list="$output_dir/archive-${mode}.txt"
unzip -Z1 "$ipa" >"$archive_list"
grep -qx "$archive_app/UT99Apple" "$archive_list"
if grep -q "^$archive_app/UT99Data/" "$archive_list"; then
  echo "package_local=failed reason=user_game_data_archived" >&2
  exit 5
fi

app_binary_sha="$(shasum -a 256 "$app/UT99Apple" | awk '{print $1}')"
engine_sha="$(shasum -a 256 "$app/Frameworks/UnrealTournament.dylib" | awk '{print $1}')"
ipa_sha="$(shasum -a 256 "$ipa" | awk '{print $1}')"
bundle_id="$(plutil -extract CFBundleIdentifier raw "$app/Info.plist")"
git_commit="$(git rev-parse HEAD)"
manifest="$output_dir/manifest-${mode}.json"

jq -n \
  --arg mode "$mode" \
  --arg bundle_id "$bundle_id" \
  --arg git_commit "$git_commit" \
  --arg app_binary_sha256 "$app_binary_sha" \
  --arg engine_sha256 "$engine_sha" \
  --arg ipa_sha256 "$ipa_sha" \
  --arg ipa "$ipa" \
  --argjson installable "$installable" \
  '{schema_version:1, mode:$mode, installable_on_stock_ios:$installable,
    bundle_identifier:$bundle_id, git_commit:$git_commit,
    contains_user_game_data:false, runtime_jit_required:false,
    app_binary_sha256:$app_binary_sha256, engine_sha256:$engine_sha256,
    ipa_sha256:$ipa_sha256, ipa:$ipa}' >"$manifest"

echo "package_local=passed mode=$mode installable_on_stock_ios=$installable"
echo "package_local_ipa=$ipa"
echo "package_local_manifest=$manifest"
if [[ "$mode" == "diagnostic" ]]; then
  echo "package_local_notice=ad_hoc_archive_is_not_installable_on_stock_ios" >&2
fi
