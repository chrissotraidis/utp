# iPhone landscape composition pass

## Result

**PASS — simulator layout/engine composition only.** A fresh iPhone 17 simulator install launched the original v469e engine into `DM-Deck16][`. The phone-specific layout reserves a compact right-side control bay, fits the gameplay canvas to 4:3 within the remaining width, and keeps the UT rail visible without clipping FIRE, ALT, USE, JUMP, DUCK, PREV, or NEXT. SCORE is moved toward the upper game edge so it does not sit behind the host hamburger.

## Evidence

- `iphone17-gameplay-phone-bay-score-fixed-landscape.png` — rotated presentation of the raw `simctl` screenshot for visual inspection.
- `iphone17-gameplay-phone-bay-score-fixed.png` — original raw `simctl` screenshot.
- `UT99-engine.stdout` — same-run engine stdout; latest entries include `Entering main loop` and the phone’s `426×320` SDL logical viewport after the compact 4:3 fit.

## Implementation

- Phone-like scenes below 600 points on their long edge reserve a 34%/170-point control bay and reduce the 4:3 game frame height accordingly.
- UIKit SDL framing, Apple graphics-profile viewport negotiation, and GoldenPad action placements share the same phone policy.
- Auto-start now waits for the actual landscape scene orientation before entering the original engine.

## Limits

This is simulator evidence. Physical iPhone safe-area, touch accuracy, performance, audio, controller, and lifecycle validation remain open. The raw `simctl` exporter includes simulator status chrome and is not physical-device evidence.
