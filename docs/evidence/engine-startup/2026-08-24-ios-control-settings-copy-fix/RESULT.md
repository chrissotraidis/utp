# iPad touch-settings copy and layering result

**Result: PASS — Simulator UI and package evidence only.**

The player-facing touch settings no longer expose the internal EctoPad reference or any preset selector. The screen now presents direct choices for opacity, size, handedness, and controller auto-hide, followed by Arrange Controls, Saved Layouts, and Restore Default Layout.

Gameplay controls are hidden while the settings panel owns interaction. This removes the rejected state where NEXT, FIRE, ALT, movement, and other game controls remained visible under the panel.

Evidence:

- `02-settings-landscape.png` — current 2360×1640 native iPad settings capture (SHA-256 `34b37722efc788d257776a9a25f089ca0fe06ad4039b04ae6c824d72335f55e5`).
- `03-old-vs-new.png` — normalized old/current comparison; rejected state on the left, current installed build on the right.
- `07-final-source-running-landscape-cua.jpeg` — final packaged source running `DM-Deck16][` in the sole landscape iPad Simulator; compact weapon directions and no giant NEXT control (SHA-256 `08b5be19190b14241c14cb8e1cdce76da1d71e9b2b6979584f5932191a23659f`).
- `design-qa.md` — blocking visual QA report, `final result: passed`.

Verification:

- `bash Tests/test_host_state_and_data_menu.sh` passed.
- `make test` passed.
- `make ios-engine-sim-real-package` rebuilt and verified the transformed real-FMOD Simulator package.
- `make ios-engine-real-package` rebuilt and verified the real-FMOD iPhoneOS candidate.
- The package verifier now rejects accidental `UT99Data/UT99Data` nesting; every package target merges runtime contents idempotently and both rebuilt candidates pass this guard.
- The current no-game-data diagnostic IPA is `build/local-package/UT99Apple-diagnostic-ad-hoc.ipa`, SHA-256 `b6f93be8fc19de97dba7c9229e1bdc9ff2ae81f90b4bcf73dbf27c72b59d4625` (`installable_on_stock_ios=false` without a development team).
- Computer Use inspected the current accessibility tree: all seven settings actions/controls were exposed, no gameplay touch actions were present while the panel was open, and one iPad Simulator/client remained active.

This does not promote physical touch, reach, multi-touch, VoiceOver traversal, or iPhone hardware layout gates.
