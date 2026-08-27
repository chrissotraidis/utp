# Controller lifecycle candidate — 2026-08-27

## Outcome

The controller lifecycle repair is **accepted locally** and still requires one
focused physical-iPad hot-connect/disconnect check.

The physically accepted keyboard baseline is commit `db4e8d1`. The controller
candidate is a separate three-file implementation/test diff. It does not alter
the SDL keyboard patch, hardware printable-key route, virtual-keyboard
printable route, or the accepted KeyDown, TextInput, KeyUp ordering.

## Root cause

The host started the non-returning Unreal entry point from
`DispatchQueue.main`. Unreal correctly stayed on the main thread for SDL's
UIKit/Metal backend, but its dispatch block never completed. SDL's nested UIKit
event pump kept ordinary touch and keyboard events alive while the serial main
dispatch queue remained occupied. GameController connect/disconnect
notifications and queued host reconciliation therefore could fail to run after
engine entry.

The candidate schedules the same main-thread entry through the main run loop.
No controller mappings, touch mappings, dead zones, cursor transforms, or
keyboard event recipes were changed.

## Real-engine lifecycle proof

A Simulator-only hidden `GCVirtualController` connected three seconds after the
real Unreal engine entered its main loop. The live engine log proved this
ordered sequence:

1. main-dispatch liveness callback executed;
2. virtual controller connected without error;
3. the host configured an extended profile and received the connect event;
4. left-stick menu input and A selection produced a stateful pointer click;
5. Options switched the authoritative mode to Gameplay;
6. gameplay left-stick movement reached `UT99TouchBridge`;
7. right-stick look and right-trigger primary fire reached their production
   bridges, including balanced release events;
8. Options returned to Menu; and
9. disconnect notification, input release, and touch-visibility reconciliation
   completed.

This probe exercises the same notification and input handlers used by a
physical extended controller, but does not substitute for iPadOS publishing the
physical Xbox profile.

## Keyboard non-regression

After the lifecycle run, the candidate reran the real-engine Player Name probe.
The stock field visibly contained `Ab 9`. Its privacy-safe log recorded Shift,
KeyDown, TextInput, KeyUp, and ShiftUp in the required order. No entered text
was written to the log.

## Verification

- focused host/input source guards: passed;
- iOS Simulator real-engine build: passed;
- post-engine controller connect/menu/gameplay/disconnect lifecycle: passed;
- Player Name `Ab 9` regression: passed;
- complete `make test`: passed;
- signed iPhoneOS build: passed;
- deep iOS package verification: passed;
- `git diff --check`: passed.

## Installed product identity

- Bundle identifier: `com.ut99apple.client`
- Host UUID: `0B4958D1-0EC7-3408-A82A-9D10F215031D`
- Host SHA-256:
  `7cf5c81c240f0f7f29a094178572e7e8d9b78fe8d134965e710590de2351354d`
- Embedded SDL SHA-256:
  `665e81cd6d640c1f34bdcfbd32e001e41822b22b1c49b8b95d571d1846b2f5d4`
- SDL patch SHA-256:
  `68a1ce30d1e8808e7a928269bfc2133c2ea17e6e8ac75b22fb3f07dace2244e2`

## Physical acceptance boundary

The candidate was installed in place after preserving preferences, `User.ini`,
and `UnrealTournament.ini`. Post-install copies of all three files are
byte-identical. Their SHA-256 values are, respectively:

- `22237a809b04e984fafda3c43ac11c995623c6ff91ea577b5c6cc11a1734aa47`;
- `7f5539979bbe67a0471faaf04ba7d454db13b21e7dc80477f4cf95368d1945aa`;
  and
- `43a8ae5c33d00d4d572eb4852e462d567b612b08c45db2888e7f75bbe80b2809`.

Perform one short sequence: launch without the Xbox controller, hot-connect it
at the original menu, confirm extended menu input, switch to Gameplay and
confirm both sticks/right trigger, disconnect and confirm touch returns, then
reconnect once in Gameplay. Stop immediately if the log reports responder-only
input rather than an extended profile.
