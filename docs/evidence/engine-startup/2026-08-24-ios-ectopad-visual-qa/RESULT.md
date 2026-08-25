# iOS EctoPad visual QA — 2026-08-24

Result: PASS for final-source simulator visual/geometry/package validation; physical touch remains NOT RUN.

## What changed

- Restored EctoPad's exact default composed opacity (`0.82`).
- Gave both fixed sticks stable 42%-diameter inner thumbs.
- Preserved the phone MENU caption despite its short pill height.
- Kept EctoPad's control sizes and hierarchy while opening the iPad UT action arc so FIRE, ALT, JUMP, DUCK, aim, movement, and the utility pad do not intersect.

## Evidence

- `ectopad-vs-ipad-final.png`: combined source/implementation comparison.
- `ectopad-vs-ipad-right-controls.png`: focused action-zone comparison.
- `ipad-final.png`: source-faithful overlap before the final UT spacing correction.
- `ipad-refined.png`: accepted iPad Air 11-inch live gameplay frame.
- `iphone-final-source.png`: accepted iPhone 17 Pro Max live gameplay frame from the same final source.

The accepted iPad scene is 1180×820 UIKit points with a 2360×1640 Metal drawable. The accepted iPhone scene is 956×440 UIKit points with a 2868×1320 Metal drawable.

## Verification

- `make test` — PASS.
- `make ios-engine-sim-package` — PASS.
- `make ios-engine-package` — PASS; ad-hoc/stub-FMOD iPhoneOS package verified.
- `make ios-engine-real-package` — PASS; ad-hoc/real-FMOD iPhoneOS package verified.
- Sequential Simulator inspection — PASS on iPad Air 11-inch (M4) and iPhone 17 Pro Max, one runtime at a time.

Remaining physical-only checks: finger reach, simultaneous move/look/fire, haptics, safe areas on real displays, audible output, sustained frame pacing, and touch-only bot-match completion.
