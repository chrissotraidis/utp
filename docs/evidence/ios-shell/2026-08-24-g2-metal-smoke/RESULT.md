# G2 host Metal and aggregate smoke — 2026-08-24

**Classification: PASS for simulator G2 automation and host-shell regression; PARTIAL/NOT RUN for physical G2.**

## Hypothesis

The native host can independently present a real Metal command buffer before engine ownership and can leave one decisive, pullable G2 marker only after its importer fixture, EctoPad default, Metal presentation, and diagnostics archive all succeed.

## Experiment

- Destination: iPhone 17 Pro Max Simulator, iOS 26.5, UDID `B37035B6-89B7-46D0-BEE3-3B1114B561F5`; one booted simulator and one client.
- Package: full transformed-engine simulator app, rebuilt after the host Metal change.
- Launch: `-UT99G2SmokeTest -UT99G2RunID=<uuid>` without starting the engine. The verifier accepts only the marker carrying the UUID from that launch, so a stale result cannot pass a repeated run.
- Success: completed Metal command buffer with nonzero native drawable, importer transaction marker passes, diagnostics marker passes, diagnostics ZIP passes `unzip -t` and includes the Metal marker, host menu opens and hides gameplay controls, then the original engine run can be restored.
- Failure: empty/deferred Metal surface, any component marker false/missing, corrupt ZIP, unresponsive host menu, or failure to restore the game.
- Cleanup: terminate the G2-only process and relaunch the latest package into the original automated bot-match path; leave one runtime.

## Result

PASS for the bounded simulator experiment:

```text
passed=true metal=true importer=true diagnostics=true ectoPad=true runID=4d007841-2920-4576-89ef-ca86c8e7303f
presented=true status=4 drawable=2868x1320 device=Apple iOS simulator GPU
UT99 import transaction smoke passed=true rollback=true replacement=4/4 systemPreserved=true debris=0
exported=true bytes=79807 entries=4 archive=UT99-diagnostics-smoke.zip
```

The ZIP independently passes CRC/central-directory inspection and contains `logs/UT99-host-metal-smoke.log`. The true-landscape host capture is `host-g2-landscape-v2.png`. Computer Use opened the full menu in `host-menu-open.jpeg`; its accessibility tree exposed all required sections, and gameplay controls disappeared while the menu owned interaction. `game-live-respawned.png` is the final-source regression: the real FIRE control starts the bot match and respawns into a full-bleed first-person Deck16 frame with the non-overlapping EctoPad-derived phone layout. One simulator and one game process were left running.

The first compile exposed a duplicate `viewDidAppear` override; the Metal request was merged into the existing lifecycle override and the rebuilt package then passed verification. A stale recovery marker also obscured the first visual capture; G2 automation now suppresses only the prompt presentation while still preserving recovered state for diagnostics. A second uniquely tagged run proved the marker freshness guard end to end. The simulator, diagnostic iPhoneOS, and real-FMOD iPhoneOS packages were then rebuilt and passed package verification from the final source.

## Physical-device path

`make verify-device` generates a fresh UUID, launches the same aggregate smoke, requires the pulled marker to echo that exact UUID, pulls all component logs and the ZIP through CoreDevice, verifies their contents, and records an `AUTOMATED_PARTIAL` bundle under ignored `build/device-evidence/`. It cannot promote G2 without physical hardware, direct menu/touch interaction, a system Files-picker fixture import, a share-sheet export, and a physical screenshot.
