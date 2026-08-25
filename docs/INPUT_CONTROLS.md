# Input control contract

UTP exposes two explicit input modes. The three-dot host menu
switches between **Use Menu Controls** and **Use Gameplay Controls**. The
selected mode applies to touch, controller, mouse, and trackpad routing. Input
mode and touch-overlay visibility are independent: changing modes never turns
touch controls on, sends Escape, or changes game state.

Connecting an extended controller auto-hides touch controls once when the
saved controller-auto-hide preference is enabled. A later explicit **Turn
Touch Controls On** overrides that transient hide even while the controller
remains connected. Disconnecting clears the transient controller hide; it
does not rewrite the player's saved touch-enabled preference.

| Input | UWindow menu | Gameplay |
| --- | --- | --- |
| Left touch stick | Move the stock UT cursor | Move player |
| SELECT / primary touch | Left mouse click | Fire |
| BACK / GAME MENU | Escape; close or go back | Escape; open menu |
| Direct touch on right half | No menu cursor teleport | Look |
| Trackpad or mouse motion | Move stock UT cursor | Look |
| Primary mouse click | Left mouse click | Fire |
| Keyboard | Stock configured key | Stock configured key |
| Controller left stick | Move stock UT cursor | Move player |
| Controller right stick | No menu action | Look |
| Controller A or right trigger | Left mouse click | Jump or fire |
| Controller B | Escape | Crouch |
| Controller View / Select | Switch to Gameplay Controls | Switch to Menu Controls |
| Controller Menu | Escape; close or go back | Escape; open menu |

Menu touch UI must always show the cursor stick, SELECT, and BACK. It must never
draw a second host cursor or route menu input through gameplay movement/fire.
SELECT and BACK have separate saved menu-layout positions, so arranging menu
controls does not move FIRE or GAME MENU in gameplay mode. Physical pointer
motion and the touch/controller trackball update the same stock cursor
position. Touch-only users can focus a stock text field and choose **Type
Text** from the host menu to summon the iPad keyboard.

Controller routing follows the explicit Menu/Gameplay mode instead of guessing
from engine mouse-capture state. In Menu mode the left stick moves the stock
cursor, A selects, and B goes back. In Gameplay mode the left stick moves, the
right stick looks, A jumps, B crouches, and the right/left triggers fire and
alt-fire. The Xbox View/Select button switches directly between the two modes;
the Xbox Menu button remains the original Unreal Escape/menu command. The
gameplay left stick suppresses only small cross-axis wobble near the four cardinal
directions, preserving deliberate diagonal movement. `GCController` callbacks run on the controller monitor queue because
the original UT main loop owns the process main thread. Both the host window
and SDL's key renderer window use `GCEventViewController` with controller UI
interaction disabled, preventing Xbox input from being downgraded to UIKit
focus-navigation presses.

Hardware and software text entry goes through the embedded SDL keyboard state
machine. The host menu's **Escape / UT Menu** action exposes Escape for touch
users, including server transitions that say “Press Escape to begin.” The
**Multiplayer** action always opens the original browser through Multiplayer →
Find Internet Games; Menu Controls being active is not treated as proof that
Unreal's menu is already open.

Fresh iPhone installs use the accepted physical-iPhone placements for gameplay
controls and the separate menu SELECT/BACK layout. Existing saved layouts still
win. The renderer uses the live iPhone safe-area frame plus a small edge pad;
iPad rendering remains full-bleed.
