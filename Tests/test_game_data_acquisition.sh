#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/ut99-game-data-acquisition.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

for directory in Maps Music Sounds Textures; do
  mkdir -p "$test_root/source/$directory"
done
printf map >"$test_root/source/Maps/DM-Fixture.unr.uz"
printf music >"$test_root/source/Music/Fixture.umx"
printf sound >"$test_root/source/Sounds/Fixture.uax"
printf texture >"$test_root/source/Textures/Fixture.utx"
printf excluded >"$test_root/source/Textures/LadderFonts.utx"
printf excluded >"$test_root/source/Textures/UWindowFonts.utx"
hdiutil makehybrid -quiet -iso -joliet -o "$test_root/fixture.iso" "$test_root/source"

xcrun swiftc -parse-as-library \
  "$root/Sources/UT99Host/UT99DataImportTransaction.swift" \
  "$root/Sources/UT99Host/UT99DataImporter.swift" \
  "$root/Sources/UT99Host/UT99GameDataAcquisition.swift" \
  "$root/Tests/GameDataAcquisitionTests.swift" \
  -o "$test_root/test_game_data_acquisition"
"$test_root/test_game_data_acquisition" "$test_root/fixture.iso"
