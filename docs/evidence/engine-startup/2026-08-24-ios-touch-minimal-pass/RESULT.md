# GoldenPad live-face touch refinement — 2026-08-24

**Classification: PASS for simulator visual/geometry regression and device-target packaging; PARTIAL for touch because no physical iPhone/iPad is attached.**

## Visual audit

1. **Current material controls — poor:** `00-current-before.png` shows each action combining an outer border, colored inset ring, SF Symbol, and micro-label. The repeated decoration makes the rail look like a set of badges and weakens the primary/secondary hierarchy.
2. **GoldenPad source comparison — source of truth:** `ref/GoldenPad/Sources/TouchControlsView.swift` implements the live `MomentaryAction` as one black translucent circle, one thin white outline, one centered label, and color only while pressed.
3. **iPad revised gameplay — pass:** `02-ipad-minimal-true-landscape.jpeg` shows the full-bleed original Deck16 renderer with a quiet right-thumb stack and separated lower rail. SCORE, original-Unreal MENU, and the host menu remain distinct.
4. **iPhone revised gameplay — pass:** `04-iphone-minimal-true-landscape.jpeg` shows the compact rail with no intersections and clear Dynamic Island/safe-area separation.

Screenshot-only limits: contrast under every map palette, finger occlusion, reach, simultaneous touches, haptic feel, and VoiceOver order require physical interaction testing.

## Implementation

- Removed blur, inset semantic rings, and glyph-plus-caption stacking.
- Live face now uses GoldenPad's 46%-black idle fill, 34%-white hairline, one centered semantic mark, and press-only action tint.
- FIRE/ALT/JUMP/USE/DUCK/PREV/NEXT use one centered UT label; SCORE and MENU use one centered utility symbol.
- GoldenPad default opacity is 0.72; Compact is 0.58 and High Visibility is 0.92.
- Tablet ALT/FIRE/JUMP and lower actions form a tighter thumb arc. Geometry fitting keeps High Visibility × 135% collision-free on the 1180×820 iPad and 874×402 iPhone reference canvases.

## Verification

- `make test` — PASS.
- `make ios-engine-sim-package` — PASS.
- One iPad Air 11-inch Simulator runtime launched the original `DM-Deck16][` path and produced the accepted iPad capture.
- The iPad runtime was shut down before one iPhone 17 Pro Max Simulator runtime produced the accepted phone capture.
- `make ios-engine-package` — PASS; nested iPhoneOS images verify.
- `make ios-engine-real-package` — PASS; real-FMOD iPhoneOS candidate verifies.
- No physical hardware result is claimed.
