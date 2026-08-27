# Input control contract

This document is the intended player-facing contract, not a record of current
physical acceptance. See [`CURRENT_INPUT_STATUS.md`](CURRENT_INPUT_STATUS.md)
for the evidence-backed working, rejected, and open behavior of the current
iPad build.

UTP exposes two explicit input modes. The three-dot host menu
switches between **Use Menu Controls** and **Use Gameplay Controls**. The
selected mode applies to touch, controller, mouse, and trackpad routing. Input
mode and touch-overlay visibility are independent: changing modes never turns
touch controls on, sends Escape, or changes game state.

Connecting an extended controller auto-hides touch controls once when the
saved controller-auto-hide preference is enabled. A later explicit **Turn
Touch Controls On** overrides that transient hide even while the controller
remains connected. Disconnecting clears the transient controller hide; it
does not rewrite the player's saved touch-enabled preference. A fresh launch
with no detected controller restores touch controls as the safe input baseline.

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
position. Touch-only users can focus a stock text field and choose **Open
Keyboard** from the host menu to reveal UTP's in-host keyboard. Its letters,
numbers, Shift, Space, Delete, and Done keys publish synchronously into the
selected stock field without depending on iPadOS's deferred keyboard window.
The host action changes to **Close Keyboard** while the panel is visible.
iPhone uses the compact layout by default, and **Small/Large** changes the panel
size on either device class. Hardware and host software keyboard entry in the
real Player Name field are physically accepted on the 2026-08-27 iPad build.

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
focus-navigation presses. If a controller hot-connected after UT entry is
temporarily exposed only as directional UIKit presses, Menu mode converts each
press lifetime into one bounded, low-speed cursor vector. This smooths the
otherwise staccato responder edges without pretending they contain analog
magnitude. That fallback cannot synthesize missing right-stick or trigger axes
for gameplay. Because UIKit also collapses both physical sticks into those same
four directions, responder-only directions are ignored in Gameplay mode and
touch movement/look remains visible. Reopen UTP with the controller already
connected to obtain the full native gameplay profile. Responder-only presses
must not switch Menu/Gameplay mode; only a configured extended controller's
explicit View/Options binding may do so.

Hardware and software text entry goes through the embedded SDL keyboard state
machine. The host menu's **Escape / UT Menu** action exposes Escape for touch
users, including server transitions that say “Press Escape to begin.” The
**Multiplayer** action always opens the original browser through Multiplayer →
Find Internet Games; Menu Controls being active is not treated as proof that
Unreal's menu is already open.

Fresh iPhone installs use the accepted physical-iPhone placements for gameplay
controls and the separate menu SELECT/BACK layout. Existing saved layouts still
win. The renderer uses the live iPhone safe-area frame plus a small edge pad;
iPad rendering remains full-bleed. Fresh iPad installs use the accepted
2026-08-26 SELECT/BACK positions; a player's saved iPad layout still wins.
