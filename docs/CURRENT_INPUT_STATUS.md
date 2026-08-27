# Current input status and low-burden validation plan

Last reconciled: 2026-08-27

This is the acceptance authority for the current iPad input work. The behavior
described in [`INPUT_CONTROLS.md`](INPUT_CONTROLS.md) is the target contract,
not proof that a build satisfies it.

## Snapshot identity

- Source baseline: `705a765de3b5fb06a2bd3e15119bef1ffba99bb6`
- Controller-at-launch log: `utp-investigation-controller-relaunch-20260826.stdout`
- Rejected physical result:
  [`evidence/engine-startup/2026-08-26-input-rejection/RESULT.md`](evidence/engine-startup/2026-08-26-input-rejection/RESULT.md)
- Accepted keyboard result:
  [`evidence/engine-startup/2026-08-27-keyboard-acceptance/RESULT.md`](evidence/engine-startup/2026-08-27-keyboard-acceptance/RESULT.md)
- Installed matching product:
  `build/ios-device-app/Build/Products/Debug-iphoneos/UT99Apple.app`
- Installed executable UUID: `76FC6C39-B7E0-3AC1-AFED-0F73CFA96E40`
- Installed executable SHA-256:
  `d141362e540d2bab1cc40ce39cccb7ab4673c0d251d9c96f5ed13c6d2dcd5cab`

The current iPad binary was installed in place without changing the data
container. Hardware and host software keyboard entry were physically accepted
on 2026-08-27. Controller hot-connect and reconnect remain rejected/open. No
later worktree edit may be called physically accepted merely because it builds
or passes a Simulator probe.

The installed candidate contains responder-only controller containment. Its
host and physical printable keys share the accepted KeyDown, TextInput, KeyUp
bridge. The rejected direct engine-character and Unicode-plus-text helpers are
absent.

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
| Physical keyboard Player Name entry | Accepted on 2026-08-27 | The attached iPad keyboard deleted and entered printable characters in the real Player Name field. The matching log records UIKit responder callbacks and the required KeyDown, TextInput, KeyUp dequeue order. |
| In-host keyboard presentation and entry | Accepted on 2026-08-27 | Open/Close presentation, sizing, Delete, uppercase and lowercase printable entry all worked in the real Player Name field. |
| Diagnostic ZIP and issue-report actions | Accepted | The modal-free export writes the bounded ZIP into the Files-visible UTP Documents folder without freezing the engine. |
| Audio and offline match flow | Accepted for the present slice | Physical gameplay and music/audio have been observed. Route interruption and long-session acceptance remain separate work. |

## Broken or unaccepted behavior

| Behavior | Status | Current diagnosis |
| --- | --- | --- |
| In-host software keyboard letters and numbers | Accepted on the current installed build | The corrected KeyDown, TextInput, KeyUp sequence visibly edited Player Name on the physical iPad. The privacy-safe device log confirms the same ordered dequeue sequence for the accepted host-key taps. |
| Xbox controller connected after UT is already running | Rejected with root boundary confirmed | The first live controller edge found zero `GCController` objects and zero extended profiles. Only collapsed `UIPress` responder events appeared; no independent sticks or triggers existed. Full gameplay cannot be synthesized from that representation. |
| Touch fallback after failed controller hot-connect | Rejected mixed-mode behavior | Touch correctly remained visible without an extended profile, but a responder `playPause` edge switched the internal state to Menu while the gameplay overlay remained visible. Touch routing and its visual layout diverged. |
| Physical trackpad pointer | Rejected on the installed build; candidate locally isolated | The candidate keeps host UIKit as the sole pointer producer and disables SDL `GCMouse` initialization. It adds no new scale or affine correction. The live engine logs `pointer owner=host-uikit sdl-gcmouse=disabled` with correct 1366x1024 point and 2732x2048 pixel geometry. Four-edge alignment and one stock click remain physical checks. |
| Launch curtain and crash-recovery dismissal | Simulator-accepted; physical remains open | The exact blank landing panel after recovery **Not Now** was reproduced in the dedicated iPad Simulator. A deferred panel refresh after alert dismissal now restores the complete Ready card. The same cold-relaunch recovery path passed twice in Simulator; the candidate has not been installed on iPad. |
| Multiplayer **Press Escape to begin** transition | Open | Escape delivery and the original download/connection state have not been separated. Do not change the prompt or input mapping without a timestamped reproduction. |
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

## The only three types of physical observation still needed

Physical work is limited to these short yes/no observations:

1. **Controller publication:** after a lifecycle-level repair candidate exists,
   hot-connect the Xbox controller once and confirm that the log reports a real
   extended profile before moving both sticks and a trigger. Do not retest full
   gameplay while the app reports responder-only input.
2. **Software text:** after dequeue/consumer logging exists, select Player Name
   once and enter one physical character followed by one host-key character.
3. **Physical pointer:** move to the four display edges and select one stock
   submenu with the physical trackpad.

Codex will mirror and record the iPad, watch the result, collect timestamps, and
correlate the logs. The user should not need to narrate the bug, export logs,
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
  physically accepted; controller lifecycle remains open.

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

### 1. Contain responder-only controller input

The discriminator is complete: an Xbox profile present before launch works,
while the hot-connected session produced only generic responder presses after
engine entry. First remove responder-fallback mode switching and make that path
explicitly menu-only. It must never hide or reroute complete touch gameplay.

A full hot-connect repair belongs at the GameController/legacy-main-loop
lifecycle boundary and is accepted only when `GCController.controllers()`
publishes a real extended profile. Do not create another synthetic gameplay map
from `UIPress`; it has no separate stick or trigger data.

### 2. Software keyboard route convergence, isolated

Send every printable character through one SDL helper that queues the matching
virtual KeyDown, TextInput, then KeyUp. This ordering is required by the stock
`UWindowEditBox` implementation and has visibly entered `Ab 9` in the real
Player Name field in Simulator. Log only event metadata and character counts,
never text. One short host-key and physical-key check in that same field remains
the deciding iPad observation; queue return values alone are not acceptance.

### 3. Physical pointer, isolated

Choose one pointer owner for the candidate. The first discriminator keeps the
host UIKit pointer route and disables SDL `GCMouse` ownership; it does not add a
new scale, affine correction, or cursor design. After automated edge-coordinate
logging, ask only for the four-edge and one-click visual check.

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
