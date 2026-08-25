# UT99Apple

<p align="center">
  <strong>Unreal Tournament 99, experimentally rehosted for iPhone and iPad.</strong><br>
  OldUnreal v469e, FruCoRe Metal rendering, touch controls, local data import,
  and the original online protocol inside a native UIKit host.
</p>

<p align="center">
  <a href="https://github.com/chrissotraidis/utp/actions/workflows/public-safety.yml"><img alt="Public repository safety" src="https://github.com/chrissotraidis/utp/actions/workflows/public-safety.yml/badge.svg"></a>
  <img alt="iOS and iPadOS 17 or later" src="https://img.shields.io/badge/iOS%20%2F%20iPadOS-17%2B-0A84FF?logo=apple">
  <img alt="FruCoRe Metal renderer" src="https://img.shields.io/badge/renderer-FruCoRe%20Metal-5E5CE6">
  <img alt="Physical-device validation pending" src="https://img.shields.io/badge/physical%20device-validation%20pending-FF9F0A">
  <img alt="No public binary" src="https://img.shields.io/badge/public%20binary-not%20available-8E8E93">
  <img alt="Game data not included" src="https://img.shields.io/badge/game%20data-not%20included-FF453A">
</p>

<p align="center">
  <a href="#release-status">Status</a> ·
  <a href="#build-and-test">Build</a> ·
  <a href="#controls-and-input">Controls</a> ·
  <a href="#frequently-asked-questions">FAQ</a> ·
  <a href="docs/evidence/index.md">Evidence</a> ·
  <a href="https://github.com/chrissotraidis/utp/issues/new/choose">Report a problem</a>
</p>

UT99Apple is an experimental native iOS/iPadOS host for the official
[OldUnreal Unreal Tournament v469e](https://github.com/OldUnreal/UnrealTournamentPatches/releases/tag/v469e)
ARM64 runtime. A deterministic build-time pipeline prepares the runtime for an
iOS app bundle, replaces or narrowly adapts audited desktop dependencies, and
hosts the original engine inside UIKit. FruCoRe remains responsible for the
Metal-rendered game, while the host owns lifecycle, touch input, data import,
diagnostics, and Apple-platform integration.

This repository does **not** contain Epic game data, OldUnreal release
binaries, a generated engine image, signing material, or a downloadable IPA.
Those boundaries are enforced by [`make public-check`](#repository-safety).

> [!IMPORTANT]
> This is a developer and preservation project, not a finished consumer
> release. Simulator gameplay is meaningful engineering evidence, but the
> signed physical-device path, hardware input/audio/performance matrix, and
> permission to distribute the transformed runtime are still open gates.

## Release status

| Surface | Current status | Meaning |
|---|---|---|
| Source repository | **Public-release preparation** | The source tree is being hardened and documented; no public source release tag has been created. |
| iPhone/iPad Simulator | **Development path working** | The original engine reaches live bot and network sessions through FruCoRe/Metal with the native host and touch layer. |
| Physical iPhone/iPad | **Not yet verified** | Device signing, first frame, touch-only play, audio, controllers, lifecycle, and sustained performance remain hardware gates. |
| TestFlight / public IPA | **Not available** | No public binary or general install path exists. A local diagnostic IPA is not a consumer release. |
| App Store / website install | **Not announced** | Distribution permission, Apple review/channel requirements, privacy work, and physical acceptance remain open. |

The authoritative gate ledger is [`docs/STATUS.md`](docs/STATUS.md). The
requirement-by-requirement view is
[`docs/COMPLETION_AUDIT.md`](docs/COMPLETION_AUDIT.md), and the underlying
records are indexed in [`docs/evidence/`](docs/evidence/index.md).

## What works today

Current repository evidence includes:

- reproducible inspection of the official OldUnreal v469e Apple Silicon
  baseline and all eight recursively discovered native images;
- build-time preparation of an iOS-platform ARM64 engine candidate without a
  runtime JIT;
- a UIKit host with a full-bleed FruCoRe Metal surface on iPhone and iPad
  Simulator targets;
- touch movement, aim, FIRE, ALT, USE, JUMP, DUCK, PREV/NEXT, SCORE, and the
  original Unreal menu;
- editable touch layout, opacity, handedness, saved profiles, diagnostics,
  lifecycle recovery, keyboard/controller bridges, and a compact host menu;
- first-run **Get Game Data** and **Import Files** flows with explicit consent,
  pinned verification, data-only extraction, transactional install, and
  temporary-file cleanup;
- the original v469 online server browser, public-server join, data-only
  package download, combat, death/respawn, map transition, and clean
  disconnect in Simulator; and
- a final-package iPhone Simulator session that held one engine process for
  more than 30 minutes and survived three Home/reopen cycles.

These are not claims of physical-device acceptance. See
[`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md) for the remaining limits.

## Game data and first launch

The app and Unreal Tournament content are deliberately separate. Local
development builds present two first-run choices:

1. **Get Game Data** shows the source, size, terms, and destination before any
   download; verifies the exact approved installer image by size and SHA-256;
   extracts only supported data packages; and removes temporary media.
2. **Import Files** accepts a user-owned folder or ZIP, rejects unsafe paths,
   encrypted entries, and desktop/native executables, then installs the data
   transactionally.

Only `Maps`, `Music`, `Sounds`, and `Textures` data is accepted. The repository
and app package remain data-free. The implemented acquisition flow is ready
for physical testing, but enabling it in a publicly distributed binary still
requires written permission and Apple-channel review. See
[`docs/DATA_COMPATIBILITY.md`](docs/DATA_COMPATIBILITY.md) and
[`docs/DISTRIBUTION_AND_ONBOARDING.md`](docs/DISTRIBUTION_AND_ONBOARDING.md).

## Controls and input

The touch interface is designed as a full-bleed landscape overlay:

- **Left thumb:** movement stick plus SCORE, USE, PREV, and NEXT utility
  directions.
- **Right thumb:** look/aim stick, FIRE, ALT, JUMP, and DUCK.
- **Menus:** a persistent `•••` button opens host settings; MENU opens the
  original Unreal interface.
- **Customization:** opacity, scale, handedness, visibility, drag/pinch layout
  editing, saved profiles, and restore defaults.

Native GameController, hardware-keyboard, and pointer bridges are included in
the device target. Their model-specific physical behavior is not accepted yet;
do not read compiled support as completed hardware validation.

## Build and test

### Requirements

- an Apple Silicon Mac;
- Xcode and its command-line tools;
- enough local storage for pinned upstream inputs and generated build output;
- a user-owned Unreal Tournament GOTY source for manual import testing; and
- an Apple Development team plus one trusted Developer Mode device for the
  physical path.

All proprietary inputs and generated products stay under ignored `ref/` and
`build/` paths.

### Core developer workflow

```bash
git clone https://github.com/chrissotraidis/utp.git
cd utp

make doctor
make bootstrap
make mac-baseline
make audit-469e
make test
make public-check
```

Useful targets:

| Command | Purpose |
|---|---|
| `make ios-engine-sim-package` | Build the no-audio Simulator diagnostic package |
| `make ios-engine-sim-real-package` | Build the local real-FMOD Simulator experiment |
| `make ios-engine-package` | Build the ad-hoc device diagnostic package |
| `make ios-engine-real-package` | Build the real-FMOD device candidate |
| `make diagnostics` | Collect a redacted local diagnostics archive |
| `make clean-runtime` | Stop project runtimes and shut down Simulators |

Simulator products are development evidence only. The device path requires a
non-secret ten-character team identifier supplied at invocation time:

```bash
DEVELOPMENT_TEAM=YOURTEAMID make device-check
DEVELOPMENT_TEAM=YOURTEAMID make device-run
DEVELOPMENT_TEAM=YOURTEAMID make verify-device
```

`device-run` uses Xcode automatic provisioning, verifies the produced app,
installs it through CoreDevice, and launches the host. Set `DEVICE_UDID` only
when more than one physical iPhone or iPad is connected. Do not commit either
value.

## Architecture

```mermaid
flowchart LR
    A["Official v469e ARM64 macOS input"] --> B["Deterministic Mach-O and dependency audit"]
    B --> C["Build-time iOS platform preparation"]
    C --> D["Signed native dependencies and narrow shims"]
    D --> E["UIKit host and SDL2 boundary"]
    E --> F["FruCoRe Metal renderer and original engine"]
    G["User-authorized game data"] --> H["Validated transactional import"]
    H --> F
```

The host owns scenes, sandbox paths, onboarding, diagnostics, recovery, and
touch UI. The original engine remains responsible for menus, maps, game rules,
bot behavior, rendering, and the UT network protocol. Imported native code is
not supported.

This is a bounded binary-rehosting experiment, not a browser port, streaming
client, Windows compatibility layer, x86 emulator, or Unreal Engine 1 rewrite.
The exact technical and stop-gate rationale is in
[`docs/UT99_Apple_PRD.md`](docs/UT99_Apple_PRD.md).

## Online play

The current Simulator build has populated the original v469 server browser,
joined unmodified public servers, downloaded data-only packages, reached
player possession, exercised combat and respawn, survived a natural map
transition, and disconnected through the original menu.

Public launch copy must wait for the physical-device networking gate: device
Wi-Fi/DNS/UDP, original-browser play, package download, chat observed by a
second player, background behavior, and clean reconnect. The exact boundary
is tracked in [`docs/NETWORK_COMPATIBILITY.md`](docs/NETWORK_COMPATIBILITY.md).

## Repository safety

Run the same fast gate used by pull requests:

```bash
make public-check
```

It rejects tracked or unignored build/reference areas, game packages,
archives, app/IPA products, signing material, likely credentials, local user
paths, oversized files, invalid scripts, malformed third-party metadata,
broken local Markdown links, and prohibited paths in Git history.

Before changing visibility, publishing a source tag, or shipping any binary,
follow [`docs/PUBLIC_RELEASE_CHECKLIST.md`](docs/PUBLIC_RELEASE_CHECKLIST.md).

## Frequently asked questions

<details>
<summary><strong>Can I download and play UT99Apple now?</strong></summary>

No public binary, TestFlight, App Store listing, or general IPA install is
available. The current repository is a developer build and evidence base. A
local diagnostic IPA is not a public consumer release.
</details>

<details>
<summary><strong>Does the repository include Unreal Tournament?</strong></summary>

No. It contains no Epic game data, OldUnreal release binary, generated engine
image, or prepared runtime package. Do not open issues requesting proprietary
files or download links.
</details>

<details>
<summary><strong>How does first-run setup work?</strong></summary>

Local builds offer **Get Game Data** and **Import Files**. Both paths validate
content and install only supported data packages. The direct acquisition path
shows its source, size, terms, and destination before consent. Its public-binary
use still requires permission and Apple review.
</details>

<details>
<summary><strong>Does it require a jailbreak or JIT?</strong></summary>

The architecture is explicitly designed for stock iOS signing without a
runtime JIT or downloaded executable code. The package and static audit paths
support that design, but a signed physical-device run remains the gate before
calling the complete runtime path proven.
</details>

<details>
<summary><strong>Which devices are supported?</strong></summary>

The project targets arm64 iPhone and iPad on iOS/iPadOS 17 or later. Current
runtime acceptance is Simulator-only. No physical model should be advertised
as supported until its first-frame, touch, audio, lifecycle, and performance
checks pass.
</details>

<details>
<summary><strong>Do controllers, keyboards, and mice work?</strong></summary>

The native controller, hardware-keyboard, and pointer bridges compile into the
device target. Physical mapping, reconnect, rumble, motion, mouse buttons,
keyboard traversal, and mixed-input behavior still require hardware evidence.
</details>

<details>
<summary><strong>Does online multiplayer work?</strong></summary>

Meaningful original-protocol play works in Simulator, including the server
browser, join, package download, combat, respawn, map transition, and
disconnect. Physical networking and observer-confirmed chat remain release
gates.
</details>

<details>
<summary><strong>Why is there no public IPA?</strong></summary>

A raw diagnostic IPA is not a universal iOS installer. More importantly,
physical acceptance, transformed-runtime distribution permission, acquisition
permission, privacy work, signing operations, and the chosen Apple delivery
channel are unresolved. TestFlight is the intended first external beta path
if those gates close.
</details>

<details>
<summary><strong>Will updates preserve imported data?</strong></summary>

The importer uses a transactional install boundary and deterministic rollback
tests pass. In-place physical app updates and real Files-provider preservation
must still be accepted before any public guarantee is made. Back up user data
before replacing development builds.
</details>

<details>
<summary><strong>Where should I report a problem?</strong></summary>

Read [`SUPPORT.md`](SUPPORT.md), then use the structured
[bug report](https://github.com/chrissotraidis/utp/issues/new/choose). Include
the commit, environment, device/OS, build stage, and exact reproduction. Share
only redacted diagnostics—never game data, generated runtime images, signing
files, credentials, or private paths.
</details>

<details>
<summary><strong>Is UT99Apple open source?</strong></summary>

Not currently in the broad licensing sense. The project-owned source is being
prepared for public inspection, but no top-level reuse license has been
granted. Third-party components retain their own terms. See
[`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md).
</details>

## Project map

| Path | Purpose |
|---|---|
| [`Sources/UT99Host/`](Sources/UT99Host/) | UIKit host, touch UI, import, recovery, and diagnostics |
| [`Sources/UT99Runtime/`](Sources/UT99Runtime/) | Narrow runtime compatibility shims |
| [`tools/`](tools/) | Bootstrap, audit, build, package, device, and safety tooling |
| [`Tests/`](Tests/) | Deterministic shell, Swift, Python, package, and source checks |
| [`third_party/deps.lock.json`](third_party/deps.lock.json) | Pinned public dependency provenance and licensing intent |
| [`docs/STATUS.md`](docs/STATUS.md) | Current gate, blockers, and verified boundary |
| [`docs/TEST_MATRIX.md`](docs/TEST_MATRIX.md) | Acceptance matrix by environment |
| [`docs/evidence/`](docs/evidence/index.md) | Human-readable evidence ledger; raw artifacts remain local |
| [`docs/PUBLIC_RELEASE_CHECKLIST.md`](docs/PUBLIC_RELEASE_CHECKLIST.md) | Source and binary publication gates |

Generated source trees, upstream binaries, local game data, screenshots/logs
with private context, app bundles, and packaging output stay ignored.

## Contributing and support

Read [`CONTRIBUTING.md`](CONTRIBUTING.md) before proposing a change. Use
[`SUPPORT.md`](SUPPORT.md) for issue-routing and evidence guidance, and
[`SECURITY.md`](SECURITY.md) for sensitive reports. Pull requests should be
focused, run `make public-check`, state the validation performed, and preserve
the distinction between Simulator evidence and physical-device acceptance.

## Legal and acknowledgements

UT99Apple is an independent, unofficial preservation and engineering project.
It is not affiliated with or endorsed by Epic Games, OldUnreal, or Apple.
Unreal Tournament, Unreal, OldUnreal, Apple platform names, and all other
third-party names and trademarks belong to their respective owners.

The project builds on or references OldUnreal v469e, SDL2, FruCoRe/OpenGLDrv,
OpenAL Soft, mpg123, libsndfile, libxmp, and their contributors. Public access
to this repository does not relicense those projects, Epic game data, or the
official runtime. See [`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md).
