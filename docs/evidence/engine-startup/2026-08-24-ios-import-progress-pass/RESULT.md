# iOS import progress and cancellation pass — 2026-08-24

## Result

PASS for the simulator-scoped importer UX and preparation-safety requirements. This does not promote a physical-device gate.

- Folder and ZIP preparation runs on `com.ut99apple.data-import`, outside UIKit's main queue.
- The modal import card exposes phase, current file, exact completed/total count, determinate progress, and a 42-point Cancel action.
- Cancellation is checked during discovery, between ZIP entries and copies, and between 1 MiB SHA-256 chunks.
- Cancellation and commit race through an atomic token transition. Cancel is disabled at the `installing` boundary; from that point, the existing backup/journal commit must finish or recover rather than publishing a half-install.
- A deterministic unit fixture cancelled after the first prepared file and proved that the installed map and manifest remained byte-for-byte unchanged, the generated `System` fixture survived, and no staging/journal debris remained.
- The iPad Air Simulator accessibility tree reported the progress surface as `GAME DATA`, `Preparing Unreal Tournament`, `Validating 132 of 283`, current file, 47% progress, and `Cancel game data import` with the safe-cancellation hint.
- The accepted Simulator Save Screen capture is 2360×1640. A second clean launch reached `Game engine initialized` and `Entering main loop` with full-bleed gameplay and separated controls after the progress overlay was removed.
- Simulator, arm64 iOS stub-audio, and arm64 iOS real-FMOD packages all passed `verify_ios_package.sh`; the real-FMOD artifact remained classified `READY`.

## Accepted evidence

- `ipad-import-progress-landscape.png` — native 2360×1640 Simulator Save Screen output with the centered, non-overlapping progress card.
- `ipad-gameplay-regression-landscape.png` — native 2360×1640 post-import-UI engine regression frame.
- `UT99-engine.stdout` — cumulative app-container log containing the accepted run's Frucore initialization, `Game engine initialized`, and `Entering main loop`.
- `accessibility.txt` — semantic labels and progress value observed through the live Simulator accessibility tree.
- `command.txt` — bounded build/test/run commands.
- `environment.json` — host, SDK, destination, package, and screenshot facts.

## Limitations

- No iPhone or iPad hardware is attached. Physical Files-provider access, storage pressure, interruption timing, and cancellation latency remain unproven.
- ZIP cancellation is cooperative between entries; a single raw-deflate entry is not interrupted inside the one-shot inflater.
- Simulator output is UI and integration evidence only, not a physical renderer, performance, thermal, battery, audio, or touch claim.
