# Touch material and interaction audit — 2026-08-24

## Result

The current iPad build replaces the rejected settings/preset surface and ambiguous controller-style overlap with a player-facing UT touch layer. `EctoPad` remains only an internal reference/import term. Gameplay exposes a fixed movement stick, a fixed aim stick, independent FIRE/ALT/JUMP/DUCK targets, compact SCORE/PREV/NEXT/USE directions, original Unreal `MENU`, and a separate host ellipsis. Every right-side gameplay frame is disjoint in the iPad geometry test.

The overlay now explicitly permits the movement and aim pan recognizers to run simultaneously, enables multiple touch on the overlay, keeps editor pan/pinch arbitration exclusive, and uses the reference's 0.92 pressed scale. This fixes a source-level two-thumb arbitration defect; a physical two-finger pass is still required before claiming hardware multi-touch.

## Audited steps

1. **Pristine reference capture — healthy.** Compared the current iPad composition with EctoPad commit `461de17f549d98742bc3b2d031156f79ab3eaa9d` and its source screenshot. The reference checkout remains clean.
2. **Player-facing settings — healthy in Simulator.** The live `Touch Controls` panel contains Opacity, Size, Left-handed, Hide with controller, Arrange Controls, Saved Layouts, and Restore Default Layout. It contains no preset row or reference-project name, and gameplay controls are hidden while it is open.
3. **Gameplay geometry — corrected and healthy in Simulator.** The giant NEXT trigger is absent. PREV/NEXT are compact utility directions. The reference's physical A/B/X/Y overlap is deliberately not copied to UT: FIRE, ALT, JUMP, DUCK, and aim now have non-intersecting frames while retaining the reference size hierarchy and thumb arc.
4. **Interaction source audit — defect found and fixed.** UIKit recognizers are exclusive unless their delegate opts in. Movement and aim now explicitly allow only their gameplay pair to recognize simultaneously. Press feedback now matches the reference's 0.92 scale.
5. **Rebuilt runtime — healthy in bounded Simulator evidence.** The real-FMOD Simulator package reaches the original Deck16 renderer at 1180×820 UIKit points / 2360×1640 Metal pixels. Assistive FIRE enters first-person play with the separated controls visible. Exactly one iPad Simulator and one UT99Apple process remain active.

## Strengths retained

- Solid translucent controller-color faces, restrained white rims, fixed sticks, and size hierarchy remain visibly derived from the pristine reference.
- Labels and actions use Unreal Tournament language; no user needs to know the implementation reference.
- FIRE remains dominant, ALT secondary, JUMP/DUCK tertiary, and weapon cycling is a compact directional utility rather than a giant shoulder.
- The full-bleed game surface is not resized to make a detached control bay.
- Action buttons expose labels, hints, and stable accessibility identifiers in the Simulator accessibility tree.

## Remaining UX and accessibility risks

- Simulator automation can activate buttons and perform sequential drags, but it cannot authoritatively reproduce two simultaneous physical thumbs. Source policy, compilation, and single-stick response pass; physical move-plus-look remains open.
- Movement and aim sticks are not currently exposed as accessibility elements. Button labels are present, but full VoiceOver traversal is not claimed.
- Physical reach, occlusion under fingers, haptics, safe areas, and preferred scale require iPhone/iPad hardware.

## Verification

- `make test` — PASS, including tablet/phone/southpaw containment and pairwise non-overlap regression coverage.
- `make ios-engine-sim-real-package` — PASS.
- `make ios-engine-real-package` — PASS; ad-hoc device candidate remains non-installable without an Apple Development identity/team.
- Simulator executable SHA-256: `db41d0d8a56581ecefd443ed868c8aa4c2632ec1f4c5dd9589432068031566ea`.
- iPhoneOS executable SHA-256: `579502641c0617e6286ca69f941513fdb147220160ae41ada4608da1f1330214`.

## Local visual evidence

- `06-right-controls-comparison.png` — prior current/reference material comparison, SHA-256 `e914f6eec92ed98ede5f7d40d9c575104d917cad46b5a2c0d627bb13ef8fda1e`.
- `11-current-touch-settings.jpeg` — corrected player-facing settings from the final rebuilt package, SHA-256 `8d7f2bca23d2c042b3b5bf5af0819e8614f7948c0601a34eae8577cded51db19`.
- `14-final-source-gameplay.jpeg` — final-source ready-state geometry, SHA-256 `20f12095c977d394abba0b32b92faca9067199adc7128b69427d646bf028ce9f`.
- `15-final-source-live-play.jpeg` — assistive FIRE entered live first-person play in the final-source package, SHA-256 `9e132935f7b8581dd383cceaddd32daeaa0e91e4701405f2219c4a7fa00febca`.

Raw screenshots remain ignored local evidence; this ledger is tracked.
