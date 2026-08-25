# Original server-browser join — 2026-08-24

Result: **PASS (Simulator slice; physical-device gate remains open)**

## Hypothesis

After the stock v469e `UT Servers` tab populates, point-accurate input can select and double-click an original browser row, allowing the unmodified engine network path to connect, download required content, load the remote map, and possess a player.

## Bounded experiment

- One iPad Air 11-inch (M4) Simulator and one `UT99Apple` client were active.
- The opt-in `-UT99ServerBrowserJoinSmokeTest` navigated the original Unreal menu, opened `Multiplayer → Find Internet Games`, selected `UT Servers`, waited for population, and double-clicked the first server row at logical point 600×60.
- The host supplied pointer events only. Server discovery, challenge, download management, map loading, login, and possession remained original v469e engine behavior.
- The selected public row is intentionally not fixed; server order, endpoint, map, and custom content can vary between runs.

## Observed result

- All point motions and button edges were accepted by the stateful SDL pointer bridge.
- The engine issued `Browse: 104.153.109.34:8008/Index.unr`.
- The endpoint returned a v469 challenge and `WELCOME LEVEL=CTF-LongGuns`.
- Original HTTP/channel download managers retrieved the selected server's required custom packages.
- The engine logged `LoadMap: 104.153.109.34:8008/CTF-LongGuns`, brought `CTF-LongGuns.MyLevel` up for play, logged in `Player`, and possessed `CTF-LongGuns.TMale20`.
- The accepted landscape capture visibly shows the live Wildcard's SiegeXtreme session with the native touch overlay still composed and responsive.
- A subsequent assistive activation of the live FIRE control logged ordered `primaryFire pressed=true` then `pressed=false` bridge edges inside that remote session. The selected server kept the client in its dead/spectator state, so this proves in-session action delivery but not respawn.

This closes the prior Simulator-side gap between populated stock browser and joined live session. It does not prove a physical finger, physical-device networking, long-session stability, chat/map transition/disconnect behavior, or the physical G8 gate.

## Artifacts

- `live-remote-session.jpeg` — authoritative Simulator-window capture of the joined live session.
- `live-fire-action.jpeg` — frame captured after the bounded in-session FIRE activation.
- `browser-join-smoke.log` — bounded original-menu, tab, and row double-click sequence.
- `engine.stdout` — complete accumulated engine/SDL output for the installed data container.

SHA-256:

- `live-remote-session.jpeg`: `f879078354668f7ea227c388afa2574df45265766a854cc3d1a7daa4d82f794a`
- `live-fire-action.jpeg`: `1445487e92aa408e58783c04fd4c5d18f9da2ad35f18941a51dd5ae0bf145800`
- `browser-join-smoke.log`: `d77bec74903173e30030ec15bca2c8db3cdff0c17ca7f91da955dfa486cd3a79`
- `engine.stdout`: `c822580215aad7b5916ef74625086846aee399cce7c11091cd7915bdca5520a8`
- Simulator host executable: `95f6331cdc263b2f34aa8ec87a746c6314eb55957d2b21ea6c767d8c0797ba78`
- iPhoneOS host executable: `a7b1fa7b086c834063396f6807b5321915557f01c5113cdf4601ff469e3cdeba`

After the live run, `make test` passed and `make ios-engine-real-package` rebuilt and verified the corresponding real-FMOD iPhoneOS candidate. The latter remains ad-hoc because no Apple Development identity/team is available.

## Next bounded step

Repeat row selection and joined play with a real finger on one signed physical device, then cover movement, firing, respawn, chat, map transition, and clean disconnect before promoting G8.
