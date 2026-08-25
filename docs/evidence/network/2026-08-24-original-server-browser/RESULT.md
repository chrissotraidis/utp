# Original v469e server-browser experiment

Result: **PASS (Simulator slice; physical-device gate remains open)**

## Hypothesis

The original v469e `Multiplayer → Internet` UI in the current iPad Simulator build can issue its configured community master-server query and visibly populate a server list without bypassing the engine through host-side protocol code.

## Bounded experiment

- **Input:** current transformed v469e engine package, installed user-data fixture, and the engine's existing `UnrealTournament.ini`/`User.ini` under the sole iPad Air 11-inch (M4) Simulator.
- **Runtime command:** one `UT99Apple -UT99AutoStart -UT99AutoMatch -UT99TouchDefaultSmokeTest -UT99ServerBrowserPointerSmokeTest` process; open the original Unreal menu, navigate to `Multiplayer → Find Internet Games`, then select the stock `UT Servers` tab through the SDL pointer bridge.
- **Success signal:** the original browser visibly lists at least one server and the engine log records a master query and/or resolved server-list traffic.
- **Failure signal:** the browser remains empty or errors after a bounded wait and the log records no usable master response.
- **Evidence:** Simulator-window screenshots, copied `UnrealTournament.log`, a filtered network summary, environment/runtime inventory, and SHA-256 hashes in this directory.
- **Cleanup:** retain exactly one Simulator and one client process; do not start a local server or a second client.
- **Decision:** PASS for this bounded Simulator experiment. The stock `UT Servers` tab became selected, the original UBrowser path queried community master servers, and the captured frame visibly contains 775 server rows. Simulator evidence does not promote the physical networking gate.

## Observed result

- The original v469e path `Multiplayer → Find Internet Games` opens the stock `UMenu/UBrowser` window.
- Bundled `.int` localization files restore readable tab labels including `News`, `UT Servers`, `Populated Servers`, game-type tabs, `Favorites`, and `LAN Servers`.
- The News page performs DNS resolution for `oldunreal.com` and renders live release/community content.
- The failed Retina-scaled attempt exposed the root cause: original `WindowConsole` multiplied SDL mouse-axis deltas by `MouseScale=0.6`, so a UIKit point could not land on the matching UWindow coordinate.
- The Apple profile now writes `MouseScale=1.000000`, and the bridge sends UIKit/SDL logical points directly. Motion is delivered before the button edge and associated with the focused SDL window.
- The bridge observed `point=480.0,23.0 logical=480,23 state=480,23 windowID=1` for motion, press, and release; all three stateful deliveries returned `result=1`.
- The original `UT Servers` tab became active. The engine resolved multiple configured master servers, entered the stock GameSpy/HTTP browser paths, and visibly populated 775 servers with 107 players and 71 spectators in the captured frame.

This closes the Simulator-side original-UWindow pointer-routing gap. Native direct connect remains independently proven. Real-finger selection, device networking, and joining through the browser remain physical-device work.

## Artifacts

- `08-retina-stateful-pointer-partial.png` — superseded failed state that demonstrated the scaled-coordinate offset.
- `10-logical-point-browser-landscape.png` — passing original browser with `UT Servers` selected and 775 visible rows.
- `11-logical-point-browser-smoke.log` — deterministic original-menu and logical-pointer action trace.
- `12-logical-point-browser-engine.stdout` — host/SDL trace, including exact observed pointer state.
- `13-logical-point-browser-UnrealTournament.log` — original engine master-server resolution, query, and ping traffic.
- `14-logical-point-browser-UnrealTournament.ini` — runtime profile proving `[UMenu.UnrealConsole] MouseScale=1.000000`.
- `06-browser-tabs-crop.png` — localized stock browser tabs.
- `network-summary.txt` — filtered browser/network/pointer events.

SHA-256:

- `10-logical-point-browser-landscape.png`: `1eeb29f9cd28469d1b62fcede8ec070950c6743e147258d9a6426252ed6f0ba7`
- `11-logical-point-browser-smoke.log`: `cd145dcc626b3cfe95baf91099422746376d2d695f8046e670bab6e55668ddba`
- `12-logical-point-browser-engine.stdout`: `72e92b46a72dff9bf19c3e928838fb6bde23465625939b0e891da0181449adab`
- `13-logical-point-browser-UnrealTournament.log`: `73ddc4150324cd4042d00d6b687d5fad966311924992528291c26d8ae3229d1e`
- `14-logical-point-browser-UnrealTournament.ini`: `84e78d4d635f18fef69e1eb925a5b5e9bb1689410121918178ad7a36de20500c`
- Simulator host executable: `25cc010cd324186fe261dfb1b88cf09b83832927ccf45233cdcf4ce054e63e1c`
- iPhoneOS host executable: `dd636a8939ded606609f93fbddfa5d2e30425cd4d2b167524d93fd494f3fceca`

## Next bounded step

Exercise this stock-browser flow with a real finger on one physical iPhone/iPad, select a listed server, and capture the join/session sequence. Do not mark the physical networking gate complete from Simulator evidence.
