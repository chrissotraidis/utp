#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

rg -q '^void UT99MetalCopyPresentationMetrics\(' Sources/UT99Runtime/UT99MetalShim.m
rg -q 'presentDrawable:' Sources/UT99Runtime/UT99MetalShim.m
rg -q 'onePercentLowFPS' Sources/UT99Host/UT99EngineBridge.swift
rg -q 'UT99-performance.log' Sources/UT99Host/GameViewController.swift
rg -q 'FruCoRe vertical sync' Sources/UT99Host/GameViewController.swift

# The old menu changed a dormant host MTKView and called that a game frame
# cap. It must not return unless FruCoRe gains an actual cap implementation.
if rg -q 'Frame cap:|preferredFramesPerSecond = cap' Sources/UT99Host/GameViewController.swift; then
  echo 'fake FruCoRe frame-cap UI returned' >&2
  exit 1
fi

for shim in \
  build/ios-engine-ios-sim/UT99MetalShim.dylib \
  build/ios-engine/deps/UT99MetalShim.dylib \
  build/ios-engine-app/Build/Products/Debug-iphoneos/UT99Apple.app/Frameworks/UT99MetalShim.dylib \
  build/ios-engine-real-app/Build/Products/Debug-iphoneos/UT99Apple.app/Frameworks/UT99MetalShim.dylib
do
  if test -f "$shim"; then
    nm -gU "$shim" | rg -q '_UT99MetalCopyPresentationMetrics$'
  fi
done
