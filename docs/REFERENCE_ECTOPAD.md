# EctoPad touch reference

EctoPad is the active visual and interaction baseline for UTP's iPhone and iPad touch interface. GoldenPad is retained only as historical context.

## Pinned source

- Repository: ignored local checkout under `ref/ectopad`
- Commit: `461de17f549d98742bc3b2d031156f79ab3eaa9d`
- Primary implementation: `ref/sunpad/apple/ios/SunPadGameOverlay.mm`
- Primary screenshot: `assets/screenshots/ectopad-chozo-ruins.jpg` (1200×899)
- Source SHA-256: `6fa2b9758ac7e36836a0b0dca254e28993f79bfe6100ea1ce860ed6d985d2a8e`
- Screenshot SHA-256: `8674dfb641843ca723bc138d045357834937088d97116abf1d1fe7baf563c7cf`

The reference repository is read-only. No EctoPad source or game data is copied into the app package.

## Interaction language

- Fixed left movement stick with a dark translucent base and light thumb.
- Fixed right camera stick with a yellow base and brighter yellow thumb.
- Solid translucent controller-color action faces, two-point white rim, clear pressed scale.
- A dominant primary action, a smaller secondary action, compact light X/Y actions, a compact D-pad, and a separate START pill.
- Controls are arranged as two reachable thumb zones without detached panels.
- The menu surface remains small, safe-area aware, and visually subordinate to gameplay.

## Measured EctoPad source geometry

Coordinates are normalized to the safe gameplay rectangle; dimensions are reference points before profile scaling.

| Archetype | Center x | Center y | Size |
| --- | ---: | ---: | ---: |
| Move stick | 0.1310395 | 0.7905895 | 172×172 |
| Camera stick | 0.9062958 | 0.8583247 | 112×112 |
| A | 0.8916545 | 0.7409514 | 104×104 |
| B | 0.8360176 | 0.8092037 | 76×76 |
| X | 0.9593704 | 0.7156153 | 62×62 |
| Y | 0.9542460 | 0.7869700 | 62×62 |
| START | 0.8967789 | 0.5780765 | 116×62 |
| D-pad | 0.2686676 | 0.7947260 | four 48×48 directions |

The phone layout is adapted from the same hierarchy around an 800×380 reference canvas and UIKit safe areas; it is not a shrunk tablet rail.

## UT-adapted iPad geometry

The shipped iPad preset keeps EctoPad's exact sizes and controller hierarchy but opens the centers enough for distinct UT actions. EctoPad's physical-controller cluster intentionally overlaps A/B/X/Y; separate FIRE/ALT/JUMP/DUCK touch targets need a measurable finger gap.

| UT action | Center x | Center y | Size |
| --- | ---: | ---: | ---: |
| Move | 0.1310395 | 0.7905895 | 172×172 |
| Look/aim | 0.9062958 | 0.8400000 | 112×112 |
| FIRE | 0.8916545 | 0.6700000 | 104×104 |
| ALT | 0.8000000 | 0.7000000 | 76×76 |
| JUMP | 0.9650000 | 0.5900000 | 62×62 |
| DUCK | 0.8100000 | 0.5900000 | 62×62 |
| MENU | 0.8967789 | 0.4700000 | 116×62 |
| Utility pad | 0.3100000 | 0.7947260 | four 48×48 directions |

The default composed opacity is EctoPad's source value, `0.82`. Both sticks render a fixed 42%-diameter inner thumb, so a layout pass cannot collapse them into ambiguous solid buttons.

## UT99 semantic adaptation

EctoPad's GameCube/Metroid meanings are not copied. UTP uses the reference's physical hierarchy as follows:

| EctoPad archetype | UT99 action |
| --- | --- |
| Left stick | Move/strafe |
| Camera stick | Look/aim |
| A | Primary fire |
| B | Alternate fire |
| X | Jump |
| Y | Crouch/duck |
| D-pad up | Scores |
| D-pad down | Use/activate |
| D-pad left/right | Previous/next weapon |
| START | Original Unreal menu |

The separate sliders icon opens the native host settings/menu.

## Acceptance method

For each visual iteration, capture one EctoPad reference and one current UTP frame, compare their control zones and hierarchy together, then verify iPad, iPhone, and left-handed geometry. The round iPad controls must have no intersecting finger targets. Simulator evidence is partial; G7 still requires a physical touch-only bot match.
