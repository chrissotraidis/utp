#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

patch_file="third_party/patches/openal-soft-ios-aligned-allocation.patch"
test -f "$patch_file"
rg -q 'TARGET_OS_OSX.*MAC_OS_X_VERSION_MIN_REQUIRED' "$patch_file"
rg -q 'openal_source="build/sources/openal-soft-ios"' tools/build_ios_dependencies.sh
rg -q 'cmake -S "\$openal_source"' tools/build_ios_dependencies.sh
rg -q 'engine_dir="build/ios-engine"' tools/build_ios_dependencies.sh

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/common"
cp ref/OpenAL-Soft/common/almalloc.cpp "$test_root/common/almalloc.cpp"
patch -s -d "$test_root" -p1 < "$patch_file"
rg -q '^#include <TargetConditionals.h>$' "$test_root/common/almalloc.cpp"
rg -q '^#if TARGET_OS_OSX && defined\(MAC_OS_X_VERSION_MIN_REQUIRED\)' "$test_root/common/almalloc.cpp"

for openal in \
  build/ios-engine-ios-sim/deps/libopenal.dylib \
  build/ios-engine/deps/libopenal.dylib
do
  if test -f "$openal"; then
    aligned_symbols="$(nm -m "$openal" | rg '__ZnamSt11align_val_t|__ZnwmSt11align_val_t')"
    test "$(printf '%s\n' "$aligned_symbols" | rg -c '^ *\(undefined\).*\(from libc\+\+\)$')" -eq 2
  fi
done
