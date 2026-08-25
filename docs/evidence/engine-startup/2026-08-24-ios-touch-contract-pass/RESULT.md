# UT touch contract pass

## Result

The final simulator package entered the original `DM-Deck16][` `Botpack.DeathMatchPlus` match, possessed the player, reached `Game engine initialized` and `Entering main loop`, and delivered the complete semantic smoke sequence through the same SDL bridge used by UIKit:

`FIRE`, `ALT`, `JUMP`, `USE`, `DUCK`, `NEXT`, `PREV`, `SCORE`, `MENU`, plus digital movement and relative look.

The staged Windows `User.ini` confirms the selected bindings: `LeftMouse=Fire`, `RightMouse=AltFire`, `Space=Jump`, `Enter=InventoryActivate`, `C=Duck`, `W/A/S/D` movement, `MouseWheelDown=NextWeapon`, `MouseWheelUp=PrevWeapon`, `F1=ShowScores`, and `Escape=ShowMenu`.

## Scope

- `make ios-engine-sim-package` — passed before launch.
- One iPad Air 11-inch (M4) simulator used; runtime was cleaned afterward.
- The smoke log confirms semantic delivery, not physical finger touch or a complete touch-only match.
- Physical device/controller validation remains open.
