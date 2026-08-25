# Native-resolution full-bleed UI pass — 2026-08-24

**PASS — iPad simulator renderer resolution and GoldenPad-derived UI composition.**

The prior 4:3 island/control-bay policy was rejected after direct comparison with the supplied screenshot and the pristine GoldenPad implementation. The app now declares a modern launch screen, receives the iPad Air 11-inch native 1180×820 landscape canvas, publishes that full scene to v469e, and forces the SDL Metal window onto its Retina path before FruCoRe's first drawable-size query.

Runtime evidence records:

- UIKit/SDL point viewport: **1180×820**
- Metal pixel drawable: **2360×1640**
- mouse/pixel scale: **2.0×**
- original `DM-Deck16][` game engine initialized and entered its main loop
- full-device rendering with the touch UI over the game rather than in a black bay

The touch layer now uses GoldenPad's actual canvas scale, neutral black idle faces, thin white rings, press-only semantic tint, and paired Unreal MENU / slider-style host settings controls. UT-specific FIRE, ALT, USE, JUMP, DUCK, PREV, NEXT, and SCORE semantics remain intact. The menu smoke also restores the prior user profile instead of leaving Compact mode persisted.

Evidence:

- [`ipad-fullbleed-native-landscape-gui.jpeg`](ipad-fullbleed-native-landscape-gui.jpeg) — authoritative Simulator GUI geometry
- [`UT99-engine.stdout`](UT99-engine.stdout) — renderer dimensions and original main loop
- [`UnrealTournament.log`](UnrealTournament.log) — original engine log

This proves simulator resolution/composition. Physical-device frame pacing, safe areas, thermals, and finger-only play remain open.
