# Current input status and low-burden validation plan

Last reconciled: 2026-08-31

This is the acceptance authority for the current iPad input work. The behavior
described in [`INPUT_CONTROLS.md`](INPUT_CONTROLS.md) is the target contract,
not proof that a build satisfies it.

## Snapshot identity

- Physically accepted keyboard baseline: `db4e8d1`
- Controller-at-launch log: `utp-investigation-controller-relaunch-20260826.stdout`
- Rejected physical result:
  [`evidence/engine-startup/2026-08-26-input-rejection/RESULT.md`](evidence/engine-startup/2026-08-26-input-rejection/RESULT.md)
- Accepted keyboard result:
  [`evidence/engine-startup/2026-08-27-keyboard-acceptance/RESULT.md`](evidence/engine-startup/2026-08-27-keyboard-acceptance/RESULT.md)
- Foreground discovery follow-up:
  [`evidence/engine-startup/2026-08-27-foreground-controller-discovery-candidate/RESULT.md`](evidence/engine-startup/2026-08-27-foreground-controller-discovery-candidate/RESULT.md)
- Accepted controller hot-connect result:
  [`evidence/engine-startup/2026-08-27-controller-hot-connect-acceptance/RESULT.md`](evidence/engine-startup/2026-08-27-controller-hot-connect-acceptance/RESULT.md)
- Accepted keyboard-plus-pointer follow-up:
  [`evidence/engine-startup/2026-08-30-pointer-capture-physical-partial/RESULT.md`](evidence/engine-startup/2026-08-30-pointer-capture-physical-partial/RESULT.md)
- Installed foreground-discovery candidate:
  `build/ios-device-app/Build/Products/Debug-iphoneos/UT99Apple.app`
- Installed executable UUID: `F97BE745-DD6D-3F98-AD4A-A3996D7F42C5`
- Installed executable SHA-256:
  `bdce45653bef78e54ef82957ef5e1d3025a5f0422e8912173d1b38230d23803b`
- Physically tested pointer-capture baseline, 2026-08-30:
  `build/ios-device-app/Build/Products/Debug-iphoneos/UT99Apple.app`
- Pointer-capture candidate executable UUID:
  `D4C2B665-63B2-3B50-91F4-FB26C1096AC4`
- Pointer-capture candidate executable SHA-256:
  `7bc460acbbef646feb23535f736db63fffa13284eda3985201a871a318094322`
- Pointer-capture candidate SDL SHA-256:
  `9d62220e21ea62538a91f274b80350886f9c78fa2ed38193b95e6c219ab79c06`
- Installed pointer-speed/WASD follow-up UUID:
  `C908B6EE-32D5-3B93-BC2F-9405C3DDBFD0`
- Installed pointer-speed/WASD follow-up executable SHA-256:
  `c56468c3f60b13b42f4dca08d9aaff45f04c7ea01b1acc323770127f6bc3f21f`
- Installed pointer-speed/WASD follow-up SDL SHA-256:
  `2a3b8f15ed1277f3f39f491a619bcab5e583fe90a610de90c647e2888b57b336`
- Installed GCKeyboard WASD candidate UUID:
  `DD3DF80E-152B-3001-B440-BD039FC79C35`
- Installed GCKeyboard WASD candidate executable SHA-256:
  `c86ca65147723b7fe8dee6f4f54dd44b6316fdbf24acc6330f99d9398dfbb649`
- Installed GCKeyboard WASD candidate SDL SHA-256:
  `6bcf306b4d698b5811784e4169833bd26d9f1900c4d9f3d7f8fd2d59c3a0d4fd`
- Installed GCKeyboard callback-plus-poll candidate UUID:
  `8CDD53E5-C761-3A8E-8C0D-83266A0197B8`
- Installed GCKeyboard callback-plus-poll executable SHA-256:
  `afbdaad442a345ffdcada3832af56753847ff1f8a00fb35accd791be7135b4cd`
- Installed GCKeyboard callback-plus-poll SDL SHA-256:
  `7035d4eb506faa383d32fce0812c9c981a10b4fc4c367558bfcbf338678bbc01`
- Installed conditional-panel/server-browser follow-up UUID:
  `D779F94B-E86C-3030-8F1B-43CE011ED368`
- Installed conditional-panel/server-browser executable SHA-256:
  `973406ca7f1576f11742f9a7311332a29e667c53829a702f6089f6da2ed0f9fa`
- Installed conditional-panel/server-browser SDL SHA-256:
  `f674efc57c0f90ac852a845f4ab8c5187ee2ee862811b8b8e05bf976b2a7075a`

The `097a630` foreground-discovery candidate was installed in place without
changing the data container; preferences and both UT INI files are
byte-identical before and after installation. Hardware and host software
keyboard entry remain physically accepted. On 2026-08-27, the user also
physically accepted Xbox hot-connect from Bluetooth Settings, original-menu
navigation, mode switching, Oblivion movement/look/fire, and pause/resume on
this exact candidate. Its predecessor `d10f613` remains a documented rejected
build. No later worktree edit may be called physically accepted merely because
it builds or passes a Simulator probe.

The installed candidate contains responder-only controller containment. Its
host and physical printable keys share the accepted KeyDown, TextInput, KeyUp
bridge. The rejected direct engine-character and Unicode-plus-text helpers are
absent.

On 2026-08-31, the user physically accepted the callback-plus-poll candidate
in an Oblivion deathmatch. Explicit Gameplay mode delivered held WASD movement,
captured trackpad look, pointer buttons, and the higher sensitivity presets.
The already-connected controller continued to work simultaneously. The same
run accepted the host keyboard and Escape actions. This closes the combined
keyboard, trackpad/mouse, and controller input defect; it does not prove wheel
behavior that was not separately narrated.

The conditional-panel/server-browser follow-up was then installed in place on
the same iPad. Preferences, `User.ini`, and `UnrealTournament.ini` were nonempty
and byte-identical before and after installation, and the new process remained
alive after launch. The user then accepted the menu and final build as working
great and explicitly authorized Preview 3 publication. This accepts the panel
conditionality and stock browser-route follow-up at the user-visible level.

## Evidence labels

- **Accepted**: the behavior was observed on the physical iPad.
- **Rejected**: the behavior was attempted on the physical iPad and failed.
- **Code-confirmed**: the implementation or log explains a path, but the user-
  visible result has not been accepted.
- **Open**: current evidence does not decide the result.

## Working baseline

| Behavior | Status | Evidence and boundary |
| --- | --- | --- |
| Normal launch reaches the original UT front end | Accepted with lifecycle caveat | The latest narrated run reached the menu. Earlier runs exposed a delayed curtain and a broken recovery **Not Now** path, so those transitions are not globally accepted. |
| Touch menu cursor, SELECT, and BACK | Accepted | The touch trackball/menu path is usable. Saved control placement must be preserved; it is not evidence that fresh-install defaults match the current iPad layout. |
| Touch gameplay movement, look, and actions | Accepted | Offline gameplay works through the gameplay touch layout. |
| Xbox controller already connected before UTP launches | Accepted | The relaunch log reports `Detected 2 joysticks` and an Xbox extended profile. Physical menu navigation and gameplay were reported working. |
| Xbox controller connected after UT is already running | Accepted on 2026-08-27 | Connecting through Bluetooth Settings published an Xbox extended profile. UTP adopted it, hid touch controls, navigated the original menu, switched to Gameplay, and delivered movement, look, and fire in Oblivion. Pause/resume also remained usable. |
| Physical keyboard Player Name entry | Accepted on 2026-08-27 | The attached iPad keyboard deleted and entered printable characters in the real Player Name field. The matching log records UIKit responder callbacks and the required KeyDown, TextInput, KeyUp dequeue order. |
| In-host keyboard presentation and entry | Accepted on 2026-08-27 | Open/Close presentation, sizing, Delete, uppercase and lowercase printable entry all worked in the real Player Name field. |
| Diagnostic ZIP and issue-report actions | Accepted | The modal-free export writes the bounded ZIP into the Files-visible UTP Documents folder without freezing the engine. |
| Audio and offline match flow | Accepted for the present slice | Physical gameplay and music/audio have been observed. Route interruption and long-session acceptance remain separate work. |
| Captured trackpad or mouse gameplay | Accepted on 2026-08-31 | Capture, relative look, pointer buttons, and the persistent speed presets worked in Oblivion. A higher preset was reported comfortable; the sensitivity values require no change. |
| Hardware-keyboard gameplay | Accepted on 2026-08-31 | WASD worked after explicitly selecting Gameplay mode. Space and weapon keys remained functional, while UIKit text entry remained intact in Menu mode. |
| Simultaneous controller plus keyboard and pointer | Accepted on 2026-08-31 | The connected controller continued to work while WASD and the captured trackpad were active. Input sources did not exclude one another. |

## Broken or unaccepted behavior

| Behavior | Status | Current diagnosis |
| --- | --- | --- |
| In-host software keyboard letters and numbers | Accepted on the current installed build | The corrected KeyDown, TextInput, KeyUp sequence visibly edited Player Name on the physical iPad. The privacy-safe device log confirms the same ordered dequeue sequence for the accepted host-key taps. |
| Launch curtain and crash-recovery dismissal | Simulator-accepted; physical remains open | The exact blank landing panel after recovery **Not Now** was reproduced in the dedicated iPad Simulator. A deferred panel refresh after alert dismissal now restores the complete Ready card. The same cold-relaunch recovery path passed twice in Simulator; the candidate has not been installed on iPad. |
| Multiplayer **Press Escape to begin** transition | Open | Escape delivery and the original download/connection state have not been separated. Do not change the prompt or input mapping without a timestamped reproduction. |
| Three-dot **Open Server Browser** action | Accepted in the final Preview 3 candidate | The first 2026-08-31 tap reached UMenu but not `UBrowser`. The installed follow-up uses a slower, phase-logged stock Multiplayer → Find Internet Games route without replacing the original browser; the user accepted the final menu/build before publication. |
| Three-dot control conditionality | Accepted in the final Preview 3 candidate | The accepted follow-up labels actual Show/Hide state, exposes Arrange only when useful, and shows speed only while capture is enabled. The user accepted the final menu as working great. |
| Fresh-install iPad SELECT/BACK defaults | Open | The user's saved layout is usable, but the currently preferred physical positions must be captured before changing defaults. Never overwrite an existing saved layout to test this. |

## What code and automation can decide without the user

The following gates are Codex's responsibility and happen before any device
handoff:

1. Record the source revision, dirty-diff digest, app binary UUID, install
   identity, and diagnostic-log timestamps.
2. Preserve and compare the preferences plist, `User.ini`, and
   `UnrealTournament.ini` around every in-place install.
3. Add or run deterministic tests for input ownership and state transitions:
   one controller edge has one owner; responder-only fallback cannot auto-hide
   touch; keyboard buttons enqueue the intended SDL event sequence; one pointer
   producer owns motion and click.
4. Build, sign, package, launch, and run the focused shell tests plus
   `git diff --check`.
5. Reject the candidate locally if logs show duplicate producers, missing
   releases, a stale mode, or a data-preservation mismatch.

These gates can prove that events are discovered, transformed, queued, released,
and attributed correctly. They cannot prove that an opaque original UWindow
field visibly changed, that the stock cursor visually aligns with the iPad
pointer, or that iPadOS published a hot-connected controller profile.

## Remaining focused input observation

Controller publication, hot-connect, original-menu navigation, gameplay, mode
switching, WASD, captured pointer look/buttons, sensitivity selection, and
simultaneous controller use are physically accepted. Remaining input work is
limited to separately confirming wheel/scroll if required and validating that
the conditional three-dot wording remains understandable in Menu mode,
Gameplay mode, controller-auto-hidden touch, visible touch, and uncaptured
pointer states.

Codex can mirror the iPad without recording, collect timestamps, and correlate
the persisted logs. The user should not need to narrate the bug, export logs,
rebuild, reinstall, or repeat a failed gesture.

## Rejected candidate evidence, 2026-08-26

- `make test` passes, including touch geometry, controller-cardinal, recovery,
  diagnostic archive, data transaction, and packaging tests.
- The patched SDL source applies cleanly and exports hardware-key, text,
  software-text, and pointer bridge symbols in the iPhoneOS candidate.
- The silent diagnostic Simulator package reaches `Game engine initialized`,
  renders the original UT menu, enters the main loop, and completes the touch
  action smoke sequence.
- The live software-text probe posts `A1z` through Unicode plus text input and
  reports queue delivery success after the main loop starts. Physical testing
  proved that this is not evidence of visible field mutation.
- The recovery **Not Now** regression was reproduced before the fix and passed
  twice afterward: the state becomes Ready and the complete Play Offline/Play
  Online card is visible instead of a blank landing screen.
- A background/foreground cycle preserves the running process and original UT
  menu, with `Running -> PausedBySystem -> Running` and balanced lifecycle logs.
- Controller diagnostics now record discovered/extended profile counts,
  responder-fallback ownership, bounded raw/transformed stick samples, and
  disconnect cleanup without recording player-entered text.
- Xcode static analysis succeeds and the complete `make test` suite passes.
- The real-audio iPhoneOS package builds and passes package verification.
- That matching device build was physically rejected for software text,
  physical-keyboard recovery, controller hot-connect, and Menu/Gameplay state
  consistency. The later keyboard follow-up described below was installed and
  physically accepted; the later `097a630` foreground-discovery candidate also
  physically closes controller hot-connect.

## Local candidate evidence, 2026-08-27

- The 127-second physical recording shows `Chri` present before the custom
  keyboard opens, DELETE clearing it, and all later printable attempts leaving
  the selected field empty. The pulled session log records the DELETE key
  edges and each software character's successful queue insertion, but no
  hardware-key responder callbacks and no SDL dequeue/consumer evidence.
- The follow-up added bounded, privacy-safe records for host first-responder
  ownership and SDL dequeue of TextInput, KeyDown, and KeyUp. It records
  character count and key metadata, never entered text.
- The custom keyboard's printable buttons and the physical printable-key route
  converge on `SDL_UT99SendKeyboardText`; the rejected direct engine call and
  Unicode-plus-text helper are absent.
- A changed SDL patch hash forced the cached source tree to be quarantined and
  rebuilt. Symbol inspection of both products finds hardware-key and plain-text
  bridges and no software-text bridge.
- `git diff --check`, the focused host-state/input test, the complete `make
  test` suite, Xcode static analysis, real-engine Simulator packaging, and
  real-FMOD iPhoneOS packaging pass.
- A deterministic real-engine Simulator probe now opens Character Creation,
  focuses the stock Player Name edit box, clears `Player`, and visibly enters
  `Ab 9`. The dequeue log proves the production route delivered Shift/KeyDown,
  TextInput, KeyUp/ShiftUp in that order. This is local Simulator acceptance,
  not physical iPad acceptance.
- Packaged UWindow source established the rejection mechanism:
  `UWindowEditBox.KeyType` inserts printable characters only while its internal
  `bKeyDown` flag is true. Plain TextInput has no key-down, while UIKit's prior
  Unicode recipe queued KeyDown, KeyUp, then TextInput and cleared the flag too
  early. The candidate now holds the matching virtual key through TextInput.
- The signed, package-verified iPad candidate is staged at
  `build/ios-device-app/Build/Products/Debug-iphoneos/UT99Apple.app`. Its host
  UUID is `76FC6C39-B7E0-3AC1-AFED-0F73CFA96E40`; host SHA-256 is
  `d141362e540d2bab1cc40ce39cccb7ab4673c0d251d9c96f5ed13c6d2dcd5cab`;
  embedded SDL SHA-256 is
  `2cca0f899592092339ca2f35a9b98aa65e1d31161226709f808a0b7fba4d06ec`.
  It was installed in place on the attached iPad on 2026-08-27. Pre/post
  copies of the preferences plist, `User.ini`, and `UnrealTournament.ini` are
  byte-identical. The normal launch reached `Game engine initialized`, entered
  the main loop, and rendered the stock menu. The focused physical keyboard
  observation subsequently passed.

## Controller lifecycle candidate, 2026-08-27

- The keyboard-accepted source is frozen in `db4e8d1`; the controller candidate
  is a separate diff and does not change the SDL keyboard patch or either
  printable-key producer.
- Root cause: Unreal was entered from a serial main-dispatch block and never
  returned. SDL's nested UIKit event pump could continue servicing UIKit event
  sources, but the executing block permanently occupied the main dispatch
  queue used by GameController lifecycle notifications and host UI
  reconciliation.
- The candidate keeps SDL/Metal/Unreal on the main thread but schedules entry
  through the main run loop instead of a non-returning main-dispatch block.
- A Simulator-only hidden `GCVirtualController` test connects three seconds
  after the real engine starts. The live run proved the main queue remained
  responsive, published an extended profile, delivered menu stick/A input,
  switched to Gameplay, delivered movement/look/right-trigger input, switched
  back to Menu, and processed disconnect cleanup.
- The same candidate then reran the real Player Name probe. The field visibly
  contained `Ab 9`, and every printable character retained KeyDown, TextInput,
  KeyUp dequeue order.
- `make test`, the focused input source guard, Simulator packaging, signed
  iPhoneOS building, and deep package verification pass. This is strong local
  lifecycle evidence, not physical controller acceptance.
- Staged signed host UUID: `0B4958D1-0EC7-3408-A82A-9D10F215031D`.
  Host SHA-256: `7cf5c81c240f0f7f29a094178572e7e8d9b78fe8d134965e710590de2351354d`.
  SDL patch SHA-256 remains
  `68a1ce30d1e8808e7a928269bfc2133c2ea17e6e8ac75b22fb3f07dace2244e2`.
- Physical result: rejected for connecting through Bluetooth Settings after
  Unreal was already running. Ending and reopening UTP with the controller
  connected restored full menu and Oblivion gameplay control.
- The failed process log was erased by the subsequent engine launch. The next
  follow-up rotates the bounded previous engine log and restarts finite
  wireless discovery plus main-run-loop reconciliation after UTP becomes
  active again.

## Physical controller hot-connect acceptance, 2026-08-27

- The accepted installed candidate is `097a630`, host UUID
  `F97BE745-DD6D-3F98-AD4A-A3996D7F42C5`.
- The user launched without the Xbox controller, entered the original UT menu,
  connected the controller through Bluetooth Settings, and returned to UTP.
- The live log records the Xbox extended profile being configured and becoming
  current, followed by automatic touch-overlay hiding.
- The user physically confirmed original-menu control, Player Name keyboard
  regression, Oblivion gameplay movement/look/fire after switching modes, and
  pause/resume.
- This closes the controller publication and hot-connect repair for the
  accepted candidate. Pointer precision and renderer defects remain separate.
- Full evidence is recorded in
  [`evidence/engine-startup/2026-08-27-controller-hot-connect-acceptance/RESULT.md`](evidence/engine-startup/2026-08-27-controller-hot-connect-acceptance/RESULT.md).

## Physical keyboard acceptance, 2026-08-27

- The installed host UUID was `76FC6C39-B7E0-3AC1-AFED-0F73CFA96E40`.
- The user selected the real Player Name field and confirmed that the attached
  iPad keyboard could delete and enter the name.
- The user opened UTP's virtual keyboard and confirmed that Delete and
  printable `S` input both changed the same field.
- The pulled device log records hardware responder callbacks and ordered
  KeyDown, TextInput, KeyUp delivery for printable characters.
- The same log records the host keyboard opening and its Delete plus printable
  character events dequeuing through the accepted production route.
- This closes the keyboard repair. Controller lifecycle work starts from this
  installed source/build baseline and must not alter
  `SDL_UT99SendKeyboardText` or its required ordering.
- Full evidence is recorded in
  [`evidence/engine-startup/2026-08-27-keyboard-acceptance/RESULT.md`](evidence/engine-startup/2026-08-27-keyboard-acceptance/RESULT.md).

## Revised execution order

### 0. Freeze the real baseline

Identify the installed binary and matching source. Preserve the app container
and capture the preferred saved iPad layout. No behavior changes occur here.

### 1. Contain responder-only controller input — accepted

The foreground-discovery candidate now publishes and adopts the real extended
profile after Bluetooth Settings and has passed physical menu/gameplay
acceptance. Responder fallback remains explicitly menu-only and must never hide
or reroute complete touch gameplay. Do not create another synthetic gameplay
map from `UIPress`; it has no separate stick or trigger data.

### 2. Software keyboard route convergence — accepted

Every printable character uses one SDL helper that queues the matching virtual
KeyDown, TextInput, then KeyUp. This ordering is required by the stock
`UWindowEditBox` implementation and has visibly passed with both the attached
hardware keyboard and UTP virtual keyboard on the physical iPad. Log only event
metadata and character counts, never text.

### 3. Physical pointer, isolated — next input slice

Use one host-owned Apple pointer route while keeping SDL's separate `GCMouse`
registration disabled. Uncaptured Menu mode uses UIKit's absolute pointer.
Opt-in capture requests iPadOS pointer lock and consumes host `GCMouse` raw
deltas for Unreal's stock cursor or gameplay look. The physical check must prove
the requested lock is granted, only one cursor remains, keyboard-plus-pointer
gameplay works, and button/wheel edges are neither duplicated nor lost.

### 4. Deferred tuning

Only after the three broken routes above pass should work resume on stick feel,
launch polish, multiplayer Escape, fresh-layout defaults, or cosmetic issues.
Those changes must not share an acceptance build with controller discovery,
software text, or pointer ownership.

## User-burden and stop rules

- Two short iPad touchpoints are the honest maximum: one controller
  discriminator, followed later by one acceptance session for candidates that
  passed every automated gate. Codex handles builds, preservation-safe in-place
  installs, mirroring, timestamps, logs, and result classification.
- Each installed candidate changes one input route only. A failure ends that
  route's physical testing until the new evidence has been analyzed.
- No uninstall, no data-container replacement, no reset of saves/progress, and
  no overwrite of the user's touch layout.
- A passing build/package/test result is never described as physical input
  acceptance.
- A code path is not called fixed until the corresponding physical observation
  passes.
