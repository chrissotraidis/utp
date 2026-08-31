# Pointer capture physical result — partial

Date: 2026-08-30

Device: physical iPad Pro

Candidate UUID: `D4C2B665-63B2-3B50-91F4-FB26C1096AC4`
Candidate executable SHA-256: `7bc460acbbef646feb23535f736db63fffa13284eda3985201a871a318094322`

## Observed result

- UTP launched in normal mode and iPadOS granted **Capture Mouse / Trackpad**.
- Touch controls could be turned off from the three-dot panel.
- The attached trackpad controlled gameplay look in a real deathmatch on
  Oblivion, proving the captured relative-pointer route reaches Unreal.
- The raw pointer gain was too high for comfortable play.
- Space jumped and keyboard weapon selection worked.
- WASD did not move the player.

The run did not separately accept secondary click, wheel behavior, every menu
edge, lifecycle release, or a preferred sensitivity value.

## Follow-up boundary

The next candidate adds a persistent captured-pointer speed preset directly to
the three-dot panel. It also routes WASD only while UTP is explicitly in
Gameplay Controls through the same directional SDL symbols already used by the
accepted touch-movement path. Menu-mode printable text ordering and the
player's existing `User.ini` remain untouched.

## First follow-up rejection

The installed `C908B6EE-32D5-3B93-BC2F-9405C3DDBFD0` follow-up still did not
move on WASD. During a live physical retry, two W presses produced no
`GameViewController.pressesBegan` keyboard-bridge event. This rejects UIKit
`UIPress` as the authoritative captured-gameplay source; it does not reject the
directional SDL translation itself. The next candidate uses host-owned
`GCKeyboard.keyChangedHandler` for gameplay WASD and keeps UIKit for menu text.

## Accepted follow-up — 2026-08-31

Candidate UUID: `8CDD53E5-C761-3A8E-8C0D-83266A0197B8`

Candidate executable SHA-256: `afbdaad442a345ffdcada3832af56753847ff1f8a00fb35accd791be7135b4cd`

- The user explicitly selected Gameplay mode and WASD movement worked in an
  Oblivion deathmatch.
- Captured trackpad look and pointer buttons worked. A higher existing speed
  preset was reported comfortable, so the sensitivity values need no change.
- The already-connected controller continued to work simultaneously with the
  keyboard and trackpad.
- Hardware text entry, the host keyboard action, and Escape remained usable.
- The combined keyboard-plus-pointer defect, WASD defect, and pointer-gain
  usability defect are accepted as closed. Wheel/scroll was not separately
  narrated.

The same run exposed two panel issues outside the accepted input route. The
touch action described the saved preference rather than the controller-hidden
visible state, and the Multiplayer action reached UMenu but not `UBrowser`.

## Final panel acceptance

The conditional follow-up was installed in place with byte-identical
preferences and both INIs. It reports actual touch visibility, hides irrelevant
Arrange/Speed actions, uses contextual Menu/Escape wording, and slows/logs the
stock server-browser route. The user accepted the resulting menu and final
build as working great and authorized Preview 3 publication.
