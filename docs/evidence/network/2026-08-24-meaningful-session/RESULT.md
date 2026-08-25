# Meaningful unmodified-server session — Simulator

Date: 2026-08-24 CDT / 2026-08-25 UTC

Status: **PASS for the bounded Simulator session; G8 remains PARTIAL pending physical and observer evidence.**

## Environment

- One iPad Air 11-inch (M4) Simulator, iOS 26.5, UDID `F05D2D40-0A01-47C9-9BD7-0C0E19F7512C`.
- One `UT99Apple` process and one remote endpoint at a time.
- Public unmodified v469 endpoint: `unreal://217.154.81.36:7777`.
- Launch arguments: `-UT99AutoStart`, direct connect, `-UT99NetworkSessionSmokeTest`, and `-UT99TouchDefaultSmokeTest`.
- Final-source `make test`, real-FMOD Simulator packaging, and real-FMOD iPhoneOS packaging pass. The iPhoneOS package is build/verification evidence only; it was not installed because no signed physical device is available.

## Proven in this iteration

- The final run completed the original v469 challenge/download/welcome/load path on `DM-Peak` and possessed the remote player pawn.
- The readiness-gated sequence published movement, look, primary fire, scoreboard, death, two respawn attempts, post-respawn movement/fire, and network-stat input through the same SDL bridge used by the touch layer.
- The live screenshots show the death/scoreboard state, a successful return to first-person play with weapon and HUD, and the full-resolution post-respawn state.
- The final disconnect used the stock Unreal menu route—Escape, Multiplayer, Disconnect from Server—not a host replacement or console-travel approximation. The original engine then recorded `Browse: Index.unr?failed`, `Failed; returning to Entry`, and possession of the Entry pawn. The final smoke log verified that exact sequence and reached `complete`.
- A separate uninterrupted run on the same endpoint captured a real server match transition from `DM-Zeto` to `DM-Pressure`: new package negotiation and `WELCOME`, connection turnover, map bring-up, and possession of the new map pawn.
- After the final stable-source rebuild, a fresh regression joined `DM-Barricade`, repeated every bounded input phase, and verified the original stock-menu disconnect back to Entry. `make test`, the real-FMOD Simulator package, and the real-FMOD iPhoneOS package all passed immediately before this run.

## Deliberately not promoted

- `say ios469 session check` was submitted, but no authoritative local echo or second-client observation was captured. Chat acceptance remains open.
- The `stat net` command was submitted, but no visual acceptance claim is made.
- This is Simulator automation evidence. It does not prove physical finger input, genuine simultaneous two-thumb play, cellular/LAN/path-change behavior, or another player observing this client.
- The natural map transition and final stock-menu disconnect occurred in separate runs against the same endpoint; they are not presented as one uninterrupted physical G8 run.

## Evidence

- `final-network-session-smoke.log` — final readiness and phase log ending in verified stock-menu disconnect.
- `final-engine-session.log` — final original-engine delta from direct connect through Entry return.
- `map-transition-engine-excerpt.log` — original-engine `DM-Zeto` → `DM-Pressure` transition excerpt.
- `01-death-scoreboard.png` — live death/scoreboard state.
- `02-respawn-live-play.png` — manual FIRE respawn to live first-person play.
- `12-post-respawn.png` — native-resolution automated post-respawn first-person state.
- `14-final-disconnect.png` — native-resolution Entry/title state after stock-menu disconnect.
- `15-final-regression-entry.png` — native-resolution final-package Entry/title state after the `DM-Barricade` stock-menu disconnect.
- `final-regression-network-session-smoke.log` — final-package bounded sequence ending in verified stock-menu disconnect and `complete`.
- `final-regression-engine.stdout` — final-package engine log containing welcome, possession, and clean return to Entry.

Selected SHA-256 values:

```text
bdd88d51f732b97546d679cead139b42ce6fae7477fd8485012e1dc0aa1354e4  01-death-scoreboard.png
e675032e885cfc6550524910a77991486a9f0a20fe71475766c66d1a0fb7153c  02-respawn-live-play.png
b7dab01be297f6fb93502b44df7c9a303cd4cf83b4cf7aec0f976a8b19c11e8d  12-post-respawn.png
ce25f68a479a2beb562f23252088f37ca1cec8c0186a331065db7406959bdc2b  14-final-disconnect.png
b814063ea3c52ec59ee72b6a929151a09a6b830f1e4cc2014733986437ac80aa  final-network-session-smoke.log
595974debf2f5968e525ab871f1a4e24e1728f835e286f6fdb7c0f3096a0930a  final-engine-session.log
b73f802979cbedc0ca674949acda645a333bba642b16fa374d0b70ee5d42184c  map-transition-engine-excerpt.log
8023a29c0533cd37d131e5fae93eaf52000a555e130ebbcb55c1e7c4231e8e41  Simulator UT99Apple executable
0206263e79ca78a3d1231fa2ea41fcc147a7c7e01ffa46d2d15bb09b2604f1e6  Simulator UnrealTournament.dylib
95a7bd037acc8d6473cbc3958007a8c31b83b0b7ab9b09a105ee239058b6154a  iPhoneOS UT99Apple executable
ee4e01192ce4caf935d3d9315059eee956bbdcf27016f7f09a1933cd5ca9eaeb  iPhoneOS UnrealTournament.dylib
a92e8a731f1455d868890d7e2484c85a8869cce8d5b0adc450a3c7c1d9046c6c  15-final-regression-entry.png
b6e4eb440f8557140c8926b9ace4ded73ef6086cdd81c3a5ef12019e882b412a  final-regression-network-session-smoke.log
400e00943a39b117f3ce99333119394946d58d46b0b9438259e4ef245537c85e  Final Simulator UT99Apple executable
0206263e79ca78a3d1231fa2ea41fcc147a7c7e01ffa46d2d15bb09b2604f1e6  Final Simulator UnrealTournament.dylib
556e5c65f24baf3056b1216da72933b9975187c6ac0a7eeb9e5779e9f41755b9  Final iPhoneOS UT99Apple executable
ee4e01192ce4caf935d3d9315059eee956bbdcf27016f7f09a1933cd5ca9eaeb  Final iPhoneOS UnrealTournament.dylib
```
