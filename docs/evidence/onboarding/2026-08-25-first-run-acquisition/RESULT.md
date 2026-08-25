# First-run game-data acquisition — 2026-08-25

Result: **PASS for local candidate implementation; physical and public-release gates remain open.**

- A clean iPad Air 11-inch Simulator install entered `NeedsData` and exposed `GET GAME DATA`, `IMPORT FILES`, and the reason game data is separate.
- Gameplay touch controls remained hidden on the setup surface.
- Activating `GET GAME DATA` through the live accessibility tree exposed the real consent sheet with source, 620 MiB size, temporary-storage requirement, Epic terms, pinned verification, data-only extraction, cleanup, manual import, and `Accept Terms & Download`. The acceptance action was deliberately not invoked during UI inspection.
- `Tests/test_game_data_acquisition.sh` built a Joliet/ISO-9660 fixture and extracted exactly four accepted files while excluding `LadderFonts.utx` and `UWindowFonts.utx`.
- The ignored official `ref/FullGameInstallers/UT_GOTY_CD1.ISO` was independently verified at 649633792 bytes with SHA-256 `e184984ca88f001c5ddd52035d76cd64e266e26c74975161b5ed72366c74704f`; the extractor accepted 283 data files including `Maps/DM-Deck16][.unr.uz`.
- A separate UZ-only package run proved original v469e detects and decompresses compressed maps at first launch.
- `make test`, the final real-FMOD Simulator package, and the final real-FMOD iPhoneOS package passed. A fresh sole-iPad run of the rebuilt Simulator package presented the 2360×1640 host Metal frame and transitioned `StartingEngine → Running` through the original entry.

Screenshots and generated packages remain ignored under `build/onboarding-evidence/`. No proprietary game data or transformed engine artifact is tracked here.

Remaining acceptance: one signed physical-device download/import, first engine launch, low-storage/network interruption, background/cancel behavior, and written permission before the direct path is enabled in a public binary.
