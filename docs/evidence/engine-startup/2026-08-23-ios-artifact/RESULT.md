# iOS engine artifact experiment — 2026-08-23

## Hypothesis

The v469e arm64 executable can be transformed during the build into an iOS-platform, signed hosted image while replacing the audited SDL2 dependency with an official iOS SDL build.

## Inputs

- Official v469e executable copied from the ignored macOS baseline.
- Source hash: `49cdda6f3f25955906ff6b9a542d3b65afd8fd8d26a6273c0c47702b4f98b9ae`.
- SDL2 `Shared Library-iOS` target built from the pinned SDL2 checkout.

## Command

```text
make sdl2-shared-ios
make ios-engine-artifact
```

## Observed result

**PARTIAL / NOT READY FOR DEVICE EMBEDDING.** The generated ignored candidate is arm64, `MH_DYLIB`, marked `platform IOS` with minimum OS 17.0, ad-hoc signed, and its SDL2 load path is rewritten to `@rpath/libSDL2.dylib`. The SDL2 replacement exports the audited engine SDL imports. The narrow shim removes the three desktop framework load commands from the main image.

The rebuildable OpenAL, XMP, mpg123, and libsndfile replacements now build for iOS. A real-FMOD device candidate also builds and verifies as an iPhoneOS package, but it has not been installed or audibly tested on hardware. The simulator candidate continues to use an explicit no-audio FMOD symbol shim solely for startup and renderer validation.

## Evidence

- Generated report: `build/ios-engine/report.json` (ignored).
- Generated candidate: `build/ios-engine/UnrealTournament.dylib` (ignored, ad-hoc signed, not distributable).
- SDL build output: `build/sdl2-shared-ios/` (ignored).
- Rebuilt dependency outputs: `build/ios-engine/deps/` (ignored, ad-hoc signed, not distributable).
- Host loading boundary: `Sources/UT99Host/UT99EngineBridge.swift` (compiled for the iOS device SDK; no automatic load is claimed).
- Device-target package experiment: `make ios-engine-package` produced and ad-hoc-signed `build/ios-engine-app/Build/Products/Debug-iphoneos/UT99Apple.app`; all eight generated dylibs are embedded under `Frameworks/`, and `codesign --verify --deep --strict` passes.
- Reproducible package check: `tools/verify_ios_package.sh` passes image presence, nested signatures, iOS platform metadata, and absence of the three desktop framework load commands from the embedded engine.
- This package has not been installed or launched because no physical iPhone/iPad is attached. Package signing and dependency presence are therefore proven, but G3 engine execution is not.

## Decision

Continue with a narrow dependency-removal/shim experiment. Do not promote the iOS engine startup gate until all unsupported dependencies are removed or replaced, the artifact is embedded and signed by Xcode, and original engine startup is observed on a physical device.
