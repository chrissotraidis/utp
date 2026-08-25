# iOS Metal presentation-metrics pass — 2026-08-24

Classification: **PASS** for simulator-native drawable instrumentation and the full-bleed iPad visual regression; **PARTIAL** for PRD performance gate G9 because no physical iPad was attached.

## Result

- FruCoRe's actual `presentDrawable:` boundary is instrumented in `UT99MetalShim`, rather than the dormant host `MTKView`.
- The renderer reported a 2360×1640 drawable while SDL reported a native 1180×820-point iPad Air scene.
- The accepted Simulator GUI capture is true landscape, full bleed, and shows distinct SCORE, MENU, host-settings, ALT, FIRE, USE, JUMP, PREV, NEXT, and DUCK surfaces without overlap or clipping.
- Graphics and Diagnostics now show measured FruCoRe average FPS, 1% low FPS, frame time, frame count, and drawable size. The former host-view “frame cap” setting was removed.
- `UseVSync=True` is persisted into `[FruCoRe.FruCoReRenderDevice]` for the next engine start. The simulator did not pace presentations to 60 Hz, so this is not treated as a simulator cap or a hardware-performance result.

## Bounded samples

| Setting | 3 s | 6 s | 10 s |
|---|---:|---:|---:|
| VSync off | 129.70 FPS | 121.98 FPS | 131.35 FPS |
| VSync on | 109.71 FPS | 122.84 FPS | 133.26 FPS |

At 10 seconds, VSync-off reported 35.71 FPS 1% low and 7.613 ms average frame time; VSync-on reported 37.42 FPS 1% low and 7.504 ms. These are produced-frame measurements from an iOS Simulator on macOS, not display refresh, physical-iPad FPS, thermal, or battery evidence.

## Evidence

- `ipad-frucore-native-performance-landscape.png` — accepted VSync-off 2360×1640 landscape capture
- `ipad-frucore-vsync-on-native-landscape.png` — accepted VSync-on 2360×1640 landscape capture
- `UT99-performance.log` — VSync-off bounded samples
- `UT99-performance-vsync-on.log` — VSync-on bounded samples
- `UT99-system.log` and `UT99-system-vsync-on.log` — shim installation and host runtime records
- `UnrealTournament.log` and `UnrealTournament-vsync-on.log` — original engine startup/main-loop records
- `UT99-engine.stdout` and `UT99-engine-vsync-on.stdout` — hosted-engine stdout

The simulator was shut down after capture; `tools/ensure_single_runtime.sh --check` reported zero booted simulators.
