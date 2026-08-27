# UTP hardening plan

The reconciled current-build acceptance matrix and the revised low-burden
execution protocol are maintained in
[`CURRENT_INPUT_STATUS.md`](CURRENT_INPUT_STATUS.md). That status document is
authoritative when an intended behavior below conflicts with physical evidence.

This plan keeps input repairs isolated so each physical-device build has one
clear behavioral change and can be accepted or rejected without ambiguity.
Preview releases must preserve installed game data, saves, progress, touch
layouts, and host settings.

## Current support slice

The live three-dot panel exposes two adjacent support actions beneath
**Multiplayer**:

- **Export Logs** creates a bounded redacted `UTP-Logs-Latest.zip` directly in
  UTP's Files-visible Documents folder. The stable in-game panel reports its
  location as **Files → On My iPad → UTP**.
- **Report a Problem** opens the repository's new-issue page with a short bug
  report outline and instructions to attach that ZIP.

The archive contains bounded host/runtime information, up to the most recent
512 KiB from each engine/host log, and recovery records. Home-directory paths
and common secret fields are redacted. Server addresses may remain relevant to
multiplayer diagnosis, so the archive tells players to review them before
sharing. The first physical implementation synchronously collected the full
diagnostic snapshot and stalled the original engine/UI thread. The player-facing
export no longer queries live Metal, audio, or network state. A second physical
attempt proved the 12 ms archive completed and then froze only after the system
Files picker was presented. Export therefore presents no system modal while the
original engine owns the main loop; the player attaches the saved ZIP from Files
when reporting the issue. Physical iPad export and a pulled ZIP integrity check
have passed for this modal-free path.

When verified data is already installed, a normal player launch proceeds
directly into the original UT front end. The Offline/Online landing choice is
not shown because both routes enter that same front end. Recovery and explicit
diagnostic launches retain their dedicated host state.

The 2026-08-26 device candidate was installed in place and physically rejected.
Software text reached the SDL enqueue boundary but not the visible UWindow
field. A hot-connected Xbox controller never appeared as an extended
GameController profile and arrived only through collapsed responder presses.
One of those generic presses also switched the internal input mode while the
visible touch layout remained in Gameplay. The full evidence is recorded in
[`evidence/engine-startup/2026-08-26-input-rejection/RESULT.md`](evidence/engine-startup/2026-08-26-input-rejection/RESULT.md).

The accepted keyboard follow-up implements only evidence-backed containment and
route convergence: responder-only input is menu-only, and host/physical
printable keys share one SDL keyboard helper. Packaged UWindow source proves
that `UWindowEditBox.KeyType` inserts only while `bKeyDown` is true. The helper
therefore queues KeyDown, TextInput, then KeyUp instead of posting plain text or
releasing the virtual key too early. A deterministic real-engine Simulator run
visibly entered `Ab 9` in Player Name and its dequeue log confirms that exact
order. The signed product was installed in place on 2026-08-27;
the preferences plist and both UT configuration files remained byte-identical,
normal engine startup passed, and both the attached hardware keyboard and UTP
virtual keyboard edited the real Player Name field. That accepted baseline is
frozen in `db4e8d1`.

The controller lifecycle candidate changes only how the non-returning engine
entry is scheduled. It remains on the main thread for SDL/UIKit/Metal, but no
longer occupies a serial main-dispatch block forever. A real-engine Simulator
probe connected an extended virtual controller after engine entry, completed
menu input, switched to Gameplay, delivered movement/look/right-trigger input,
returned to Menu, and disconnected cleanly. The `Ab 9` Player Name regression
then passed unchanged. Physical Xbox hot-connect/disconnect remains the sole
acceptance boundary for this slice.

The same candidate also contains a narrow recovery presentation repair. The
dedicated iPad Simulator reproduced the blank landing screen after choosing
**Not Now** from **Previous Session Interrupted**. Refreshing the onboarding
panel after the alert dismissal completes restores the Ready card. Two
post-repair recovery runs, a real engine launch, and a background/foreground
cycle pass locally. This remains distinct from physical iPad acceptance.

## Confirmed input findings

- Physical hardware and UTP virtual-keyboard entry are accepted. The
  software-key rejection was caused by event order inside UWindow: TextInput
  arrived after KeyUp, so `bKeyDown` was false. The accepted helper holds the
  matching key through TextInput and must remain unchanged.
- A controller present before launch obtains an extended profile and works. In
  the rejected hot-connect run, no `GCController` object appeared at all;
  iPadOS exposed only generic `UIPress` values. Both sticks collapse into the
  same directions and triggers have no stable profile in that path.
- The rejected build could process responder `playPause` immediately while its
  deferred overlay change never ran, leaving mode and layout crossed. The
  lifecycle candidate restores main-queue progress; the post-engine Simulator
  probe completed both mode transitions and their UI reconciliation.
- Menu cursor movement crosses two hard dead zones without rescaling,
  hysteresis, or sample filtering.
- Gameplay left-stick movement is translated to digital arrow-key holds after
  fixed dead-zone and cardinal-snap thresholds; stick magnitude is not analog
  movement speed.
- Controller reconciliation handlers exist for connect and disconnect, but the
  rejected non-returning main-dispatch engine entry prevented those lifecycle
  notifications from running reliably. The main-run-loop scheduling candidate
  passes post-engine connect/disconnect locally and awaits physical acceptance.
- Touch visibility can override the pointer surface's explicit input mode,
  allowing controller and mouse/trackpad routing to disagree.
- The multiplayer Escape failure is not yet localized between input delivery
  and the original engine's download/connection state.

## Ordered input hardening slices

1. **Input observability (candidate implemented).** Record source-tagged
   keyboard/controller edges, text-post counts and focus, throttled
   raw/transformed stick values, controller reconciliation, pointer ownership,
   and disconnect cleanup. Keep exported logs bounded and redacted; never log
   player-entered text.
2. **Keyboard route convergence (physical iPad accepted 2026-08-27).** Route printable keys
   through the one KeyDown, TextInput, KeyUp helper required by UWindow and log
   only event metadata plus character counts. Do not restore the rejected plain
   TextInput, Unicode KeyDown/KeyUp/TextInput, or direct `UEngine::Key` recipes.
   Hardware and host-key entry both passed in the real Player Name field. Treat
   this slice as frozen while controller lifecycle work proceeds.
3. **Controller containment.** A configured extended controller owns the native
   route. Responder-only input is menu-only, cannot switch mode, and cannot
   auto-hide or reroute touch gameplay. Full hot-connect work resumes only
   after a lifecycle change publishes an extended profile after engine entry.
4. **Menu-stick response.** Use captured Xbox traces to select one radial dead
   zone, rescale after it, add small hysteresis, and tune a continuous cursor
   speed curve. Validate small targets and all four display corners.
5. **Gameplay movement.** Determine whether the original `JoyX`/`JoyY` axis
   route can safely replace digital arrow-key holds. If it cannot, retain the
   digital bridge but remove stacked thresholds and add transition hysteresis.
6. **Pointer ownership (candidate ready).** Host UIKit is the sole pointer
   producer; SDL `GCMouse` setup is disabled. Do not tune scale or add another
   transform until the four-edge physical check decides whether one is needed.
7. **Mode consistency.** Make explicit Menu/Gameplay mode authoritative for
   touch, controller, mouse, and trackpad. Touch visibility must not change
   pointer routing.
8. **Multiplayer Escape.** Correlate Escape delivery with the original engine's
   connection/download state before changing either input or prompt behavior.

## Physical acceptance for every input slice

- Install in place with the same bundle identifier; never uninstall or replace
  the application data container.
- Record the exact source revision and confirm the app launches.
- Exercise only the changed behavior plus a short offline gameplay regression.
- Export a diagnostics ZIP after the test and verify it can be saved/shared.
- Stop and document the result before beginning the next behavioral slice.
