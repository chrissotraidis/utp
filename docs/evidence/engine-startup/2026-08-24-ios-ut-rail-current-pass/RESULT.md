# iOS UT touch rail current visual pass

## Result

**PASS — simulator visual iteration only.** A fresh iPad Air 11-inch (M4) simulator install launched the embedded original v469e engine into `DM-Deck16][` and captured the current default GoldenPad-derived UT rail. The game surface remains a native 4:3 canvas on the left with a dedicated black control bay on the right. The default GoldenPad profile now uses 0.86 overlay opacity so the semantic action colors remain readable without using the high-visibility profile.

## Evidence

- `ut99-default-opacity-gameplay.png` — raw `simctl` screenshot from the fresh install.
- `UT99-engine.stdout` — engine stdout copied from the same app container; the latest run contains player possession, `USDLViewport::ResizeViewport(1024, 768)`, `Frucore: Using BGRA8 frame buffer`, and `Entering main loop.`

## Scope and limits

- The current rail is visibly closer to the supplied UT reference: orange FIRE, teal ALT, green USE/JUMP, gold DUCK, and blue PREV/NEXT faces are readable at rest.
- The screenshot exporter is rotated relative to the Simulator GUI landscape presentation; this is raw pixel evidence, not a physical-device screenshot.
- Touch accuracy, safe-area placement, backing-scale behavior, frame timing, audio, controller input, and complete touch-only match completion remain unproven without physical hardware.
