# Data compatibility

The sanctioned OldUnreal macOS installer workflow identifies the GOTY disc image by SHA-256:

`e184984ca88f001c5ddd52035d76cd64e266e26c74975161b5ed72366c74704f`

The local ignored ISO was verified against that hash. `tools/prepare_ut99_data.py` copies only user content from `Maps`, `Music`, `Sounds`, and `Textures`, excludes desktop executables, and omits `LadderFonts.utx` and `UWindowFonts.utx` so modern engine-provided fonts remain authoritative.

Current local preparation result: 283 content files across the four content directories, with a SHA-256 manifest and ignored ZIP under `build/UT99Data*`. The simulator diagnostic package stages this pack together with the locally verified System/config files and decompressed startup maps; the original v469e engine now reaches FruCoRe, Deck16, and its main loop from that package.

Runtime imports no longer merge staged files directly into the live set. The host copies the complete last-known-good content/manifest into a backup, publishes an atomic phase journal, replaces only Maps/Music/Sounds/Textures plus the user manifest, and recovers an interrupted committing phase before startup. The generated System tree is never part of the transaction. Preparation runs outside UIKit's main queue and reports phase, current file, count, and progress. Cancellation is cooperative through discovery, ZIP entries, copies, and 1 MiB SHA-256 chunks; it disables when the non-cancellable journaled install begins. Verify uses streaming SHA-256 reads and the Game Data menu exposes repair/reimport and manifest export. Simulator interruption/replacement evidence is in `docs/evidence/engine-startup/2026-08-24-ios-data-transaction-pass/`, and progress/cancellation evidence is in `docs/evidence/engine-startup/2026-08-24-ios-import-progress-pass/`; Steam-origin and physical-device imports remain open.

Source/provenance: [OldUnreal full-game installer page](https://www.oldunreal.com/downloads/unrealtournament/full-game-installers/) and the ignored checkout under `ref/FullGameInstallers/`.

OldUnreal's current installer page states that its installers download the original UT99 GOTY disc image from OldUnreal-hosted files with Archive.org fallback and then apply the latest patch. This makes a user-consented **Get Game Data** onboarding path technically plausible. It does not by itself authorize UT99Apple to mirror the disc image, rebundle it in an IPA, or redistribute the transformed OldUnreal runtime. Until written permission and an Apple-supported delivery route are confirmed, the shipping boundary remains an app without game data plus explicit folder/ZIP import. The proposed source/consent/hash/extract flow is specified in `docs/DISTRIBUTION_AND_ONBOARDING.md`.
