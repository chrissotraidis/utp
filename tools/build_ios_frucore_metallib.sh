#!/bin/bash
set -euo pipefail

source_metallib="${1:?usage: build_ios_frucore_metallib.sh source.metallib output.metallib [ios|iossim]}"
output_metallib="${2:?usage: build_ios_frucore_metallib.sh source.metallib output.metallib [ios|iossim]}"
platform="${3:-iossim}"
minimum_os="${UT99_IOS_MIN:-17.0}"
[[ "$minimum_os" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || {
  echo "invalid UT99_IOS_MIN: $minimum_os" >&2
  exit 2
}
minimum_triple="$minimum_os"
[[ "$minimum_triple" == *.*.* ]] || minimum_triple="$minimum_triple.0"

case "$platform" in
  ios) target_triple="air64_v26-apple-ios$minimum_triple" ;;
  iossim) target_triple="air64_v26-apple-ios$minimum_triple-simulator" ;;
  *) echo "unsupported Metal platform: $platform" >&2; exit 2 ;;
esac
export target_triple

[[ -f "$source_metallib" ]] || { echo "missing source metallib: $source_metallib" >&2; exit 2; }
mkdir -p "$(dirname "$output_metallib")"
work="$(mktemp -d)"
export work
trap 'rm -rf "$work"' EXIT

objdump="$(xcrun --find metal-objdump)"
air_as="$(xcrun --find air-as)"
metallib="$(xcrun --find metallib)"

# The shipped library retains AIR LLVM IR in its module list. Extract that
# IR, retarget it, and relink it with the current Apple Metal toolchain. The
# old Mac library uses global constructors to copy function-constant values;
# iOS AIR rejects those constructors, so the optional feature flags default
# to false until Frucore supplies the per-pipeline constants.
"$objdump" --metallib --disassemble-symbols=DrawComplexVertex "$source_metallib" > "$work/modules.ll"
awk '/^source_filename/{n++; if (out) close(out); out=sprintf("%s/module-%02d.ll", ENVIRON["work"], n)} /^0x[0-9a-f]+ --/ {if (out) close(out); out=""; next} out{print > out}' "$work/modules.ll"

for module in "$work"/module-*.ll; do
  perl -0777 -pi -e 's/define internal void @_GLOBAL__sub_I_[^\n]+\{.*?\n\}\n\n//s' "$module"
  perl -pi -e 's/^\@llvm\.global_ctors.*$//; s/air64-apple-macosx10\.13\.0/$ENV{"target_triple"}/g; s/!\{i32 2, i32 0, i32 0\}/!{i32 2, i32 6, i32 0}/g; s/!\{!"Metal", i32 2, i32 0, i32 0\}/!{!"Metal", i32 3, i32 1, i32 0}/g; s/\[2 x i32\] \[i32 26, i32 0\]/[2 x i32] [i32 26, i32 5]/g; s/addrspace\(2\) global i8 undef/addrspace(2) global i8 0/g' "$module"
  "$air_as" "$module" -o "${module%.ll}.air"
done

"$metallib" "$work"/module-*.air -o "$output_metallib"
"$objdump" --metallib --all-headers "$output_metallib" | rg -q 'MacOSTarget: 0'
