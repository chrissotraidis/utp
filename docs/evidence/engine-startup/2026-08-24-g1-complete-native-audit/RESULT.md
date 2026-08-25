# Complete G1 native-image/dependency audit — 2026-08-24

**Classification: PASS for PRD G1 static feasibility.** This result does not claim physical iOS execution or promote G2 and later gates.

## Method

- Input: ignored official v469e macOS DMG, SHA-256 `b6b3a1f462e4b702df0eecf90d663ef1f847cc36aadca1ec6dd35278d091fa0d`.
- Command: `make audit-469e`.
- Discovery: recursively identify every Mach-O under `UnrealTournament.app/Contents` with `file(1)`, then inspect each ARM64 slice from a disposable temporary thinning directory.
- Verification: `./Tests/test_complete_macho_audit.sh` validates the parser and generated schema. The committed tooling redacts local paths and developer identity from generated JSON.

## Result

- Native images discovered: 8 (`UnrealTournament`, `UCC`, and six bundled dylibs).
- ARM64 slices: 8/8; every image also retains its x86_64 slice in the pristine input.
- Encryption: none in 8/8.
- Writable+executable segments: none in 8/8.
- Entry point: `LC_MAIN` identified in both executable images.
- Main direct bundled dependencies: all six dylibs identified.
- Dependency edges: 61 total; 41 iOS-compatible APIs, 10 narrow-shim edges, 6 rebuildable third-party edges, and 4 replaceable optional-driver edges. Unknown: 0. Fatal: 0.
- Native package inference: configured stock `.u` packages are data/bytecode for the monolithic runtime; no additional Mach-O package image was found.
- G1 evaluation: `PASS` for a plausible ARM64, unencrypted, build-time no-JIT path with bounded dependencies.

## Artifacts

- `469e-audit.json` — complete deterministic schema-v2 record, including hashes, load metadata, imports/rpaths, exports/undefined symbols, Objective-C metadata, signing, encryption, and segments for every image.
- `audit.log` — generation transcript.

## Remaining boundary

The audit establishes feasibility only. No physical iPhone/iPad is attached, so transformed-image loading, signing/entitlements, touch, audio, renderer behavior, and lifecycle on hardware remain unproven under G2 and later gates.
