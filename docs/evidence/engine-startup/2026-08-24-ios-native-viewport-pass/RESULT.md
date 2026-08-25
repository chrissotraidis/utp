# Native 4:3 viewport pass

## Result

The renderer layout was corrected at the SDL/UIKit boundary. The host now keeps the SDL window attached to the full landscape scene but constrains the renderer root to a native 4:3 game rect, left-aligned and vertically centered. The Apple graphics profile also derives a 4:3 `SDLDrv.SDLClient` mode from the active screen instead of inheriting the macOS 1280×800 desktop mode.

The final one-simulator run reached the original Deck16 match and the latest engine stdout contains:

- `USDLViewport::ResizeViewport(1024, 768)`
- `SDLDrv: Window Point Size 1024x768`
- `Game engine initialized`
- `Entering main loop.`

The captured raw simulator image shows the intended composition: a 4:3 UT canvas on the left and a black right-side GoldenPad control bay. The raw `simctl` image retains Apple's rotated exporter orientation; the pixel geometry is authoritative for the game/control split, while the earlier GUI capture remains authoritative for device orientation.

## Changes

- `SDL_uikitviewcontroller.m`: publish the aspect-preserving renderer frame rather than the legacy 512×384 point request.
- `SDL_uikitmetalview.m`: remove the compensating view transform that caused low-resolution/stretch behavior.
- `UT99EngineBridge.swift`: normalize the SDL client fullscreen/windowed mode to a device-derived 4:3 size.

## Scope

- `make ios-engine-sim-package` — passed.
- One iPad Air 11-inch (M4) simulator used per run; cleaned afterward.
- Physical-device resolution, safe-area behavior, and performance remain unproven.
