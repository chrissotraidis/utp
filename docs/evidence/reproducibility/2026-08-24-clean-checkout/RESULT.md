# Clean-checkout reproduction — 2026-08-24

Result: **PASS**

The tracked repository at commit `e61023d2ffa01d9ec19b2f49e82e0fb3ccdd941a` was cloned locally with no shared working tree and reproduced from ignored, freshly bootstrapped inputs.

## Fresh-checkout results

- `make bootstrap`: PASS. The official v469e DMG hash and every public dependency pin in `third_party/deps.lock.json` were verified.
- `make mac-baseline`: PASS. The official ARM64 v469e macOS oracle was prepared beneath the clean checkout's ignored `build/` tree.
- `make test`: PASS.
- `make ios-engine-real-package`: PASS. SDL2, OpenAL Soft, libxmp, libsndfile, mpg123, the transformed real FMOD dependency, FruCoRe Metal library, transformed v469e engine, and native host were rebuilt for iPhoneOS before package verification.

The pristine pinned SDL2 checkout remained unmodified. `tools/prepare_sdl2_source.sh` copied it to ignored `build/sources/SDL2-UT99`, applied tracked patch SHA-256 `36989c0413a7b3df4c6fe55e943d1951ca91fb91ce3c3f2a1562f72fdd2b6863`, and built from that generated copy.

## Verified iPhoneOS artifacts

- Host executable SHA-256: `c690a4db4c9a32ab2e1d7484be7e8ef92d43ea28f59079db653f1a7dc56fe740`
- Embedded `UnrealTournament.dylib` SHA-256: `ee4e01192ce4caf935d3d9315059eee956bbdcf27016f7f09a1933cd5ca9eaeb`
- Package: `build/ios-engine-real-app/Build/Products/Debug-iphoneos/UT99Apple.app`
- Verification: PASS, ad-hoc device candidate; no development identity or team was available.

All downloaded references and generated artifacts remained ignored. This proof establishes source/bootstrap/build reproducibility; it does not promote physical G2, installability on stock hardware, user-owned data availability, or physical input/audio/performance gates.

## Current-source Simulator regression

The main checkout then rebuilt `make ios-engine-sim-real-package` through the same generated SDL path and installed it on the sole booted iPad Air 11-inch (M4) Simulator. One client was launched with the stock Deck16 automated match and default touch smoke arguments.

- Sole runtime PID: `65371`
- Native scene: 1180×820 points
- Metal drawable: 2360×1640 pixels at 2×
- Engine log: `Game engine initialized` followed by `Entering main loop.`
- Simulator host SHA-256: `f48020ceb50d7c80b48ff71b3e0459eb7dc5e8a704adfa21ca87dbe23100fe36`
- Simulator engine SHA-256: `0206263e79ca78a3d1231fa2ea41fcc147a7c7e01ffa46d2d15bb09b2604f1e6`
- Authoritative landscape capture: `current-source-ipad-landscape.jpeg` (SHA-256 `35ca6c23dbcea1a329ee8995fafdac53589056a64a660f547b3ee57f3b86f19a`)

The capture shows full-bleed original rendering with the compact utility pad and distinct combat cluster. The internal reference profile name appears only in diagnostic logging; it is not exposed in player settings.
