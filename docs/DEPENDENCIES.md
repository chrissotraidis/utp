# Dependency classification

This classification is based on the v469e audit artifacts under `docs/evidence/engine-startup/2026-08-23-g1-audit/`. It is a feasibility record, not permission to ship any upstream binary.

| Dependency | Observed in | Classification | Next action |
|---|---|---|---|
| SDL2 2.0 ABI image | main, UCC | Replaceable optional/platform dependency | Build official SDL2 `release-2.32.10` for iOS and compare exported/imported ABI |
| Cocoa/AppKit/Carbon/IOKit/ForceFeedback | main, UCC, SDL2 | Desktop-only transitive surface | SDL2 replacement built; main Cocoa/ApplicationServices/CoreServices load commands now use a narrow audited shim; remaining native-library surfaces require device verification |
| Metal/MetalKit/QuartzCore | main, SDL2 | Available on iOS with API audit | Verify FruCoRe drawable/layer path |
| CoreGraphics/Foundation/CoreFoundation/CoreServices | main, UCC, SDL2 | Available or narrow shim required | Locate actual call sites before patching |
| OpenAL Soft 1.25.2 | main | Rebuilt from pinned source for iOS with a recorded iOS aligned-allocation guard | Simulator ALAudio/music path passes with zero allocation failures; audible hardware behavior and full G6 remain unverified |
| FMOD | main | Optional/proprietary audio risk | Current `libfmod.dylib` is explicitly a no-audio diagnostic shim; obtain a production-legal path or disable FMOD in favor of OpenAL |
| mpg123, libsndfile, libxmp | main | Rebuilt third-party libraries | `make ios-audio-deps`; codec behavior remains unverified |
| libiconv, libc++, libSystem, Objective-C runtime | main/UCC | Available system/runtime dependencies | Verify iOS load commands after transformation |
| UCC | stock tool | Not part of final runtime | Keep as host-side data preparation tool; do not embed desktop executable |

## Pinned public source

- SDL2 `release-2.32.10`, commit `5d249570393f7a37e037abf22cd6012a4cc56a71`, ignored checkout at `ref/SDL2/`.
- OldUnreal v469e and data provenance are recorded in `third_party/deps.lock.json`.
- OpenAL Soft, mpg123 1.33.6, libsndfile, and libxmp source pins and licenses are recorded in `third_party/deps.lock.json`; all source checkouts/downloads are ignored under `ref/`.
- The pristine OpenAL checkout is copied to `build/sources/openal-soft-ios` and patched at build time by `third_party/patches/openal-soft-ios-aligned-allocation.patch`; `Tests/test_openal_ios_patch.sh` checks the guard, output path, and simulator/device symbols.

The SDL2 `Static Library-iOS` target built successfully for the iOS Simulator, and the `xcFramework-iOS` target built successfully for device and simulator slices. Comparing the 87 SDL2 imports recorded from the v469e main image against the arm64 iOS static library found zero missing exports. Generated output was moved to ignored `build/sdl2-ios-products/`; the reference checkout remains clean. This is ABI-symbol evidence only; it does not prove behavior or engine startup.
