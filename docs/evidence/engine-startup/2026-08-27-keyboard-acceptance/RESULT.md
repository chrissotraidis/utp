# Physical iPad keyboard acceptance — 2026-08-27

## Outcome

The keyboard repair is **accepted** on the physical iPad.

The user selected the stock Unreal Tournament Player Name field and confirmed:

- the attached iPad hardware keyboard could delete and enter printable text;
- UTP's virtual keyboard opened correctly;
- virtual Delete changed the selected field; and
- a virtual printable `S` changed the selected field.

This closes the software- and hardware-keyboard Player Name defect for the
accepted build. Controller lifecycle work must start from this baseline and
must not change the keyboard event recipe.

## Accepted build identity

- Bundle identifier: `com.ut99apple.client`
- Host UUID: `76FC6C39-B7E0-3AC1-AFED-0F73CFA96E40`
- Host SHA-256:
  `d141362e540d2bab1cc40ce39cccb7ab4673c0d251d9c96f5ed13c6d2dcd5cab`
- Embedded SDL SHA-256:
  `2cca0f899592092339ca2f35a9b98aa65e1d31161226709f808a0b7fba4d06ec`
- SDL patch SHA-256:
  `68a1ce30d1e8808e7a928269bfc2133c2ea17e6e8ac75b22fb3f07dace2244e2`

The signed app was installed in place. Pre/post copies of
`com.ut99apple.client.plist`, `User.ini`, and `UnrealTournament.ini` were
byte-identical, preserving touch layout, host settings, and UT configuration.

## Root cause locked into the baseline

Packaged UWindow source shows that `UWindowEditBox.KeyType` inserts printable
characters only while its internal `bKeyDown` flag is true. Plain TextInput
never set that flag. The earlier UIKit recipe queued KeyDown, KeyUp, then
TextInput, clearing it before the character arrived.

`SDL_UT99SendKeyboardText` now sends one matching virtual KeyDown, then
TextInput, then KeyUp per printable character. Shift remains held around the
sequence for uppercase characters. Swift invokes the helper once per
`Character`, so every character has an independent, balanced key lifecycle.

The focused regression test asserts the relative order of those three calls.
It is not sufficient for future code merely to retain the helper name.

## Physical log correlation

The private pulled device log contains no entered text. It records only event
metadata and character counts. During the accepted run it shows:

- hardware `pressesBegan`/`pressesEnded` callbacks;
- printable hardware input accepted by the shared bridge;
- KeyDown, TextInput, KeyUp dequeue order for those characters;
- virtual keyboard presentation;
- virtual Delete key down/up dequeue; and
- virtual printable input using the same ordered dequeue path.

The user's visible observation establishes field mutation; the log establishes
that the accepted production route produced it. Queue return values alone are
not treated as acceptance.

## Verification completed before installation

- pinned SDL patch dry-run: passed;
- clean SDL source regeneration: passed;
- focused host/input regression test: passed;
- full `make test`: passed;
- real-engine Player Name Simulator probe with visible `Ab 9`: passed twice;
- signed iPhoneOS build: passed;
- deep package signature verification: passed; and
- normal physical launch to the stock UT menu: passed.

## Frozen boundary

The next controller candidate may change controller enumeration, lifecycle,
ownership, menu cursor behavior, and touch auto-hide logic. It must not change:

- `SDL_UT99SendKeyboardText` ordering;
- `publishTextEntry` per-character dispatch;
- the virtual keyboard's use of `publishMenuCharacter`; or
- the hardware printable-key route through the same helper.
