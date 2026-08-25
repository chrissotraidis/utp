# UT combat-hierarchy touch refinement — 2026-08-24

**Classification: PASS for simulator visual, geometry, semantic-pulse, and package regression; PARTIAL for touch because no physical iPhone/iPad is attached.**

## Audit scope

The bounded surface was the live UT99 gameplay overlay on an iPad Air 11-inch and iPhone 17 Pro Max Simulator. The user goal was to make the controls read as a deliberate FPS touch interface while retaining GoldenPad's large move/look zones and UT99's distinct actions.

## Captured flow

1. **Equal-weight labeled rail — poor.** `01-live-before.png` shows seven nearly identical text circles. FIRE has too little visual priority, PREV/NEXT read as detached coins, and the action path has no clear thumb home.
2. **Combat hierarchy — pass.** `05-ipad-final-idle.png` shows one dominant crosshair trigger, smaller ALT/USE/JUMP/DUCK satellites, and a joined previous/next weapon switcher. SCORE, Unreal MENU, and the host menu remain separate utilities.
3. **Live activation — pass.** `06-ipad-final-fire-activated.png` shows the same control layer after assistive activation entered first-person play. `accessibility-fire-pulse.log` records ordered `primaryFire pressed=true` and `pressed=false` edges.
4. **Compact phone layout — pass.** `04-iphone-hierarchy.png` preserves the same hierarchy at 874×402 points, clears the Dynamic Island, and has no intersecting action frames.

## Implementation

- Replaced live gameplay words with one SF Symbol per action; accessibility labels and hints retain the complete semantic names.
- Increased the default GoldenPad-profile opacity from 0.72 to 0.84 for map-independent readability while keeping Compact and High Visibility alternatives.
- Made FIRE the dominant target, arranged ALT/USE/JUMP/DUCK as a thumb arc, and grouped PREV/NEXT in one translucent segmented weapon rail.
- Kept GoldenPad-derived invisible movement/look regions, press-only semantic color, haptics, normalized drag/resize persistence, safe-area fitting, and the original SDL event bindings.
- Added a synchronous accessibility activation pulse because the original SDL entry owns the main thread during gameplay; the pulse cannot strand a held action.

## Verification

- `make test` — PASS, including collision-free High Visibility × 135% tablet and phone geometry.
- `make ios-engine-sim-package` — PASS.
- One iPad Air 11-inch Simulator run produced the accepted iPad captures and entered live first-person play through the FIRE control.
- The iPad runtime was shut down before one iPhone 17 Pro Max Simulator run produced the accepted phone capture.
- `make ios-engine-package` — PASS.
- `make ios-engine-real-package` — PASS.
- No physical-device result is claimed. Finger occlusion, simultaneous multi-touch, reach, haptic feel, VoiceOver traversal, and hardware safe-area behavior remain physical-test items.
