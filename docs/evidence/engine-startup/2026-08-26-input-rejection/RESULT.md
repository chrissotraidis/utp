# Physical iPad input candidate rejection — 2026-08-26

## Candidate identity

- Bundle identifier: `com.ut99apple.client`
- Installed executable UUID: `E5213421-823B-34EF-A82F-7E7C3FB3C3F5`
- Installed executable SHA-256:
  `362250f973142933ef0c16bc242a716ecc9d14d774e99340076eaf54e7e8d113`
- Matching local product:
  `build/ios-device-app/Build/Products/Debug-iphoneos/UT99Apple.app`
- Source baseline: `705a765de3b5fb06a2bd3e15119bef1ffba99bb6`
- Focused implementation diff digest:
  `1cd762c31ad54deaf0f6437732ab77f9ae6016f524b7713b52767b7cefc5f16b`

The candidate was installed in place with the existing bundle identifier.
`User.ini`, `UnrealTournament.ini`, and the saved touch-layout data were
preserved across the install. No uninstall or data-container replacement was
performed.

## Physical result

The candidate is **rejected** and is not release-ready.

### Software and hardware text

- The physical keyboard initially entered Player Name successfully.
- The host keyboard opened, but letters, numbers, and Space did not visibly
  mutate the selected UWindow field. DELETE worked.
- Every host-key tap logged
  `software text characters=1 delivery=unicode+text result=1`.
- After the host-keyboard attempt, reconnected physical-key presses still
  reached the host and logged `text accepted`, but the selected field no longer
  visibly changed.

`result=1` only proves that SDL accepted an event into its queue. It does not
prove that `USDLViewport::UpdateInput` polled it or that UWindow's focused edit
control consumed it. The engine binary's disassembly confirms that
`SDL_TEXTINPUT` (`0x303`) is decoded and forwarded to the engine character
handler when it is actually polled. The missing discriminator is therefore
queue consumption/focused-field ownership, not another speculative key map.

### Xbox hot-connect

- The Xbox controller was connected after the original engine was running.
- On the first controller responder event, the host logged:
  `controller enumerate reason=active responder event main=true count=0 extended=0`.
- The session contains no `controller connected`, `controller became current`,
  `controller configured`, or extended-profile sample record.
- The engine detected only the `iOS Accelerometer`; it never added an Xbox SDL
  joystick during this run.

iPadOS delivered only generic `UIPress` responder events. That representation
collapses both physical sticks into the same four arrow types and provides no
separate right-stick axes or trigger profile. It cannot be used to implement a
full gamepad. Touch controls correctly remained visible because no extended
controller existed, but the fallback still produced a broken mixed-mode state.

### Crossed Menu/Gameplay state

- The host entered Gameplay mode at `19:38:15` and protected the complete touch
  fallback because the controller was responder-only.
- At `19:38:20`, a generic responder `playPause` press changed the internal
  input state back to Menu.
- `toggleInputModeFromController()` changes `originalMenuInputActive`
  immediately, then defers the visible overlay update through
  `DispatchQueue.main.async`. The legacy UT loop owns that queue, so the state
  and visible gameplay layout can diverge.
- The preserved recording shows the gameplay overlay still visible after the
  internal state switched to Menu. In that state the left touch stick is
  routed as a menu cursor while the look surface continues to publish look,
  matching the reported crossed controls.

Responder-only controller input must not be allowed to switch input mode or
pretend to provide gameplay axes. Only a configured extended controller may
own the native controller mode-switch and gameplay mapping.

## Preserved evidence

- A 4 minute 26 second QuickTime mirror/recording is preserved as an unsaved
  QuickTime composition on the development Mac. It was not uploaded or
  deleted.
- A private pulled snapshot containing `UT99-engine.stdout`,
  `UnrealTournament.log`, `User.ini`, and the preferences plist was retained
  locally for correlation. Raw logs are not committed because they may contain
  player-specific runtime data.

## Smallest next diagnostic candidate

Do not combine another keyboard behavior experiment with controller rewiring.

1. Add bounded SDL dequeue logging for `SDL_KEYDOWN`, `SDL_KEYUP`, and
   `SDL_TEXTINPUT`, including type, window ID, scancode, keycode, and character
   count but never the entered text itself.
2. Test one physical printable key and one host printable key while the same
   Player Name field remains selected. This decides whether the host event is
   lost before `USDLViewport::UpdateInput` or after its engine character call.
3. Independently remove responder-fallback mode switching and make a
   responder-only hot-connect explicitly menu-only. Keep touch gameplay
   visible and show the existing reopen-with-controller notice.
4. Retain the physically accepted full controller route when the extended Xbox
   profile is present before launch. A true hot-connect repair requires
   restoring GameController profile publication during the legacy main loop;
   generic `UIPress` synthesis is not an equivalent substitute.

No new build or reinstall was performed after this rejection.

## Second diagnosis pass

### Why hot-connect works only before launch

Apple documents that `GCControllerDidConnect` is posted on the main thread and
that `GCEventViewController` can route an input either to the responder chain
or to controller profile objects, but not both simultaneously:

- <https://developer.apple.com/documentation/gamecontroller/gccontrollerdidconnectnotification>
- <https://developer.apple.com/documentation/gamecontroller/gceventviewcontroller>

The host invokes the original UT entry on the main thread. The source already
contains a warning that the legacy loop does not drain blocks queued through
`DispatchQueue.main.async`; host-panel actions therefore run inline. The same
starvation explains both rejected controller symptoms:

1. A controller present before engine entry is enumerated while the normal app
   main loop still runs and receives a real extended profile.
2. A controller connected after entry produces responder events, but the
   framework's main-thread connection publication never becomes observable to
   either the host or SDL. Re-enumeration on a responder callback still returns
   zero controllers.
3. `toggleInputModeFromController()` changes the routing Boolean immediately
   and then queues its visual overlay update on that same undrained main queue.
   This creates the recorded Menu-state/Gameplay-overlay split.

This is an architecture boundary, not another button-map defect. A complete
hot-connect repair requires the engine loop to coexist with the real app main
loop or an equivalent supported GameController publication path. Until then,
the honest safe behavior is: full Xbox support when connected before launch;
responder-only hot-connect is menu-only, cannot change mode, leaves touch
gameplay intact, and tells the player to reopen UTP.

### A narrower software-keyboard route exists below SDL

The 469e engine binary exports
`UEngine::Key(UViewport *, EInputKey)`. Disassembly of
`USDLViewport::UpdateInput` shows that its `SDL_TEXTINPUT` case decodes the
character and calls that exact engine-level character handler using the current
viewport. The host can resolve the existing `GCurrentViewport`/`GClient`
symbols and invoke the same exported handler synchronously from a host-key
button callback.

That produces a smaller discriminator than another SDL event recipe:

1. Leave physical-keyboard handling unchanged.
2. Route only host printable keys through the exact engine character handler
   and record only character count plus the handler's consumed/not-consumed
   result.
3. Keep DELETE and DONE on their already working key-edge routes.
4. Test one host `A` in Player Name. If the engine reports consumed and the
   field changes, remove the failed software-text helper. If it reports not
   consumed, the remaining defect is UWindow focus ownership after opening the
   host panel.

This direct character path must run synchronously on the engine/main thread;
the host keyboard's UIKit action already executes inside the legacy event pump
on that thread. It should not be dispatched asynchronously.

### Current tests do not protect these failures

The focused shell test currently checks that the source contains
`SDL_UT99SendSoftwareText`, the Unicode helper, responder fallback, and a
controller mode-switch call. Those are presence checks. The physical rejection
proves they do not establish field mutation, controller profile publication,
or synchronized routing/UI state. The next code slice must replace the relevant
presence assertions with ownership/state assertions and keep keyboard and
controller acceptance builds separate.

## Local follow-up candidate — not installed

The two evidence-backed changes above are now implemented locally without
touching the physical iPad:

- Responder-only controller input can move/select/back in Menu mode, but every
  responder gameplay press is ignored. It cannot switch Menu/Gameplay mode or
  synthesize jump, crouch, fire, movement, or look. Touch owns gameplay until a
  real extended profile exists. The accepted native extended-controller
  mapping is unchanged.
- Host keyboard letters, numbers, and Space call the exported
  `UEngine::Key(UViewport *, EInputKey)` synchronously and log its actual
  consumed/not-consumed result. Physical-key input, DELETE, and DONE are
  unchanged.

Local candidate identity:

- Focused implementation diff digest:
  `c668cf92f79b232068339e53998d50563f02f4a3f26051e0ca9c37fca9c556c0`
- Unsigned iPhoneOS app:
  `build/ios-input-diagnostic/Build/Products/Debug-iphoneos/UT99Apple.app`
- Host executable UUID: `12192174-9AF7-3AED-9ED3-F8E4C5CF2F50`
- Host executable SHA-256:
  `97fd942cbcc72a32fa67e3648e6fc9622f0fd83302ee586293d3448ede599d7d`

Verification completed:

- Simulator-target Swift compilation: passed.
- In-place QA Simulator launch: passed; the original engine reached
  `Game engine initialized`, entered its main loop, and visibly rendered the
  stock UT menu. The Simulator app was stopped after the capture.
- Unsigned iPhoneOS compilation: passed.
- Full `make test`: passed.
- `git diff --check`: passed.
- The embedded engine exports `GCurrentViewport`, `GClient`, and the exact
  `UEngine::Key` symbol used by the new bridge.

These checks establish buildability and routing intent only. They do not prove
that Player Name visibly changes or broaden hot-connect support. No app was
signed, installed, launched, or accepted on the physical iPad during this
follow-up.

## Root cause and corrected local candidate — 2026-08-27

The earlier direct-character candidate above was rejected and removed. A later
deterministic Simulator probe navigated the real front end to Character
Creation, focused Player Name, and compared the actual SDL dequeue order with
the packaged UWindow script source.

`UWindowEditBox.KeyType` inserts printable characters only while its internal
`bKeyDown` flag is true. Plain `SDL_TEXTINPUT` never sets that flag. SDL UIKit's
Unicode helper queued KeyDown, KeyUp, then TextInput, so the flag was already
false when the printable character arrived. Both paths could report successful
delivery while leaving the field unchanged.

The production helper now queues one matching virtual KeyDown, TextInput, then
KeyUp per character, with Shift held around uppercase characters. The focused
probe first used Backspace to clear `Player`, then visibly entered `Ab 9` in the
real Player Name field. The privacy-safe dequeue log confirmed the exact event
order without recording the entered text. The SDL patch applies cleanly to the
pinned source and the focused host/input regression test passes.

This is Simulator acceptance of the engine text path only. The signed candidate
was subsequently installed in place on 2026-08-27. The saved preferences,
`User.ini`, and `UnrealTournament.ini` were byte-identical before and after the
install, and normal engine startup reached the stock menu. Physical software-
key entry and hardware-key responder recovery after detach/reconnect remain
separate acceptance gates.
