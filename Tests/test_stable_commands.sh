#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

required=(doctor bootstrap mac-baseline data-pack audit-469e mac-hosted-harness ios-shell ios-device test verify-device diagnostics package-local clean-runtime)
for target in "${required[@]}"; do
  grep -Eq "^${target}:" Makefile || {
    echo "Missing stable Make target: $target" >&2
    exit 1
  }
done
grep -Eq '^ios15-experimental-package:' Makefile

bash -n tools/bootstrap_dependencies.sh
bash -n tools/prepare_mac_baseline.sh
bash -n tools/collect_diagnostics.sh
bash -n tools/prepare_sdl2_source.sh
grep -Fq 'OldUnreal-UTPatch469e-macOS.dmg' tools/bootstrap_dependencies.sh
grep -Fq 'b6b3a1f462e4b702df0eecf90d663ef1f847cc36aadca1ec6dd35278d091fa0d' tools/bootstrap_dependencies.sh
grep -Fq 'OldUnreal-UTPatch469e-Windows-x86.zip' tools/bootstrap_dependencies.sh
grep -Fq '8c94eb7e990f5480b1fb7bcb1bd15c2512da134dbf01bfa16e7f99f0a8a0ee86' tools/bootstrap_dependencies.sh
grep -Fq 'build/sources/SDL2-UT99/Xcode/SDL/SDL.xcodeproj' Makefile
grep -Fq '/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox' Makefile
if grep -Fq '/System/Library/Frameworks/AudioUnit.framework/AudioUnit' Makefile; then
  echo "FMOD still targets the unavailable iOS AudioUnit runtime path" >&2
  exit 1
fi

echo "Stable command surface PASS targets=${#required[@]}"
