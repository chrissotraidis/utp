# Native direct-connect UI and live server result

Result: **PASS for the native direct-connect UI and original-engine handoff; G8 remains partial.**

The iPad host now presents a compact native Multiplayer sheet from the three-dot menu. It reports current path availability, accepts either a hostname or an `unreal://` address, normalizes a bare hostname to the Unreal scheme, rejects non-Unreal schemes, remembers the last valid address, and launches the original v469e entry with that address. While the engine is already active, the same menu directs the player to Unreal Tournament's original Multiplayer menu instead of attempting a duplicate engine start.

## Live sequence

1. Opened the host three-dot menu and selected Multiplayer.
2. Confirmed the native sheet exposed one server-address field plus Cancel and Join Server.
3. Entered `https://example.com`; the sheet closed and the host reported `Enter a valid UT server hostname or unreal:// address` without starting the engine.
4. Reopened the sheet and entered the bare hostname `ut99.weba.ru:7777`.
5. The host normalized it to `unreal://ut99.weba.ru:7777` and started the embedded original engine.
6. `UnrealTournament.log` recorded DNS resolution, `CHALLENGE VER=469`, the server download-manager declarations, `WELCOME LEVEL=DM-CMetal`, and `LoadMap: ut99.weba.ru/DM-CMetal`.
7. The visible Simulator reached the server's live scene and MapVote/Welcome UI with the corrected touch layer still composited.

No credential, account token, or private server address was used.

## Evidence

- `direct-connect-sheet.png` — native pre-engine Multiplayer sheet. SHA-256 `d962c1050e6cbecc2920589cd6acbcdccfc7118eff4e96095f90750df6dcd94b`.
- `live-server-session.png` — original engine connected to the public endpoint and rendering its current live map. SHA-256 `075ec483affbf40d4dd87af970b4852c85d129f20f8cd3918ce87669da3446d9`.

## Remaining G8 work

This proves the player-facing direct-connect path, DNS, v469 handshake, download-manager negotiation, welcome, map load, and visible remote session in Simulator. It does not yet prove a community master query/server-list population, chat, map transition, another player's observation of movement/combat, a meaningful multiplayer match, cellular/LAN behavior, or physical-device networking.
