#!/bin/bash
set -euo pipefail

app="${1:?usage: prepare_embedded_runtime_data.sh path/to/UT99Apple.app}"
data="$app/UT99Data"
baseline="build/macos-baseline/UnrealTournament.app/Contents/MacOS"
support="$(python3 -c 'from pathlib import Path; print(Path.home() / "Library/Application Support/Unreal Tournament")')"

[[ -d "$data" ]] || exit 0
mkdir -p "$data/System" "$data/Textures" "$data/Maps" "$data/Music" "$data/Sounds"
cp -R "$baseline/System/"* "$data/System/"
cp -R "$baseline/Textures/"* "$data/Textures/"
# The v469e macOS bundle keeps English localization beside System rather than
# inside it. Unreal's Localize() still searches the writable runtime System
# directory on iOS, so stage the original .int resources there. Without this,
# the stock server browser exposes raw <int?...> placeholders for every tab.
localized="$baseline/SystemLocalized/int"
if [[ -d "$localized" ]]; then
  find "$localized" -maxdepth 1 -type f -name '*.int' -exec cp {} "$data/System/" \;
fi
# Frucore loads the v469e shader library during the first SDL viewport open.
# The desktop app keeps it beside Contents/MacOS in Contents/Resources; the
# embedded host enters Application Support/.../System, so stage the same
# signed library alongside the engine data it resolves from that cwd.
shader="build/macos-baseline/UnrealTournament.app/Contents/Resources/default.metallib"
if [[ "$app" == *Debug-iphoneos* && -f "build/ios-engine/default.metallib" ]]; then
  shader="build/ios-engine/default.metallib"
elif [[ -f "build/ios-engine-ios-sim/default.metallib" ]]; then
  shader="build/ios-engine-ios-sim/default.metallib"
elif [[ -f "$baseline/../Resources/default.metallib" ]]; then
  shader="$baseline/../Resources/default.metallib"
fi
if [[ -f "$shader" ]]; then
  cp "$shader" "$data/System/default.metallib"
  # Frucore asks NSBundle.mainBundle for the default library. Keep the
  # library at the app bundle root as well as in the writable runtime data.
  cp "$shader" "$app/default.metallib"
fi

# Reuse the locally prepared, owner-authorized runtime support directory when
# it exists. This supplies decompressed startup maps and matching INI paths
# without placing proprietary game data in source control.
if [[ -d "$support/System" ]]; then cp -R "$support/System/"* "$data/System/"; fi
for directory in Maps Music Sounds Textures; do
  if [[ -d "$support/$directory" ]]; then cp -R "$support/$directory/"* "$data/$directory/"; fi
done

# v469e ships this template as DefUser.ini, while the early appInit path
# probes the expanded legacy name before it initializes the object subsystem.
# Keep both names in the private embedded data pack so the original lookup
# succeeds without changing the engine's config semantics.
if [[ -f "$data/System/DefUser.ini" && ! -f "$data/System/DefaultUser.ini" ]]; then
  cp "$data/System/DefUser.ini" "$data/System/DefaultUser.ini"
fi
