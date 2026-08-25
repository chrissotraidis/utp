# iOS simulator input and package pass — 2026-08-24

## Hypothesis

The UT-specific GoldenPad action layer can carry the missing controller weapon
and original-game-menu semantics without changing the original v469e engine.

## Experiment

Built `make ios-engine-sim-package`, launched exactly one iPad Air 11-inch
(M4) simulator (`F05D2D40-0A01-47C9-9BD7-0C0E19F7512C`) with:

```text
-UT99AutoStart -UT99AutoMatch -UT99TouchSmokeTest -UT99MenuSmokeTest
```

The run was captured to `touch-controller-menu-pass.png`, `system.log`,
`engine.stdout`, and `engine.log`. The runtime was shut down with
`tools/ensure_single_runtime.sh --clean` afterward.

## Result

**PASS for simulator evidence / PARTIAL for the physical-input gate.** The
original engine reached `DM-Deck16][`, possessed the player, initialized the
game engine, and entered the main loop. The bridge delivered primary fire,
alternate fire, jump, use, crouch, next weapon, previous weapon, scoreboard,
and the separate Escape-backed original Unreal `MENU` action. The screenshot
shows the original Unreal front end with the fixed host three-dot button and
the UT-specific touch rail simultaneously composited.

The controller semantic path now maps left/right shoulders to previous/next
weapon, the optional controller Options button to the original Unreal menu,
and retains the controller Menu button for the host menu. The simulator cannot
prove those physical callbacks; no physical controller or iPad is attached.

Both native device packages were rebuilt after the change:

```text
make ios-engine-package ios-engine-real-package
```

Both package verifiers passed. No simulator remained booted after cleanup.
