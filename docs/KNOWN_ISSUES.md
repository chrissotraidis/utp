# Known issues and technical debt

## Launch-thread feedback reconciliation — 2026-08-30

The actionable requests and defects raised in the launch thread are classified
below. A listed request is not a promise that it belongs in the next preview.

- **On-screen controls:** implemented and physically usable on iPhone and iPad.
  Discoverability remains imperfect because touch has explicit Menu and Gameplay
  modes; the three-dot panel must clearly state the current mode and what MOVE,
  SELECT, and the right-side surface do before and after switching.
- **Keyboard plus trackpad or mouse:** physically accepted as one gameplay-grade
  path on 2026-08-31. A trackpad and a mouse are the same pointer class here.
  In explicit Gameplay mode, held WASD, captured relative look, pointer buttons,
  and a higher persistent speed preset worked in Oblivion while the connected
  controller also remained usable. Menu-mode hardware text entry was preserved.
  The original combined-input, WASD, raw-sensitivity, and duplicate-pointer
  defects are closed. Wheel/scroll was not separately narrated and remains a
  narrow validation gap rather than a reason to reopen the accepted defect.
- **Three-dot panel conditionality:** the accepted input build exposed stored
  settings instead of visible state: it offered to turn touch off while a
  controller had already auto-hidden it, exposed Arrange for hidden controls,
  and always showed pointer speed. The follow-up uses actual Show/Hide wording,
  hides Arrange until touch is visible, and shows speed only when capture is on.
  The same physical run found that **Multiplayer** reached UMenu but not the
  server browser. The accepted follow-up renames the action **Open Server
  Browser** and slows/instruments the stock navigation route.
- **Controller breadth:** Xbox startup and hot-connect are physically accepted.
  UTP targets extended GameController profiles, but DualShock 4/PS4 control is an
  explicit hardware-matrix gap until it is exercised in UTP; do not generalize
  the Xbox result to “all controllers.”
- **Small original-menu text and square/incorrect shadow or alpha effects:** both
  are already open defects below. Native Retina output does not resolve the
  stock UWindow scaling limitation.
- **iOS 15 and iOS 16 requests:** the current binary deliberately targets iOS and
  iPadOS 17 or later. Lowering the deployment target is unproven compatibility
  expansion, not a supported-runtime repair. The reported iOS 16.6.1 launch
  failure is therefore not evidence of a regression on the supported target.
- **Installation and App Store availability:** the unsigned sideloading flow is
  documented. TestFlight, App Store, and website distribution remain separate
  permission, review, privacy, and release-operations work.

## Preview 1 physical-device debt — 2026-08-26

- Keyboard text entry is physically accepted on the 2026-08-27 iPad candidate. Both the attached hardware keyboard and UTP's virtual keyboard edited the real Player Name field, including Delete and printable characters. The accepted implementation must retain the stock `UWindowEditBox` ordering requirement: matching KeyDown, then TextInput, then KeyUp. Controller work must not modify this path.
- Xbox controller hot-connect is physically accepted on the installed `097a630` candidate. Launching with Xbox off, connecting through Bluetooth Settings after reaching the original menu, and returning to UTP produced a real extended profile, automatic touch hiding, working menu control, mode switching, Oblivion movement/look/fire, and pause/resume. The rejected `d10f613` responder-only result remains historical evidence and must not be reintroduced.
- Dismissing **Previous Session Interrupted** with **Not Now** left the host in `.crashed` with the onboarding panel hidden. The next candidate transitions back to the ready landing screen; recovery launch actions remain available on the next app launch.
- A controller active before UTP starts continues to receive the full native analog/gameplay mapping. The responder-only hot-connect fallback has no separate analog-axis or right-stick values, so it cannot provide equivalent gameplay control by itself.
- The first launch-curtain candidate could remain above a running, audible engine until another host interaction reattached SDL. The log proved UT entry completed in under one second while the first attach occurred about twenty seconds later. The current candidate dismisses the curtain synchronously at the entry-result boundary and requires physical acceptance.
- During server package downloads, the original status line can say **Press Escape to begin**, but the host Escape action may appear to do nothing while the connection/download state still owns the screen. The download can continue, but the prompt and response are confusing and require follow-up.

These items are intentionally documented rather than repaired for Preview 1.

The implementation order and physical acceptance gates are maintained in
[`HARDENING_PLAN.md`](HARDENING_PLAN.md). The first isolated follow-up exposes
the existing redacted diagnostic ZIP and GitHub issue reporter directly in the
live three-dot panel; it does not change input behavior.

- The first physical **Export Logs** action stalled the live engine immediately after selection. A bounded follow-up proved the archive completed in 12 ms but presenting a Files picker still froze the engine-owned main loop. The current path writes `UTP-Logs-Latest.zip` directly to the Files-visible UTP Documents folder and uses only the stable in-game panel for confirmation. Physical iPad export and ZIP integrity validation have passed for this path.

- The current physical-iPad candidate builds, signs, installs, and launches as UTP. Its engine log confirms OpenAL/CoreAudio initialization and title/menu music playback at 48 kHz with no buffer-allocation failures; audible level and interruption/route recovery still require user acceptance.
- Controller input is physically accepted both at launch and after connecting through Bluetooth Settings once UTP is running. Configured extended controllers own native input; responder fallback remains containment for the first undiscovered edge and cannot take over gameplay.
- Menu/gameplay input mode and touch visibility are intended to be independent. Menu SELECT/BACK have separate editable placements and physical pointer plus touch/controller trackball share one stock cursor position. A controller-free launch now restores touch as the safe baseline instead of preserving a stale controller-era hidden state. The latest physical iPad SELECT/BACK placements were captured from preferences as the new fresh-install tablet defaults; existing saved layouts still override them.

- Physical iPad gameplay now runs with working audio and usable touch combat, but the original UWindow text remains very small even at the staged v469e maximum GUI scale. FruCoRe also renders some in-game shadows incorrectly. Both are visible defects; neither is treated as fixed by host-side menu improvements.
- Physical iPad menu validation found an affine mismatch between the UIKit touch indicator and the original UWindow cursor: both aligned around the top Options-menu anchor, while UWindow magnified displacement by roughly 2× elsewhere. The current candidate applies the measured inverse transform and requires a fresh physical corner-to-corner/click acceptance pass.
- An earlier candidate did not enumerate the Xbox Wireless Controller. The `GCEventViewController` host and foreground-discovery repairs now deliver native Xbox input and auto-hide touch controls after physical hot-connect.
- The iOS/Xcode target and engine host remain work in progress. The original renderer, audio, offline match flow, touch combat, keyboard entry, Gameplay WASD, captured pointer look/buttons, adjustable pointer speed, and native Xbox controller path now run on the attached physical iPad; fine text readability, shadow fidelity, wheel behavior, and broader lifecycle/performance acceptance remain open.
- The prior GoldenPad rail is superseded. The host now contains a reference-derived UIKit overlay with measured iPad sizing, a dedicated phone adaptation, fixed movement/aim sticks, non-overlapping UT-specific FIRE/ALT/JUMP/DUCK/aim targets, a four-way utility D-pad, original Unreal MENU, separate host menu, and a drag/pinch/reset/live-test editor. Movement and aim explicitly opt into simultaneous recognition; editor gestures remain exclusive. Handedness, hidden actions, acceleration, dead zones, controller auto-hide, and versioned named `.ut99touch` profiles persist. Assistive FIRE and packaged Simulator Movement/Aim actions work against the live engine loop; genuine simultaneous physical thumbs, physical VoiceOver traversal/speech, haptics, reach, editor persistence, and touch-only match completion on hardware remain unproven.
- The app supports both landscape sides, requests a generic landscape geometry only from portrait, declares a modern launch screen, and receives the native 1180×820 iPad Air canvas. SDL/FruCoRe now negotiates a 2360×1640 Retina drawable at 2× and fills the landscape device beneath the overlay. Simulator iteration fixed a fixed-side 180-degree relaunch, but physical rotation, touch-only gameplay, device safe areas, frame pacing, thermals, and memory remain unproven.
- The three-dot importer accepts either a user-owned folder or ZIP archive, validates safe content paths, rejects desktop executables/encrypted entries, supports stored/raw-deflate entries, prepares on a background queue, reports phase/current-file/count progress, and offers cooperative cancellation before its journaled install boundary. Deterministic tests prove cancellation during preparation and streaming hash work preserves the installed manifest/content without debris. A single raw-deflate ZIP entry still uses a one-shot inflater, so cancellation is observed between entries rather than within one large entry. Physical-device Files providers, low-disk behavior, and real cancellation latency remain untested.
- GOTY data is available locally as ignored input and a prepared ignored data pack; the macOS v469e oracle now has reproducible CityIntro/player-possession rendering evidence.
- The official v469e main binary still imports macOS-only frameworks in its original form; the iOS candidate uses build-time path retargeting plus the narrow platform shims documented in the artifact evidence.
- The build-time iOS candidate now replaces SDL2, normalizes Apple framework paths, redirects the audited legacy speech/launch-services imports through distinct narrow shims, and supplies a re-exporting Metal compatibility shim. OpenAL, XMP, mpg123, and libsndfile build for iOS. The iPadOS simulator can invoke the original engine entry; simulator FMOD remains an explicit no-audio shim, while the real-FMOD device candidate now produces audible physical-iPad game audio.
- The complete schema-v2 audit now covers all eight recursively discovered Mach-O images and classifies every imported dependency edge, so G1 static feasibility passes. This does not prove that the transformed image, rebuilt dependencies, or narrow shims execute correctly on physical iOS hardware.
- A trusted physical iPad and development signing path are now available and have been used for repeated in-place builds. Install/launch/PID proof and the hands-on gameplay/audio observations above do not by themselves establish controller, pointer accuracy, lifecycle, thermals, memory pressure, or long-session acceptance.
- First-run game-data acquisition is implemented and passes Simulator UI plus exact-image extraction tests, but a physical 620 MiB download, low-storage behavior, cancellation across network loss/backgrounding, and first-launch map decompression still require device acceptance. The app contains no ISO/game data; permission to enable the direct download in a publicly distributed binary remains separate from technical readiness.
- Native GameController extended-gamepad bindings, UIKit hardware-key forwarding for stock UT99 symbols, captured GameController mouse/trackpad input, and AVAudioSession interruption/route handling are present. Physical audio, Xbox-at-launch/hot-connect gameplay, hardware/host keyboard text, Gameplay WASD, captured pointer look/buttons, adjustable speed, and simultaneous controller input are working. Wheel semantics remain open. A clean opt-in simulator audio run reaches OpenAL, logs UT music playback, and holds at zero sound-buffer allocation failures with all audio sections normalized to 16 effect channels; the default simulator diagnostic remains silent.
- A live public server handshake and stock-map session pass on the simulator. The Metal shim now expands BC1/DXT1 descriptors and uploads to RGBA8, and a current `ut99.weba.ru:7777` session reached map download, login, and possession on `DM-Agear` with the fallback installed. The historically failing `DM-Unreality][` package was not selected in that run, so broad custom-server BC1 compatibility and physical-device behavior remain unproven.
- The original v469e Internet browser now accepts point-accurate logical SDL input in Simulator: `UT Servers` selects, the original table visibly lists 775 servers, and master/server traffic is captured. Browser-selected joining passes, while a separate direct-connect session now proves extended play, respawn, natural map transition, and stock-menu disconnect. Physical finger/device networking, observer-confirmed chat, and one uninterrupted physical G8 run remain open.
- The controller semantic mapping covers shoulder PREV/NEXT weapon actions, Xbox View/Select as the explicit Menu/Gameplay control-mode switch, and Xbox Menu as the original Unreal Escape/menu command. Menu/gameplay switching and core Oblivion control are physically accepted on the current iPad candidate.
- Simulator GUI background/foreground now records the host `resign-active`/`active` callbacks. A final-package iPhone run survived three real Home/reopen cycles in one PID/engine, accepted post-resume FIRE, and continued through a Deck16-to-Codex travel during a 30-minute soak. Physical lifecycle, drawable quiescing, watchdog/OOM behavior, and audio-route recovery still require hardware evidence; the installed `simctl` has no suspend/resume subcommands.
- Persisted recovery markers, Crashed/SafeMode/StoppingEngine state transitions, safe-profile launch, and diagnosable host restoration are implemented and deterministic tests pass. A Simulator forced-termination sequence recovers both normal and safe-mode sessions without a stale active marker. Physical `.ips` reports, watchdog/OOM classification, actual device termination timing, and controlled original-entry return remain unproven.
- Diagnostic export now produces a structurally validated, redacted ZIP through the same code used by the menu; a pulled Simulator archive passed independent CRC/central-directory inspection and included engine stdout plus recovery JSON. The physical `UIActivityViewController` handoff, Files-provider save, and saved-file round trip remain untested.
- The simulator's raw `simctl io screenshot` remains rotated relative to the GUI landscape presentation; the GUI capture is authoritative for visual geometry. The current pass fills the native landscape scene at 2×, but physical-device safe-area, pixel-density, and touch-scale validation remains open.
- A playback-only AVAudioSession experiment was not accepted: the simulator runtime disappeared before timed capture while using the `Jump Desktop Audio` route. The source remains on the stable `.playAndRecord`/`.gameChat` session. The OpenAL aligned-allocation regression is fixed and the 16-effect-channel simulator baseline now has music-engine playback with zero allocation failures, but audible output, sound-effect fidelity, interruption recovery, and route recovery remain open until physical-device testing.
- The final Simulator layout uses the reference's fixed-stick and controller-color hierarchy with UT semantics: separated FIRE/ALT/JUMP/DUCK/aim targets on the aiming side and SCORE/PREV/NEXT/USE as a compact utility D-pad beside movement. The rejected giant analog-trigger mapping for NEXT is gone. Reference names and presets are absent from player settings; players adjust size and opacity directly. Physical reachability, occlusion, preferred sizing, and simultaneous multi-touch remain open.
- The previous narrow-phone control bay was superseded. The accepted physical iPhone 14 gameplay and Menu SELECT/BACK placements are now the fresh-install phone defaults, while the renderer is inset to the live phone safe area plus a four-point edge pad. Existing layouts and the full-bleed iPad path remain unchanged; the adjusted physical-iPhone viewport still requires acceptance.
- FruCoRe presentation-boundary instrumentation now reports produced-frame average FPS, 1% low, frame time, frame count, and actual drawable size. The final-package iPhone Simulator reported 121.88 produced FPS at 10 seconds on 2868×1320 and completed a 30:48 soak; sampled RSS peaked near 429 MiB and later fell near 400 MiB. Simulator VSync is not treated as a hardware refresh cap, the RSS trend is not a general no-leak result, and no physical-device performance, thermal, memory-pressure, or battery claim is made.
