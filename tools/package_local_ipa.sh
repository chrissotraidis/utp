#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

mode="${UT99_PACKAGE_MODE:-signed}"
case "$mode" in
  signed|public|diagnostic) ;;
  *) echo "package_local=blocked reason=invalid_mode expected=signed_public_or_diagnostic" >&2; exit 2 ;;
esac

team="${DEVELOPMENT_TEAM:-}"
if [[ "$mode" != "diagnostic" && -z "$team" ]]; then
  echo "package_local=blocked reason=set_DEVELOPMENT_TEAM mode=signed" >&2
  echo "For a non-installable packaging check, run: UT99_PACKAGE_MODE=diagnostic make package-local" >&2
  exit 4
fi

./tools/ensure_single_runtime.sh --clean
make ios-engine-real-artifact

output_dir="build/local-package"
mkdir -p "$output_dir"

if [[ "$mode" == "signed" || "$mode" == "public" ]]; then
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
    clean build
  app="$derived_data/Build/Products/Release-iphoneos/UT99Apple.app"
  if [[ "$mode" == "public" ]]; then
    release_version="${UT99_RELEASE_VERSION:-0.1.0-preview.1}"
    [[ "$release_version" =~ ^[0-9A-Za-z._-]+$ ]] || {
      echo "package_local=blocked reason=invalid_release_version" >&2
      exit 2
    }
    ipa="$output_dir/UTP-${release_version}-unsigned.ipa"
    installable=false
    re_signable=true
  else
    ipa="$output_dir/UTP-signed.ipa"
    installable=true
    re_signable=false
  fi
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
    clean build
  app="$derived_data/Build/Products/Release-iphoneos/UT99Apple.app"
  codesign --force --deep --sign - "$app" >/dev/null
  ipa="$output_dir/UTP-diagnostic-ad-hoc.ipa"
  installable=false
  re_signable=false
fi

./tools/verify_ios_package.sh "$app"

if [[ -d "$app/UT99Data" ]]; then
  echo "package_local=failed reason=user_game_data_embedded" >&2
  exit 5
fi

signature_dump="$(codesign -dvv "$app" 2>&1 || true)"
if [[ "$mode" == "signed" || "$mode" == "public" ]]; then
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
if [[ "$mode" == "public" ]]; then
  find "$stage/Payload/UT99Apple.app" -name _CodeSignature -type d -prune -exec rm -r {} +
  find "$stage/Payload/UT99Apple.app" -name embedded.mobileprovision -type f -delete
  while IFS= read -r -d '' candidate; do
    if file "$candidate" | grep -q 'Mach-O'; then
      codesign --remove-signature "$candidate"
    fi
  done < <(find "$stage/Payload/UT99Apple.app" -type f -print0)
fi
rm -f "$ipa"
(cd "$stage" && /usr/bin/zip -X -q -r "$root/$ipa" Payload)
unzip -t "$ipa" >"$output_dir/unzip-${mode}.txt"

archive_app="Payload/UT99Apple.app"
archive_list="$output_dir/archive-${mode}.txt"
unzip -Z1 "$ipa" >"$archive_list"
if grep -q '^__MACOSX/' "$archive_list"; then
  echo "package_local=failed reason=mac_metadata_archived" >&2
  exit 5
fi
grep -qx "$archive_app/UT99Apple" "$archive_list"
if grep -q "^$archive_app/UT99Data/" "$archive_list"; then
  echo "package_local=failed reason=user_game_data_archived" >&2
  exit 5
fi
if [[ "$mode" == "public" ]] && grep -Eq '(^|/)(_CodeSignature/|embedded\.mobileprovision$)' "$archive_list"; then
  echo "package_local=failed reason=signing_metadata_archived" >&2
  exit 5
fi
if [[ "$mode" == "public" ]]; then
  while IFS= read -r -d '' candidate; do
    if file "$candidate" | grep -q 'Mach-O' && codesign -d "$candidate" >/dev/null 2>&1; then
      echo "package_local=failed reason=embedded_code_signature_archived" >&2
      exit 5
    fi
  done < <(find "$stage/Payload/UT99Apple.app" -type f -print0)
  if rg -a -q "$team" "$stage/Payload/UT99Apple.app"; then
    echo "package_local=failed reason=development_team_identifier_archived" >&2
    exit 5
  fi
  local_user="$(id -un)"
  printf -v local_home '/%s/%s/' Users "$local_user"
  if rg -a -q "$local_home" "$stage/Payload/UT99Apple.app"; then
    echo "package_local=failed reason=local_build_path_archived" >&2
    exit 5
  fi
fi

packaged_app="$stage/Payload/UT99Apple.app"
app_binary_sha="$(shasum -a 256 "$packaged_app/UT99Apple" | awk '{print $1}')"
engine_sha="$(shasum -a 256 "$packaged_app/Frameworks/UnrealTournament.dylib" | awk '{print $1}')"
ipa_sha="$(shasum -a 256 "$ipa" | awk '{print $1}')"
bundle_id="$(plutil -extract CFBundleIdentifier raw "$packaged_app/Info.plist")"
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
  --argjson re_signable "$re_signable" \
  '{schema_version:1, mode:$mode, installable_on_stock_ios:$installable,
    re_signable:$re_signable,
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
