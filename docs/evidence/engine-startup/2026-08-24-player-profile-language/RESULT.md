# Player-facing touch profile language and iPad runtime verification

Date: 2026-08-24

## Result

PASS for the current Simulator/package scope. The internal reference-project name is no longer presented as a player preset, written to new preferences or exported in `.ut99touch` documents, or emitted by current runtime touch diagnostics.

- Existing `ectoPad` and `goldenPad` profile identifiers remain accepted only as legacy import aliases. Validation canonicalizes either value to `standard` before persistence or export.
- The Touch Controls panel has no preset selector. It exposes only Opacity, Size, Left-handed, Hide with controller, Arrange Controls, Saved Layouts, and Restore Default Layout.
- Opening the settings panel suppresses gameplay controls rather than layering controls behind the panel.
- The default iPad layout uses compact chevron buttons for previous/next weapon in the four-way utility pad. There is no wide or oversized NEXT surface.
- Exactly one iPad Air 11-inch (M4) Simulator and one `UT99Apple` process were used at a time.

## Runtime evidence

The current real-FMOD Simulator package launched with:

```text
-UT99AutoStart -UT99AutoMatch -UT99TouchDefaultSmokeTest
```

The run reported:

```text
UT99 touch visual smoke profile=standard userScale=1.0
UT99 host Metal first frame presented=true status=4 drawable=2360x1640
UT99 Metal drawable points 1180x820 scale 2.00 pixels 2360x1640
Game engine initialized
Entering main loop.
```

`standard-touch-gameplay.jpeg` is the authoritative Simulator-GUI landscape capture of the live full-resolution game and current control placement. `touch-controls-settings-clean.jpeg` records the packaged settings panel with no preset row or reference-project terminology and no gameplay controls underneath it.

Screenshot SHA-256:

```text
f31f1edf852cc4b5f1d99ca7bfe5d48eafbbda42579e5f35d6b9648400df8010  standard-touch-gameplay.jpeg
eef520dcd9a7dc2036df0d15b2e7dabe373a68dc8ae854c94124715329c61187  touch-controls-settings-clean.jpeg
```

Both screenshots are 850×672 Simulator-window captures. The rendered game drawable is independently logged at 2360×1640 pixels.

## Build and regression verification

- `make test`: PASS
- `make ios-engine-sim-real-package`: PASS
- `make ios-engine-real-package`: PASS
- Simulator host SHA-256: `d3a920945f7e83a2f6214f2ac318879b2d09bfa02993aa10fedde008129c628d`
- iPhoneOS host SHA-256: `26ea0b5e5644f5205b3a6ade306b9c6effaa877e3ea7130f536cbf48261709d6`

This is visual, accessibility-tree, migration, and packaged-runtime evidence. It does not promote physical finger reach, simultaneous multi-touch, haptics, or physical iPhone/iPad behavior.
