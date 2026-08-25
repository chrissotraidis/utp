# UT99Apple touch controls and settings visual QA

final result: passed

## Visual truth and implementation

- Source image: `/Users/chrissotraidis/GitHub/utp/ref/ectopad/assets/screenshots/ectopad-chozo-ruins.jpg`
- Source implementation: `/Users/chrissotraidis/GitHub/utp/ref/ectopad/ref/sunpad/apple/ios/SunPadGameOverlay.mm` at `461de17f549d98742bc3b2d031156f79ab3eaa9d`
- User-rejected settings capture: `/var/folders/px/95pn2y3n77xb97y8k2fpmd2m0000gp/T/TemporaryItems/NSIRD_screencaptureui_eaPBA0/Screenshot 2026-08-24 at 2.19.15 PM.png`
- Final iPad gameplay: `docs/evidence/engine-startup/2026-08-24-ios-player-facing-controls-fix/09-final-current-gameplay-landscape.png`
- Final iPhone gameplay: `docs/evidence/engine-startup/2026-08-24-ios-ectopad-menu-redesign/11-iphone-controls-standard.jpeg`
- Final iPad host menu: `docs/evidence/engine-startup/2026-08-24-ios-ectopad-menu-redesign/09-ipad-native-menu-dark.jpeg`
- Final iPad touch settings: `docs/evidence/engine-startup/2026-08-24-ios-player-facing-controls-fix/05-current-settings-landscape.png`
- Final iPhone touch settings: `docs/evidence/engine-startup/2026-08-24-ios-ectopad-menu-redesign/13-iphone-touch-settings-final.jpeg`
- Full source/implementation comparison: `docs/evidence/engine-startup/2026-08-24-ios-player-facing-controls-fix/10-reference-vs-final-gameplay.jpg`
- Focused action-cluster comparison: `docs/evidence/engine-startup/2026-08-24-ios-ectopad-menu-redesign/24-reference-vs-final-right-controls.png`
- Rejected/corrected settings comparison: `docs/evidence/engine-startup/2026-08-24-ios-player-facing-controls-fix/07-rejected-vs-current-settings.png`

## Captured viewports and state

| Surface | Screenshot pixels | State |
| --- | ---: | --- |
| EctoPad source | 1200×899 | Active first-person gameplay, default touch layer |
| iPad Air 11-inch (M4) | 2360×1640 | Native landscape drawable, live Deck16 session, default touch layout |
| iPhone 17 Pro Max | 841×481 | Landscape simulator window, active UT match, Standard touch layout |
| Full comparison | 2496×900 | Source and current iPad drawable normalized to the same captured height |
| Focused comparison | 1166×720 | Source and iPad right action clusters at equal crop height |
| User-rejected settings source | 1934×1518 | Framed iPad Simulator capture; recovery dialog, leaked reference name, preset strip, duplicate sizing, and gameplay controls under the settings panel |
| Corrected settings implementation | 2360×1640 | Native iPad drawable; touch-settings diagnostic state with gameplay controls suppressed |
| Rejected/corrected settings comparison | 2442×900 | Rejected framed capture and current native drawable normalized to the same captured height; the focused settings region is compared, while surrounding recovery/game state is intentionally different |

## Iteration history

1. The original host menu was an oversized scrolling diagnostics panel, and the game rendered in a small corner beside a detached control bay. This failed the full-bleed and menu hierarchy checks.
2. The first EctoPad-derived pass restored fixed movement/aim sticks and the GameCube face hierarchy, but UT actions were scattered and weapon controls sat near movement without a coherent group.
3. A literal mapping of EctoPad's wide analog R trigger to `NEXT` weapon produced a giant binary button. This failed semantic translation and was removed immediately.
4. The final UT mapping uses EctoPad's four-direction utility group for scoreboard, previous weapon, next weapon, and use. The right cluster contains only actions used while aiming: primary fire, alternate fire, jump, crouch, and look. The separate UT menu pill stays above it.
5. The internal reference name `EctoPad` leaked into the preset UI. It was replaced with the user-facing name `Standard`; the other choices remain `Compact` and `Large`.
6. The first phone settings capture clipped the lower actions; the next placed the host ellipsis over the close button. The panel was expanded and shifted left so its close button and all settings actions are simultaneously visible.
7. The accessibility/controller menu fallback initially inherited a light popover over the dark game. It now forces the same dark native appearance as the host shell. Direct touch continues to use UIKit's attached hierarchical `UIMenu`.
8. A stale installed build still showed `EctoPad` as a preset and the rejected wide NEXT trigger. The current source was rebuilt, reinstalled, and inspected in the Simulator: the visible settings now say `Standard`, `Compact`, and `Large`; PREV/NEXT are compact utility-pad directions; and an accessibility FIRE activation entered the live match.
9. The final current-source build also includes the native direct-connect multiplayer sheet. It was relaunched into the local Deck16 bot match and recaptured with the corrected Standard controls, leaving one iPad Simulator and one client process running.
10. The latest pass removes presets from player UI entirely. The settings panel now exposes only direct choices—opacity, size, handedness, and controller auto-hide—plus arrange, save, and restore actions. Gameplay controls are hidden while the panel owns interaction, eliminating the overlapping NEXT/FIRE cluster seen under the rejected panel.
11. The settings smoke hook originally opened before the renderer overlay transition, so the renderer could hide the panel and make a fresh packaged build look stale. Auto-start smoke presentation now occurs after the host overlay is prepared. The rebuilt package shows the real in-game panel with no preset row, no leaked reference name, and no gameplay buttons underneath it.

## Final findings

- The renderer is full-bleed in landscape with no detached black control bay.
- Movement and look are fixed, differentiated sticks with visible inner thumbs.
- FIRE is dominant, ALT secondary, and JUMP/DUCK tertiary, preserving EctoPad's physical hierarchy with UT-specific labels.
- Score, use, and weapon cycling form one compact four-direction utility group beside movement; there is no giant shoulder control.
- The reference implementation name and the preset concept are absent from player-facing settings, help, and profile error copy. Internal compatibility identifiers remain unchanged for existing saved layouts.
- The source's intentional face-cluster overlap is retained only where it communicates the controller hierarchy; low-frequency UT utilities no longer compete with the aiming hand.
- Host menu, original UT menu, touch settings, and edit-layout entry points are visually distinct and use native iOS presentation.
- iPad and iPhone captures clear their safe areas, and the phone settings panel exposes every action without scrolling or obstruction.
- No actionable P0, P1, or P2 visual mismatch remains in the captured simulator states.
- Physical reach, simultaneous multi-touch, haptic feel, and hardware safe-area behavior remain outside screenshot QA and still require the physical-device gate.

## Required fidelity surfaces

- **Fonts and typography:** Player-facing controls use the native system family with bold optical weight for combat actions and restrained smaller utility text. The settings hierarchy remains legible at the captured iPad scale without wrapping or truncation.
- **Spacing and layout rhythm:** The renderer remains full bleed. Movement, utility, aim, and action zones have distinct thumb territories; the only overlap retained is the deliberate EctoPad-style face hierarchy in the combat cluster. The old wide NEXT control no longer crosses the screen or settings panel.
- **Colors and visual tokens:** The source hierarchy is preserved through dark neutral movement, yellow aim, green FIRE, red ALT, light tertiary actions, white rims, and the dark native host/settings surfaces. Contrast remains readable against both the host gradient and live Deck16 frames.
- **Image and icon fidelity:** Gameplay is the real FruCoRe/Metal-rendered engine frame. UIKit controls use supplied SF Symbols where an icon is appropriate; no screenshot slices, placeholder art, emoji, handcrafted SVG, or simulated game imagery replace visible source assets.
- **Copy and content:** The settings panel now uses direct player language: `Opacity`, `Size`, `Left-handed`, `Hide with controller`, `Arrange Controls`, `Saved Layouts`, and `Restore Default Layout`. UT actions use UT semantics—FIRE, ALT, JUMP, DUCK, SCORE, PREV, NEXT, USE, and MENU—and no player-facing settings/profile error copy exposes the reference implementation name.

## Interaction evidence

- The native host menu opened from the persistent ellipsis.
- The current host menu opened and exposed `Touch Controls` and `Arrange Controls` without a preset submenu.
- The real settings function was presented through its bounded launch diagnostic; the accessibility tree exposed every label, slider, switch, and action with no gameplay controls underneath it.
- FIRE accessibility activation produced a down/up action and entered the active match.
- Exactly one iPad Simulator and one UT99Apple process were left running in the final state.
