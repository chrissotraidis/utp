#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
dmg="${UT99_V469E_DMG:-$root/ref/OldUnreal/OldUnreal-UTPatch469e-macOS.dmg}"
out="$root/build/audit"
mkdir -p "$out"
if [[ ! -f "$dmg" ]]; then echo "Missing v469e DMG: $dmg" >&2; exit 2; fi
mountpoint="$(mktemp -d /tmp/ut99-mount.XXXXXX)"
device=""
cleanup() { if [[ -n "$device" ]]; then hdiutil detach "$device" -quiet || true; fi; rmdir "$mountpoint" 2>/dev/null || true; }
trap cleanup EXIT
hdiutil attach -readonly -nobrowse -mountpoint "$mountpoint" "$dmg" >/dev/null
device="$(mount | awk -v p="$mountpoint" '$0~p{print $1; exit}')"
app="$(find "$mountpoint" -maxdepth 3 -type d -name '*.app' -print -quit)"
if [[ -z "$app" ]]; then echo "No .app found in mounted DMG" >&2; exit 3; fi
main="$app/Contents/MacOS/UnrealTournament"
if [[ ! -f "$main" ]]; then echo "Missing main executable: $main" >&2; exit 4; fi
shasum -a 256 "$main" > "$out/main.sha256"
file "$main" > "$out/file.txt"
lipo -archs "$main" > "$out/architectures.txt" 2>&1 || true
otool -hv "$main" > "$out/header.txt"
otool -l "$main" > "$out/load-commands.txt"
otool -L "$main" > "$out/dependencies.txt"
nm -m -u "$main" > "$out/undefined-symbols.txt" 2>&1 || true
codesign -dvvv --entitlements :- "$app" > "$out/codesign.txt" 2>&1 || true
while IFS= read -r image; do
  name="$(basename "$image")"
  safe="${name//[^A-Za-z0-9_.-]/_}"
  file "$image" > "$out/$safe.file.txt"
  shasum -a 256 "$image" > "$out/$safe.sha256"
  lipo -archs "$image" > "$out/$safe.architectures.txt" 2>&1 || true
  otool -hv "$image" > "$out/$safe.header.txt" 2>&1 || true
  otool -L "$image" > "$out/$safe.dependencies.txt" 2>&1 || true
done < <(find "$app/Contents" -type f \( -path '*/MacOS/UCC' -o -name '*.dylib' \) -print | sort)
python3 "$root/tools/write_audit_json.py" "$dmg" "$app" "$main" "$out/469e-audit.json"
cp "$out/469e-audit.json" "$out/audit.json"
echo "Complete native-image audit written to $out/469e-audit.json"
