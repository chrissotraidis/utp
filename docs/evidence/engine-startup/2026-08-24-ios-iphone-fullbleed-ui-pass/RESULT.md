# iPhone full-bleed control-layout pass — 2026-08-24

**PASS — simulator resolution and non-overlapping phone/tablet control geometry.**

The full-bleed renderer remains active on iPhone 17 at **874×402 UIKit/SDL
points**, **2622×1206 Metal pixels**, and **3× mouse scale**. The original
`DM-Deck16][` engine initialized and entered its main loop.

The shared iPad action geometry was not viable in the phone's 402-point
landscape height: FIRE/ALT/JUMP intersected, the secondary actions crowded the
same lower arc, and Unreal `MENU` sat beneath the host settings button. The
overlay now selects a phone-specific GoldenPad-derived layout below 500 points
of landscape height. It uses a measured three-button primary stack, a separate
four-button lower rail, smaller transparent movement/look hit surfaces, and
trailing-safe-area-relative utility placement. Default, Compact, and High
Visibility profile bounds remain collision-free on the reference canvas.

The same rebuilt package was then run alone on the iPad Air 11-inch simulator.
It retained the tablet composition at **1180×820 points**, **2360×1640 pixels**,
and **2× mouse scale**, and the original engine again entered its main loop.

Evidence:

- [`iphone17-fullbleed-controls-landscape-gui.jpeg`](iphone17-fullbleed-controls-landscape-gui.jpeg) — authoritative iPhone Simulator GUI frame
- [`UT99-engine.stdout`](UT99-engine.stdout) — iPhone renderer dimensions and original main loop
- [`UnrealTournament.log`](UnrealTournament.log) — iPhone original-engine log
- [`ipad-air-regression-landscape-gui.jpeg`](ipad-air-regression-landscape-gui.jpeg) — authoritative iPad regression frame
- [`iPad-UT99-engine.stdout`](iPad-UT99-engine.stdout) — iPad native-resolution regression log

This proves simulator presentation only. Physical iPhone/iPad touch reach,
safe-area behavior, performance, thermals, and finger-only gameplay remain
open.
