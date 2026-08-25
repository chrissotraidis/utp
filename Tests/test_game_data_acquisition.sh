#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/ut99-game-data-acquisition.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

for directory in Maps Music Sounds Textures System; do
  mkdir -p "$test_root/source/$directory"
done
printf map >"$test_root/source/Maps/DM-Fixture.unr.uz"
printf music >"$test_root/source/Music/Fixture.umx"
printf sound >"$test_root/source/Sounds/Fixture.uax"
printf texture >"$test_root/source/Textures/Fixture.utx"
printf excluded >"$test_root/source/Textures/LadderFonts.utx"
printf excluded >"$test_root/source/Textures/UWindowFonts.utx"
for runtime_file in Default.ini DefUser.ini UnrealTournament.ini User.ini Core.u Engine.u BotPack.u UWindow.u UMenu.u UTMenu.u; do
  printf runtime >"$test_root/source/System/$runtime_file"
done
printf localized >"$test_root/source/System/Fixture.int"
printf native >"$test_root/source/System/Engine.dll"
printf native >"$test_root/source/System/Setup.exe"
hdiutil makehybrid -quiet -iso -joliet -o "$test_root/fixture.iso" "$test_root/source"

xcrun --sdk macosx clang -c "$root/Sources/UT99Host/UT99ZipInflate.c" \
  -o "$test_root/UT99ZipInflate.o"
xcrun swiftc -parse-as-library \
  -import-objc-header "$root/Sources/UT99Host/UT99Apple-Bridging-Header.h" \
  "$root/Sources/UT99Host/UT99DataImportTransaction.swift" \
  "$root/Sources/UT99Host/UT99DataImporter.swift" \
  "$root/Sources/UT99Host/UT99ZipArchive.swift" \
  "$root/Sources/UT99Host/UT99GameDataAcquisition.swift" \
  "$root/Tests/GameDataAcquisitionTests.swift" \
  "$test_root/UT99ZipInflate.o" -lz \
  -o "$test_root/test_game_data_acquisition"
"$test_root/test_game_data_acquisition" "$test_root/fixture.iso"

official_iso="${UT99_GOTY_ISO:-$root/ref/OldUnreal/UT_GOTY_CD1.ISO}"
official_patch="${UT99_V469E_PATCH:-$root/ref/OldUnreal/OldUnreal-UTPatch469e-Windows-x86.zip}"
if [[ -f "$official_iso" && -f "$official_patch" ]]; then
  "$test_root/test_game_data_acquisition" "$official_iso" --official --patch "$official_patch"
elif [[ -f "$official_iso" ]]; then
  "$test_root/test_game_data_acquisition" "$official_iso" --official
fi
