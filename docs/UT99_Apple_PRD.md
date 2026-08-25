# Unreal Tournament 99 for Apple Platforms — Product Requirements Document

**Canonical repository location:** `docs/UT99_Apple_PRD.md`  
**Companion execution document:** `docs/UT99_Agent_Goal_Loop.md`  
**Status:** Implementation PRD with mandatory feasibility gates  
**Research cutoff:** 2026-08-23  
**Internal working name:** `UT99Apple`  
**Primary product:** Native Unreal Tournament (1999) client for iOS and iPadOS  
**Reference desktop build:** OldUnreal Unreal Tournament v469e for macOS  
**UI reference:** EctoPad under `ref/ectopad` (source mirror `/Users/chrissotraidis/GitHub/ectopad`)

---

## 1. Executive summary

Build a genuinely native ARM64 version of **Unreal Tournament (1999)** for iPhone and iPad. The finished app must run the original game locally, render through Metal, support excellent touch controls and physical controllers, import user-owned or otherwise authorized Unreal Tournament GOTY content, and remain compatible with the existing Unreal Tournament v469 online ecosystem.

This is **not** a browser port, streamed game, Windows compatibility layer, x86 emulator, or generic macOS-on-iOS launcher. The target experience is a normal iOS/iPadOS game application:

1. Install the locally signed app or IPA.
2. Import supported Unreal Tournament game data from a folder or canonical ZIP.
3. Launch the original game.
4. Play bot matches, single-player ladders, LAN games, and online multiplayer.
5. Use a physical controller, keyboard and mouse on iPad, or a polished EctoPad-derived touch interface.

The modern macOS version already solves several of the hardest platform problems. OldUnreal v469e supports Apple Silicon, uses SDL-based window management, contains a native Metal renderer called Fruit Company Renderer (`FruCoRe`/`Frucore`), and is the current official OldUnreal release recommended for online play. However, OldUnreal’s complete modified engine source is not publicly available. The public 469 SDK is a development SDK, not a complete buildable engine tree. Therefore the primary independent strategy is a **bounded binary-rehosting project**:

- Preserve the official v469e ARM64 macOS build as the behavioral and networking baseline.
- Audit the shipped ARM64 Mach-O executable and native packages.
- Create a build-time patch pipeline that converts the required macOS ARM64 code into signed iOS-compatible embedded code.
- Replace or shim macOS-only dependencies with iOS implementations.
- Host the patched engine inside a native UIKit/Metal application.
- Reuse or rehost the public Metal renderer rather than writing a new renderer.

This route is plausible but not guaranteed. The project must not spend months hiding a failed foundation behind UI work. It has strict promotion and stop gates. The first major success criterion is not a polished menu; it is **the official v469e ARM64 engine reaching its own startup code on a physical iPhone or iPad without runtime JIT**. If the dependency audit proves that the engine is inseparably tied to unavailable macOS APIs, or if stock iOS code signing makes the approach impossible without JIT, the agent must stop and produce a precise feasibility report rather than pivoting into an Unreal Engine 1 reimplementation.

---

## 2. Product vision

### 2.1 Vision statement

Deliver the first credible native iOS/iPadOS Unreal Tournament 99 client: the original game, the original content and network protocol, modern Apple rendering and controls, and a setup flow that a technically competent owner can complete without hunting through abandonware forums or manually editing configuration files.

### 2.2 The compelling demonstration

The product is successful when an iPad or iPhone can:

- open Unreal Tournament;
- load `DM-Deck16][` with bots;
- play smoothly with touch controls;
- pair with an Xbox, DualSense, or MFi controller;
- open Multiplayer → Internet;
- populate the community server browser or connect by address; and
- join an unmodified server alongside Windows, Linux, and macOS v469 players.

### 2.3 Product principles

1. **Working game before ornamental UI.** UI work cannot conceal an engine that does not boot.
2. **Same game, not a remake.** Preserve UT packages, physics, AI, rendering behavior, game rules, demos, and network protocol as closely as the v469e engine permits.
3. **469-class compatibility.** The target is modern UT99 compatibility and online interoperability, not merely an isolated v400 mobile build.
4. **Native Apple integration.** ARM64, Metal, UIKit, Game Controller, Files integration, correct lifecycle handling, and Apple-platform diagnostics.
5. **Authorized data with explicit consent.** Do not commit or silently redistribute Epic game data or OldUnreal binaries. An approved source download may be offered only with clear provenance, terms, consent, digest verification, and permission for this use.
6. **Reproducibility.** A new developer must be able to run a documented bootstrap command and reproduce the build from pinned inputs.
7. **Evidence over optimism.** Every promotion gate requires logs, screenshots, test output, and device details.
8. **No accidental engine project.** If the selected foundation fails, stop. Do not begin finishing SurrealEngine or reconstructing UE1 unless the project owner explicitly authorizes that separate undertaking.

---

## 3. Goals and non-goals

### 3.1 Primary goals

- Establish a flawless, reproducible v469e macOS reference installation using Metal.
- Build an iOS/iPadOS host application that can run the v469e ARM64 game engine natively.
- Support iPhone and iPad in landscape orientation.
- Deliver a high-quality custom touch controller based on EctoPad's measured iPhone/iPad interface.
- Support physical controllers, keyboard, and mouse.
- Support sound effects, music, voice/announcer audio, and correct audio interruption behavior.
- Import and validate game data from common GOTY distributions, including Steam-origin data when available to the user.
- Provide a first-run **Get Game Data** path from an explicitly authorized source, if distribution permission is confirmed, while retaining folder/ZIP import.
- Preserve online compatibility with current community master servers and direct-address v469 servers.
- Provide an excellent three-dot host menu for controls, data management, diagnostics, logs, and recovery.
- Produce complete build, architecture, testing, provenance, and troubleshooting documentation.
- End with a current README modeled on the quality and clarity of the EctoPad reference README.

### 3.2 Secondary goals

- External display support on iPad.
- Configurable gyro aiming.
- 60 Hz and 120 Hz presentation modes where stable.
- Data-only community maps, skins, mutators, and UnrealScript packages.
- A canonical data-export utility for macOS.
- A reproducible locally signed IPA packaging flow.
- A documented TestFlight-first beta and permission-gated public distribution plan.

### 3.3 Explicit non-goals for the initial release

- Unreal Tournament 2004.
- UnrealEd on iOS/iPadOS.
- App Store approval or public commercial distribution before engine/data permissions, physical gates, and Apple review requirements are satisfied.
- Bundling Epic’s original game content in the source repository.
- Bundling a modified OldUnreal engine binary in public releases without clear permission.
- Supporting arbitrary downloaded native C++ mods or desktop `.dll`/`.dylib` modules.
- Finishing SurrealEngine.
- Using UT99-Android, `ut99dc`, the Dreamcast lineage, Wine, QEMU, or WebAssembly as the shipping runtime.
- Running the macOS executable through CPU emulation.
- Requiring JIT in the final preferred architecture.
- Rewriting the renderer from scratch before the existing Metal renderer has been exhausted.

---

## 4. Current landscape and research conclusions

### 4.1 What already exists

- **OldUnreal v469e** is the current official OldUnreal UT99 release and is recommended for online play.
- OldUnreal supports **Apple Silicon macOS**, SDL-based macOS window management, community master servers, and the **FruCoRe Metal renderer**.
- OldUnreal’s macOS installation deliberately separates modern engine/system files from user-provided content. Users copy `Maps`, `Sounds`, `Textures`, and `Music`; they must not replace the modern `System` directory with the original game’s desktop binaries.
- OldUnreal and its community infrastructure provide sanctioned full-game installation workflows that obtain the GOTY disc content and apply the modern patch.
- The public Fruit Company Renderer source initializes Metal through SDL’s Metal view and a `CAMetalLayer`. Its architecture is much closer to iOS than an AppKit-bound renderer would be.
- SDL2 and SDL3 both have official iOS support, including UIKit lifecycle glue, Metal game templates, high-DPI handling, controller support, sandbox paths, and device/simulator frameworks.
- UT99 has working ARM mobile precedent on Android. This proves that the game’s workload, controls, and data model are viable on mobile hardware, but that codebase is not the selected production foundation.

### 4.2 What does not exist publicly

- No credible public native UT99 iOS/iPadOS client was found.
- OldUnreal’s full v469e engine source is not public.
- The public v432 `Ut99PubSrc` repository describes itself as only the publicly released portion of the source. Its CMake targets link against prebuilt `Core`/`Engine` libraries and do not provide a modern Apple engine implementation.
- SurrealEngine is a permissively licensed clean reimplementation, but it remains behaviorally incomplete and currently has no networking. It is not a shortcut to a complete online UT99 client.

### 4.3 Why binary rehosting is being attempted

The official macOS game is already compiled for ARM64. CPU instruction translation is unnecessary. The remaining gap is platform ABI and operating-system integration:

- Mach-O platform declaration: macOS → iOS.
- macOS dynamic library paths → signed iOS frameworks/dylibs.
- macOS application/window lifecycle → UIKit/SDL iOS lifecycle.
- any direct AppKit/CoreVideo/macOS-only imports → iOS equivalents or narrow shims.
- read/write paths → iOS sandbox.
- input → Game Controller and touch overlay.
- code signing → all executable code generated at build time and signed into the app.

There is public prior art for changing a macOS ARM64 binary’s platform, converting an executable into a dylib, rewriting framework imports, and invoking its entry point from an iOS host. Projects such as `maciOS` and LiveContainer demonstrate the mechanism. They also demonstrate the danger: generic compatibility layers only run simple applications and often depend on JIT or broad framework emulation. This project must avoid becoming a generic compatibility layer. It should implement only the symbols and behavior the audited UT99 binary actually needs.

### 4.4 Feasibility position

The project is **worth a bounded implementation spike** because:

- the CPU architecture already matches;
- the renderer already targets Metal and `CAMetalLayer`;
- the desktop client already uses SDL;
- the same engine supplies the desired network protocol and game behavior; and
- the initial go/no-go experiment is sharply defined.

The project is **not yet guaranteed** because:

- the complete source is unavailable;
- the shipped app may contain direct desktop framework assumptions;
- iOS requires all executable code to be signed and platform-compatible;
- the engine’s native package loading model may conflict with iOS restrictions; and
- audio or other bundled libraries may include macOS-only/proprietary components.

---

## 5. Target users and user stories

### 5.1 Primary user

A technically comfortable UT99 owner or preservation enthusiast who wants the original game on an iPhone or iPad and can initially build/sign or sideload an IPA.

### 5.2 Core user stories

- As a user, I can import a valid GOTY data folder or ZIP and receive a precise validation result.
- As a user, I can start UT99 and reach the original menu without a desktop computer remaining connected.
- As a touch player, I can move, aim, fire primary and alternate fire, jump, crouch, switch weapons, use inventory, open the scoreboard, and navigate menus.
- As a controller player, I can pair a supported controller and play without touch controls obscuring the screen.
- As an iPad player, I can use keyboard and mouse with correct pointer capture and release.
- As an online player, I can populate the v469 community browser or join a server by address.
- As a user, I can open the right-side three-dot menu to customize controls, manage data, inspect logs, and recover from a bad configuration.
- As a developer, I can reproduce the patched engine artifact from an official v469e input without committing proprietary binaries.
- As a developer, I can identify the exact failing subsystem from a structured log bundle.

---

## 6. Supported platforms and baseline requirements

### 6.1 Product targets

- **iPadOS:** Primary target; landscape; arm64; iPadOS 17 or later unless a lower target is proven inexpensive.
- **iOS:** Required target; landscape; arm64; iOS 17 or later unless a lower target is proven inexpensive.
- **macOS:** Development/reference target. Use the official v469e Apple Silicon application as the baseline. A macOS helper or harness may be built, but rebuilding the full desktop game is not required.
- **Simulator:** UI shell, importer, menu, and touch-layout testing only. The real rehosted engine must be proven on physical hardware because an arm64 iOS Simulator slice is a different platform from arm64 iOS-device and macOS slices.

### 6.2 Development environment

- Apple Silicon Mac.
- Current installed Xcode and command-line tools; use the currently required iOS/iPadOS SDK for packaging.
- A physical iPad as the primary engine-validation device.
- A physical iPhone for layout and thermal validation before release.
- A valid Apple development team for signing.
- Sufficient local disk space for the DMG, data sources, generated canonical data pack, build products, and evidence.

### 6.3 Initial device performance targets

- M-series iPad: stable 60 FPS at native or near-native internal resolution; 120 FPS optional.
- A14-class or newer iPhone/iPad: stable 60 FPS in stock maps after tuning.
- Input latency suitable for multiplayer.
- No continuous background CPU usage when the app is not active.
- Memory warnings handled without corrupting data or configuration.

These are targets, not assumptions. The agent must record actual metrics by device and map.

---

## 7. Chosen technical strategy

### 7.1 Primary strategy: build-time rehosting of official v469e ARM64 code

The preferred final architecture contains no runtime JIT and no on-device binary patching. The macOS input binary is processed on the development Mac during the build:

```text
Official OldUnreal v469e macOS DMG
            ↓ extract and verify
Pristine ARM64 UnrealTournament executable + required native packages
            ↓ audit
Host-side Mach-O transformation
            ↓
Signed iOS-compatible engine dylib/framework(s)
            ↓
Native UIKit/Metal host app
            ↓
User-imported GOTY data
            ↓
UT99 on iPhone/iPad
```

All generated executable artifacts live under ignored build directories. The public source tree contains the patcher, shims, host, tests, manifests, and documentation—not OldUnreal or Epic binaries.

### 7.2 Two ordered execution experiments

#### Experiment A — direct executable retarget

Create a copy of the ARM64 executable, patch its platform/load commands, replace dependencies, sign it as the iOS app’s main executable, and determine whether it can enter its startup routine. This is the least invasive route but makes host-overlay integration harder.

#### Experiment B — hosted engine dylib

Convert a copy from `MH_EXECUTE` to `MH_DYLIB`, adjust `__PAGEZERO`, retain or expose the LC_MAIN entry point through a small trampoline, patch dependencies, embed and sign it, then call it from the UIKit host. This route is preferred for the final product because the native host can own lifecycle, data import, the touch overlay, the three-dot menu, logs, and recovery.

The agent must test both only as necessary. If Experiment A reaches startup but is difficult to integrate, use it to validate feasibility and continue with Experiment B. If both fail for the same fundamental reason, stop.

### 7.3 Explicitly rejected automatic pivots

If rehosting fails, the agent must not silently move to:

- SurrealEngine completion;
- v432 engine reconstruction;
- the Android/Dreamcast source lineage;
- Wine or Windows emulation;
- generic macOS framework emulation;
- a browser/WebAssembly port; or
- a streamed desktop client.

Any such pivot requires a new PRD decision by the project owner.

---

## 8. Proposed system architecture

### 8.1 Components

#### `UT99Host`

Swift/Objective-C++ iOS application shell. Owns `UIApplication`, scenes, lifecycle, safe areas, system dialogs, file import, overlays, the three-dot menu, diagnostics, and engine start/stop state.

#### `UT99RuntimeBridge`

C/Objective-C++ boundary between the host and the patched engine. Responsibilities:

- configure paths and environment;
- load the signed engine image;
- locate and invoke the entry point;
- bridge input;
- expose engine status and log streams;
- handle controlled shutdown/restart;
- prevent multiple engine instances;
- interpose only explicitly audited functions.

#### `UT99MachOPatcher`

Host-side deterministic tool. Inputs pristine v469e artifacts and emits generated iOS artifacts plus a JSON audit report. It may use Apple tools, LIEF, ChOma, or a small in-repo parser, subject to license review.

#### `UT99PlatformShims`

Narrow iOS libraries for symbols that the official binary imports but iOS does not provide with compatible behavior. No generic AppKit clone. Each implemented symbol requires:

- source import symbol;
- observed call site or stack;
- iOS behavior;
- test;
- documentation entry.

Likely categories include display timing, desktop event/window glue, executable-path queries, filesystem paths, process termination, and optional desktop dialogs.

#### `UT99DataKit`

Shared Swift/C++ data validation and import library. Used by both the macOS preparation tool and iOS app.

#### `UT99TouchUI`

EctoPad-derived custom touch interface and layout editor. Emits a canonical action state independent of engine implementation.

#### `UT99InputBridge`

Normalizes EctoPad-derived touch, `GCController`, keyboard, mouse, and optional gyro into engine key/axis events.

#### `UT99Diagnostics`

Collects host logs, engine logs, binary audit fingerprints, device details, renderer, content manifest, FPS, memory, thermal state, and crash markers. Exports a redacted ZIP through Files/share sheet.

### 8.2 High-level runtime flow

```text
UIApplication / UT99HostViewController
        ├── Game-data importer and validator
        ├── EctoPad-derived touch overlay
        ├── Three-dot menu and diagnostics
        └── UT99RuntimeBridge
                 ├── patched v469e engine image
                 ├── signed native package images
                 ├── SDL2 iOS implementation
                 ├── Metal/FruCoRe path
                 ├── iOS audio dependencies
                 └── narrow platform shims
                            ↓
                    Application Support/UT99
                    ├── GameData
                    ├── SystemData
                    ├── Config
                    ├── Cache
                    └── Logs
```

### 8.3 Threading constraints

- UIKit and touch UI remain on the main thread.
- SDL iOS lifecycle expectations must be honored.
- Do not assume the desktop `main()` can run arbitrarily on a background thread.
- The first hosted prototype must explicitly document whether the engine loop owns the main thread, is ticked by the host, or runs on a dedicated thread.
- Cross-thread input uses a lock-free snapshot or small synchronized queue; no UIKit objects cross into the engine thread.
- The menu must release all held touch/button states before intercepting input.

---

## 9. Repository structure

The agent should converge on the following structure, adapting only when the existing repository has a stronger convention:

```text
/
├── README.md
├── Makefile
├── Brewfile
├── Package.swift                     # if Swift packages are used
├── UT99Apple.xcodeproj or project.yml
├── docs/
│   ├── UT99_Apple_PRD.md
│   ├── UT99_Agent_Goal_Loop.md
│   ├── STATUS.md
│   ├── ARCHITECTURE.md
│   ├── BINARY_AUDIT.md
│   ├── DEPENDENCIES.md
│   ├── DATA_COMPATIBILITY.md
│   ├── NETWORK_COMPATIBILITY.md
│   ├── TEST_MATRIX.md
│   ├── DECISIONS.md
│   ├── KNOWN_ISSUES.md
│   ├── DISTRIBUTION_AND_LEGAL.md
│   ├── STOP_REPORT.md                 # created only if a hard stop occurs
│   └── evidence/
│       ├── index.md
│       ├── macos-baseline/
│       ├── ios-shell/
│       ├── engine-startup/
│       ├── first-frame/
│       ├── gameplay/
│       └── multiplayer/
├── ref/
│   ├── ectopad/                       # pristine active touch reference
│   ├── OldUnreal/                     # read-only research/reference checkouts
│   └── BinaryRehosting/               # LiveContainer/maciOS research, if used
├── Sources/
│   ├── UT99Host/
│   ├── UT99RuntimeBridge/
│   ├── UT99PlatformShims/
│   ├── UT99DataKit/
│   ├── UT99TouchUI/
│   ├── UT99InputBridge/
│   └── UT99Diagnostics/
├── tools/
│   ├── bootstrap_dependencies.sh
│   ├── prepare_macos_baseline.sh
│   ├── prepare_ut99_data.py
│   ├── inspect_macho.sh
│   ├── patch_469e.py
│   ├── verify_generated_binary.py
│   ├── sign_and_package.sh
│   └── ensure_single_runtime.sh
├── Tests/
│   ├── Unit/
│   ├── Patcher/
│   ├── Importer/
│   ├── Input/
│   └── Integration/
├── third_party/
│   ├── README.md
│   ├── deps.lock.json
│   └── licenses/
├── .cache/                             # ignored
├── build/                              # ignored
└── local/                              # ignored; user binaries/data only
```

The agent must never modify the supplied `ref/` repository in place. It may copy reusable code into the product only after recording source, commit, and license.

---

## 10. Dependency and prerequisite policy

### 10.1 Downloads the agent is allowed to perform

The agent may install or download build prerequisites required to complete the project, including:

- Homebrew packages;
- CMake and Ninja;
- Python/uv and pinned Python packages;
- XcodeGen or equivalent project generation tools;
- Apple command-line binary inspection tools;
- LIEF, ChOma, or another host-side Mach-O tooling library;
- SDL2 source and iOS framework build inputs;
- OpenAL Soft and audited audio dependencies;
- libxmp, mpg123, libsndfile, libiconv, or replacements if the binary requires them;
- ZIPFoundation or another audited ZIP implementation;
- fishhook or a similarly narrow symbol-interposition library;
- official OldUnreal v469e release artifacts;
- sanctioned Unreal Tournament GOTY installation media for local development; and
- public reference repositories.

### 10.2 Dependency rules

- Pin every source dependency to a tag or commit in `third_party/deps.lock.json`.
- Record URL, commit/tag, SHA-256 where applicable, license, purpose, and whether it ships in the app.
- Build third-party native libraries from source for the correct iOS device target whenever practical.
- Never rely on an opaque random prebuilt dylib when source is available.
- Store downloads under ignored `.cache/` or `local/` paths.
- Do not commit Epic game assets, official OldUnreal executables, Steam files, DMGs, ISOs, or generated patched binaries.
- Do not automate acceptance of a new license without recording it.
- Detect Xcode absence or an unaccepted Xcode license and report the exact prerequisite; do not attempt unsafe workarounds.

### 10.3 Expected runtime dependency investigation

The binary audit must determine the exact versions and import surface. Expected candidates include:

- SDL2 in the shipped v469e app;
- OpenAL Soft / ALAudio;
- libxmp;
- mpg123;
- libsndfile;
- libiconv;
- optional/proprietary FMOD components; and
- Fruit Company Renderer native package(s).

Do not assume all bundled macOS libraries are needed. Disable or remove optional audio/render drivers and choose the smallest viable stack. Prefer ALAudio/OpenAL over a proprietary FMOD requirement. If FMOD is a mandatory unresolved import, first determine whether the official iOS FMOD library can legally and technically satisfy it; otherwise treat it as a stop-risk and document it.

---

## 11. macOS reference implementation requirements

The macOS phase is not an invitation to rewrite a solved desktop port. Its purpose is to establish a reproducible oracle and obtain pristine inputs.

### 11.1 Baseline setup

The agent must:

1. Download the official v469e macOS release from OldUnreal’s GitHub release.
2. Record the download URL, release tag, SHA-256, code-signing identity, bundle version, and architectures.
3. Preserve the pristine DMG and app in ignored local storage.
4. Import valid GOTY game data from an available source.
5. Configure the Metal renderer.
6. Launch the game on Apple Silicon without Rosetta.
7. Record the engine log and screenshots.
8. Verify the server browser or direct online connection.

### 11.2 Accepted macOS data sources

The macOS preparation tool should accept any source that contains compatible content packages, including:

- a Steam GOTY installation owned by the user;
- a GOG installation or extracted installer;
- an existing Windows/Linux/macOS UT99 installation;
- the OldUnreal-sanctioned GOTY disc image workflow; or
- a canonical data pack previously produced by this project.

The tool must validate content packages rather than requiring the entire distributions to be byte-for-byte identical.

### 11.3 macOS baseline acceptance tests

At minimum:

- App launches natively on Apple Silicon.
- Intro/menu renders through FruCoRe Metal.
- Music and sound effects play.
- Keyboard/mouse works.
- A supported physical controller works or is mapped.
- `DM-Deck16][` starts with multiple bots.
- A complete bot match can be played without a crash.
- `CTF-Face` loads.
- Server browser populates or direct-address connection succeeds.
- Logs and configuration paths are known.
- The exact native packages loaded during each scenario are recorded.

### 11.4 Baseline artifacts

Create:

- `docs/evidence/macos-baseline/environment.json`
- `docs/evidence/macos-baseline/binary-hashes.json`
- `docs/evidence/macos-baseline/loaded-images.txt`
- `docs/evidence/macos-baseline/UnrealTournament.log`
- screenshots of menu, Deck16, FruCoRe settings, and server browser;
- `docs/evidence/macos-baseline/RESULT.md`

---

## 12. Game-data preparation and import

### 12.1 Canonical data model

The iOS app must not attempt to use the original desktop `System` folder wholesale. Separate:

1. **Generated engine/system payload** — extracted from the official v469e patch during the local build and bundled or installed according to signing constraints.
2. **User game data** — original content packages imported at runtime.
3. **Writable configuration and cache** — generated on-device.

Recommended sandbox structure:

```text
Application Support/UT99/
├── GameData/
│   ├── Maps/
│   ├── Music/
│   ├── Sounds/
│   ├── Textures/
│   └── Packages/               # permitted .u/.int content from bonus packs
├── SystemData/                 # non-executable v469 system content, if needed
├── Config/
├── Cache/
├── Downloads/
├── Logs/
└── Manifests/
```

### 12.2 Canonical exporter

Provide a macOS CLI:

```bash
./tools/prepare_ut99_data.py \
  --source "/path/to/Unreal Tournament" \
  --output "build/UT99Data"
```

It must:

- discover nested UT roots;
- detect source type when possible;
- validate required folders and known packages;
- copy only required content;
- preserve case correctly;
- avoid overwriting modern patch-provided font textures;
- remove or flag incompatible `LadderFonts.utx` and `UWindowFonts.utx` as required by OldUnreal’s macOS instructions;
- copy required bonus-pack `.u` and `.int` files as data, not native desktop binaries;
- decompress `.uz` maps using the official macOS UCC tool when available;
- generate `manifest.json` with SHA-256, size, package type, and source;
- optionally emit `UT99Data.zip` for iCloud Drive/AirDrop import; and
- never include desktop executables, DLLs, or the original engine configuration by default.

### 12.3 iOS import UX

First launch presents:

- **Import UT99 Folder**
- **Import UT99Data ZIP**
- **Learn Where to Get the Files**
- **Open Diagnostics**

The importer must:

- use a system document/folder picker;
- copy selected content into the app container, not depend indefinitely on a security-scoped external URL;
- validate before replacing a working installation;
- import transactionally into a staging directory;
- show progress and current file;
- support cancellation;
- preserve the previous good data set until commit;
- provide exact missing/incompatible package errors;
- offer an exportable validation report; and
- start the engine only after a valid manifest exists.

### 12.4 Steam compatibility requirement

The project must specifically test at least one Steam-origin GOTY installation or canonical pack made from it. It does not need to prove that every byte in Steam equals the GOTY ISO. It must prove that the content packages required by the v469e engine are accepted and behave correctly. Record differences in `docs/DATA_COMPATIBILITY.md`.

### 12.5 Authorized first-run download

OldUnreal currently publishes full-game installers that download the original UT99 GOTY disc image and apply the latest patch. The candidate now implements **Get Game Data** beside **Import Files** using the same pinned source contract; enabling that path in a publicly distributed binary still requires OldUnreal/Epic permission and Apple-channel clearance.

Before downloading, the app must show source, approximate size, terms/provenance, storage destination, and an explicit consent action. The candidate does this, fetches only from the pinned OldUnreal installer mirrors/Archive fallback, verifies exact size and digest, extracts only required data packages, rejects executable/native code, reuses the transactional importer, and removes temporary source media after completion or cancellation. A website may explain and deep-link into this flow, but must not silently install data or imply that permission to download equals permission for this project to mirror or rebundle it.

Public implementation remains gated on written permission and the selected Apple distribution channel. See `docs/DISTRIBUTION_AND_ONBOARDING.md`.

---

## 13. Binary audit and go/no-go gate

### 13.1 Required audit commands

The agent must build a repeatable audit around tools such as:

```bash
file <binary>
lipo -archs <binary>
lipo -thin arm64 <binary> -output <arm64-copy>
vtool -show-build <binary>
otool -hv <binary>
otool -l <binary>
otool -L <binary>
nm -m -u <binary>
nm -gU <binary>
dyld_info -imports <binary>
dyld_info -exports <binary>
codesign -dvvv --entitlements :- <binary>
strings -a <binary>
```

Use `jtool2`, `llvm-objdump --macho`, LIEF, or ChOma where they provide better structured output.

Audit every executable image that stock gameplay loads, not just the main application.

### 13.2 Machine-readable audit output

`build/audit/469e-audit.json` must include:

- SHA-256 and size;
- Mach-O file type;
- architecture;
- platform/minimum OS/SDK load commands;
- entry point and page-zero layout;
- all dylib/framework imports;
- rpaths;
- exported and undefined symbols;
- Objective-C classes/selectors if present;
- code-signing properties;
- encrypted/not-encrypted state;
- writable/executable segment characteristics;
- dynamically loaded native package names inferred from config, strings, and runtime traces; and
- a classification for every dependency.

### 13.3 Dependency classification

Each dependency is categorized as:

- **Available on iOS with compatible API**
- **Rebuildable third-party library**
- **Replaceable optional driver**
- **Narrow shim required**
- **Bundle-and-patch native package**
- **Unknown—experiment required**
- **Fatal/unbounded blocker**

### 13.4 Promotion gate G1

Proceed beyond the audit only if all of the following are true:

- a native ARM64 slice exists;
- the binary is not encrypted or otherwise inaccessible;
- the entry point can be identified;
- no x86-only stock native package is required for the selected gameplay path;
- macOS-only dependencies appear concentrated enough to patch or shim; and
- a no-JIT, build-time-signing approach remains plausible.

If G1 fails, create `docs/STOP_REPORT.md` and stop.

---

## 14. iOS host shell

### 14.1 Host shell requirements

Before loading UT, create a native app that demonstrates:

- landscape iPhone and iPad layouts;
- a Metal-backed game surface;
- safe-area-aware EctoPad-derived overlay placeholder;
- right-side three-dot button and menu;
- file importer;
- unified logging;
- physical controller discovery;
- keyboard/mouse discovery on iPad;
- app suspend/resume callbacks;
- a diagnostics screen;
- one active runtime instance; and
- build/install on a physical device.

### 14.2 Host states

Use an explicit state machine:

```text
NeedsData
ValidatingData
Ready
StartingEngine
Running
PausedBySystem
StoppingEngine
Crashed
SafeMode
UnsupportedBuild
```

Never launch a second engine instance because the user taps twice. Transitions and errors must be logged.

### 14.3 Promotion gate G2

- Host builds for iOS device and iPadOS device.
- Host launches on physical iPad.
- Metal surface presents.
- EctoPad-derived overlay and menu remain responsive.
- Importer can copy and validate a test fixture.
- Logs export correctly.

---

## 15. Mach-O transformation and engine startup

### 15.1 Patcher requirements

The patcher must operate only on copies and be deterministic. Depending on the chosen experiment, it may need to:

- thin the universal app to ARM64;
- change `LC_BUILD_VERSION` platform from macOS to iOS;
- adjust minimum OS/SDK metadata;
- convert `MH_EXECUTE` to `MH_DYLIB` for hosted mode;
- reduce or relocate `__PAGEZERO` for dlopen-compatible loading;
- preserve or expose the LC_MAIN entry point through a trampoline;
- rewrite `LC_LOAD_DYLIB` and `LC_RPATH` values;
- replace macOS framework imports with host shim framework paths;
- inject a signed runtime-bridge dependency if required;
- remove unsupported load commands only when understood;
- preserve relocations/chained fixups correctly;
- verify all load commands after modification;
- sign nested frameworks/dylibs before signing the app; and
- emit a patch manifest describing every byte-level transformation.

Do not patch executable pages at runtime on-device.

### 15.2 macOS hosted harness

Before iOS, isolate executable-to-dylib transformation from platform differences:

1. Convert a copy of the macOS ARM64 executable into a hostable macOS dylib.
2. Load it from a minimal macOS harness.
3. Invoke the recovered entry point.
4. Capture startup output.

A successful harness materially de-risks the entry-point and file-type conversion.

### 15.3 iOS startup sequence

The first iOS attempts should reduce optional systems:

1. Start with no game data and prove entry-point logging.
2. Set controlled environment and sandbox paths.
3. Disable sound if a supported command-line/config path exists.
4. Avoid network and native mods.
5. Initialize Core/Engine.
6. Load the Entry/intro package.
7. Initialize SDL/iOS and Metal.
8. Present the first frame.

Verify command-line switches against the actual engine before depending on them; likely candidates include `-log`, `-nosound`, explicit ini paths, and direct map URLs.

### 15.4 Promotion gate G3 — engine code executes

All of the following are required:

- patched code is embedded and signed during the Xcode build;
- no JIT entitlement or external JIT enabler is required;
- the process reaches the original UT entry/startup code on a physical device;
- a distinctive engine log line proves it is not a host stub;
- no unsigned code is loaded; and
- the app can return to a diagnosable host state after failure.

If only a JIT-dependent generic loader works, document it as research evidence but do not promote the product architecture.

---

## 16. Platform compatibility layer

### 16.1 Rule: implement the smallest surface possible

The agent must not write a general AppKit compatibility framework. For each unresolved import:

1. locate the import and call sites;
2. reproduce the call in the macOS baseline;
3. determine whether it is required for stock gameplay;
4. disable the optional feature where possible;
5. otherwise implement the narrow equivalent; and
6. add a focused test.

### 16.2 Expected areas

#### Application and windowing

Prefer replacing the macOS SDL2 dylib with an ABI-compatible iOS SDL2 build. Let the native host own `UIApplication`. Determine whether the engine calls SDL’s public API only or directly relies on `SDL_main`/desktop-specific startup behavior.

#### Display timing

If the engine or renderer directly uses `CVDisplayLink`, bridge timing to `CADisplayLink` or an iOS-compatible display callback. Do not run two independent frame clocks.

#### Filesystem

Map desktop assumptions to sandbox roots. Candidate hooks include:

- executable path;
- current working directory;
- home directory;
- preferences/config root;
- temp directory;
- case sensitivity normalization;
- atomic rename; and
- file enumeration.

#### Process control

Intercept engine `exit`/fatal handling so a controlled engine termination can produce a host crash screen and exportable logs where possible.

#### Dialogs and clipboard

Replace desktop message boxes with logged errors and host UI. Clipboard is optional initially.

#### Native package loading

All required native packages must be known at build time, embedded in the app, platform-patched or rebuilt, and signed. Arbitrary native mods loaded from imported data are unsupported.

### 16.3 Promotion gate G4 — engine initialization

- Engine identifies version 469e or the selected exact reference build.
- Engine resolves Core/Engine/native stock packages.
- It reads config from the iOS sandbox.
- It locates valid user game data.
- It reaches renderer initialization or a documented next blocker.

---

## 17. Metal renderer

### 17.1 Preferred renderer path

Use the v469e Fruit Company Renderer. Ordered options:

1. Rehost the official ARM64 FruCoRe native package if it is a separate signed image.
2. Compile the public Fruit Company Renderer source for iOS against compatible 469 headers/symbol stubs, if technically possible.
3. Patch only the small platform-specific parts of FruCoRe.

Do not start a new UE1 renderer before these paths fail and the owner approves a scope change.

### 17.2 Known adaptation areas

- SDL2 versus current SDL3 source API.
- iOS `CAMetalLayer` ownership.
- iOS Metal GPU-family/feature-set checks rather than macOS-only feature-set constants.
- drawable size and Retina scale.
- safe-area-independent render surface size.
- pixel formats and 10-bit framebuffer fallback.
- MSAA support.
- drawable acquisition when backgrounded or obscured.
- frame pacing and ProMotion.
- screenshots written to sandbox.

### 17.3 First-frame test

First target the intro/Entry view. Then load:

- `DM-Deck16][`
- `CTF-Face`
- one map with water/fog/detail textures
- one map with real-time textures

### 17.4 Promotion gate G5 — playable rendered map

- Original menu or direct map is visible.
- `DM-Deck16][` renders correctly enough to navigate.
- No severe corruption in BSP, meshes, lightmaps, UI tiles, or weapon view.
- Frame timing is measured.
- Screenshot evidence and Metal validation output are stored.

---

## 18. Audio

### 18.1 Required behavior

- weapon and pickup effects;
- announcer and voices;
- tracker/module music;
- independent music/effects volume;
- Bluetooth and speaker route changes;
- interruption handling for calls/Siri/audio sessions;
- suspend/resume without a dead audio device; and
- no desktop audio device polling loops that drain battery.

### 18.2 Strategy

Prefer OldUnreal’s ALAudio path with an iOS-compatible OpenAL Soft build. Rebuild required codec libraries for iOS. Disable Cluster/FMOD if optional. Configure `AVAudioSession` in the host and allow the engine audio backend to use the active device.

### 18.3 Promotion gate G6

- sound effects and music both play in Deck16;
- background/foreground restores audio;
- route change does not crash;
- volume controls work; and
- no mandatory unresolved proprietary audio dependency remains.

---

## 19. Input and EctoPad touch UI

### 19.1 EctoPad reference requirement

At the beginning of UI work, the agent must inspect `ref/ectopad` and the pristine EctoPad source implementation. It must document:

- project/target names;
- touch-control components;
- input abstraction;
- three-dot menu implementation;
- typography, materials, iconography, spacing, and animation tokens;
- control layout persistence;
- controller auto-detection behavior;
- diagnostics/log UI; and
- README structure.

Capture reference screenshots and an interaction map under `docs/evidence/reference-ectopad/`. Do not modify the reference repository. EctoPad is the acceptance baseline for placement, hierarchy, icon-first faces, fixed-stick feedback, translucency, spacing, and two-thumb behavior on both iPhone and iPad. GoldenPad remains historical context only.

### 19.2 Canonical action model

All sources emit the same actions:

```text
MoveForward / MoveBackward
StrafeLeft / StrafeRight
LookYaw / LookPitch
PrimaryFire
AlternateFire
Jump
Crouch
Walk
NextWeapon
PreviousWeapon
ActivateItem / Use
ShowScores
OpenGameMenu
OpenHostMenu
ConsoleOrChat
```

The engine adapter maps them to verified UT input names/axes.

### 19.3 Default touch layout

- Left EctoPad-style fixed stick: movement and strafe.
- Right yellow EctoPad-style fixed stick: yaw/pitch with acceleration and sensitivity controls.
- Primary fire: dominant green A-archetype target reachable while aiming.
- Alternate fire: red B-archetype target adjacent to primary fire.
- Jump and crouch: light X/Y-archetype targets in the right-thumb cluster.
- Scores/use/previous weapon/next weapon: compact D-pad up/down/left/right semantics.
- Original Unreal menu: separate START-pill archetype.
- Three-dot host menu: fixed on the right edge, safe-area aware, always reachable.
- Pause/game menu: separate from host menu.

The layout must not require more than two simultaneous thumbs for ordinary combat. EctoPad's game-specific labels and bindings are not copied: its A/B/X/Y/D-pad/START control archetypes are adapted to UT99's verified action model.

### 19.4 Touch configuration

- drag and resize controls;
- change opacity;
- change button size;
- sensitivity and acceleration;
- invert Y;
- dead zones;
- left-handed preset;
- hide individual controls;
- reset to default;
- save named profiles;
- safe-area visualization;
- live test mode; and
- optional gyro aiming.

### 19.5 Physical controller

Use Apple Game Controller APIs or SDL controller events, with one canonical mapping layer. Support Xbox, DualSense/DualShock, and MFi extended profiles. Respect system remapping. Optionally hide touch controls when a physical controller is active.

### 19.6 Keyboard and mouse

On iPad:

- WASD movement;
- mouse look;
- primary/alternate mouse buttons;
- pointer capture during play;
- release pointer when host/game menu opens;
- editable bindings; and
- no stuck keys after app backgrounding.

### 19.7 Promotion gate G7

- Complete a bot match with touch only.
- Complete a bot match with a physical controller.
- Navigate original menus with touch and controller.
- No stuck actions after opening/closing the three-dot menu.
- Touch layout persists across restarts.

---

## 20. Three-dot host menu

### 20.1 Placement and behavior

- Fixed on the right edge in landscape.
- EctoPad visual language.
- Above the game surface and touch controls.
- Single tap opens; tapping outside or Resume closes.
- Opening immediately releases all gameplay touch states.
- Remains available when the engine reports a recoverable error.

### 20.2 Required sections

#### Resume
Return to game.

#### Controls
Controller mapping, touch sensitivity, invert axis, gyro, keyboard/mouse, auto-hide touch controls.

#### Touch Layout
Enter EctoPad-derived layout editor, presets, reset, export/import profile.

#### Graphics
Resolution scale, frame cap, ProMotion option, MSAA, texture/detail toggles exposed safely by FruCoRe, FPS counter.

#### Audio
Music, effects, announcer/voice, output status, restart audio.

#### Multiplayer
Player name, connection status, direct connect, local-network permission state, server-browser repair/status where available.

#### Game Data
Installed manifest, source type, package count, verify, repair/reimport, export manifest, storage used.

#### Diagnostics
- host version and Git commit;
- engine build/version/hash;
- renderer and Metal device;
- SDL/audio versions;
- current FPS/memory/thermal state;
- network path;
- last 200 log lines;
- export full diagnostic ZIP;
- copy build information;
- reset configuration;
- restart engine;
- safe mode.

#### About
Credits, licenses, Epic/OldUnreal disclaimer, source repository, required-data statement.

---

## 21. Networking and online compatibility

### 21.1 Core requirement

Online interoperability is part of Definition of Done. The client must use the selected v469e engine/network implementation rather than a new approximate protocol.

### 21.2 Required scenarios

- community master-server query;
- in-game server browser;
- direct IP/hostname connect;
- DNS resolution;
- UDP gameplay traffic over Wi-Fi;
- gameplay over cellular where the server/path permits;
- LAN direct connect after local-network permission;
- server downloads/data redirects where compatible;
- chat, scoreboard, movement, firing, damage, death, respawn, and match transitions;
- disconnect/reconnect after network path change; and
- graceful behavior when backgrounding disconnects the session.

### 21.3 iOS integration

- Include a clear `NSLocalNetworkUsageDescription` for LAN/direct local play.
- Observe path changes using Network framework only for host UX; do not replace the UT protocol unless required.
- Do not block cellular by default, but clearly expose constrained/expensive path state.
- Avoid Bonjour declarations unless actual Bonjour discovery is added.

### 21.4 Compatibility testing

Use existing unmodified public or project-controlled v469 servers. Because of the one-runtime constraint, do not run a local client and local server concurrently unless the owner explicitly permits that narrow test. Record:

- server address;
- server version;
- client-reported version;
- packages downloaded;
- ping and packet-loss observations;
- full session log;
- screenshot/video; and
- whether anti-cheat rejects the client.

### 21.5 Promotion gate G8

- Server browser or master query works.
- Direct connect works.
- The iOS client joins an unmodified v469-compatible server.
- Other players observe movement and combat correctly.
- The iOS player completes a match or meaningful multiplayer session.

If stock gameplay works but unmodified-server interoperability cannot be achieved, the project is not release-complete.

---

## 22. App lifecycle, stability, and performance

### 22.1 Lifecycle

- Pause or safely quiesce when inactive.
- Release drawable access while backgrounded.
- Resume without duplicated engine threads or controllers.
- Treat background network disconnect as expected.
- Persist configuration before suspension.
- Handle memory warnings.
- Recover from audio interruptions.
- Prevent screen sleep during active play, restore default afterward.

### 22.2 Stability requirements

- No second engine instance.
- No stale controller state.
- No corrupted ini after forced termination.
- Transactional data imports.
- Crash marker and next-launch recovery prompt.
- Safe mode can reset host config and launch engine with conservative settings.

### 22.3 Performance instrumentation

Measure per device/map:

- average and low-percentile FPS;
- frame time;
- CPU usage;
- resident memory;
- thermal state;
- battery impact where practical;
- input latency observations;
- drawable resolution; and
- network ping.

Do not claim 120 FPS until measured and stable.

### 22.4 Promotion gate G9

- 30-minute offline soak across stock maps without crash.
- Multiple suspend/resume cycles.
- Audio route change.
- Controller disconnect/reconnect.
- Data verification during a separate session.
- No severe thermal throttling on target iPad.

---

## 23. Logging and diagnostics

### 23.1 Unified logging

Capture:

- host `os_log` entries;
- stdout/stderr from the engine where possible;
- UT log file;
- runtime bridge events;
- patcher manifest;
- dependency versions;
- input-device changes;
- lifecycle transitions;
- renderer initialization and errors;
- network state changes; and
- crash marker/last state.

### 23.2 Log redaction

Before export, redact or warn about:

- local file paths containing user names;
- server passwords;
- tokens or signing information;
- personal IPs where appropriate; and
- Apple developer identifiers if not needed.

### 23.3 Evidence rules

Every major gate gets a dated evidence folder with:

- `RESULT.md`;
- command transcript;
- environment JSON;
- logs;
- screenshots; and
- relevant binary hashes.

---

## 24. Functional requirements

### Engine and rendering

- **FR-001:** The product shall execute original v469e ARM64 engine code on a physical iOS/iPadOS device.
- **FR-002:** The preferred final build shall not require JIT.
- **FR-003:** The product shall render through Metal using FruCoRe or a directly derived iOS build/rehost.
- **FR-004:** The product shall load stock GOTY maps and packages.
- **FR-005:** The product shall play bot matches with original AI/game rules.
- **FR-006:** The product shall preserve original menu/ladders where compatible.

### Data

- **FR-010:** The app shall import a folder or ZIP through the system picker.
- **FR-011:** The app shall validate content before committing an import.
- **FR-012:** The app shall support a canonical pack produced from Steam-origin content.
- **FR-013:** The app shall not require original desktop executables at runtime.
- **FR-014:** The app shall expose verify, repair/reimport, and manifest export.
- **FR-015:** When an authorized source is approved, the app shall offer consent-based game-data acquisition with pinned integrity verification and no executable-code import.

### Input/UI

- **FR-020:** The app shall ship an EctoPad-derived touch layout for iPhone and iPad, measured from the reference rather than approximated.
- **FR-021:** The app shall support a layout editor and persistent profiles.
- **FR-022:** The app shall support physical extended gamepads.
- **FR-023:** The iPad app shall support keyboard and mouse.
- **FR-024:** The app shall expose a right-side three-dot host menu.
- **FR-025:** Opening a host menu shall release gameplay input states.

### Audio

- **FR-030:** The app shall play UT effects, voices, and music.
- **FR-031:** The app shall recover from audio interruptions and route changes.

### Networking

- **FR-040:** The client shall query or otherwise use the v469 community server ecosystem.
- **FR-041:** The client shall join an unmodified compatible server.
- **FR-042:** Direct connect shall work.
- **FR-043:** Core multiplayer replication shall remain correct through a match.
- **FR-044:** Online play shall be a launch-critical capability, with current community master-server defaults and tested-server compatibility documented.

### Diagnostics

- **FR-050:** The app shall expose engine/host versions and hashes.
- **FR-051:** The app shall export a diagnostic bundle.
- **FR-052:** The app shall offer safe mode and configuration reset.

---

## 25. Non-functional requirements

- **NFR-001 Reproducibility:** Bootstrap and build inputs are pinned and documented.
- **NFR-002 Provenance:** No proprietary binary or game data is committed.
- **NFR-003 Performance:** Stable 60 FPS is the initial target on supported hardware.
- **NFR-004 Latency:** Touch/controller latency must be suitable for UT combat.
- **NFR-005 Reliability:** Imports and config writes are transactional.
- **NFR-006 Resource discipline:** The agent uses only one simulator and one game/client executable at a time.
- **NFR-007 Maintainability:** Platform shims are narrowly scoped and tested.
- **NFR-008 Transparency:** Unsupported native mods and distribution limitations are plainly documented.
- **NFR-009 Accessibility:** Controls can be resized/repositioned; text respects reasonable scaling where host UI permits.
- **NFR-010 Security:** No executable code is downloaded and run after installation in the preferred final design.

---

## 26. Build and developer commands

The repository should expose stable commands, regardless of internal implementation:

```bash
make doctor                 # inspect Xcode, signing, tools, disk and ref inputs
make bootstrap              # install/pin permitted dependencies
make mac-baseline           # prepare and verify official v469e macOS reference
make data-pack SOURCE=...   # create canonical UT99Data pack
make audit-469e             # generate Mach-O/dependency audit
make mac-hosted-harness     # test executable-to-dylib conversion on macOS
make ios-shell              # build UI shell for one selected target
make ios-device             # build/sign/install physical-device build
make test                   # unit and non-device integration tests
make verify-device          # run current device gate and collect evidence
make diagnostics            # collect project/build diagnostics
make package-local          # create locally signed IPA; no proprietary upload
make clean-runtime          # stop project processes and simulators
```

`make doctor` must never modify the system. `make bootstrap` may install missing permitted tools after logging what it will do.

---

## 27. Test matrix and Definition of Done

### 27.1 Minimum test devices

- Apple Silicon Mac reference machine.
- One M-series iPad.
- One recent iPhone.
- One physical Xbox/DualSense/MFi controller.
- iPad keyboard/mouse when available.

### 27.2 Required game scenarios

- Startup and intro/menu.
- Practice session on `DM-Deck16][`.
- CTF on `CTF-Face`.
- Weapon cycle and primary/alternate fire.
- Bots, pickups, lifts/movers, water, damage, death, respawn.
- Music transition.
- Host menu open/close.
- Controller connect/disconnect.
- Background/foreground.
- Online server join and match.

### 27.3 Definition of Done

The project is complete only when:

1. The official macOS baseline is reproducible and documented.
2. A clean checkout can obtain permitted prerequisites and generate the iOS engine artifact from pinned official inputs.
3. The app installs on a physical iPad and iPhone.
4. A user can import a supported GOTY data pack without Xcode intervention after app installation.
5. The original menu and a complete bot match work.
6. FruCoRe/Metal renders correctly enough for normal play.
7. Sound and music work.
8. EctoPad-derived touch controls provide a genuinely playable experience on iPhone and iPad.
9. Physical controller works.
10. iPad keyboard/mouse works or any hardware limitation is explicitly documented and accepted.
11. The three-dot menu includes controls, data, diagnostics, logs, and recovery.
12. The client joins an unmodified v469-compatible server and completes a meaningful multiplayer session.
13. The preferred build does not require JIT.
14. No prohibited game data or binaries are committed.
15. All third-party licenses and provenance are documented.
16. `docs/` reflects the final implementation rather than the original plan.
17. README is current, screenshot-backed, and at least as useful as EctoPad’s reference README.
18. No extra simulator or stale game instance remains running after tests.
19. Public release copy may advertise online play only after physical server-browser play and another-player/observer validation pass.
20. Any prebuilt distribution and first-run game-data download have documented owner permission and an Apple-supported delivery channel.

---

## 28. Hard stop conditions

The agent must stop implementation and create `docs/STOP_REPORT.md` if any of these become true after the prescribed experiments:

1. The official v469e macOS package lacks a usable ARM64 engine/native-package path.
2. The binary cannot be transformed and signed without JIT or runtime executable-page modification.
3. Both direct-executable and hosted-dylib experiments fail before original engine startup for the same fundamental dyld/platform reason.
4. Required AppKit/Carbon/private macOS behavior is pervasive enough that the project becomes a generic macOS compatibility layer.
5. A required stock native package is x86-only and cannot be rebuilt or boundedly rehosted.
6. A mandatory proprietary dependency has no legally usable iOS path and cannot be replaced by an already-supported alternative driver.
7. FruCoRe cannot be rehosted or rebuilt and continuing would require writing a new UE1 renderer.
8. The engine requires arbitrary unsigned native code from user game data.
9. The only viable runtime is an emulator, browser, streamed client, or unfinished reimplementation.
10. The client cannot preserve unmodified-server compatibility without replacing substantial engine/network behavior.

The stop report must identify the last passed gate, exact errors, binaries and hashes, dependency graph, experiments attempted, evidence paths, and the smallest decision needed from the owner. “Could not get it working” is not an acceptable report.

---

## 29. Open questions the implementation must answer

1. Is the ARM64 v469e main executable directly linked to AppKit, or is AppKit present only through SDL/framework dependencies?
2. Is FruCoRe a separate native package in the shipped app, and is it ARM64/universal?
3. Which native packages are loaded for stock Deck16 gameplay, audio, and networking?
4. Does the main executable export enough symbols for patched/rebuilt native packages?
5. Can an iOS SDL2 build satisfy the exact public SDL ABI imported by v469e?
6. Does the desktop executable own SDL application startup in a way that conflicts with a UIKit host?
7. Can hosted mode invoke the engine entry point without runtime JIT?
8. Which bundled audio libraries are actually mandatory?
9. Does ALAudio fully remove the FMOD requirement?
10. Which direct filesystem/executable-path assumptions need hooks?
11. Can FruCoRe current source compile against the 469 SDK plus generated symbol stubs, or must its shipped binary be rehosted?
12. Do stock UnrealScript/native package loads satisfy iOS code-signing rules when all native images are embedded and signed?
13. What exact Steam/GOG/ISO package differences affect the importer?
14. Does community master-server traffic require any TLS/HTTP behavior that the iOS process lacks?
15. Which public servers reject the client because of legacy anti-cheat rather than protocol incompatibility?
16. Can the preferred final IPA be distributed as a prebuilt artifact under applicable permissions, or must users locally build it? Current answer: unresolved; Simulator/package success is not distribution permission.
17. May UT99Apple directly acquire the GOTY image/data from OldUnreal's authorized installer endpoints, or must it hand off to the existing installer/manual import flow?
18. Is TestFlight/App Store viable for the transformed engine, or is Apple-approved regional website distribution/local signing required?

Each answer belongs in `docs/DECISIONS.md` or the relevant specialized document with evidence.

---

## 30. README completion requirements

The final README must include:

- project status and honest limitations;
- hero image/video or screenshots from physical hardware;
- platform matrix;
- exactly what “native” means;
- feature list;
- supported data sources;
- user installation/import flow;
- local build instructions;
- controller and touch layout diagrams;
- three-dot menu overview;
- multiplayer status and tested servers;
- architecture summary;
- troubleshooting and log export;
- known issues;
- license/provenance table;
- Epic, OldUnreal, SDL, EctoPad, and contributor credits;
- no-asset/no-affiliation disclaimer; and
- evidence-backed completion status.

Use EctoPad’s README as a quality and structure reference, not as text to copy blindly.

---

## 31. Research sources

The agent should pin or archive the exact versions it uses. Core sources informing this PRD:

1. OldUnreal UT99 patches repository and installation/compatibility notes:  
   https://github.com/OldUnreal/UnrealTournamentPatches
2. OldUnreal v469e release, recommended for online play:  
   https://github.com/OldUnreal/UnrealTournamentPatches/releases/tag/v469e
3. OldUnreal full-game installer information:  
   https://www.oldunreal.com/downloads/unrealtournament/full-game-installers/
4. Fruit Company Renderer source and build constraints:  
   https://github.com/OldUnreal/FruitCompanyRenderer
5. SDL2 iOS integration documentation:  
   https://wiki.libsdl.org/SDL2/README-ios
6. SDL3 iOS integration documentation, useful for current renderer evolution:  
   https://wiki.libsdl.org/SDL3/README-ios
7. Apple Game Controller framework:  
   https://developer.apple.com/documentation/gamecontroller
8. Apple guidance for virtual/custom touch controls:  
   https://developer.apple.com/documentation/gamecontroller/adding-virtual-controls-to-games-that-support-game-controllers-in-ios
9. Apple game-control design guidance:  
   https://developer.apple.com/design/human-interface-guidelines/game-controls
10. Apple App Review Guidelines, especially downloaded/executable code constraints:  
    https://developer.apple.com/app-store/review/guidelines/
11. LiveContainer executable-hosting and Mach-O patching architecture:  
    https://github.com/LiveContainer/LiveContainer
12. maciOS proof-of-concept for macOS ARM64 binary rehosting on iOS:  
    https://github.com/stossy11/maciOS
13. UT99 public-source distribution limitations:  
    https://github.com/FaultyRAM/Ut99PubSrc
14. SurrealEngine and its current compatibility/networking limitations:  
    https://github.com/dpjudas/SurrealEngine
15. UT99 Android mobile precedent and data-import/controller behavior:  
    https://github.com/Andiweli/UT99-Android
16. Apple beta and release distribution:
    https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases
17. Apple website distribution requirements:
    https://developer.apple.com/documentation/appdistribution/distributing-your-app-from-your-website

---

## 32. Final product directive

The agent’s job is not to produce a persuasive prototype video of a shell. Its job is to determine whether the official modern UT99 engine can be made into a real iOS/iPadOS application and, if the feasibility gates pass, finish the product end to end.

The order is mandatory:

```text
Verified macOS v469e baseline
→ complete binary/dependency audit
→ signed physical-device host shell
→ original engine startup
→ engine initialization and data paths
→ FruCoRe Metal first frame
→ original menu and bot match
→ audio
→ EctoPad touch/controller UX
→ lifecycle/stability
→ unmodified online server interoperability
→ packaging, documentation, and README
```

Do not reverse this order. Do not call the project successful before the game itself works.
