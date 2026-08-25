# iOS icon touch and named-profile pass

## Result

PASS for the bounded simulator and packaging scope. The physical-device gate remains open because no iPhone or iPad is attached.

- The iPad Air 11-inch run fills a 2360×1640 landscape target.
- The iPhone 17 Pro Max run fills a 2868×1320 landscape target and clears the Dynamic Island.
- Gameplay controls use small icon-only visual faces while retaining larger circular hit bounds and accessibility labels.
- FIRE remains dominant, ALT/USE/JUMP/DUCK form a separated combat group, and PREV/NEXT share a joined weapon rail.
- Opening the host menu hides gameplay controls; the saved-layout popover presents save, import, export, apply, and delete without overlap.
- `.ut99touch` schema-v1 profiles round-trip configuration and normalized placements through bounded validation and persistence.

## Verification

- `make test` — PASS, including profile validation and iPad/iPhone right/left High Visibility × 135% collision geometry.
- `make ios-engine-sim-package` — PASS.
- `make ios-engine-package` — PASS; diagnostic audio-stub device package verified.
- `make ios-engine-real-package` — PASS; real-FMOD device package verified.
- Sequential simulator runs only; zero simulators left booted.

## Captures

- `02-ipad-icon-refined.png` — refined iPad gameplay layout.
- `03-ipad-saved-layouts.png` — host menu and named-layout popover.
- `04-iphone-default.png` — compact iPhone gameplay layout at 2868×1320.

Raw `simctl io screenshot` captures are retained alongside the rotated landscape evidence because the simulator exporter reports the device buffer in portrait orientation.

## Remaining physical gates

Finger reach, simultaneous touch, drag/pinch persistence, VoiceOver order, haptics, controller coexistence, audio output, thermals, frame pacing, and real-device safe areas are not claimed.
