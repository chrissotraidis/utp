#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
source="$root/build/macos-baseline/UnrealTournament.app"
out="$root/build/macos-hosted"
if [[ ! -f "$source/Contents/MacOS/UnrealTournament" ]]; then echo "Run the macOS baseline preparation first" >&2; exit 2; fi
mkdir -p "$out/Frameworks" "$out/evidence"
lipo -thin arm64 "$source/Contents/MacOS/UnrealTournament" -output "$out/UnrealTournament.arm64"
python3 "$root/tools/patch_macho_hosted.py" "$out/UnrealTournament.arm64" "$out/UnrealTournament.dylib" "$out/evidence/patch.json" dylib
for name in libxmp.4.dylib libopenal.1.dylib libSDL2-2.0.0.dylib libmpg123.dylib libsndfile.1.dylib libfmod.dylib; do cp "$source/Contents/Frameworks/$name" "$out/Frameworks/$name"; done
codesign -f -s - "$out/UnrealTournament.dylib"
clang -Wall -Wextra "$root/tools/mac_hosted_harness.c" -framework Foundation -o "$out/hosted-loader"
mkdir -p "$out/HostedLoader.app/Contents/MacOS" "$out/HostedLoader.app/Contents/Resources"
cp "$out/hosted-loader" "$out/HostedLoader.app/Contents/MacOS/hosted-loader"
cp "$source/Contents/Info.plist" "$out/HostedLoader.app/Contents/Info.plist"
cp "$source/Contents/Resources/default.metallib" "$out/HostedLoader.app/Contents/Resources/default.metallib"
plutil -replace CFBundleExecutable -string hosted-loader "$out/HostedLoader.app/Contents/Info.plist"
codesign -f -s - "$out/HostedLoader.app"
set +e
"$out/hosted-loader" "$out/UnrealTournament.dylib" > "$out/evidence/rtld-now.txt" 2>&1
now_rc=$?
UT99_DLOPEN_LAZY=1 "$out/hosted-loader" "$out/UnrealTournament.dylib" > "$out/evidence/rtld-lazy.txt" 2>&1
lazy_rc=$?
set -e
printf 'rtld_now_exit=%s\nrtld_lazy_exit=%s\n' "$now_rc" "$lazy_rc" | tee "$out/evidence/result.txt"
cat "$out/evidence/rtld-now.txt" "$out/evidence/rtld-lazy.txt"
if [[ "$lazy_rc" -ne 0 ]]; then exit "$lazy_rc"; fi
file "$out/UnrealTournament.dylib" > "$out/evidence/file.txt"
otool -hv "$out/UnrealTournament.dylib" > "$out/evidence/header.txt"
otool -L "$out/UnrealTournament.dylib" > "$out/evidence/dependencies.txt"
