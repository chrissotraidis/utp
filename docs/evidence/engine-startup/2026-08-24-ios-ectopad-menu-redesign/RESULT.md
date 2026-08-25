# EctoPad-derived menu and touch redesign result

Result: simulator visual QA passed; diagnostic iPhoneOS package passed; physical-device gate blocked.

## Completion-audit follow-up

- Removed the unreachable pre-native custom host-menu implementation and its stale test assertions. The active paths remain UIKit `UIMenu`, dark action sheet, and the compact responsive Touch Control Settings panel.
- Added and exercised the PRD-required `make bootstrap`, `make mac-baseline`, `make mac-hosted-harness`, and `make diagnostics` command surface.
- A fresh real-FMOD Simulator rebuild exposed a load-time regression that static package verification had missed: the transformed macOS FMOD image referenced `/System/Library/Frameworks/AudioUnit.framework/AudioUnit`, which is not a loadable iOS runtime image. `17-real-fmod-audiounit-load-failure.jpeg` records the black host-only failure.
- The transform now maps that legacy dependency to `/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox`, which exports the AudioUnit symbols on iOS. Package verification rejects the invalid path and also rejects AudioUnit imports without AudioToolbox.
- The repaired real-FMOD Simulator package reaches host state `Running`, original engine entry, and visible Deck16 rendering. `18-current-source-real-fmod-running.png` is the authoritative Simulator-window capture (SHA-256 `7a70dcb6fbe463e16e3eb51014f987530365c5faa8fd430b77730534bcea3e43`).
- The repaired real-FMOD iPhoneOS package builds and passes the strengthened package verifier; embedded FMOD SHA-256 is `0253f8b3232253b25b82431c3cdc8a9e19d7eb771820845da557ea984ce0cd42`. Physical load/audio still cannot be claimed without hardware.

## Runtime evidence

- `14-ipad-controls-final-running.jpeg`: final Standard layout in an active iPad Air 11-inch match.
- `11-iphone-controls-standard.jpeg`: final Standard layout in an active iPhone 17 Pro Max match.
- `09-ipad-native-menu-dark.jpeg`: compact dark native host-menu presentation.
- `07-ipad-touch-settings-standard.jpeg`: iPad touch settings with user-facing Standard/Compact/Large presets.
- `13-iphone-touch-settings-final.jpeg`: phone panel with every setting and close action visible.
- `15-reference-vs-ipad-final.jpg`: EctoPad source and final iPad implementation in one comparison image.
- `16-focused-right-controls-comparison.jpg`: equal-size source/implementation action-cluster comparison.
- `19-ipad-settings-standard-no-reference-name.png`: corrected installed settings screen with Standard/Compact/Large player-facing names.
- `21-ipad-active-match-corrected-controls.png`: current-source real-FMOD match after live FIRE activation.
- `22-reference-vs-final-corrected.png`: current source and EctoPad normalized to one comparison canvas.
- `23-old-vs-corrected-settings.png`: rejected stale build beside the corrected installed build.
- `24-reference-vs-final-right-controls.png`: focused final action-cluster comparison.
- `25-final-single-ipad-runtime.png`: final current-source active match left running as the sole simulator/client process (SHA-256 `bf42549038571341efbf5d5fbdec45a9781128eec8f568b49b37adb314da6795`).
- `29-final-source-multiplayer-enabled-bot-match.png`: latest current-source active match after the native multiplayer flow was added, with Standard controls and compact PREV/NEXT utility directions (SHA-256 `3364b8f7cbde9763de11ed3516445922a8f45fa137b0bfef38b3f7775c2bc49d`). This supersedes `25` as the final running-state capture.

Only one simulator was booted at a time. The phone was shut down before the final iPad run.

## Corrections proven by iteration

- Removed the rejected giant NEXT trigger. PREV/NEXT now occupy left/right positions in the compact utility D-pad with SCORE/USE above/below.
- Removed `EctoPad` from user-facing preset names; the default is `Standard`.
- Removed the remaining reference-name leakage from player-facing control help and profile copy, and added a regression check that permits it only in internal logging/compatibility paths.
- Replaced the oversized custom diagnostics menu in all active paths with UIKit-native menu/action-sheet presentation.
- Forced native fallback menus into dark appearance.
- Expanded and shifted the phone settings panel so it neither clips actions nor hides its close button behind the persistent ellipsis.

## Verification

- `make test`: passed, including doctor, physical readiness, G2 script, package contract, Mach-O audit, data transactions, recovery, diagnostics archive, touch configuration/profile, and iPad/iPhone/southpaw geometry.
- Real simulator builds: passed for the final source.
- `UT99_PACKAGE_MODE=diagnostic make package-local`: passed after explicitly linking zlib and removing a `pipefail`/SIGPIPE archive-list bug.
- IPA archive CRC: passed.
- Contains user game data: false.
- Runtime JIT required: false.

Diagnostic artifact (not installable on stock iOS without Apple signing):

- IPA: `build/local-package/UT99Apple-diagnostic-ad-hoc.ipa`
- Manifest: `build/local-package/manifest-diagnostic.json`
- IPA SHA-256: `44dc5a6ac0b98908b73d39217607f9691d2d262fa000b3bf7141891d7cdd3e39`
- App binary SHA-256: `42c524cdc67ec784b42e58e6c9c774209985803e55e67b5c0ce3225e8726b454`
- Engine SHA-256: `ee4e01192ce4caf935d3d9315059eee956bbdcf27016f7f09a1933cd5ca9eaeb`

## Remaining gate

G2 cannot be promoted without exactly one trusted Developer Mode iPhone/iPad, an Apple Development identity, and a configured development team. Physical finger-only play, simultaneous multi-touch, reach, haptics, audio, controller/keyboard/mouse, Files/share handoff, rotation, thermals, and frame pacing remain unproven.
