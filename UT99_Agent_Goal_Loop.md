# Unreal Tournament 99 for Apple — Autonomous Agent Goal Loop

**Canonical repository location:** `docs/UT99_Agent_Goal_Loop.md`  
**Authoritative requirements:** `docs/UT99_Apple_PRD.md`  
**Project:** Native Unreal Tournament (1999) for iOS and iPadOS  
**Reference UI repository:** the GoldenPad implementation under `ref/`  
**Execution host:** the current Apple Silicon macOS computer

---

## 1. Mission

Build the product specified in `docs/UT99_Apple_PRD.md` from the current repository to a verified end state, or stop at a mandatory feasibility boundary with a complete evidence-backed report.

The target is a native ARM64 iOS/iPadOS Unreal Tournament 99 client based primarily on the official OldUnreal v469e Apple Silicon build. The finished client must import supported user game data, render through Metal, provide a GoldenPad-quality touch interface and three-dot menu, support controllers and iPad keyboard/mouse, play stock bot matches, and join unmodified compatible UT99 servers.

You are authorized to download and install reasonable public prerequisites and reference source code needed to build and test the project. You are not authorized to commit proprietary game data, official OldUnreal binaries, credentials, signing identities, or generated patched engine artifacts.

The PRD is the product contract. This loop is the operating system for executing it.

---

## 2. Read-first contract

At the start of every session:

1. Read `docs/UT99_Apple_PRD.md` completely.
2. Read `docs/STATUS.md`, `docs/DECISIONS.md`, `docs/KNOWN_ISSUES.md`, and the newest evidence result.
3. Inspect `git status`, current branch, recent commits, and active worktree changes.
4. Inspect the repository rather than assuming its layout.
5. Locate the GoldenPad reference under `ref/` and never modify it.
6. Identify the highest-priority unmet PRD promotion gate.
7. Work only on the smallest experiment that can advance or falsify that gate.

If the PRD and current code disagree, record the discrepancy before changing architecture. Never silently rewrite the goal.

---

## 3. Non-negotiable operating rules

### 3.1 One runtime at a time

- Only one iOS Simulator may be booted at any time.
- Only one game/client executable may be running at any time.
- Do not run the macOS reference client and iOS client simultaneously.
- Do not leave stale UT99, host, test-game, or simulator processes running.
- A local dedicated server may not run concurrently with the client under this constraint; use a remote/public test server unless the owner explicitly permits a narrow exception.
- Before switching target, stop the previous runtime and verify it exited.

Implement and use `tools/ensure_single_runtime.sh`. It should:

- list project-related processes;
- stop only project-related stale processes;
- run `xcrun simctl shutdown all` before booting a simulator;
- verify no more than one target runtime remains;
- avoid killing unrelated Xcode or user applications unless necessary and explicitly logged.

### 3.2 No fake completion

Do not mark a gate complete because code compiles. Evidence must match the gate:

- Engine startup requires original engine log output from a physical device.
- First frame requires a physical-device screenshot and renderer log.
- Gameplay requires a recorded playable session.
- Multiplayer requires an actual unmodified server connection.
- Touch completion requires a touch-only bot match.
- Release completion requires a clean-checkout reproduction and current documentation.

### 3.3 No silent foundation pivot

Do not switch the shipping foundation to SurrealEngine, UT99-Android, `ut99dc`, Wine, WebAssembly, streaming, or a generic macOS compatibility environment. These may be inspected as references only. If the official v469e path reaches a hard stop, produce `docs/STOP_REPORT.md` and stop.

### 3.4 No runtime JIT as the preferred final answer

JIT may be used only as a temporary diagnostic to prove that code itself is otherwise viable, and only when clearly labeled. A gate does not pass until the same result is achieved with build-time patching, embedded signing, and no external JIT enabler.

### 3.5 Preserve pristine inputs

- Never patch the only copy of an official binary.
- Keep pristine inputs read-only under ignored local storage.
- Hash every input and output.
- Generate patched artifacts under `build/`.
- Never commit DMGs, ISOs, game data, app bundles, patched Mach-O files, provisioning profiles, or IPA payloads.

### 3.6 Document continuously

Documentation is part of the implementation, not a final cleanup task. After every meaningful experiment, update:

- `docs/STATUS.md`
- the relevant architecture/audit/test document
- `docs/evidence/<gate>/<date-or-build>/RESULT.md`
- `docs/DECISIONS.md` when a decision changes
- `docs/KNOWN_ISSUES.md` when a reproducible defect appears

A later agent must be able to understand the current state without reading terminal scrollback.

---

## 4. Machine and dependency discipline

### 4.1 Doctor before installation

Run or implement:

```bash
make doctor
```

It must report without modifying the system:

- macOS and hardware;
- Xcode version and selected developer directory;
- installed iOS SDKs;
- signing-team availability without exposing secrets;
- available physical devices;
- booted simulators;
- Homebrew and required tools;
- Python/uv;
- free disk space;
- current project processes;
- presence of PRD and GoldenPad reference;
- presence of local v469e/game-data inputs; and
- git cleanliness.

### 4.2 Permitted bootstrap

After the doctor report, `make bootstrap` may install missing public prerequisites. Before each installation:

1. state what is missing and why it is needed;
2. prefer source or official package-manager distribution;
3. pin the version/commit;
4. record license and URL;
5. update `third_party/deps.lock.json`; and
6. store downloads in ignored cache directories.

Do not auto-install Xcode from an unofficial source. Do not expose developer certificates, passwords, API keys, or tokens in logs.

### 4.3 Build resource limits

- Do not run concurrent `xcodebuild` jobs for different destinations.
- Do not run more than one simulator.
- Avoid unbounded parallel compilation; choose a reasonable job count.
- Do not retain huge duplicate build trees unnecessarily.
- Clean only generated artifacts, never user data or pristine references.

---

## 5. Required project state files

Create these immediately if absent:

### `docs/STATUS.md`

Must contain:

- current PRD gate;
- last passing gate;
- current hypothesis;
- current blocker;
- exact next command/experiment;
- active device/destination;
- latest evidence folder;
- current branch/commit;
- whether proprietary local inputs are present; and
- whether the project is GO, INVESTIGATING, BLOCKED, or STOPPED.

### `docs/DECISIONS.md`

Append-only decision records with date, context, options, decision, evidence, and reversal condition.

### `docs/BINARY_AUDIT.md`

Human-readable explanation of the generated audit, dependency classifications, and unresolved imports.

### `docs/TEST_MATRIX.md`

Requirements and latest results by platform, device, input method, map, audio, lifecycle, and networking.

### `docs/evidence/index.md`

Links every gate to its best evidence folder and result.

### `third_party/deps.lock.json`

Machine-readable dependency pins and licenses.

---

## 6. The main goal loop

Repeat this loop until Definition of Done or a PRD hard stop:

### Step 1 — Select the highest-value unmet gate

Use the PRD order. Do not polish later phases while an earlier foundational gate is unproven.

### Step 2 — State one falsifiable hypothesis

Examples:

- “The main v469e ARM64 binary does not directly import AppKit; AppKit is loaded only by SDL2.”
- “Converting the executable to MH_DYLIB and adjusting PAGEZERO is sufficient for a macOS host to call its LC_MAIN entry point.”
- “An iOS SDL2 build exports every SDL symbol the game imports.”
- “FruCoRe can acquire an iOS CAMetalLayer through the replacement SDL implementation.”

Write the hypothesis into `docs/STATUS.md` before experimenting.

### Step 3 — Design the smallest decisive experiment

An experiment must have:

- inputs and hashes;
- exact command;
- expected success signal;
- expected failure signal;
- output/evidence path;
- cleanup action; and
- decision that follows each outcome.

Do not mix three architectural changes into one experiment.

### Step 4 — Enforce runtime limits

Run the single-runtime guard. Shut down extra simulators and stale game processes.

### Step 5 — Execute and capture

Capture stdout/stderr, exit status, tool versions, target UDID where safe, timestamps, and relevant logs. Never rely solely on visual memory.

### Step 6 — Evaluate honestly

Classify the result:

- **PASS:** exact gate condition met.
- **PARTIAL:** new evidence, gate not met.
- **FAIL-RETRYABLE:** hypothesis wrong but another bounded implementation exists.
- **FAIL-FUNDAMENTAL:** PRD stop condition likely reached.

### Step 7 — Update code and documentation

- Add tests for fixed behavior.
- Update the evidence result.
- Update dependency/audit/decision docs.
- Update `docs/STATUS.md` with the next hypothesis.

### Step 8 — Verify repository hygiene

- `git status` understood.
- no game assets or generated binaries staged;
- no secrets;
- no modifications under `ref/`;
- no stale simulator/game process.

### Step 9 — Commit an atomic result

Commit only when the change is coherent. Message examples:

- `docs: record 469e macOS baseline`
- `tools: add deterministic Mach-O audit`
- `runtime: load converted engine in macOS harness`
- `ios: reach original 469e startup logging`
- `render: present FruCoRe first frame on iPad`

### Step 10 — Continue or stop

If a hard-stop condition is met, do not keep grinding. Produce the stop report and end in a clean, documented state.

---

## 7. Phase execution plan

## Phase 0 — Repository and reference inventory

### Goal

Understand existing code and the GoldenPad reference before changing anything.

### Actions

1. Inventory files, Xcode projects, schemes, build scripts, docs, and local ignored inputs.
2. Locate the GoldenPad reference under `ref/`.
3. Run GoldenPad sequentially on one suitable simulator or device if it builds.
4. Capture touch UI and three-dot menu screenshots.
5. Identify reusable components and licenses.
6. Create `docs/REFERENCE_GOLDENPAD.md`.
7. Establish project naming and target conventions based on the existing repo.

### Gate

- PRD and loop are present.
- GoldenPad reference is located and documented.
- Repo has no unexplained preexisting changes.
- Initial `docs/STATUS.md` exists.

If GoldenPad is missing, continue engine feasibility work but record the missing UI reference. Do not invent a final UI and claim it matches GoldenPad.

---

## Phase 1 — macOS v469e golden baseline

### Goal

Create a reproducible, native Apple Silicon, Metal-rendered reference installation.

### Actions

1. Download official v469e macOS DMG.
2. Verify tag, URL, SHA-256, code signature, architectures, and bundle layout.
3. Preserve pristine copy.
4. Locate or prepare supported GOTY game data.
5. Build canonical data pack from the available source, including Steam-origin data when available.
6. Configure FruCoRe Metal.
7. Launch only the macOS game.
8. Capture startup, menu, Deck16, CTF-Face, audio, controller, and networking evidence.
9. Trace loaded images/native packages for each scenario.
10. Document exact paths and configuration.

### Required result

`docs/evidence/macos-baseline/<build>/RESULT.md` with PASS/FAIL and all PRD artifacts.

Do not spend time redesigning the macOS game. Fix only reproducibility/configuration problems needed to establish the oracle.

---

## Phase 2 — deterministic binary audit

### Goal

Answer whether the official ARM64 binary is boundedly rehostable.

### Actions

1. Implement `tools/inspect_macho.sh` and structured parser output.
2. Audit main executable, UCC, FruCoRe, audio drivers, render packages, and every stock native image observed in the baseline.
3. Classify imports.
4. Determine whether AppKit/CoreVideo/macOS frameworks are direct or transitive.
5. Identify LC_MAIN, PAGEZERO, build platform, rpaths, fixups, exports, undefined symbols, and code signatures.
6. Compare ARM64 macOS exports with required native package imports.
7. Produce dependency graph.
8. Update `docs/BINARY_AUDIT.md` and `docs/DEPENDENCIES.md`.

### Gate G1

Use the PRD criteria. If G1 fails, write the stop report.

---

## Phase 3 — iOS host shell and UI infrastructure

### Goal

Build a signed native shell without pretending the engine works.

### Actions

1. Create `UT99Host` iOS/iPadOS target.
2. Add Metal game surface.
3. Add host state machine.
4. Add logging/export.
5. Add importer using fixtures.
6. Add physical controller discovery.
7. Add GoldenPad-derived placeholder overlay and three-dot menu.
8. Add one-runtime guard.
9. Build for one simulator for UI only.
10. Shut down simulator.
11. Build/install on physical iPad.

### Gate G2

Pass PRD G2 and store evidence.

---

## Phase 4 — macOS hosted-engine harness

### Goal

Prove executable-to-dylib/entry-point work before adding iOS framework differences.

### Actions

1. Copy pristine ARM64 binary into `build/generated/macos-hosted/`.
2. Convert file type and PAGEZERO as required.
3. Recover/expose entry point.
4. Load from minimal macOS harness.
5. Invoke once.
6. Capture original UT startup output.
7. Shut down cleanly.
8. Document every binary transformation.

### Decision

- If PASS, reuse the same patch architecture for iOS.
- If the direct executable route is simpler, record the decision and prove it separately.
- If conversion fundamentally fails, test the direct iOS-main-executable route before stopping.

---

## Phase 5 — iOS engine startup

### Goal

Reach original engine startup on a physical device without JIT.

### Actions

1. Build or embed ABI-compatible iOS dependencies.
2. Patch platform/load commands and rpaths.
3. Add only required shims.
4. Sign all nested executable images.
5. Install on physical iPad.
6. Start once.
7. Capture dyld console, crash report, host log, and engine output.
8. Fix one missing symbol/dependency class per iteration.
9. Avoid renderer/audio until core startup is proven.

### Gate G3

The original engine must produce distinctive startup output. A host message saying “engine loaded” is insufficient.

### Stop logic

After both direct and hosted approaches have been tested against a fundamental loader/platform failure, invoke the PRD stop conditions. Do not implement generic AppKit.

---

## Phase 6 — engine initialization, paths, and data

### Goal

Resolve stock packages and reach renderer initialization.

### Actions

1. Map bundle and sandbox paths.
2. Generate iOS-specific ini/user ini from known-good 469e config.
3. Import canonical data pack.
4. Resolve Core/Engine/Render/IpDrv and stock native packages.
5. Remove desktop drivers from selected config.
6. Add path and process shims only as observed.
7. Ensure failed startup returns actionable diagnostics.

### Gate G4

Pass the PRD engine-initialization criteria.

---

## Phase 7 — Metal first frame

### Goal

Present original UT rendering through FruCoRe.

### Actions

1. Determine whether to patch shipped FruCoRe or build current public source against compatible interfaces.
2. Replace SDL Metal surface path with iOS implementation.
3. Correct iOS GPU feature checks and drawable scaling.
4. Present Entry/menu.
5. Load Deck16 directly if menu blocks progress.
6. Use Metal API validation during development.
7. Capture screenshots and GPU logs.

### Gate G5

A playable rendered map on physical iPad.

Do not begin visual redesign before this gate.

---

## Phase 8 — audio

### Goal

Restore effects and music using a legally usable iOS stack.

### Actions

1. Prefer ALAudio/OpenAL Soft.
2. Build required codecs for iOS.
3. Configure `AVAudioSession` in host.
4. Disable FMOD/Cluster unless proven necessary and permitted.
5. Test effects, music, interruption, route change, and resume.

### Gate G6

Pass PRD audio criteria.

---

## Phase 9 — production touch and controller UX

### Goal

Turn working gameplay into a good iPhone/iPad game.

### Actions

1. Extract GoldenPad design tokens/components.
2. Implement canonical input action model.
3. Implement touch layout and edit mode.
4. Map actions to verified UT keys/axes.
5. Implement physical controller mapping.
6. Implement keyboard/mouse on iPad.
7. Implement optional gyro only after base controls work.
8. Ensure three-dot menu releases input.
9. Play complete matches with each input mode.

### Gate G7

Pass touch-only and controller-only match tests.

---

## Phase 10 — three-dot menu and diagnostics

### Goal

Match GoldenPad’s usability and provide complete recovery tools.

### Actions

Implement every PRD menu section. Prioritize:

1. Resume.
2. Controls.
3. Touch layout.
4. Game data verify/reimport.
5. Diagnostics/log export.
6. Graphics/audio.
7. Multiplayer/direct connect.
8. Safe mode/reset/restart.
9. About/licenses.

Test the menu while running, after a recoverable engine error, and on iPhone/iPad safe areas.

---

## Phase 11 — multiplayer

### Goal

Join existing unmodified UT99 servers.

### Actions

1. Verify DNS and UDP socket behavior.
2. Add local-network usage text.
3. Test master-server query.
4. Test direct hostname/IP connection.
5. Use one remote server at a time.
6. Capture version handshake, logs, downloads, and match behavior.
7. Test chat, movement, weapon fire, damage, death, respawn, and map transition.
8. Distinguish protocol failure from legacy anti-cheat rejection.
9. Update `docs/NETWORK_COMPATIBILITY.md`.

### Gate G8

Complete a meaningful multiplayer session with an unmodified compatible server.

---

## Phase 12 — stability and release hardening

### Goal

Make the build repeatable and reliable.

### Actions

1. Run offline soak tests.
2. Run lifecycle cycles.
3. Run controller and audio-route transitions.
4. Test data reimport/rollback.
5. Test crash recovery and safe mode.
6. Measure FPS, memory, and thermal behavior.
7. Validate iPhone layout.
8. Run clean-checkout bootstrap/build.
9. Ensure no JIT dependency.
10. Package local IPA.
11. Verify no proprietary files in git history or release artifacts.

### Gate G9 and Definition of Done

Use the PRD verbatim.

---

## 8. GoldenPad UI implementation loop

For each GoldenPad-derived UI feature:

1. Locate the exact reference component and behavior.
2. Capture screenshot/video of the reference.
3. Record design tokens and interaction contract.
4. Implement the smallest equivalent in `UT99TouchUI` or host menu.
5. Test on one simulator or physical device.
6. Compare side by side sequentially—not with two runtime instances open.
7. Fix safe-area, scaling, opacity, animation, and input conflicts.
8. Store evidence.
9. Update README screenshots only after behavior is stable.

Do not clone GoldenPad’s game-specific labels or bindings blindly. Reuse its quality, patterns, and components while mapping to UT99 actions.

---

## 9. Debugging protocol

When the app crashes or fails to launch:

1. Do not immediately change multiple patches.
2. Preserve the exact generated binary and patch manifest.
3. Capture device console and `.ips` crash report.
4. Symbolicate host code.
5. Identify whether failure is:
   - code signing;
   - wrong Mach-O platform;
   - missing dylib;
   - missing symbol;
   - chained fixup/relocation;
   - Objective-C class/selector;
   - entry-point/lifecycle;
   - filesystem;
   - native package load;
   - renderer;
   - audio; or
   - game data.
6. Reproduce in the smallest harness possible.
7. Add a regression test or audit check.
8. Record the result before the next attempt.

Never treat `EXC_BAD_ACCESS` as permission to randomly stub functions. Determine the caller and expected contract.

---

## 10. Evidence standard

A gate evidence folder should contain:

```text
RESULT.md
commands.txt
environment.json
input-hashes.json
patch-manifest.json          # when relevant
host.log
UnrealTournament.log         # when available
device-console.log
crash.ips                    # when relevant
screenshot.png or video.mov
notes.md
```

`RESULT.md` includes:

- gate;
- build commit;
- device and OS;
- exact input build/hash;
- result classification;
- what was proven;
- what remains unproven;
- next decision; and
- links to files.

---

## 11. Stop-report procedure

When a PRD hard stop is reached:

1. Stop all runtimes and simulators.
2. Preserve the last generated artifacts under ignored local storage.
3. Create `docs/STOP_REPORT.md` containing:
   - executive conclusion;
   - last passing gate;
   - exact failing gate;
   - pristine input hashes;
   - dependency graph;
   - direct-executable experiment;
   - hosted-dylib experiment;
   - logs/crashes;
   - shims attempted;
   - why the blocker is fundamental rather than unfinished work;
   - why continuing would become an engine/reimplementation project;
   - bounded alternatives and their costs in scope, not speculative dates;
   - smallest owner decision needed.
4. Update `docs/STATUS.md` to `STOPPED`.
5. Ensure the branch builds any completed tooling/tests.
6. Commit the documentation and stop.

Do not end with an ambiguous half-working UI branch and no conclusion.

---

## 12. README finalization loop

README work begins only after gameplay, but it is a release gate.

1. Re-read GoldenPad README.
2. Remove stale claims.
3. Use physical-device screenshots.
4. Explain required game data exactly.
5. Explain local build/signing exactly.
6. State whether JIT is required; preferred completion requires “no.”
7. State multiplayer evidence and tested versions.
8. Include control diagrams and three-dot menu.
9. Include architecture and provenance.
10. Include known issues and diagnostics.
11. Run every command in README from a clean checkout.
12. Verify all links.
13. Ensure no instruction tells users to download an unapproved proprietary artifact.

---

## 13. Completion checklist

Before declaring completion, verify every item:

- [ ] `docs/UT99_Apple_PRD.md` is current.
- [ ] macOS v469e baseline passes and uses Metal.
- [ ] official inputs and generated outputs are hashed.
- [ ] binary audit is complete.
- [ ] iOS engine startup is proven on physical hardware.
- [ ] no JIT required by preferred build.
- [ ] original menu works.
- [ ] Deck16 bot match completes.
- [ ] CTF-Face loads.
- [ ] sound and music work.
- [ ] GoldenPad-derived touch controls are playable.
- [ ] physical controller works.
- [ ] iPad keyboard/mouse works or owner accepted documented limitation.
- [ ] three-dot menu includes all PRD sections.
- [ ] data importer accepts canonical ZIP/folder.
- [ ] Steam-origin data compatibility is tested.
- [ ] suspend/resume works.
- [ ] crash recovery and safe mode work.
- [ ] server browser or master query works.
- [ ] direct connect works.
- [ ] unmodified-server multiplayer match is proven.
- [ ] performance and stability evidence exists.
- [ ] clean-checkout build succeeds.
- [ ] local IPA packaging succeeds.
- [ ] repository contains no prohibited binaries/assets/secrets.
- [ ] licenses/provenance are complete.
- [ ] README matches final reality.
- [ ] only one/no simulator remains booted.
- [ ] no project game executable remains running.

Only then set `docs/STATUS.md` to `COMPLETE`.

---

## 14. Immediate first actions

Unless the repository already proves a later gate, begin with:

1. Place this file and the PRD under `docs/`.
2. Run `make doctor` or create it.
3. Inventory `ref/` and document GoldenPad.
4. Create state/evidence files.
5. Acquire and hash official v469e macOS release.
6. Establish the Metal macOS baseline.
7. Generate the full Mach-O/native-package audit.
8. Make the G1 go/no-go decision.
9. Build the signed iOS shell.
10. Attempt macOS hosted-engine conversion, then physical-device engine startup.

The first true victory is a physical iPad log line emitted by the original v469e engine. Everything before that is preparation; everything after that is product completion.
