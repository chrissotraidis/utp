# EctoPad touch-baseline pass

- **Gate:** G7 touch UX, partial simulator evidence
- **Build commit:** working tree based on `65b00668ff963d2e0a98679e1c8611ba30d80169`
- **Reference:** EctoPad `461de17f549d98742bc3b2d031156f79ab3eaa9d`
- **Destinations:** iPad Air 11-inch (M4), iPhone 17 Pro Max, iOS 26.5 Simulator; one runtime at a time
- **Classification:** PARTIAL

## Result

The previous GoldenPad-derived control rail is superseded. The active default is measured from EctoPad's `SunPadGameOverlay.mm` and preserves its two-thumb hierarchy: fixed dark movement stick, fixed yellow aim stick, dominant green primary action, red secondary action, compact light jump/crouch actions, four-way utility D-pad, and separate START/menu tier.

The UT semantic mapping is A→FIRE, B→ALT, X→JUMP, Y→DUCK, D-pad up/down/left/right→SCORE/USE/PREV/NEXT, and START→the original Unreal menu. The sliders button remains the native host menu.

Deterministic geometry tests pass for all eleven controls on iPad, iPhone, and mirrored southpaw layouts. `make test` passes. The full transformed-engine Simulator package, diagnostic device package, and real-FMOD device package build and verify sequentially. In the running iPhone engine, assistive FIRE activation emitted an ordered down/up pair through the live SDL bridge, and the host-menu accessibility path opened the real host panel synchronously on the main thread while the original SDL loop was active.

## What is visibly proven

- Native full-bleed 2360×1640 iPad rendering with the measured EctoPad-derived overlay.
- Native full-bleed 2868×1320 iPhone rendering; the Simulator-window capture is upright and clears the Dynamic Island.
- No detached black control bay.
- Coherent two-hand placement and reference-derived size hierarchy.
- Host menu opens above the running renderer and hides gameplay controls.
- The final rebuilt simulator package is installed and left running on the sole booted iPhone destination.

## What remains unproven

- Genuine physical finger events, simultaneous multi-touch, reach, haptics, and touch-only bot-match completion.
- Physical iPhone/iPad safe areas, orientation transitions, performance, and thermal behavior.
- Controller, keyboard, mouse-button, and audio-route behavior on hardware.

## Evidence

- `00-ectopad-reference.jpg` — pristine visual reference.
- `00-ut99-before.png` — rejected pre-EctoPad baseline supplied by the user.
- `02-ipad-measured-landscape.png` — 2360×1640 measured iPad pass.
- `06-iphone-live-upright.jpeg` — live transformed-engine iPhone pass.
- `07-iphone-host-menu.jpeg` — host menu open above the live game.
- `08-iphone-final-running-landscape.png` — final rebuilt package running at the native 2868×1320 landscape target.
- `09-reference-vs-ipad.png` — same-state visual comparison of the EctoPad source hierarchy and measured UT99 iPad adaptation.
- `commands.txt` — build/test/runtime commands and decisive log lines.

## Next decision

Keep EctoPad as the active baseline. Validate physical touch delivery as soon as an iPad or iPhone is attached; do not promote G7 from this Simulator/AX evidence.
