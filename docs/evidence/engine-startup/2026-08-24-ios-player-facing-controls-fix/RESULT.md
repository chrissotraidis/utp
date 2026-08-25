# Player-facing touch controls correction

**Result: PASS — iPad Simulator visual and packaged-build slice.**

The rejected installed state exposed `EctoPad` as a preset, duplicated size configuration, left gameplay controls active beneath settings, and mapped next-weapon to an oversized trigger. The current player-facing settings contain no preset concept or reference-project name. They expose only direct options—Opacity, Size, Left-handed, Hide with controller, Arrange Controls, Saved Layouts, and Restore Default Layout—and suppress gameplay controls while the panel owns interaction.

The gameplay layer retains the reference's two-thumb hierarchy without copying its game-specific bindings: a fixed movement stick, compact four-way UT utility group, separate menu tier, dominant primary fire, smaller alternate fire, jump/crouch actions, and a fixed look stick. Previous/next weapon are compact left/right directions; the rejected giant NEXT control is absent.

The settings smoke hook was also corrected so auto-start presents the panel only after the renderer overlay is prepared. This ensures the automated screenshot validates the installed in-game state rather than an early panel that the renderer immediately covers.

## Evidence

- `05-current-settings-landscape.png` — current real-FMOD packaged build with the in-game settings panel, no presets, no leaked reference name, and no gameplay-control overlap (SHA-256 `fc09d2754adeb17f79ed14525c3c239d5e88c8ab96e35a430221988da04332a9`).
- `07-rejected-vs-current-settings.png` — rejected state on the left and current settings region on the right (SHA-256 `24939fed1875579aace8a8f27454662a9fd0bec961cca98b87b9be82443354ae`).
- `09-final-current-gameplay-landscape.png` — final current-source gameplay layer left running in the sole iPad Simulator (SHA-256 `967a0fe6d77aaea52f9bbde1020ab6fd5e7ae3419d304c6e2b9c87eb64bbac40`).
- `10-reference-vs-final-gameplay.jpg` — EctoPad source and current UT99 layout normalized into one visual comparison (SHA-256 `944104dd4f9f250fb7cc1a64b84000e63634a87136e4458d3b875757732b2053`).

## Verification

- Real-FMOD Simulator and iPhoneOS device packages rebuilt and passed `tools/verify_ios_package.sh`.
- Simulator host binary SHA-256: `350a97f4c7150da72ffef66fcc86e8fdc644c06cb5c03a3add2a7d306215d121`.
- Device host binary SHA-256: `8b238aa62863cf3d83b21b91ee27742a5be1967625e59015105bfb565ddf5a6a`.
- The full `make test` suite passed, including host-state/menu and touch configuration/profile/geometry coverage.
- One iPad Air 11-inch (M4) Simulator and one `UT99Apple` process remain active.
- This is Simulator visual evidence, not physical-device touch, reach, haptics, or multi-touch proof.
