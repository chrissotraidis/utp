#!/usr/bin/env bash
# PadMint's iPhone/iPad build of UTP, from a fresh clone: pinned open-source
# dependencies, OldUnreal's free 469e macOS release (checked against its
# pinned checksum), the iOS engine with real audio and the app, packaged as an
# IPA to sign with your own Apple ID. No Unreal Tournament game data is read:
# players import their own GOTY files inside UTP after installing it.
#
#   tools/build_padmint_ios.sh OUTPUT.ipa
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="${1:?usage: tools/build_padmint_ios.sh OUTPUT.ipa}"
cd "$root"

echo "UTP: fetching the pinned dependencies"
make bootstrap
echo "UTP: preparing OldUnreal's 469e macOS release"
make mac-baseline
echo "UTP: building the iOS engine and app"
make ios-engine-real-package

app="$root/build/ios-engine-real-app/Build/Products/Debug-iphoneos/UT99Apple.app"
test -x "$app/UT99Apple"
staging="$(mktemp -d "${TMPDIR:-/tmp}/utp-ipa.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
mkdir "$staging/Payload"
ditto --norsrc --noextattr "$app" "$staging/Payload/UT99Apple.app"
if find "$staging/Payload" -type d -iname 'UT99Data' | grep -q .; then
  echo "Refusing to package game data into the IPA" >&2
  exit 1
fi
(cd "$staging" && COPYFILE_DISABLE=1 /usr/bin/zip -qry "$staging/UTP.ipa" Payload)
mkdir -p "$(dirname "$output")"
mv "$staging/UTP.ipa" "$output"
echo "UTP IPA: $output"

