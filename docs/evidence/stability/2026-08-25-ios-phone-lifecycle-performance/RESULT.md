# iPhone Simulator lifecycle and performance soak

Date: 2026-08-25
Result: PASS for the bounded Simulator experiment; physical G2/G9 remain open

## Scope

The final real-FMOD Simulator package was installed on the sole booted iPhone 17 Pro Max Simulator and launched into the original `DM-Deck16][` bot match. The run exercised the visible UIKit touch layer, three actual Simulator Home/reopen cycles, post-resume gameplay, a natural map rollover to `DM-Codex`, and more than 30 minutes in one unchanged app process.

Computer Use operated the visible Simulator Home control and the app icon for each lifecycle cycle. It also invoked the exposed FIRE and Movement accessibility surfaces against the live original engine loop. This is stronger than a synthetic notification test, but it is still Simulator/assistive input evidence rather than physical-finger, VoiceOver, or device evidence.

## Result

- Exactly one Simulator was booted and exactly one `UT99Apple` client process remained active.
- The process ran for 30 minutes 48 seconds at the final timed capture with one `Game engine initialized` record and one `Entering main loop.` record.
- Three Home/reopen cycles each recorded `Running -> PausedBySystem` and `PausedBySystem -> Running`; the PID did not change.
- FIRE produced three ordered down/up pairs. A post-resume FIRE activation returned from the death state to visible first-person play.
- The engine naturally traveled from `DM-Deck16][` to `DM-Codex`, loaded the second map, and possessed a player without restarting the process.
- Final RSS was 412,016 KiB. Samples rose to roughly 429 MiB and later fell near 400 MiB before the final capture. That bounded release behavior is useful, but it is not a general memory-leak claim.
- FruCoRe's produced-frame samples reported 129.05 FPS at 3 seconds, 122.47 FPS at 6 seconds, and 121.88 FPS at 10 seconds, with a 2868×1320 drawable. Simulator presentation is not a physical refresh-rate, thermal, or battery result.
- No app fatal/assertion/crash record was found. The engine log contains one duplicated Simulator accessibility-bundle warning from the iOS runtime; the app continued normally.

## Evidence

- `01-phone-deck16.png` — initial Deck16 ready state
- `02-phone-live-match.png` — live first-person state after FIRE
- `03-phone-resumed.png` — rendered state after the first Home/reopen cycle
- `04-phone-after-three-resumes.png` — renderer alive after three cycles
- `05-phone-post-resume-respawn.png` — live first-person play after the lifecycle cycles
- `06-phone-30-minute-soak.png` — final rendered state after 30 minutes 48 seconds
- `phone-engine.stdout` — original engine startup, Deck16/Codex loads, and possession records
- `phone-system.log` — host state transitions and touch-bridge edges
- `phone-performance.log` — FruCoRe presentation samples
- `lifecycle-input-excerpt.log` — bounded lifecycle/input excerpt
- `soak-summary.txt` — process and event counts at the timed capture

SHA-256:

```text
150eb37c64c79fef621041b958db6c3441ee4fd594c742a5480bd1a0e7e5d584  01-phone-deck16.png
064fc49b3a1c0c5434f8c20346bbe43bf1ed80a7f631a83fb67165fa0d1d1511  02-phone-live-match.png
2a8ba80570d2651f4dc0c58a4a5b764166d1751ca5b8c87eaa4d2d3c23532761  03-phone-resumed.png
c6a3451c0435ca31091940d3c542452f5ea8161c3654454d22bc5173dd88aba2  04-phone-after-three-resumes.png
022af20da6d8787806dd1e2f517cc40cc03bbe8103c3f1846c37eb967afd20a1  05-phone-post-resume-respawn.png
122a1923b6a49ed11fbddf25d01542dd273ce1d2da250a4f04f1bc4d0ac5df01  06-phone-30-minute-soak.png
83c685bbaaa4b52b8e3ec77ea5c524b263b681143644d24fbc64166d12e7e908  lifecycle-input-excerpt.log
195de1f888056fa7aae8791d0a8d4f72cbf0f21c1bd09967982f56b6c0420ec5  phone-engine.stdout
be4a5ca4bfd521ea9e6c5681cf14140e215aebf2d4683dc025c87014dd848555  phone-performance.log
05bffcc897e5722bf06055370d806fc9d45a072975d4724fb99a375a9b7d963b  phone-system.log
36f63af274d13d88a0d129c84e0ec1b3d91dd400f65205b595478a336b6c3d7f  soak-summary.txt
```

## Limits

This result does not promote physical G2, G6, G7, or G9. A signed physical iPhone/iPad is still required for finger multitouch, audible audio and route recovery, suspension/watchdog behavior, hardware FPS and pacing, thermals, memory pressure, battery impact, safe areas, haptics, and accessory input.
