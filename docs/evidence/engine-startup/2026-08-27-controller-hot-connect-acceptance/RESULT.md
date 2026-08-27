# Physical controller hot-connect acceptance — 2026-08-27

## Outcome

The `097a630` foreground-discovery candidate is **physically accepted** for
Xbox controller hot-connect on the attached iPad. The already accepted
hardware and virtual-keyboard behavior also passed in the same session.

## Physical sequence

The user:

1. launched UTP and chose the normal start with the Xbox controller off;
2. reached the original Unreal Tournament menu;
3. connected the controller through iPadOS Bluetooth Settings;
4. returned to UTP and navigated the original menu with the controller;
5. verified hardware and UTP virtual-keyboard Player Name entry;
6. loaded `DM-Oblivion`, switched to Gameplay controls, and confirmed movement,
   look, and fire; and
7. paused and returned to play successfully.

## Correlated device evidence

The retained engine session records:

- `20:05:01.298`: `Xbox Wireless Controller` configured, became current, and
  connected;
- `20:05:01.302`: touch overlay hidden with `extendedController=true` and
  `responderFallback=false`;
- original-menu controller input after adoption;
- `DM-Oblivion.unr` browse/load and player possession;
- `20:06:13.606`: controller input mode changed to `gameplay-look`; and
- sustained left-stick, right-stick, and primary-fire input during the visible
  gameplay observation.

This is the missing physical proof that iPadOS publishes a real extended
profile after returning from Settings and that UTP reconciles it without an app
restart. It supersedes the hot-connect result of the rejected `d10f613` build;
it does not erase that historical evidence.

## Accepted product identity

- Source candidate: `097a630`
- Bundle identifier: `com.ut99apple.client`
- Host UUID: `F97BE745-DD6D-3F98-AD4A-A3996D7F42C5`
- Host SHA-256:
  `bdce45653bef78e54ef82957ef5e1d3025a5f0422e8912173d1b38230d23803b`
- Embedded SDL SHA-256:
  `1830d33b185c66e75ea4cc0e96cb8b361fd32c3010b31f54db680a6eb5af4277`
- Accepted engine stdout SHA-256:
  `bd03f0798ea756f9c63c353c165bd95974b09ddf9565def00373328c0b3ecc6c`
- Previous engine stdout SHA-256:
  `79a1c4ad2c64773414c57c2e9351b440f710bc1eca093791009363b77b830554`
- Unreal Tournament log SHA-256:
  `7d56d24994e12e3d346efaeda0a2e320d2b77fbb57b3e202d841ae266ed32d6b`

The raw pulled device logs remain outside the repository because they may
contain player/session details. This record contains only bounded acceptance
metadata and hashes.

## Remaining boundaries

This acceptance does not establish physical mouse/trackpad precision,
secondary-button or wheel support, renderer shadow correctness, multiplayer
compatibility, or long-session performance.
