# Binary audit

The complete audit is generated from the official v469e macOS DMG and is stored under the dated evidence folder. It is intentionally read-only: the recursive discovery and ARM64 inspection use the pristine app, while temporary thinned copies are discarded after inspection. No executable is patched, copied into source, or signed by the audit.

## Complete v469e findings

- Recursive `file(1)` discovery finds eight Mach-O images: `UnrealTournament`, `UCC`, and six bundled dylibs (SDL2, FMOD, mpg123, OpenAL, libsndfile, and libxmp).
- All 8/8 images contain both `x86_64` and `arm64` slices, are unencrypted, and have no writable-and-executable segment.
- `UnrealTournament` and `UCC` are ARM64 `MH_EXECUTE` images with identified `LC_MAIN` entry points. The six dylibs are directly loaded by the main runtime; `UCC` is a desktop tool and is not loaded by the iOS client.
- Each image record includes SHA-256, size, file type, architectures, platform/minimum OS/SDK, entry point, page-zero details, imports, rpaths, exports, undefined symbols, Objective-C classes/selectors, signing properties, encryption state, and segment protections.
- All 61 imported dependency edges have a bounded disposition: 41 are available through compatible iOS APIs, 10 require narrow audited shims, 6 are rebuildable third-party libraries, and 4 desktop/optional-driver edges are eliminated with the complete SDL2 replacement or bounded FMOD path. There are no unknown or fatal dependency classifications.
- `Default.ini` configured classes and `EditPackages` were inspected for native-package inference. The stock `.u` packages are Unreal package data/bytecode consumed by the monolithic runtime; recursive discovery finds no additional native package dylibs.
- The generated schema-v2 audit evaluates PRD gate G1 as `PASS`: an ARM64, unencrypted, entry-point-bearing, build-time no-JIT path with bounded dependencies remains plausible. This is a static feasibility result, not physical iOS execution evidence.

## iOS artifact findings

- `make ios-engine-artifact` produces an arm64 `MH_DYLIB` with `LC_BUILD_VERSION platform IOS`, minimum iOS 17.0, and ad-hoc code signing.
- SDL2 is built from the official iOS shared-library target; OpenAL Soft, libxmp, mpg123, and libsndfile are rebuilt from pinned ignored sources.
- `Cocoa.framework`, `ApplicationServices.framework`, and `CoreServices.framework` are redirected to `UT99DesktopShim.dylib`, which exports only the audited legacy symbols.
- `libfmod.dylib` is currently a diagnostic no-audio symbol shim. This is not an audio implementation and does not pass G6.
- The result is `DIAGNOSTIC_ONLY_AUDIO_STUB_OR_MISSING_DEPENDENCIES`; it is not G3 evidence.

## Evidence

See [the complete G1 result](evidence/engine-startup/2026-08-24-g1-complete-native-audit/RESULT.md) and its generated `469e-audit.json`. The [initial G1 audit](evidence/engine-startup/2026-08-23-g1-audit/RESULT.md) is retained as superseded historical evidence.
