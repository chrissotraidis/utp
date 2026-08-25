# iOS interrupted-session recovery and safe mode — 2026-08-24

**Classification: PASS for deterministic host tests, one-simulator interrupted-session recovery, safe-mode launch, and iPhoneOS packaging; PARTIAL for crash handling because no physical iPhone/iPad crash report or controlled engine return is available.**

## Implemented behavior

- Writes an atomic, bounded `UT99-active-session.json` before invoking the original entry and updates it to `Running` after startup.
- On the next launch, converts a surviving marker into `UT99-last-failure.json`, removes the active marker, enters `Crashed`, and offers Safe Mode, Normal Start, Diagnostics, or Not Now.
- Safe mode enables safe textures and VSync, disables audio, and records `safeMode=true` in the running session marker.
- A clean engine return archives `StoppingEngine`; a nonzero return archives `Crashed` and restores the diagnosable host surface.
- Diagnostics text summarizes active/failed/clean sessions, and diagnostic ZIP assembly now includes the bounded recovery JSON records under `recovery/`.

## Runtime sequence

1. `-UT99RecoverySmokeTest` seeded a running normal-mode marker. The same launch recovered it as `Crashed`, removed the active marker, and displayed `01-recovery-prompt-landscape.png`.
2. **Start in Safe Mode** launched the real embedded v469e entry. `02-safe-mode-engine-running.png` shows FruCoRe rendering with the current touch layer. The active marker reported `state=Running` and `safeMode=true`; preferences recorded safe textures/VSync on and audio off.
3. `simctl terminate` interrupted that live safe-mode process. A normal relaunch displayed `03-safe-mode-interruption-recovered.png`, explicitly identifying the previous safe-mode session. `final-last-failure.json` preserves that session as `Crashed`, and the active marker was removed.
4. The Diagnostics menu reported `Host state: Crashed`, `active=none`, and `lastFailure=Crashed/safe`.

## Verification

- `make test` — PASS, including abandoned, corrupt, failed-safe-mode, clean-return, diagnostic-summary, and diagnostic-artifact coverage.
- `make ios-engine-sim-package` — PASS.
- One iPad Air 11-inch Simulator ran the entire normal-marker → prompt → safe-mode engine → forced interruption → safe-mode recovery sequence. No second simulator was active.
- `make ios-engine-package` — PASS.
- `make ios-engine-real-package` — PASS.
- Physical `.ips` capture, watchdog/OOM distinction, actual device process termination, controlled original-entry return, and post-crash hardware audio/renderer behavior remain unproven.
