# UT99Apple

UT99Apple is an in-progress native iOS/iPadOS host for the official OldUnreal Unreal Tournament 99 v469e ARM64 runtime. It is a local-build and preservation project: it does not redistribute Epic game data, OldUnreal binaries, or generated engine artifacts.

## Current status

The macOS v469e baseline is reproducible on Apple Silicon. The build-time rehosting pipeline produces signed-at-build iOS-platform engine candidates, embeds them in an Apple UIKit host, and reaches the original engine’s renderer and main loop in the iOS Simulator.

Verified simulator coverage currently includes:

- iPad Air 11-inch (M4), landscape, live `DM-Deck16][` bot-session entry.
- iPhone and iPad landscape targets with a native full-bleed Metal surface and overlaid touch controls.
- Metal/FruCoRe initialization and original engine logs.
- EctoPad-derived UT controls for movement, look, FIRE, ALT, USE, JUMP, DUCK, PREV/NEXT, SCORE, and the original Unreal game menu.
- Persistent touch layout editing, opacity/profile settings, host menu, data import, diagnostics, lifecycle callbacks, and controller/keyboard bridge code.
- The original v469 online server browser, public-server join, data-only package downloads, movement/combat, death/respawn, map transition, and clean disconnect.
- A final-package iPhone run held one engine process for more than 30 minutes and survived three actual Simulator Home/reopen cycles with post-resume play.

Physical iPad/iPhone startup, first-frame capture, touch-only play, safe-area scaling, performance, controller hardware, audio routes, and keyboard/mouse hardware are not yet proven. No physical device is attached in the current development environment.

See [`docs/STATUS.md`](docs/STATUS.md) for the active gate and [`docs/evidence/index.md`](docs/evidence/index.md) for the evidence ledger.

The next gate is physical hardware. The build, UI, offline game, and online protocol path are in good enough local shape to stop Simulator iteration and test one signed iPhone/iPad. See [Distribution and first-run onboarding](docs/DISTRIBUTION_AND_ONBOARDING.md) for the physical handoff and eventual TestFlight/website/data-download plan.

## Local prerequisites and inputs

You need an Apple Silicon Mac with Xcode and a user-owned Unreal Tournament GOTY installation or authorized content source. The local workflow keeps proprietary inputs under ignored paths:

- official v469e macOS release under `ref/OldUnreal/`;
- EctoPad reference under `ref/ectopad/` (with a pristine local source mirror when needed);
- GOTY installation media/content under `ref/`;
- generated canonical content under `build/UT99Data*`.

Do not commit these inputs, patched binaries, app bundles, IPA payloads, signing material, or user game data.

## Build and test

```bash
make doctor
make bootstrap
make mac-baseline
make audit-469e
make data-pack SOURCE=/path/to/Unreal\ Tournament
make mac-hosted-harness
make ios-engine-sim-package
make ios-engine-package
make ios-engine-real-package
make test
make device-check
make diagnostics
UT99_PACKAGE_MODE=diagnostic make package-local
make clean-runtime
```

`ios-engine-sim-package` is diagnostic simulator evidence. The two `iphoneos` targets produce unsigned/ad-hoc locally verifiable device packages; installing and running them still requires a physical device, signing configuration, and hardware evidence.

`bootstrap` obtains only the pinned public inputs recorded in `third_party/deps.lock.json`, verifies hashes/commits, and stores them under ignored `ref/`. `mac-baseline` verifies the official v469e DMG and prepares the ignored macOS oracle app. The diagnostic IPA mode checks archive construction and ad-hoc signing but is intentionally not installable on stock iOS; the default `package-local` mode requires `DEVELOPMENT_TEAM` and a real Apple Development identity.

For the first physical-device pass, connect and trust exactly one iPhone or iPad, enable Developer Mode, and provide the non-secret Apple development team identifier without storing it in the repository:

```bash
DEVELOPMENT_TEAM=YOURTEAMID make device-check
DEVELOPMENT_TEAM=YOURTEAMID make device-run
DEVELOPMENT_TEAM=YOURTEAMID make verify-device
```

`device-run` shuts down simulator/game runtimes, builds the real-FMOD iPhoneOS candidate with Xcode automatic provisioning, verifies it, installs it through CoreDevice, and launches the host. After importing valid data on the device, opt into the automated engine/match launch with `UT99_DEVICE_AUTOSTART=1 DEVELOPMENT_TEAM=YOURTEAMID make device-run`. Set `DEVICE_UDID` only when more than one physical iOS/iPadOS device is connected.

`verify-device` performs the automated portion of G2: signed install, one host Metal presentation, transactional importer fixture, diagnostics archive creation, CRC verification, and evidence collection under ignored `build/device-evidence/`. It deliberately reports `AUTOMATED_PARTIAL`; a physical screenshot, direct EctoPad/menu taps, Files-picker import, and share-sheet export are still required before promoting G2.

The runtime discipline is intentional: use only one simulator and one UT99 client at a time. Always run `./tools/ensure_single_runtime.sh --clean` after a run and verify that no simulator remains booted.

## Architecture

```text
official v469e ARM64 macOS input
        → deterministic build-time Mach-O/platform transformation
        → signed iOS-compatible engine image and native dependencies
        → UIKit host + SDL2 UIKit/Metal boundary
        → FruCoRe Metal renderer
        → user-imported GOTY data
        → EctoPad-derived touch/controller/keyboard input
```

The host owns scene lifecycle, sandbox paths, data import, diagnostics, and touch UI. The original engine remains responsible for UT menus, maps, game rules, bot behavior, rendering, and the UT network protocol. Native code from imported game data is not supported.

## Controls

The default touch layout is measured from EctoPad’s native overlay: a fixed dark movement stick, fixed yellow aim stick, dominant green FIRE action, red ALT action, light JUMP/DUCK actions, and a compact D-pad mapped to SCORE/USE/PREV/NEXT. The original Unreal `MENU` action and native sliders host menu remain separate. The Touch Layout section provides drag, pinch, reset, opacity, scale, handedness, visibility, and profile controls.

The host uses the complete landscape scene for FruCoRe and overlays the EctoPad-derived controls above it. Current Simulator passes negotiate 1180×820 points / 2360×1640 pixels on iPad and 956×440 points / 2868×1320 pixels on iPhone. Physical safe-area, reach, simultaneous touch, and haptic validation remain required.

## Data and legal boundary

The importer accepts an authorized folder or canonical data ZIP, validates content before transactional commit, writes a manifest, and rejects desktop executables/native modules. OldUnreal now publishes full-game installers that obtain the GOTY disc image from its own servers with Archive.org fallback, so a consent-based **Get Game Data** flow is a sensible product direction. This repository will not mirror that image, bundle it into the IPA, or ship a prebuilt transformed engine until the exact permissions and Apple distribution route are confirmed. UT99, Unreal Tournament, OldUnreal, SDL, FruCoRe, and EctoPad are third-party names and projects; this repository is unaffiliated unless explicitly stated by their owners.

## Distribution direction

The intended beta path is TestFlight after physical-device signing and validation. Ad Hoc IPA files work only for registered test devices; placing a raw IPA on a webpage is not universal iOS installation. Apple-approved web distribution is region- and entitlement-dependent and requires review/notarization plus server-side installation licensing.

The eventual first-run experience should offer **Get Game Data** and **Import Existing Data**, show source/size/terms before download, verify a pinned digest, extract only data packages, and commit them transactionally. Details and open permission gates are in [`docs/DISTRIBUTION_AND_ONBOARDING.md`](docs/DISTRIBUTION_AND_ONBOARDING.md).

## Physical hardware handoff

Connect and trust exactly one Developer Mode iPhone or iPad, add an Apple Development team, then run:

```bash
DEVELOPMENT_TEAM=YOURTEAMID make device-check
DEVELOPMENT_TEAM=YOURTEAMID make device-run
DEVELOPMENT_TEAM=YOURTEAMID make verify-device
UT99_DEVICE_AUTOSTART=1 DEVELOPMENT_TEAM=YOURTEAMID make device-run
```

The physical pass must capture first frame, touch-only play, audio, three Home/resume cycles, safe areas/rotation, performance, online server-browser play, and diagnostic export. Simulator evidence must not be used to waive a failed hardware check.

## Evidence and known limitations

The project is not Definition-of-Done complete. The authoritative limitations are tracked in [`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md), and the full product contract is [`docs/UT99_Apple_PRD.md`](docs/UT99_Apple_PRD.md). The next promotion work is physical-device validation of the native engine path, followed by touch-only gameplay, audio, controller, lifecycle, performance, and unmodified-server evidence.
