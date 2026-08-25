# G1 binary/dependency feasibility audit — 2026-08-23

**Classification: PARTIAL.** The official v469e package contains accessible ARM64 slices in all seven audited native images, but G1 is not promoted because several direct macOS framework imports remain unresolved.

## Input

- Release: `v469e`
- URL: https://github.com/OldUnreal/UnrealTournamentPatches/releases/tag/v469e
- Local input: ignored `ref/OldUnreal/OldUnreal-UTPatch469e-macOS.dmg`
- SHA-256: `b6b3a1f462e4b702df0eecf90d663ef1f847cc36aadca1ec6dd35278d091fa0d`

## Observed

- Main image is universal `x86_64 arm64`.
- ARM64 Mach-O type is `MH_EXECUTE`.
- `LC_MAIN` is present.
- Direct imports include Cocoa, ApplicationServices, CoreServices, CoreGraphics, Metal, MetalKit, SDL2, OpenAL, FMOD, mpg123, libsndfile, libxmp, libiconv, libc++, libSystem, and Objective-C runtime support.
- The DMG also contains `UCC`, six framework dylibs, and stock `.u` packages; these have not yet been classified for iOS.
- `UCC` and all six framework dylibs also contain `x86_64` and `arm64` slices; per-image hashes and dependency transcripts are included here.

## Decision

Continue with dependency classification and a bounded host-side transformation experiment. Do not attempt an iOS install or claim G3/G4/G5. If the unresolved desktop surface is pervasive or a mandatory native dependency cannot be rebuilt/replaced, write `docs/STOP_REPORT.md` and stop per the PRD.
