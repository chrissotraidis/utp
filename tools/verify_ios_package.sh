#!/bin/bash
set -euo pipefail

app="${1:?usage: verify_ios_package.sh path/to/UT99Apple.app}"
frameworks="$app/Frameworks"

[[ -d "$app" && -d "$frameworks" ]] || { echo "missing app/frameworks directory" >&2; exit 2; }
codesign --verify --deep --strict "$app"

if [[ -d "$app/UT99Data/UT99Data" ]]; then
  echo "nested runtime data directory found: UT99Data/UT99Data" >&2
  exit 8
fi

required=(
  UnrealTournament.dylib
  UT99DesktopShim.dylib
  UT99MetalShim.dylib
  UT99CocoaShim.dylib
  UT99ApplicationServicesShim.dylib
  UT99CoreServicesShim.dylib
  libSDL2.dylib
  libfmod.dylib
  libmpg123.dylib
  libopenal.dylib
  libsndfile.dylib
  libxmp.dylib
)
for name in "${required[@]}"; do
  file="$frameworks/$name"
  [[ -f "$file" ]] || { echo "missing embedded image: $name" >&2; exit 3; }
  codesign --verify --strict "$file"
  build_info="$(xcrun vtool -show-build "$file")"
  printf '%s\n' "$build_info" | rg -q 'platform IOS($| )|platform IOSSIMULATOR|LC_VERSION_MIN_IPHONEOS' || { echo "not an iOS image: $name" >&2; exit 4; }
done

main="$frameworks/UnrealTournament.dylib"
otool -L "$main" | rg -q 'Cocoa\.framework|ApplicationServices\.framework|CoreServices\.framework' && {
  echo "desktop framework dependency remains in embedded engine" >&2
  exit 5
}

fmod="$frameworks/libfmod.dylib"
if otool -L "$fmod" | rg -q '/System/Library/Frameworks/AudioUnit\.framework/AudioUnit'; then
  echo "unavailable iOS AudioUnit runtime dependency remains in embedded FMOD" >&2
  exit 6
fi
if ! otool -L "$fmod" | rg -q '/System/Library/Frameworks/AudioToolbox\.framework/AudioToolbox'; then
  # The diagnostic FMOD stub has no audio framework dependencies. A non-stub
  # image must use AudioToolbox, which exports the AudioUnit symbols on iOS.
  if nm -u "$fmod" | rg -q '_Audio(Component|OutputUnit|Unit)'; then
    echo "embedded FMOD has AudioUnit imports without the iOS AudioToolbox runtime" >&2
    exit 7
  fi
fi

echo "iOS package verification passed: $app"
