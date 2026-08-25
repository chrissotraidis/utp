# iOS simulator lifecycle pass — 2026-08-24

## Hypothesis

The UIKit host releases gameplay input when the app leaves the foreground and
re-enables the host surface on return without starting a second v469e engine
instance.

## Experiment

With one iPad Air 11-inch (M4) simulator running the current embedded package,
the app was launched with `-UT99AutoStart -UT99AutoMatch`. The Simulator GUI
Home control was used to background the app, then the `UT99Apple` app icon was
opened to return to the game. `simctl` suspend/resume was attempted first but
is not available in the installed Xcode 26.5 command-line tool; that attempt
was not counted as evidence.

## Result

**PASS for simulator lifecycle behavior / PARTIAL for the physical-device
gate.** The authoritative GUI log contains:

```text
UT99 lifecycle: resign-active
UT99 lifecycle: active
```

The resumed capture shows the live Deck16 scene, the original waiting-for-ready
state, and the complete UT-specific touch rail. The same process had one
`auto-start result: Original engine entry started` and no duplicate-engine or
fatal/abort record. Runtime cleanup afterward reported zero booted simulators.

Evidence: `gui-system.log`, `gui-engine.stdout`, and `gui-resume-pass.png`.
