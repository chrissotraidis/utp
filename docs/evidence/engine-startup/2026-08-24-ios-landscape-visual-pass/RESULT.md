# iPad landscape visual pass — 2026-08-24

## Hypothesis

When the iPad simulator is actually rotated to landscape, the host scene
should present the native 4:3 Unreal frame at full usable width and keep the
GoldenPad-derived UT controls aligned to the same landscape canvas.

## Experiment

Built the current simulator package and launched exactly one iPad Air 11-inch
(M4) simulator with `-UT99AutoStart -UT99AutoMatch`. The Simulator GUI Rotate
control was used to move from the initial portrait device presentation to
landscape. The live GUI frame was saved as `landscape-gui-pass.png`; the raw
`simctl io screenshot` is retained separately as
`landscape-gameplay-touch-rail.png` because that exporter rotates the image
relative to the GUI presentation.

## Result

**PASS for simulator landscape composition / PARTIAL for physical-device
framing.** The GUI capture shows the full 4:3 Deck16 scene filling the intended
landscape game surface, with the fixed host three-dot button at the right edge,
the separate original Unreal `MENU` control beneath it, and the UT-specific
ALT/FIRE/USE/JUMP/DUCK/PREV/NEXT rail positioned over the same scene. The
renderer installed the BC1 fallback and entered the original engine. Simulator
accessibility/coordinate clicks are not physical-touch evidence and did not
replace a hardware input pass.

Evidence: `landscape-gui-pass.png`, `landscape-gameplay-touch-rail.png`,
`system.log`, and `engine.stdout`.
