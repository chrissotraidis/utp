# iOS touch configuration and refinement pass

Date: 2026-08-24

## Result

PASS for simulator visual layout, persistence, orientation, deterministic geometry, and package construction. Physical touch behavior remains NOT RUN because no iPhone or iPad is attached.

The GoldenPad-derived overlay now presents UT actions as translucent circular controls with both a semantic SF Symbol and a compact rounded caption. FIRE is the dominant orange-accented target; ALT, USE, JUMP, and DUCK form a lower-thumb arc; PREV/NEXT share one segmented rail. The prior faint icon-only iteration is superseded.

Touch configuration persists handedness, per-action visibility, look acceleration, look and movement dead zones, and controller-triggered auto-hide. Live-test mode leaves gameplay controls active, shows MOVE/LOOK affordances without opaque debug panels, and places its banner/DONE strip clear of MENU in either handedness preset.

The iPhone pass exposed and fixed two defects:

- the left-handed MENU control was hidden under the live-test banner;
- forcing `landscapeRight` during every scene activation could rotate an already-landscape app 180 degrees inside the Simulator shell.

The host now accepts either landscape side for geometry updates and uses the manifest's landscape-left orientation as the initial presentation preference. A true-landscape iPhone relaunch stayed upright and retained the left-handed preset with SCORE and DUCK hidden while correctly dropping transient test guides.

## Visual evidence

- `ipad-left-handed-live-test-before-refinement.jpeg`: saved baseline showing the faint icon-only controls and large test-zone panels.
- `ipad-default-refined.jpeg`: accepted 965×756 Simulator GUI capture of the default right-handed iPad layout over full-bleed gameplay.
- `ipad-left-handed-persisted-refined.jpeg`: accepted persisted left-handed iPad layout with SCORE/DUCK hidden.
- `iphone-left-handed-live-test-before-banner-fix.jpeg`: baseline exposing the banner/MENU collision.
- `iphone-left-handed-live-test-refined-upright.jpeg`: accepted 956×539 true-landscape live-test capture after banner and orientation fixes.
- `iphone-left-handed-persisted-refined.jpeg`: accepted normal-mode relaunch with left-handed settings retained and test guides absent.

The Simulator GUI capture is authoritative. Raw `simctl io screenshot` remains orientation-ambiguous for these landscape devices.

## Runtime evidence

- iPad: SDL/FruCoRe used 1180×820 points, a 2360×1640 Metal drawable, and 2× mouse scale.
- iPhone 17 Pro Max: SDL/FruCoRe used 956×440 points, a 2868×1320 Metal drawable, and 3× mouse scale.
- Both devices reached the original entry, SDL viewport, Metal presentation, and original engine main loop.
- Only one simulator was booted at a time; final runtime check reports zero booted simulators.
- `iphone-engine.stdout`, `iphone-engine-highlights.txt`, and `iphone-system.log` preserve the phone runtime transcript.

## Automated verification

`make test` passes, including:

- touch configuration persistence, clamping, dead-zone, acceleration, and invert-Y tests;
- current refined target sizes on iPad and iPhone;
- right- and left-handed mirror geometry;
- High Visibility × 135% collision and safe-area fitting.

Fitted geometry multipliers:

- iPad right/left: 0.997;
- iPhone right/left: 0.952.

Package verification passes for:

- simulator diagnostic package;
- iPhoneOS stub-FMOD diagnostic package;
- iPhoneOS real-FMOD package.

App executable SHA-256 values:

- simulator: `10da32c9bebe5eb284cefff53cf8a88b16360926c3fbce738342c1cf6ddbf502`;
- iPhoneOS stub-FMOD: `d6a5cdcffd9bff4ff8b58c3fddb7518b621c5bc71f9c00cb1fe524971f397425`;
- iPhoneOS real-FMOD: `f7874ebc702795590642206bb98b1b5c7ea5de52a8119e46a0caabd3a3f104fb`.

## Remaining gates

- physical multi-touch, reach, haptics, safe areas, orientation, and drag/pinch persistence;
- named user profiles and profile import/export;
- optional gyroscope aiming;
- physical controller auto-hide and hardware input/audio/renderer gates.

`ref/GoldenPad` remains pristine at `54474a40e93b77259d10c7594919e6a05f5e276d`. The existing local `ref/OpenAL-Soft/al/buffer.cpp` change predates this pass and was not modified.
