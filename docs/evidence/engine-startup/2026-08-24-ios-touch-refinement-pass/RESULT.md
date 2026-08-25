# iOS touch refinement pass

## Result

PASS for Simulator visual composition, adaptive geometry, and package verification; physical touch remains OPEN.

The rejected rounded-tile and text-only debug-face iterations were superseded by a custom circular touch component. Each action now uses a clipped ultra-thin dark material face, inset semantic ring, dominant action glyph, restrained micro-label, light haptic, and subtle press scale. Semantic color becomes the pressed fill instead of turning the idle HUD into a panel grid. No `UIButton.Configuration`, shadow, or rounded-rectangle background remains in the gameplay rail.

The iPad default uses a deliberate right-thumb arc with FIRE as the largest action, ALT/JUMP as primary neighbors, USE inside the arc, and DUCK/PREV/NEXT along the lower rail. The iPhone path uses its own safe-area-aware stack and bottom rail. The shared geometry solver kept High Visibility × 135% collision-free on the 1180×820 iPad and 874×402 phone reference canvases. Editor mode shows the safe area, move stick, look region, actions, and non-conflicting DONE chrome; an input release no longer hides MOVE while editing.

## Accepted visual evidence

- `ipad-material-default-gameplay.png`: iPad Air 11-inch (M4), true landscape, GoldenPad default at 100%, live original Deck16 renderer.
- `ipad-material-layout-editor.png`: same simulator and material controls with safe-area/MOVE/LOOK editor affordances visible.
- `iphone-material-default-gameplay.png`: iPhone 17 Pro Max, true landscape, compact rail clearing the simulated Dynamic Island.
- `ipad-high-visibility-135-stress.png`: collision stress from the geometry pass; its text-only face iteration is superseded visually by the accepted material captures.

All images are Simulator Save Screen output. They are not photographs or physical-device evidence.

## Verification

- `make test`: PASS, including iPad and iPhone High Visibility × 135% geometry checks.
- `make ios-engine-sim-package`: PASS.
- `make ios-engine-package`: PASS (ad-hoc device target with diagnostic FMOD stub).
- `make ios-engine-real-package`: PASS (ad-hoc device target with real local FMOD input).
- One simulator runtime was active at a time and all runtimes were shut down after capture.
- `ref/GoldenPad` remained pristine; the pre-existing `ref/OpenAL-Soft/al/buffer.cpp` modification was not changed.

## Limits

No physical iPhone/iPad was attached. Multi-touch coexistence, target reach, haptics, manual drag/pinch persistence, long-session ergonomics, and hardware performance remain unproven and do not advance G2/G3/G5/G6/G7/G9.
