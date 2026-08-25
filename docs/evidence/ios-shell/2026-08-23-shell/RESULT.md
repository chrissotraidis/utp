# iOS host shell — 2026-08-23

**Classification: PASS for simulator shell only; engine gates remain unmet.**

- Built `UT99Apple.xcodeproj` for `iphonesimulator` with Xcode 26.6.
- Booted only iPad Air 11-inch (M4), UDID `F05D2D40-0A01-47C9-9BD7-0C0E19F7512C`.
- Installed and launched bundle `com.ut99apple.client`.
- Captured [the shell screenshot](ut99apple-shell.png).
- Shut down the simulator and verified zero booted simulators.

The screenshot demonstrates the Metal-backed host surface, GoldenPad-derived iPad touch layout, status text, and right-side three-dot host-menu affordance. The modern-preset visuals use transparent move/look hit zones, guide-only-on-demand movement feedback, tinted translucent action buttons, and press tinting. Touch gestures publish semantic host events, but the original engine input queue and touch-only gameplay are not yet proven.
