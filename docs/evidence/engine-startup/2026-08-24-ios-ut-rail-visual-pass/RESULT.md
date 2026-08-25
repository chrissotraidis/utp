# UT action-rail visual pass

## Result

The simulator build now presents the UT-specific rail with larger, readable targets and persistent semantic colors: orange `FIRE`, teal `ALT`, green `USE`/`JUMP`, gold `DUCK`, and blue `PREV`/`NEXT`. `SCORE` and the original-Unreal `MENU` remain neutral utility controls. The live engine reached the ready-signals Deck16 scene and the screenshot was captured before cleanup.

This is a simulator visual pass, not touch-completion evidence. The Simulator `simctl` exporter writes the landscape frame with rotated image metadata; the saved PNG is retained as raw evidence and the prior GUI capture remains authoritative for orientation and window geometry.

## Verification

- `make ios-engine-sim-package` — passed.
- One iPad Air 11-inch (M4) simulator used; no concurrent simulator remained.
- Launch: `-UT99AutoStart -UT99AutoMatch`.
- Screenshot: `ut99-ut-rail-sim.png`.
- Physical finger interaction and safe-area sizing remain unproven.
