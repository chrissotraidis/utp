# Decisions

## 2026-08-23 — Preserve the official v469e binary as an ignored reference input

- **Context:** The PRD requires the official OldUnreal v469e Apple Silicon build as the primary feasibility foundation.
- **Options:** Commit the DMG, download it to an ignored reference path, or proceed without it.
- **Decision:** Download `OldUnreal-UTPatch469e-macOS.dmg` into `ref/OldUnreal/`, hash it, and never commit it or generated app contents.
- **Evidence:** SHA-256 `b6b3a1f462e4b702df0eecf90d663ef1f847cc36aadca1ec6dd35278d091fa0d`; `docs/evidence/engine-startup/2026-08-23-g1-audit/`.
- **Reversal condition:** Use a newer official v469e artifact only after recording its release URL and hash.

## 2026-08-23 — Stop at evidence-backed feasibility work before UI fabrication

- **Context:** The repository has no GoldenPad reference, app target, game data, or physical device evidence.
- **Decision:** Implement the doctor, single-runtime guard, and deterministic Mach-O audit first; do not claim an iOS shell, engine startup, renderer, or gameplay gate.
- **Evidence:** `make doctor` reports no GoldenPad, no game data, and no physical device; audit shows desktop framework imports.
- **Reversal condition:** Required references, data, and device access become available and G1 remains viable.

## 2026-08-23 — Treat the iOS-platform artifact as diagnostic until desktop imports are removed

- **Context:** The official SDL2 source provides a native iOS shared library with the audited SDL ABI, and the v469e executable can be transformed and ad-hoc signed at build time.
- **Decision:** Add `make sdl2-shared-ios` and `make ios-engine-artifact`, but classify the output as diagnostic-only while Cocoa, ApplicationServices, and CoreServices remain in its load graph. Do not claim G3 from Mach-O metadata or simulator behavior.
- **Evidence:** `docs/evidence/engine-startup/2026-08-23-ios-artifact/RESULT.md`; `build/ios-engine/report.json`.
- **Reversal condition:** A clean artifact with no unsupported desktop dependencies loads as an Xcode-embedded, signed image and reaches original engine startup on physical iOS hardware.

## 2026-08-23 — Keep FMOD as an explicit no-audio diagnostic shim

- **Context:** The v469e main image has strong FMOD imports, but the available input is proprietary and a production-legal iOS FMOD path is not present.
- **Decision:** Build a symbol-complete `libfmod.dylib` only to test the complete dyld dependency graph under a no-audio startup profile. Mark every artifact using it as diagnostic-only and do not use it for G6, gameplay, or release claims.
- **Evidence:** `Sources/UT99Runtime/UT99FMODShim.c`; `docs/evidence/engine-startup/2026-08-23-ios-artifact/RESULT.md`.
- **Reversal condition:** A legally usable, behaviorally compatible iOS audio implementation replaces the stub and passes physical-device audio evidence.

## 2026-08-23 — Keep the GoldenPad overlay semantic and UT-bound

- **Context:** GoldenPad supplies the iPad normalized layout and visual control language, while UT99 uses different gameplay actions and default bindings.
- **Decision:** Keep GoldenPad's normalized tablet placement, tinted translucent circular faces, bright rings, live movement guide, and transparent move/look hit zones; map the controls to the shipped UT99 `User.ini` bindings through SDL events rather than copying GoldenPad's unrelated game vocabulary.
- **Evidence:** `Sources/UT99Host/GoldenPadTouchOverlay.swift`; `Sources/UT99Host/UT99EngineBridge.swift`; `docs/evidence/engine-startup/2026-08-23-ios-sim-stub/ut99-engine-touch-overlay-final.png`; `touch-smoke.log`.
- **Reversal condition:** A physical-device comparison or user-provided GoldenPad baseline demonstrates a specific placement/visual mismatch.

## 2026-08-23 — Diagnostic smoke input is not touch completion

- **Context:** The simulator package has no supported `simctl` touch-injection operation, and no physical iPhone/iPad is attached.
- **Decision:** Add `-UT99TouchSmokeTest` only as a diagnostic path that drives the same semantic bridge into the live SDL engine loop, including button and analog events. Classify it as bridge evidence, not a touch-only bot-match pass.
- **Evidence:** `docs/evidence/engine-startup/2026-08-23-ios-sim-stub/touch-smoke.log`; engine log reaches `Entering main loop` in the same run.
- **Reversal condition:** Replace the diagnostic result with a recorded physical touch-only bot match or an authoritative simulator UI-injection trace.

## 2026-08-23 — Match GoldenPad idle/pressed action-face states exactly

- **Context:** The initial UT adaptation color-filled every idle action button, while the pristine GoldenPad reference uses a neutral black translucent face at rest and applies each semantic tint only while pressed.
- **Decision:** Keep UT99's additional actions and labels, but use GoldenPad's black idle face (`black.opacity(0.46)`), white idle title, and per-action tint only during the pressed state. Preserve the reference normalized tablet geometry and hidden-at-rest movement/look guides.
- **Evidence:** `Sources/UT99Host/GoldenPadTouchOverlay.swift`; `docs/evidence/engine-startup/2026-08-23-ios-sim-stub/ut99-goldenpad-black-idle-landscape.png`; `goldenpad-black-idle-touch-smoke.log`.
- **Reversal condition:** A physical-device comparison or updated GoldenPad reference demonstrates a platform-specific readability or touch-target regression.

## 2026-08-23 — Reassert host input ownership after SDL window creation

- **Context:** SDL creates a secondary UIKit window for the original renderer. A simulator run showed the GoldenPad controls in the correct visual layer, but the host menu and action buttons did not receive injected taps after SDL's later window attachment.
- **Decision:** Keep SDL's window render-only and, on every attachment, resign its key status, reassert the host window and overlay as interactive, bring the overlay/menu to the front, and make the host key and visible. This preserves the original renderer while giving UIKit controls a deterministic input owner.
- **Evidence:** `Sources/UT99Host/GameViewController.swift`; `docs/evidence/engine-startup/2026-08-23-ios-sim-stub/ut99-window-ownership-fire-landscape.png`; `window-ownership-fire-engine.stdout`.
- **Reversal condition:** Physical-device or lifecycle testing demonstrates that forcing host key ownership breaks SDL keyboard, mouse, controller, or external-display input.

## 2026-08-23 — Forward hardware keyboard events through the host

- **Context:** SDL's UIKit renderer window is intentionally render-only so GoldenPad and the host menu retain touch ownership. That means iPad hardware-key events cannot depend on SDL's normal responder chain.
- **Decision:** Make the host controller first-responder-capable and translate the stock UT99 hardware-key set (movement, action, function, arrow, Escape, and Tab keys) into the existing SDL keyboard event bridge, releasing keys on UIKit end/cancel callbacks.
- **Evidence:** `Sources/UT99Host/GameViewController.swift`; `Sources/UT99Host/UT99EngineBridge.swift`; `docs/evidence/engine-startup/2026-08-23-ios-sim-stub/keyboard-bridge-engine.stdout`; device packages passed verification.
- **Reversal condition:** Physical iPad testing shows a specific key-repeat, keyboard dismissal, or SDL text-input regression; Simulator keyboard injection alone is not sufficient to reverse the design.

## 2026-08-23 — Forward iPad pointer hover as relative UT99 look input

- **Context:** SDL's UIKit window remains render-only so the host owns GoldenPad and menu interaction. Hardware keyboard forwarding is hosted by UIKit, but trackpad/mouse hover movement would otherwise have no input owner.
- **Decision:** Add a non-cancelling `UIHoverGestureRecognizer` to the GoldenPad host overlay and translate pointer deltas into the existing SDL relative mouse-motion event. Keep touch pan look independent; defer mouse-button mapping until physical hardware evidence identifies the correct UIKit event path.
- **Evidence:** `Sources/UT99Host/GoldenPadTouchOverlay.swift`; `Sources/UT99Host/UT99EngineBridge.swift`; `docs/evidence/engine-startup/2026-08-23-ios-sim-stub/ut99-pointer-bridge.png`; device packages passed verification.
- **Reversal condition:** Physical iPad testing shows pointer movement conflicts with touch gestures, pointer acceleration is unusable, or the OS delivers a better native mouse event path.

## 2026-08-23 — Present the legacy SDL Metal surface at iPad backing scale

- **Context:** The original engine's iOS fullscreen negotiation publishes a 512x384 point resize even after the host scene is 1024x768 points, leaving gameplay undersized in the upper-left of the iPad Simulator.
- **Decision:** Keep the renderer's native 2x `CAMetalLayer` drawable, make the SDL Metal view flexible, and present the legacy point surface with the iPad backing-scale transform. Reconcile the SDL window/root view with the active host scene during UIKit layout so the GoldenPad overlay and original 4:3 frame share one landscape canvas.
- **Evidence:** `ref/SDL2/src/video/uikit/SDL_uikitmetalview.m`; `ref/SDL2/src/video/uikit/SDL_uikitviewcontroller.m`; `docs/evidence/engine-startup/2026-08-23-ios-sim-stub/ut99-render-layout-fix-simulator-window.jpeg`; `render-layout-fix-landscape-engine.stdout`; simulator and device packages verified.
- **Reversal condition:** Physical iPad testing shows clipped content, incorrect drawable scale, or a device-specific scene layout where the transform should be derived from the live view-to-host ratio instead of the native backing scale.

## 2026-08-23 — Preserve controller D-pad movement and neutralize analog takeover

- **Context:** The extended-gamepad callback treated left-stick and D-pad changes as the same event, then always read the left-stick axes. Controller disconnect/takeover also released digital movement without explicitly neutralizing relative look.
- **Decision:** Read the changed controller element, use D-pad axes when the D-pad is active, apply a small dead zone, and publish neutral look on disconnect or touch-overlay takeover. Keep the existing UT99 semantic action bindings.
- **Evidence:** `Sources/UT99Host/GameViewController.swift`; `docs/evidence/engine-startup/2026-08-23-ios-sim-stub/controller-neutrality-engine.stdout`; simulator and both device-target packages passed verification.
- **Reversal condition:** Physical controller testing shows the dead zone or D-pad precedence suppresses intended diagonal movement, or a controller-specific profile requires separate mappings.

## 2026-08-23 — Expand remote BC1 textures at the Metal boundary

- **Context:** A custom public-server package previously reached the iOS simulator renderer as `MTLPixelFormatBC1_RGBA` (format 130) and aborted even though the Apple graphics profile disabled new S3TC selection.
- **Decision:** Install a narrow runtime hook in the re-exporting Metal shim. Only BC1 texture descriptors are redirected to RGBA8, and only uploads for textures created through that path are expanded from DXT1 blocks; all other Metal formats and calls remain unchanged.
- **Evidence:** `Sources/UT99Runtime/UT99MetalShim.m`; `Sources/UT99Host/UT99EngineBridge.swift`; `docs/evidence/engine-startup/2026-08-23-ios-sim-stub/bc1-fallback-system.log`; `bc1-remote-engine.stdout`; simulator and both device-target packages passed verification.
- **Reversal condition:** A physical Apple GPU or a controlled server package shows incorrect alpha/color decoding, upload corruption, or a performance regression; the old custom `DM-Unreality][` content still needs a targeted retest.

## 2026-08-23 — Add a persistent GoldenPad-style touch layout editor

- **Context:** The host had UT-specific GoldenPad placements and profile scaling, but no way to move or resize controls as required by the reference UX.
- **Decision:** Add an explicit host-menu editor mode. Action faces and the move/look zones are draggable and pinch-resizable, normalized placements are persisted in `UserDefaults`, and a reset action restores the reference iPad defaults. The editor is disabled as a gameplay input source until DONE commits the layout.
- **Evidence:** `Sources/UT99Host/GoldenPadTouchOverlay.swift`; `Sources/UT99Host/GameViewController.swift`; `docs/evidence/engine-startup/2026-08-23-ios-sim-stub/layout-editor-engine.stdout`; simulator and both device-target packages passed verification.
- **Reversal condition:** Manual iPad testing shows gesture conflicts, controls cannot be recovered, or persisted positions create unsafe-area clipping; the command-line smoke does not replace manual drag/resize evidence.

## 2026-08-23 — Preserve host menu panels during SDL window reassertion

- **Context:** SDL can attach or reorder its UIKit renderer window after a host menu is opened. The host reassertion pass initially hid every non-renderer subview, which included the newly created menu panel; the panel had a valid frame but was visually absent.
- **Decision:** Exclude the active host menu from renderer cleanup, force layout before logging/interaction, and bring the menu above the render-only touch surface after SDL attachment. Keep SDL render-only and the host window key.
- **Evidence:** `Sources/UT99Host/GameViewController.swift`; `docs/evidence/engine-startup/2026-08-23-ios-sim-stub/touch-menu-editor-final.png`; `touch-menu-editor-final-system.log`.
- **Reversal condition:** Physical-device scene management requires a different ownership policy or introduces clipping/interaction conflicts.

## 2026-08-23 — Make host settings explicit about live versus next-start effects

- **Context:** The expanded host menu exposed Controls, Graphics, and Audio but initially only reported status.
- **Decision:** Persist look sensitivity and Y inversion as immediate input preferences consumed by the touch-look bridge. Persist safe-texture compatibility and engine-audio enablement as next-start preferences because the original renderer/audio initialization occurs inside the engine entry; expose audio-route reactivation separately.
- **Evidence:** `Sources/UT99Host/GameViewController.swift`; `Sources/UT99Host/UT99EngineBridge.swift`; `docs/evidence/engine-startup/2026-08-23-ios-sim-stub/settings-menu-validation-system.log`.
- **Reversal condition:** Manual iPad testing shows the action-sheet settings are insufficient for discoverability or the next-start boundaries need a full restart workflow.

## 2026-08-23 — Separate the original Unreal game menu from the host menu

- **Context:** The first touch implementation hid the pause action and used the three-dot host button as the only menu surface, conflating engine and host responsibilities.
- **Decision:** Keep the fixed three-dot button for host settings/import/diagnostics. Expose a distinct `MENU` touch action that sends Escape through the original SDL keyboard path, matching Unreal's own in-game menu behavior. Controller Menu remains a host-menu entry point until physical controller UX is validated.
- **Evidence:** `Sources/UT99Host/GoldenPadTouchOverlay.swift`; `Sources/UT99Host/UT99EngineBridge.swift`; `docs/evidence/engine-startup/2026-08-23-ios-sim-stub/unreal-menu-split-pass.png`; `unreal-menu-split-system.log`.
- **Reversal condition:** Physical controller or touch testing shows that the two surfaces conflict, cannot both be reached safely, or the original engine uses a different menu binding on the supported v469e data set.

## 2026-08-24 — Complete the controller weapon/menu semantic routes

- **Context:** The touch rail already exposed UT-specific PREV/NEXT actions, but the extended-gamepad path had no shoulder weapon mapping and no distinct route to the original Unreal game menu.
- **Decision:** Map left/right shoulders to PREV/NEXT weapon, map the optional controller Options button to the same Escape-backed original Unreal menu semantic as touch `MENU`, and retain the controller Menu button for the host three-dot menu.
- **Evidence:** `Sources/UT99Host/GameViewController.swift`; `docs/evidence/engine-startup/2026-08-24-ios-sim-input-pass/`; both iOS device packages rebuilt and verified.
- **Reversal condition:** Physical controller testing shows a platform-specific button convention or a conflict between the host and original game-menu routes.

## 2026-08-24 — Use a high-visibility UT action rail while retaining GoldenPad geometry

- **Context:** The first UT adaptation copied GoldenPad's low-contrast neutral idle faces. In the user-provided iPad capture, the UT rail is larger, semantically color-coded, and readable at rest; Unreal's FIRE/ALT/JUMP/USE/DUCK/weapon actions also need to be distinguishable without the GoldenEye-style legend.
- **Decision:** Keep the GoldenPad-derived circular geometry, normalized placement, white ring/title treatment, and pressed event semantics, but use UT action colors at rest and increase the action diameter baseline from 70 to 86 points. Keep SCORE and MENU as smaller neutral utility controls.
- **Evidence:** `docs/evidence/engine-startup/2026-08-24-ios-ut-rail-visual-pass/ut99-ut-rail-sim.png`; simulator screenshot shows larger orange FIRE, teal ALT, green USE/JUMP, gold DUCK, and blue PREV/NEXT controls over a live Deck16 match.
- **Reversal condition:** Physical-device testing shows the larger targets obscure the 4:3 gameplay view, violate safe areas, or reduce touch accuracy; tune per-device rather than reverting to unreadable neutral faces.

## 2026-08-24 — Preserve native 4:3 UT render while reserving the touch bay

- **Context:** The iOS boundary was negotiating legacy 512×384 and desktop-oriented 1280×800 modes, producing a cropped or stretched game surface instead of the reference composition.
- **Decision:** Derive a screen-fitting 4:3 SDL mode from the Apple display, publish the aspect-preserved renderer root on the left side of the scene, leave the right side available for the GoldenPad-derived UT rail, and remove the legacy Metal view transform that applied a second geometry adjustment.
- **Evidence:** `docs/evidence/engine-startup/2026-08-24-ios-native-viewport-pass/`; latest simulator stdout publishes 1024×768 and the raw capture shows the 4:3 game canvas plus right-side control bay. Both device-target packages rebuilt and verified.
- **Reversal condition:** Physical iPad/iPhone testing demonstrates safe-area clipping, incorrect backing-scale behavior, unacceptable performance, or a better per-device layout strategy.

## 2026-08-24 — Make the default UT rail readable without forcing high-visibility mode

- **Context:** A fresh simulator capture showed that the persisted Compact profile compounded its opacity with the colored button fills, making the action rail visibly weaker than the supplied UT reference.
- **Decision:** Keep the GoldenPad, Compact, and High visibility profiles, but raise their default overlay opacities to 0.86, 0.74, and 1.0 respectively. Preserve the user’s explicit persisted opacity and keep the semantic rail geometry unchanged.
- **Evidence:** `docs/evidence/engine-startup/2026-08-24-ios-ut-rail-current-pass/ut99-default-opacity-gameplay.png`; the fresh-install simulator capture shows readable colored idle faces over a live Deck16 scene.
- **Reversal condition:** Physical hardware demonstrates that the default opacity reduces gameplay visibility or touch hit feedback; tune per-device while retaining the explicit profile controls.

## 2026-08-24 — Reserve a compact control bay on narrow iPhone landscapes

- **Context:** The iPhone simulator reports a much narrower logical landscape scene than the iPad. A full-height 4:3 canvas left only a 54-point remainder, clipping the UT rail and placing SCORE behind the host menu.
- **Decision:** For phone-like scenes below 600 points on the long edge, reserve a compact 34%/170-point control bay, fit a centered-height 4:3 gameplay frame into the remaining width, move SCORE toward the upper game edge, and require the actual landscape scene orientation before auto-starting the engine. Keep the iPad full-height policy unchanged.
- **Evidence:** `docs/evidence/engine-startup/2026-08-24-ios-iphone-landscape-pass/iphone17-gameplay-phone-bay-score-fixed-landscape.png`; the fresh simulator run shows the original Deck16 scene and all primary UT actions visible without clipping.
- **Reversal condition:** Physical iPhone testing shows the compact game frame is too small for play, safe-area insets invalidate the 170-point bay, or touch reachability requires a different phone preset.

## 2026-08-24 — Supersede control bays with native full-bleed Retina rendering

- **Context:** Direct Simulator inspection showed that the 4:3 island and separate black control bay did not match GoldenPad's actual composition and made UT appear detached from the controls. A second defect initialized FruCoRe from a pre-Metal 1180×820 fallback while the iPad CAMetalLayer was 2360×1640, so the renderer occupied only the upper-left quarter of the drawable. The menu smoke also persisted Compact mode after testing.
- **Decision:** Supersede the 4:3/tablet and compact-phone bay decisions. Use the complete landscape scene for the original renderer and composite touch controls above it. Declare a modern launch screen, force SDL's iOS window onto the HiDPI path, return pixel dimensions from the pre-view Metal drawable query, and maintain a 2× drawable during every layout. Match GoldenPad's live scale and neutral idle/pressed-tint treatment; restore the prior profile after menu smoke.
- **Evidence:** `docs/evidence/engine-startup/2026-08-24-ios-fullbleed-ui-pass/`; SDL reports 1180×820 points, 2360×1640 pixels, and 2× mouse scale while the Simulator GUI shows full-device Deck16 rendering beneath the UT controls.
- **Reversal condition:** Physical iPad/iPhone evidence shows FruCoRe cannot sustain native Retina resolution, widescreen projection is materially incorrect, or safe-area/touch reachability requires a device-specific inset—not a detached black control bay.

## 2026-08-24 — Use dedicated collision-free geometry on landscape phones

- **Context:** Native 874×402 iPhone rendering was correct, but applying the 820-point-tall iPad action proportions made ALT/FIRE/JUMP intersect, crowded the lower action arc, and put Unreal `MENU` beneath the host settings button.
- **Decision:** Keep the renderer full-bleed and preserve GoldenPad's neutral circular visual language. Below 500 landscape points, use a measured three-action primary stack, a separate four-action bottom rail, compact transparent move/look regions, and utility positions derived from UIKit safe-area insets. Clamp phone profile scaling so Compact through High Visibility remain non-overlapping.
- **Evidence:** `docs/evidence/engine-startup/2026-08-24-ios-iphone-fullbleed-ui-pass/`; the iPhone 17 true-landscape frame shows distinct controls at 874×402 while the subsequent iPad regression remains full-bleed at 1180×820.
- **Reversal condition:** Physical reach testing shows the phone targets are too small or the rail is uncomfortable; adjust phone geometry and profile bounds without restoring a detached control bay.

## 2026-08-24 — Limit OpenAL's legacy aligned-allocation fallback to macOS

- **Context:** The first audio-enabled simulator baseline produced 280 `alGenBuffers ... Out of Memory` records, starting on the first allocation. OpenAL Soft's pre-macOS-10.13 fallback checked only `MAC_OS_X_VERSION_MIN_REQUIRED`; iOS headers also define that macro with a legacy value, causing ordinary low-alignment allocations to reach `posix_memalign` and fail.
- **Decision:** Do not apply the allocator fix inside the OpenAL reference checkout. Copy the pinned source into generated build storage, apply a recorded patch that adds `TargetConditionals.h` and requires `TARGET_OS_OSX` for the fallback, and write the device output to the same `build/ios-engine/deps` directory Xcode embeds. Assert the source guard and aligned-allocation symbol disposition in `make test`.
- **Evidence:** `third_party/patches/openal-soft-ios-aligned-allocation.patch`; `tools/build_ios_dependencies.sh`; `Tests/test_openal_ios_patch.sh`; `docs/evidence/engine-startup/2026-08-24-ios-openal-buffer-pass/`.
- **Reversal condition:** Upstream OpenAL removes the broad Apple guard, a newer pinned release makes the patch inapplicable, or physical-device testing shows an allocator/runtime incompatibility.

## 2026-08-24 — Measure FruCoRe at the Metal presentation boundary

- **Context:** The Graphics panel labeled changes to the host shell's `MTKView.preferredFramesPerSecond` as an engine frame cap, but FruCoRe renders through SDL's separate Metal window. That control neither measured nor paced the actual game renderer.
- **Decision:** Remove the host frame-cap claim and swizzle the concrete Metal command-buffer class used by FruCoRe to record bounded `presentDrawable:` intervals and drawable dimensions. Expose average FPS, 1% low FPS, average frame time, frame count, and drawable size in Graphics/Diagnostics. Persist FruCoRe `UseVSync` as a next-start preference, defaulting on, while treating simulator pacing as non-authoritative.
- **Evidence:** `Sources/UT99Runtime/UT99MetalShim.m`; `Sources/UT99Host/UT99EngineBridge.swift`; `Sources/UT99Host/GameViewController.swift`; `Tests/test_metal_performance_metrics.sh`; `docs/evidence/engine-startup/2026-08-24-ios-metal-performance-pass/`.
- **Reversal condition:** Physical Apple GPU evidence shows the command-buffer hook misses presentations, materially perturbs frame pacing, or a supported renderer-native telemetry API provides a safer equivalent.

## 2026-08-24 — Journal user-data replacement and make engine state explicit

- **Context:** The importer completed staging before copying, but then replaced live files individually. A failure during that merge could leave a mixed old/new data set despite the UI's transactional claim. The host also allowed manual/direct-connect paths to invoke the original entry again after it was already running.
- **Decision:** Copy the complete last-known-good content and manifest to a transaction backup, atomically publish a committing/installed phase journal, replace only user content, and recover committing journals before bundled runtime preparation. Verify installed manifests with streaming SHA-256 reads. Track the PRD host states, reject start/connect while StartingEngine/Running/PausedBySystem, and remove the host panel before SDL's first frame.
- **Evidence:** `Sources/UT99Host/UT99DataImportTransaction.swift`; `Sources/UT99Host/GameViewController.swift`; `Tests/DataImportTransactionTests.swift`; `docs/evidence/engine-startup/2026-08-24-ios-data-transaction-pass/`.
- **Reversal condition:** Physical low-storage/interruption tests show backup copying is too expensive or filesystem coordination requires an app-container-specific transaction strategy; preserve rollback semantics when replacing the mechanism.

## 2026-08-24 — Cancel only before the journaled import commit

- **Context:** Folder discovery, ZIP extraction, copies, and SHA-256 hashing ran synchronously in the document-picker callback. Large GOTY packs could freeze UIKit, provided no current-file feedback, and could not be cancelled despite PRD 12.3.
- **Decision:** Move preparation to one dedicated serial import queue and expose a modal phase/current-file/count progress card. Honor cooperative cancellation during discovery, between ZIP entries/copies, and between 1 MiB hash chunks. Use an atomic token transition so cancellation and commit cannot both win. Treat the transition to `installing` as a hard cancellation boundary: disable Cancel and allow the backup/journal transaction to complete or recover so cancellation can never publish a mixed data set.
- **Evidence:** `Sources/UT99Host/UT99DataImporter.swift`; `Sources/UT99Host/UT99ZipArchive.swift`; `Sources/UT99Host/GameViewController.swift`; `Tests/DataImportTransactionTests.swift`; `docs/evidence/engine-startup/2026-08-24-ios-import-progress-pass/`.
- **Reversal condition:** Physical Files-provider or storage-pressure tests show cooperative cancellation latency is unacceptable; replace copy/inflate primitives with chunked equivalents while preserving the same pre-commit boundary and rollback guarantees.

## 2026-08-24 — Use custom circular material controls for the UT action vocabulary

- **Context:** A direct SF-symbol `UIButton.Configuration` pass rendered as chunky rounded tiles, while the subsequent literal text-only GoldenPad circles looked like debug labels once UT's nine actions were visible together. GoldenPad's circular, translucent, thumb-oriented behavior remained the correct interaction basis, but copying its sparse face treatment did not provide enough hierarchy for Unreal's FIRE/ALT/JUMP/USE/DUCK/weapon/menu vocabulary.
- **Decision:** Keep GoldenPad's circular hit targets, translucent idle state, press-only semantic color, large invisible move/look zones, and tablet thumb arc. Render each action with a custom clipped `UIButton` subclass containing ultra-thin dark material, an inset semantic ring, a dominant SF Symbol, and a restrained caption. Do not use `UIButton.Configuration`, shadows, or tile backgrounds. Fit the complete action group against safe areas and minimum gaps, with a dedicated compact landscape-phone rail and a visible MOVE guide during editor input release.
- **Evidence:** `Sources/UT99Host/GoldenPadTouchOverlay.swift`; `Sources/UT99Host/UT99TouchLayoutGeometry.swift`; `Tests/TouchLayoutGeometryTests.swift`; `docs/evidence/engine-startup/2026-08-24-ios-touch-refinement-pass/`; all simulator and both device-target packages rebuilt and verified sequentially.
- **Reversal condition:** Physical iPad/iPhone testing shows blur/material cost, poor contrast, unreachable actions, multi-touch cancellation, or insufficient target size; tune material density, glyph scale, or per-device placement while preserving circular controls and collision guarantees.

## 2026-08-24 — Discover and classify every stock native image recursively

- **Context:** The initial G1 evidence fully described the main executable but treated `UCC`, the six bundled dylibs, and possible package-native code as an inventory follow-up. Filename-only scans could also miss an executable image without a conventional extension.
- **Decision:** Identify Mach-O files recursively under the pristine app with `file(1)`, audit every ARM64 slice into one deterministic schema-v2 JSON report, and infer native package requirements from `Default.ini` configured classes and `EditPackages`. Classify dependencies per importing image: desktop AppKit/IOKit/ForceFeedback edges owned by the replaced SDL2 image are optional-driver edges eliminated with that complete replacement, while the same frameworks remain narrow-shim requirements if imported elsewhere. Do not weaken unknown or fatal classifications to obtain a pass.
- **Evidence:** `tools/write_audit_json.py`; `tools/inspect_macho.sh`; `Tests/test_complete_macho_audit.sh`; `docs/evidence/engine-startup/2026-08-24-g1-complete-native-audit/`.
- **Reversal condition:** A stock-loaded path reveals another native image, a dependency lacks the recorded disposition, or physical-device loading disproves the build-time no-JIT feasibility conclusion; add the image/edge and reevaluate G1.

## 2026-08-24 — Supersede the material badge treatment with GoldenPad's live action face

- **Context:** The blur/inset-ring/glyph-plus-caption pass removed rounded tiles but still rendered every action as a multi-layer badge. A fresh live iPad capture showed nine competing decorated marks, while GoldenPad's actual `MomentaryAction` uses a single translucent circle, one hairline, and one centered label.
- **Decision:** Match that live-face construction directly in UIKit: 46%-black idle fill, 34%-white one-point outline, one centered rounded bold mark, and semantic action color only while pressed. Use one UT label for the seven gameplay actions; reserve icon-only treatment for the SCORE and original-Unreal MENU utilities. Restore GoldenPad's 0.72 default overlay opacity and tighten the tablet action arc without changing semantic bindings or invisible move/look zones.
- **Evidence:** `ref/GoldenPad/Sources/TouchControlsView.swift`; `Sources/UT99Host/GoldenPadTouchOverlay.swift`; `Tests/TouchLayoutGeometryTests.swift`; `docs/evidence/engine-startup/2026-08-24-ios-touch-minimal-pass/`.
- **Reversal condition:** Physical play shows insufficient contrast, labels obscured by fingers, or poor reach; tune opacity, mark scale, and per-device placement while preserving the single-layer face and touch semantics.

## 2026-08-24 — Give UT's GoldenPad-derived controls a combat hierarchy

- **Context:** The source-faithful single-word circles were visually quieter than the rejected badge pass, but a fresh same-map comparison still showed seven equal-weight coins. FIRE had no dominant thumb target, weapon changes were detached, and the result read as a debug overlay rather than a finished FPS interface.
- **Decision:** Retain GoldenPad's translucent circular hit targets, invisible move/look zones, normalized editor, press-only semantic color, and SDL bindings. Use icon-only live faces with full accessibility labels; make FIRE the dominant target; arc ALT/USE/JUMP/DUCK around it; and group PREV/NEXT in one translucent segmented weapon rail. Raise the default profile opacity to 0.84 for map-independent readability. Emit accessibility activation as a synchronous down/up pair because the original SDL main loop owns the main thread and cannot service a delayed main-queue release.
- **Evidence:** `Sources/UT99Host/GoldenPadTouchOverlay.swift`; `Sources/UT99Host/UT99TouchLayoutGeometry.swift`; `Tests/TouchLayoutGeometryTests.swift`; `docs/evidence/engine-startup/2026-08-24-ios-touch-hierarchy-pass/`.
- **Reversal condition:** Physical finger reach, occlusion, simultaneous-touch, VoiceOver, or haptic testing shows the icon vocabulary or thumb arc is unclear; adjust symbols and per-device geometry while preserving semantic bindings and collision guarantees.

## 2026-08-24 — Persist engine ownership before entry and recover through a safe profile

- **Context:** The PRD named Crashed, SafeMode, and StoppingEngine states, but the host did not persist engine ownership across process death, distinguish an interrupted session at next launch, or restore a diagnosable surface when the original entry returned.
- **Decision:** Atomically create a redacted active-session marker before original entry, update it with host state, and archive/remove it only on controlled return, explicit failure, or next-launch recovery. Offer safe mode after interruption with safe textures and VSync enabled and audio disabled. Preserve failed/clean markers in diagnostics and include their JSON records in the exported ZIP. Treat Simulator process termination as recovery-path evidence, not a physical crash classification.
- **Evidence:** `Sources/UT99Host/UT99RuntimeRecovery.swift`; `Sources/UT99Host/GameViewController.swift`; `Sources/UT99Host/UT99EngineBridge.swift`; `Tests/RuntimeRecoveryTests.swift`; `docs/evidence/engine-startup/2026-08-24-ios-crash-recovery-pass/`.
- **Reversal condition:** Physical crash/watchdog/OOM evidence requires a different marker lifetime, iOS background termination makes a clean callback misleading, or controlled engine returns expose unsafe UIKit restoration; preserve diagnosability and explicit state transitions when changing the mechanism.

## 2026-08-24 — Make diagnostic export independently verifiable and redacted

- **Context:** The host menu wrote a stored ZIP through private controller code and immediately presented a share sheet. The prior Simulator session could not prove that the resulting archive was structurally valid or that exported logs met the PRD redaction requirement.
- **Decision:** Move stored-ZIP construction into a Foundation-only component with preflight path/duplicate/size validation and deterministic headers. Route the menu and `-UT99DiagnosticsExportSmokeTest` through the same archive assembly, include redacted full logs, installed manifest when present, recovery JSON, host/runtime metadata, and the embedded engine SHA-256. Redact home paths and common secret fields and warn users to review server addresses before sharing.
- **Evidence:** `Sources/UT99Host/UT99DiagnosticsArchive.swift`; `Tests/DiagnosticsArchiveTests.swift`; `Tests/test_diagnostics_archive.sh`; `docs/evidence/engine-startup/2026-08-24-ios-diagnostics-export-pass/`. The app-generated ZIP passes `unzip -t` after being pulled from the Simulator container.
- **Reversal condition:** Physical Files/share-sheet testing exposes provider incompatibility, export size becomes unbounded, or additional sensitive fields are observed; preserve archive validation and test coverage while adapting transport, bounds, or redaction rules.

## 2026-08-24 — Persist UT-specific touch tuning and test both handedness layouts live

- **Context:** The icon-only hierarchy pass improved spacing but remained too faint and ambiguous in true Simulator frames. PRD 19.4 also required more than opacity and scale: handedness, dead zones, hidden controls, and a live test path were missing. The first left-handed phone live-test frame then showed MENU hidden under the editor banner.
- **Decision:** Keep GoldenPad's circular thumb targets and invisible move/look hit regions, but give UT actions a semantic glyph plus compact rounded caption, translucent gradient fill, action-colored edge, dominant FIRE size, and press feedback. Persist left-handed mirroring, hidden actions, look acceleration, look/movement dead zones, and controller auto-hide in one sanitized configuration. Keep live-test controls active, reveal MOVE/LOOK affordances without opaque panels, center the banner/DONE strip, and move SCORE below it only while a layout mode is active. Share mirror geometry with deterministic right/left tests.
- **Evidence:** `Sources/UT99Host/GoldenPadTouchOverlay.swift`; `Sources/UT99Host/UT99TouchConfiguration.swift`; `Sources/UT99Host/UT99TouchLayoutGeometry.swift`; `Tests/TouchConfigurationTests.swift`; `Tests/TouchLayoutGeometryTests.swift`; `docs/evidence/engine-startup/2026-08-24-ios-touch-configuration-pass/`.
- **Reversal condition:** Physical reach, simultaneous-touch, contrast, haptic, or accessibility testing shows the hierarchy is unclear or a mirrored control is unreachable; tune role styling and per-device geometry while retaining semantic bindings, persistence sanitization, and collision tests.

## 2026-08-24 — Support either landscape side without re-forcing an active scene

- **Context:** Reinstalling the phone app while the Simulator shell was already landscape exposed a 180-degree mismatch. Scene activation always requested `landscapeRight`, even when the physical simulated device was on the other landscape side.
- **Decision:** Declare/support both landscape orientations, request the generic landscape mask only when the scene is portrait, and use the manifest-consistent landscape-left orientation as the initial presentation preference. Do not force a new side each time the scene becomes active.
- **Evidence:** `Sources/UT99Host/Info.plist`; `Sources/UT99Host/SceneDelegate.swift`; `Sources/UT99Host/GameViewController.swift`; `docs/evidence/engine-startup/2026-08-24-ios-touch-configuration-pass/iphone-left-handed-live-test-refined-upright.jpeg`; `iphone-left-handed-persisted-refined.jpeg`; phone runtime logs report full 956×440 / 2868×1320 presentation after relaunch.
- **Reversal condition:** Physical rotation testing shows iOS needs a different scene-geometry strategy; preserve both-side support and never introduce a fixed-side 180-degree relaunch.

## 2026-08-24 — Decouple touch hit targets from their visual faces and version named layouts

- **Context:** Caption-heavy action circles remained visually blocky even after their geometry and behavior were correct. Users also needed a durable way to preserve and exchange tuned layouts without exposing arbitrary defaults data.
- **Decision:** Keep the proven GoldenPad-derived circular hit bounds, thumb geometry, SDL bindings, and accessibility labels, but render a smaller inset icon-only face so the interface reads as touch affordances instead of labeled debug controls. Persist named layouts in a bounded schema-v1 `.ut99touch` JSON document containing sanitized configuration and normalized placements. Reject unknown versions, actions, presets, oversized input, non-finite values, and more than twelve local profiles. Hide gameplay controls while the host menu is open.
- **Evidence:** `Sources/UT99Host/GoldenPadTouchOverlay.swift`; `Sources/UT99Host/UT99TouchProfileStore.swift`; `Sources/UT99Host/GameViewController.swift`; `Tests/TouchProfileStoreTests.swift`; `docs/evidence/engine-startup/2026-08-24-ios-icon-touch-profile-pass/`.
- **Reversal condition:** Physical play shows the inset faces are too small to identify or the invisible margin causes misleading activation; adjust face inset independently of the hit bounds while retaining validation, accessibility semantics, and collision guarantees.

## 2026-08-24 — Replace GoldenPad with EctoPad as the touch baseline

- **Context:** Repeated GoldenPad-derived iterations produced a detached UT action rail, equal-weight debug controls, or decorative badges that did not behave or read like a finished mobile game. The user supplied EctoPad as the new baseline. Its pristine `SunPadGameOverlay.mm` has an explicit iPad hierarchy, device-aware phone layout, fixed movement/camera sticks, solid controller-color faces, a four-way D-pad, and a separate START tier.
- **Decision:** Supersede all prior GoldenPad default-layout and face-treatment decisions. Measure EctoPad at commit `461de17f549d98742bc3b2d031156f79ab3eaa9d`; preserve its placement, size hierarchy, colors, fixed-stick feedback, white rim, and two-thumb interaction. Adapt its archetypes to UT99 semantics: A→FIRE, B→ALT, X→JUMP, Y→DUCK, D-pad→SCORE/USE/PREV/NEXT, START→original Unreal menu. Keep the separate sliders control for the host menu. Retain `GoldenPadTouchOverlay` and the legacy `goldenPad` profile name only for source/profile compatibility.
- **Evidence:** `docs/REFERENCE_ECTOPAD.md`; `Sources/UT99Host/GoldenPadTouchOverlay.swift`; `Sources/UT99Host/UT99TouchLayoutGeometry.swift`; `Tests/TouchLayoutGeometryTests.swift`; `docs/evidence/engine-startup/2026-08-24-ios-ectopad-baseline/`.
- **Reversal condition:** A newer pinned EctoPad implementation or physical-device testing demonstrates a specific reach, occlusion, safe-area, contrast, or multi-touch failure. Tune per device while retaining EctoPad as the visual/interaction source unless the owner explicitly changes the baseline again.

## 2026-08-24 — Keep menu accessibility synchronous while SDL owns the main loop

- **Context:** The original engine's SDL main loop executes on the app main thread. Delayed main-queue accessibility releases and the stock host-menu activation path were not serviced during a live Simulator run, even though custom touch-action accessibility activation worked.
- **Decision:** Keep action accessibility as a synchronous down/up pair and give the host-menu button a synchronous `accessibilityActivate` path. Continue using ordinary UIKit touch targets for physical interaction; classify accessibility activation as bridge/assistive evidence rather than physical finger proof.
- **Evidence:** `Sources/UT99Host/GameViewController.swift`; `Sources/UT99Host/GoldenPadTouchOverlay.swift`; `docs/evidence/engine-startup/2026-08-24-ios-ectopad-baseline/commands.txt`; the live host-menu log reports `mainThread=true`.
- **Reversal condition:** Moving the engine off the main thread becomes safe, SDL's event pump changes, or physical/VoiceOver testing reveals duplicated or missed activations; preserve ordered input edges and menu reachability when changing the mechanism.

## 2026-08-24 — Make physical-device readiness explicit and fail before mutation

- **Context:** G2 requires a physical iPad, but the doctor report mixed the host Mac and simulators into one device listing, still named GoldenPad as the UI reference, and did not disclose whether code signing could succeed. The repository had verified ad-hoc iPhoneOS packages but no single command that safely provisioned, installed, and launched one on attached hardware.
- **Decision:** Use CoreDevice's structured JSON interface to count only physical iOS/iPadOS devices. Report signing identity and configured-team counts without printing identity or device details. Add guarded `device-check`, `device-build`, `device-install`, and `device-run` commands that require exactly one selected device and an explicitly supplied development team, clean project runtimes before building, use Xcode automatic provisioning, verify the real-FMOD package, and install/launch through `devicectl`. Launch the host by default; require `UT99_DEVICE_AUTOSTART=1` for automated engine/match arguments.
- **Evidence:** `tools/doctor.sh`; `tools/run_ios_device.sh`; `Tests/test_doctor_report.sh`; `Tests/test_device_readiness.sh`; `docs/evidence/ios-shell/2026-08-24-device-readiness/`.
- **Reversal condition:** Physical installation shows CoreDevice identifier selection or automatic provisioning is unreliable; preserve the preflight, single-runtime enforcement, no-secret reporting, and explicit opt-in while adapting the signed build/install transport.

## 2026-08-24 — Prove the host's own Metal surface before engine ownership

- **Context:** G2 requires the native host shell to present a Metal surface before loading UT. The host had an `MTKView`, but its `draw(in:)` delegate was empty; visible Simulator evidence came from FruCoRe after engine startup and could not prove the independent host requirement.
- **Decision:** Submit and present one bounded host-owned Metal command buffer after the view has appeared, record completion status and native drawable size, and include that artifact in diagnostic exports. Add an aggregate `-UT99G2SmokeTest` that runs transactional import, applies the EctoPad default, waits for completed Metal presentation, exports diagnostics, and writes a final marker only when every component passes. Keep physical promotion manual: automated collection is `AUTOMATED_PARTIAL` until direct touch/menu, Files picker, share sheet, and screenshot checks pass on hardware.
- **Evidence:** `Sources/UT99Host/GameViewController.swift`; `tools/verify_ios_device.sh`; `Tests/test_device_gate_script.sh`; `docs/evidence/ios-shell/2026-08-24-g2-metal-smoke/`.
- **Reversal condition:** Physical hardware shows the transparent host clear conflicts with FruCoRe ownership, command-buffer completion is unreliable during scene activation, or CoreDevice cannot pull app-container artifacts; retain independent host-Metal proof and final all-components marker while adapting timing or collection.

## 2026-08-24 — Translate EctoPad hierarchy into UT actions instead of controller names

- **Context:** A literal pass mapped EctoPad's wide analog R trigger to UT's binary NEXT-weapon command and exposed `EctoPad` as a preset name. The resulting giant NEXT button and implementation-facing terminology were visibly wrong despite matching source geometry.
- **Decision:** Keep EctoPad as the internal source of proportions, colors, fixed sticks, and face hierarchy, but map UT's four low-frequency utilities to the four-direction pad: SCORE up, PREV left, NEXT right, and USE down. Reserve the right hand for FIRE, ALT, JUMP, DUCK, and look; keep original Unreal MENU above that cluster. Present the default preset as `Standard`. Use the reference 40-point ellipsis with UIKit's native hierarchical menu for touch and a compact dark native action-sheet mirror for controller/VoiceOver activation. Give phone settings a full-height right panel shifted clear of the host ellipsis.
- **Evidence:** `Sources/UT99Host/GoldenPadTouchOverlay.swift`; `Sources/UT99Host/UT99TouchLayoutGeometry.swift`; `Sources/UT99Host/GameViewController.swift`; `Tests/TouchLayoutGeometryTests.swift`; `design-qa.md`; `docs/evidence/engine-startup/2026-08-24-ios-ectopad-menu-redesign/`.
- **Reversal condition:** Physical thumb reach, occlusion, multi-touch, VoiceOver, or menu behavior reveals a specific failure; tune per-device placement or accessibility presentation while preserving user-facing UT semantics and the EctoPad interaction hierarchy.

## 2026-08-24 — Link zlib explicitly and avoid pipefail/SIGPIPE in IPA verification

- **Context:** The mocked packaging test passed, but the first real diagnostic iPhoneOS archive failed to link `_inflate*` from `UT99ZipInflate.c`. After adding zlib, archive verification exited 141 because `grep -q` closed a live `unzip -Z1` pipeline under `pipefail`.
- **Decision:** Link `-lz` in both app configurations. Materialize the IPA member list once, then run all archive membership checks against that file so successful early matches cannot SIGPIPE the producer.
- **Evidence:** `UT99Apple.xcodeproj/project.pbxproj`; `tools/package_local_ipa.sh`; `Tests/test_local_ipa_packaging.sh`; `build/local-package/manifest-diagnostic.json`.
- **Reversal condition:** The project moves to a framework-based zlib dependency or a different archive tool; preserve explicit device-target linkage, no-game-data verification, deterministic hashes, and a non-installable diagnostic classification when no team is configured.

## 2026-08-24 — Treat Simulator execution as a dependency-verification requirement

- **Context:** Static package verification accepted a transformed real-FMOD image whose dependency was rewritten from macOS's versioned `AudioUnit.framework` path to an unversioned `AudioUnit.framework` path. The iOS 26.5 Simulator could not load that runtime image and presented a black host-only surface, even though the package had passed signing/platform checks.
- **Options:** Keep the real-FMOD package as build-only; use the diagnostic FMOD stub exclusively; or map FMOD's AudioUnit imports to the iOS AudioToolbox runtime and make the verifier reject the invalid dependency.
- **Decision:** Map the legacy AudioUnit dependency to `/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox` for both Simulator and iPhoneOS transformations. Reject the unavailable `AudioUnit.framework/AudioUnit` path and reject non-stub AudioUnit imports without AudioToolbox during package verification. Keep physical audio quality as an open hardware gate.
- **Evidence:** Repaired Simulator host state reaches `Running`; `docs/evidence/engine-startup/2026-08-24-ios-ectopad-menu-redesign/18-current-source-real-fmod-running.png`; strengthened `tools/verify_ios_package.sh`; rebuilt iPhoneOS package.
- **Reversal condition:** Replace the transformed macOS FMOD image with a native supported iOS audio implementation or prove a different dependency surface on the minimum supported iOS runtime.

## 2026-08-24 — Expose every documented stable developer command

- **Context:** The PRD promised `bootstrap`, `mac-baseline`, `mac-hosted-harness`, and `diagnostics`, but the Makefile did not expose them, preventing a clean-checkout reproduction claim.
- **Decision:** Add deterministic, pinned implementations and a command-surface smoke test. Bootstrap verifies/downloads only recorded public inputs under ignored `ref/`; mac-baseline verifies the official DMG before preparing the ignored oracle; diagnostics writes a bounded ZIP under ignored `build/`.
- **Evidence:** `make bootstrap`, `make mac-baseline`, `make diagnostics`, and `Tests/test_stable_commands.sh` pass on 2026-08-24.
- **Reversal condition:** Internal scripts may change, but the stable Make targets and pinned-input behavior remain contractual.

## 2026-08-24 — Keep implementation references and presets out of player settings

- **Context:** Renaming the leaked `EctoPad` preset to `Standard` did not solve the underlying problem: the settings still exposed an implementation-oriented preset model, duplicated the independent size slider, and remained visually entangled with active gameplay buttons underneath the panel.
- **Decision:** Remove the preset selector and preset submenu from player UI. Keep legacy profile identifiers only in the versioned import/migration boundary. Present direct player controls for opacity, size, handedness, and controller auto-hide, use Arrange/Save/Restore language, and hide gameplay controls while settings own interaction.
- **Evidence:** `Sources/UT99Host/GameViewController.swift`; `Sources/UT99Host/UT99TouchProfileStore.swift`; `Tests/test_host_state_and_data_menu.sh`; `design-qa.md`; `docs/evidence/engine-startup/2026-08-24-ios-control-settings-copy-fix/`.
- **Reversal condition:** Physical usability testing demonstrates that named player presets materially improve onboarding; any future presets must use player outcomes rather than reference-project or implementation names and must not duplicate direct controls.

## 2026-08-24 — Make runtime-data embedding idempotent and reject nested packs

- **Context:** Rebuilding into an existing Xcode product directory with `cp -R build/UT99Data <app>/UT99Data` changed semantics once the destination existed and created `<app>/UT99Data/UT99Data`. The prior verifier checked native images and signatures but did not reject this malformed duplicate tree.
- **Decision:** Create the destination explicitly and merge `build/UT99Data/.` into it for every device and Simulator package target. Reject `UT99Data/UT99Data` in `verify_ios_package.sh` so repeated builds cannot silently ship nested runtime data.
- **Evidence:** `Makefile`; `tools/verify_ios_package.sh`; `Tests/test_local_ipa_packaging.sh`; rebuilt real-FMOD iPhoneOS and Simulator packages both pass verification.
- **Reversal condition:** Runtime data moves to an asset catalog, on-demand resource, or external import-only model; preserve idempotent assembly and an explicit malformed-layout rejection.

## 2026-08-24 — Generate patched SDL from a pristine pinned checkout

- **Context:** The first independent clean-checkout test failed because five required SDL/UIKit changes existed only as edits inside ignored `ref/SDL2`. That made the working build impossible to reproduce from tracked source and violated the rule that references remain unmodified.
- **Decision:** Store the complete SDL delta in `third_party/patches/sdl2-ut99-ios.patch`. Require the exact pinned, clean SDL commit; copy it to ignored `build/sources/SDL2-UT99`; apply the tracked patch there; stamp its SHA-256; and build every SDL device/Simulator target from that generated copy. Reject dirty or unexpected reference checkouts and quarantine stale generated copies outside the repository before regeneration.
- **Evidence:** `tools/prepare_sdl2_source.sh`; `third_party/patches/sdl2-ut99-ios.patch`; `Tests/test_ios_build_path.sh`; `docs/evidence/reproducibility/2026-08-24-clean-checkout/RESULT.md`.
- **Reversal condition:** SDL is replaced or the changes are accepted upstream; preserve exact source pinning, a pristine reference checkout, deterministic transformation, and clean-checkout package reproduction.
