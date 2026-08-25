# iPad regression after phone layout policy

## Result

**PASS — simulator regression only.** The final simulator package, including the phone-specific compact-bay changes, was installed fresh on an iPad Air 11-inch (M4) simulator. The original v469e engine entered `DM-Deck16][`, the iPad retained its full-height 4:3 gameplay canvas, and the colored UT rail remained in the right-side bay without clipping.

## Evidence

- `ipad-air-gameplay.png` — raw `simctl` screenshot.
- `UT99-engine.stdout` — same-run engine stdout with original engine startup and main-loop evidence.

The raw exporter is rotated relative to the Simulator GUI landscape presentation; this is simulator pixel evidence, not a physical-device pass.
