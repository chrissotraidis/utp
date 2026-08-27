#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

rg -q 'case startingEngine = "StartingEngine"' Sources/UT99Host/GameViewController.swift
rg -q 'case running = "Running"' Sources/UT99Host/GameViewController.swift
rg -q 'case stoppingEngine = "StoppingEngine"' Sources/UT99Host/GameViewController.swift
rg -q 'case crashed = "Crashed"' Sources/UT99Host/GameViewController.swift
rg -q 'case safeMode = "SafeMode"' Sources/UT99Host/GameViewController.swift
rg -q 'blocked duplicate engine start' Sources/UT99Host/GameViewController.swift
rg -q 'Previous Session Interrupted' Sources/UT99Host/GameViewController.swift
rg -q 'Start in Safe Mode' Sources/UT99Host/GameViewController.swift
rg -Fq 'transition(to: .ready, reason: "recovery deferred by player")' Sources/UT99Host/GameViewController.swift
rg -Fq 'UT99 onboarding state=%@ landing=%@ hidden=%@ frame=%@ window=%@' Sources/UT99Host/GameViewController.swift
rg -q 'runtimeRecovery\.beginSession' Sources/UT99Host/GameViewController.swift
rg -q 'runtimeRecovery\.recordFailure' Sources/UT99Host/GameViewController.swift
rg -q 'runtimeRecovery\.finishCleanly' Sources/UT99Host/GameViewController.swift
rg -q 'restoreHostAfterEngineExit' Sources/UT99Host/GameViewController.swift
rg -q 'onExit: \(\(Int32\) -> Void\)\?' Sources/UT99Host/UT99EngineBridge.swift
if rg -q 'buildFullHostMenu|private var hostMenu: UIView\?|code after .return. will never be executed' Sources/UT99Host/GameViewController.swift; then
    echo "Legacy custom host menu implementation is still present" >&2
    exit 1
fi
rg -q 'appendingPathComponent\("Frameworks", isDirectory: true\)' Sources/UT99Host/GameViewController.swift
rg -q 'UT99DataImportTransaction\.commit' Sources/UT99Host/GameViewController.swift
rg -q 'Export Installed Manifest' Sources/UT99Host/GameViewController.swift
rg -q 'recoverInterruptedCommit' Sources/UT99Host/GameViewController.swift
rg -q 'com.ut99apple.data-import' Sources/UT99Host/GameViewController.swift
rg -q 'Cancel game data import' Sources/UT99Host/GameViewController.swift
rg -Fq 'GET GAME DATA' Sources/UT99Host/GameViewController.swift
rg -Fq 'PLAY OFFLINE' Sources/UT99Host/GameViewController.swift
rg -Fq 'PLAY ONLINE' Sources/UT99Host/GameViewController.swift
rg -Fq 'Accept Terms & Download' Sources/UT99Host/GameViewController.swift
rg -Fq 'Get Verified Game Data…' Sources/UT99Host/GameViewController.swift
rg -Fq -- '-UT99OnboardingSmokeTest' Sources/UT99Host/GameViewController.swift
rg -Fq 'gameDataDownload?.cancel()' Sources/UT99Host/GameViewController.swift
rg -Fq 'self?.startEngine()' Sources/UT99Host/GameViewController.swift
rg -Fq 'self?.showMultiplayerInfo()' Sources/UT99Host/GameViewController.swift
rg -Fq 'let shouldHide = !engineActive' Sources/UT99Host/GameViewController.swift
if rg -Fq 'let resume = action("Resume Game", symbol: "play.fill") { }' Sources/UT99Host/GameViewController.swift; then
    echo "Inactive host menu still contains the old no-op Resume action" >&2
    exit 1
fi
rg -q 'phase: \.installing' Sources/UT99Host/UT99DataImporter.swift
rg -q -- '-UT99TouchEditorSmokeTest' Sources/UT99Host/GameViewController.swift
rg -q -- '-UT99TouchDefaultSmokeTest' Sources/UT99Host/GameViewController.swift
rg -q -- '-UT99DiagnosticsExportSmokeTest' Sources/UT99Host/GameViewController.swift
rg -q -- '-UT99G2SmokeTest' Sources/UT99Host/GameViewController.swift
rg -q -- '-UT99G2RunID=' Sources/UT99Host/GameViewController.swift
rg -q 'UUID\(uuidString:' Sources/UT99Host/GameViewController.swift
rg -q 'commandBuffer\.present\(drawable\)' Sources/UT99Host/GameViewController.swift
rg -q 'UT99-host-metal-smoke\.log' Sources/UT99Host/GameViewController.swift
rg -q 'UT99 G2 host smoke started' Sources/UT99Host/GameViewController.swift
rg -q 'UT99 G2 host smoke finished' Sources/UT99Host/GameViewController.swift
rg -Fq '.playAndRecord,' Sources/UT99Host/GameViewController.swift
rg -Fq '.defaultToSpeaker' Sources/UT99Host/GameViewController.swift
rg -q -- '-UT99TouchConfigurationSmokeTest' Sources/UT99Host/GameViewController.swift
rg -q -- '-UT99TouchProfileSmokeTest' Sources/UT99Host/GameViewController.swift
rg -q 'UT99DiagnosticsArchive\.write' Sources/UT99Host/GameViewController.swift
rg -Fq 'localized="$baseline/SystemLocalized/int"' tools/prepare_embedded_runtime_data.sh
rg -q 'find "\$localized".*-name.*\.int.*-exec cp' tools/prepare_embedded_runtime_data.sh
rg -Fq 'embeddedLocalization' Sources/UT99Host/GameViewController.swift
rg -Fq 'pathExtension.lowercased() == "int"' Sources/UT99Host/GameViewController.swift
rg -Fq 'UT99 bundled localization backfilled files=%lu' Sources/UT99Host/GameViewController.swift
rg -q 'Test Layout' Sources/UT99Host/GameViewController.swift
rg -q 'Visible Controls & Handedness' Sources/UT99Host/GameViewController.swift
rg -q 'Saved Layouts' Sources/UT99Host/GameViewController.swift
rg -Fq 'components.scheme?.lowercased() == "unreal"' Sources/UT99Host/GameViewController.swift
rg -Fq 'engineBridge.openStockServerBrowser(originalMenuAlreadyOpen: false)' Sources/UT99Host/GameViewController.swift
rg -Fq 'originalMenuAlreadyOpen: Bool = false' Sources/UT99Host/UT99EngineBridge.swift
rg -q 'UT99TouchProfileStore\.decode' Sources/UT99Host/GameViewController.swift
rg -q 'lookAcceleration' Sources/UT99Host/UT99TouchConfiguration.swift
rg -q 'movementDeadZone' Sources/UT99Host/UT99EngineBridge.swift
rg -q 'safeAreaGuide\.isHidden = !active' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'layoutDoneButton.leadingAnchor.constraint(equalTo: layoutBanner.trailingAnchor' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'private final class UT99TouchActionButton: UIButton' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'case primary, secondary, utility, dPad, start' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'symbol: symbol(for: action)' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'case standard' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'case .primaryFire, .leftPrimaryFire: "scope"' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'frame("leftPrimaryFire"' Sources/UT99Host/UT99TouchLayoutGeometry.swift
rg -Fq 'case .primaryFire, .leftPrimaryFire: pushMouseButton' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'override func accessibilityActivate() -> Bool' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'moveRing.isHidden = false' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'case .standard, .ectoPad, .goldenPad: 0.82' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'let thumbDiameter = resolvedDiameter * 0.42' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'let compact = visualRole == .dPad' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'final class GoldenPadTouchOverlay: UIView, UIGestureRecognizerDelegate' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'isMultipleTouchEnabled = true' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'movePan.delegate = self' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'CGAffineTransform(scaleX: 0.92, y: 0.92)' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'movePad.accessibilityIdentifier = "ut99.touch.move"' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'movementAccessibilityAction(name: "Stop movement", value: .zero)' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'value: accessibilityMovement' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'accessibilityMovement = .zero' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq '? "Stopped"' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'UIApplication.shared.connectedScenes' Sources/UT99Host/GameViewController.swift
if rg -Fq 'UIApplication.shared.windows' Sources/UT99Host/GameViewController.swift; then
    echo "Deprecated process-wide window lookup returned" >&2
    exit 1
fi
if rg -q 'moveThumb\.(widthAnchor|heightAnchor)' Sources/UT99Host/GoldenPadTouchOverlay.swift; then
    echo "stick thumbs must use explicit bounds after reference-frame placement" >&2
    exit 1
fi
if rg -q 'yellow camera stick|private let lookSurface' Sources/UT99Host/GoldenPadTouchOverlay.swift; then
    echo "Obsolete fixed look stick returned" >&2
    exit 1
fi
rg -Fq '0.8898305085' Sources/UT99Host/UT99TouchLayoutGeometry.swift
rg -Fq 'private final class UT99HostMenuButton: UIButton' Sources/UT99Host/GameViewController.swift
rg -Fq 'menuButton.onAccessibilityActivate' Sources/UT99Host/GameViewController.swift
rg -Fq 'menuButton.showsMenuAsPrimaryAction = false' Sources/UT99Host/GameViewController.swift
rg -Fq 'private var hostMenuPanel: UIVisualEffectView?' Sources/UT99Host/GameViewController.swift
rg -Fq '"USE GAMEPLAY CONTROLS" : "USE MENU CONTROLS"' Sources/UT99Host/GameViewController.swift
rg -Fq 'hostPanelButton("ESCAPE / UT MENU"' Sources/UT99Host/GameViewController.swift
rg -Fq 'keyboardIsOpen ? "CLOSE KEYBOARD" : "OPEN KEYBOARD"' Sources/UT99Host/GameViewController.swift
rg -Fq 'hostPanelButton("TRY NORMAL START"' Sources/UT99Host/GameViewController.swift
rg -Fq 'hostPanelButton("START IN SAFE MODE"' Sources/UT99Host/GameViewController.swift
rg -Fq 'RECOVERY DIAGNOSTICS' Sources/UT99Host/GameViewController.swift
rg -Fq 'hostPanelButton("EXPORT LOGS"' Sources/UT99Host/GameViewController.swift
rg -Fq 'self?.exportDiagnostics()' Sources/UT99Host/GameViewController.swift
rg -Fq 'UT99 support log archive ready' Sources/UT99Host/GameViewController.swift
rg -Fq 'private func supportLogEntries()' Sources/UT99Host/GameViewController.swift
rg -Fq 'maximumBytes: 524_288' Sources/UT99Host/GameViewController.swift
rg -Fq 'FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]' Sources/UT99Host/GameViewController.swift
rg -Fq 'UTP-Logs-Latest.zip' Sources/UT99Host/GameViewController.swift
rg -Fq 'Files → On My iPad → UTP' Sources/UT99Host/GameViewController.swift
rg -Fq 'private func hostPanelMessage' Sources/UT99Host/GameViewController.swift
rg -Fq 'hostPanelButton("REPORT A PROBLEM"' Sources/UT99Host/GameViewController.swift
rg -Fq 'https://github.com/chrissotraidis/utp/issues/new' Sources/UT99Host/GameViewController.swift
rg -Fq 'Attach UTP-Logs-Latest.zip from Files' Sources/UT99Host/GameViewController.swift
rg -Fq 'let normalVerifiedLaunch = recoveredSession == nil && isGameDataReady()' Sources/UT99Host/GameViewController.swift
rg -Fq 'if normalVerifiedLaunch { showLaunchTransition() }' Sources/UT99Host/GameViewController.swift
rg -Fq 'launchTransitionView?.removeFromSuperview()' Sources/UT99Host/GameViewController.swift
if rg -Fq 'hostPanelButton("RESUME GAME"' Sources/UT99Host/GameViewController.swift; then
    echo "No-op Resume Game host action returned" >&2
    exit 1
fi
rg -Fq 'handler()' Sources/UT99Host/GameViewController.swift
if rg -Fq 'DispatchQueue.main.async(execute: handler)' Sources/UT99Host/GameViewController.swift; then
    echo "Host-panel actions must not be deferred onto the main GCD queue" >&2
    exit 1
fi
rg -Fq 'prepareGameplayForTouchLayoutEditing()' Sources/UT99Host/GameViewController.swift
rg -Fq 'setTouchInputEnabled(true)' Sources/UT99Host/GameViewController.swift
if rg -Fq 'menuButton.menu = buildHostMenu()' Sources/UT99Host/GameViewController.swift; then
    echo "Warp-prone native three-dot UIMenu was reattached" >&2
    exit 1
fi
rg -Fq 'guard rootName.contains("SDL") else { return }' Sources/UT99Host/GameViewController.swift
rg -Fq 'SettingsKey.audioEnabled: true' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'SettingsKey.audioDefaultMigration' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq '#if targetEnvironment(simulator)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'let audioEnabled = !safeMode && CommandLine.arguments.contains("-UT99AudioEnabled")' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'title.text = "Controls & Display"' Sources/UT99Host/GameViewController.swift
rg -Fq 'touchSettingsRow(title: "Size", control: size)' Sources/UT99Host/GameViewController.swift
rg -Fq 'touchSettingsRow(title: "Look sensitivity", control: lookSensitivity)' Sources/UT99Host/GameViewController.swift
rg -Fq 'touchSettingsRow(title: "Move sensitivity", control: moveSensitivity)' Sources/UT99Host/GameViewController.swift
rg -Fq 'layoutSizeSlider.accessibilityLabel = "Selected control size"' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'moveRing.isHidden = true' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'moveAnchor = point' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'lookPad.accessibilityIdentifier = "ut99.touch.lookStick"' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq '@objc private func publishFloatingLook()' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'lookPad.isHidden = active' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'button.isHidden = active' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'guard !CommandLine.arguments.contains("-UT99AutoStart") else { return }' Sources/UT99Host/GameViewController.swift
rg -Fq 'CommandLine.arguments.contains("-UT99TouchSettingsPanelSmokeTest"),' Sources/UT99Host/GameViewController.swift
rg -Fq 'touchOverlay.isHidden = true' Sources/UT99Host/GameViewController.swift
if rg -q 'Layout Preset|touchPresetChanged|showTouchProfiles|Choose a control size preset|UISegmentedControl\(items:' Sources/UT99Host/GameViewController.swift; then
    echo "Internal touch-layout terminology leaked into the player settings UI" >&2
    exit 1
fi
rg -Fq 'private final class UT99GameSurfaceInputView: UIView' Sources/UT99Host/GameViewController.swift
rg -Fq 'location: self.rendererPoint(fromHostPoint: location)' Sources/UT99Host/GameViewController.swift
rg -Fq 'gameSurfaceInputView.onLook' Sources/UT99Host/GameViewController.swift
rg -Fq '@objc private func pointerHovered' Sources/UT99Host/GameViewController.swift
rg -Fq 'onPointer?(location, nil, true)' Sources/UT99Host/GameViewController.swift
rg -Fq 'inputMode == .gameplayLook && location.x < bounds.midX' Sources/UT99Host/GameViewController.swift
rg -Fq 'onLook?(value, true)' Sources/UT99Host/GameViewController.swift
rg -Fq 'touchOverlay.setMenuInteractionActive(active)' Sources/UT99Host/GameViewController.swift
rg -Fq 'GCSupportsControllerUserInteraction' Sources/UT99Host/Info.plist
rg -Fq 'GCSupportedGameControllers' Sources/UT99Host/Info.plist
if rg -Fq 'controllerPressFallbackActive' Sources/UT99Host/GameViewController.swift; then
    echo "Controller fallback presses must not hide or flash the touch overlay" >&2
    exit 1
fi
rg -Fq 'engineBridge.publishMenuCursorClick(pressed: pressed)' Sources/UT99Host/GameViewController.swift
rg -Fq 'prepareControllerFromActiveEvent()' Sources/UT99Host/GameViewController.swift
rg -Fq 'configureAvailableControllers(reason: "active responder event")' Sources/UT99Host/GameViewController.swift
rg -Fq 'private var activeControllerFallbackPresses: [ObjectIdentifier: UIPress.PressType] = [:]' Sources/UT99Host/GameViewController.swift
rg -Fq 'let nativeControllerOwnedEvent = configuredExtendedControllerIsPresent()' Sources/UT99Host/GameViewController.swift
rg -Fq 'if nativeControllerOwnedEvent { return true }' Sources/UT99Host/GameViewController.swift
rg -Fq 'UT99 controller responder fallback suppressed' Sources/UT99Host/GameViewController.swift
rg -Fq 'activeControllerFallbackPresses[ObjectIdentifier(press)] = press.type' Sources/UT99Host/GameViewController.swift
rg -Fq 'activeControllerFallbackPresses.removeValue(forKey: identifier)' Sources/UT99Host/GameViewController.swift
rg -Fq '<key>ProfileName</key><string>ExtendedGamepad</string>' Sources/UT99Host/Info.plist
rg -Fq 'final class GameViewController: GCEventViewController' Sources/UT99Host/GameViewController.swift
rg -Fq 'controllerUserInteractionEnabled = false' Sources/UT99Host/GameViewController.swift
rg -Fq '#define SDLRootViewController GCEventViewController' third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'self.controllerUserInteractionEnabled = NO' third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'window.rootViewController = GameViewController()' Sources/UT99Host/SceneDelegate.swift
rg -Fq 'subview !== gameSurfaceInputView' Sources/UT99Host/GameViewController.swift
rg -Fq 'subview !== touchSettingsPanel' Sources/UT99Host/GameViewController.swift
rg -Fq 'subview !== touchSettingsPanel && subview !== menuKeyboardPanel' Sources/UT99Host/GameViewController.swift
rg -Fq 'if let menuKeyboardPanel { view.bringSubviewToFront(menuKeyboardPanel) }' Sources/UT99Host/GameViewController.swift
rg -Fq 'self.presentSDLWindowIfAvailable()' Sources/UT99Host/GameViewController.swift
rg -Fq 'gameSurfaceInputView.isHidden = false' Sources/UT99Host/GameViewController.swift
rg -Fq 'UITouch.TouchType.indirectPointer.rawValue' Sources/UT99Host/GameViewController.swift
rg -Fq '@objc private func pointerPressed' Sources/UT99Host/GameViewController.swift
rg -Fq 'return hit === self ? nil : hit' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'pushMouseMotion(windowID: windowID, x: x, y: y, xrel: 0, yrel: 0)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'let (window, windowID) = focusedSDLWindow()' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'SDL_WarpMouseInWindow' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'write32(windowID, at: 8, into: &event)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'SDL_UT99SendMousePointer' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'SDL_UT99SendMousePointer' third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'mouse->last_x = window->w * 4' third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'anchor ? 1 : 0' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'if pressed != nil || edgeSample {' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'onPointer?(location, true, false)' Sources/UT99Host/GameViewController.swift
if rg -Fq 'onPointer?(location, true, true)' Sources/UT99Host/GameViewController.swift; then
    echo "Direct touch must not hold UWindow's mouse button while the finger travels" >&2
    exit 1
fi
rg -Fq 'dirty_ref' tools/prepare_sdl2_source.sh
rg -Fq 'patch -s -d "$staging/source" -p1' tools/prepare_sdl2_source.sh
rg -Fq 'let pointerScale = 1.0' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'normalizedLines.append(pointerScaleLine)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'let enginePoint = location' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'func publishMenuCursor(_ value: CGPoint, active: Bool)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'self.engineBridge.publishMenuCursor(value, active: active)' Sources/UT99Host/GameViewController.swift
rg -Fq 'self.engineBridge.publishMenuCursorClick(pressed: pressed)' Sources/UT99Host/GameViewController.swift
rg -Fq 'engineBridge.scheduleInitialOriginalMenu()' Sources/UT99Host/GameViewController.swift
rg -Fq 'func isGameplayMouseCaptureEnabled() -> Bool' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'dlsym(handle, "GCurrentViewport")' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'fromByteOffset: 0x1A8' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'private func toggleTouchInterfaceMode()' Sources/UT99Host/GameViewController.swift
rg -Fq 'private func selectTouchInterfaceMode(menu: Bool)' Sources/UT99Host/GameViewController.swift
rg -Fq 'Visibility is an independent user choice' Sources/UT99Host/GameViewController.swift
rg -Fq '"USE GAMEPLAY CONTROLS" : "USE MENU CONTROLS"' Sources/UT99Host/GameViewController.swift
rg -Fq '"Use Gameplay Touch Controls" : "Use Menu Touch Controls"' Sources/UT99Host/GameViewController.swift
if rg -Fq 'synchronizeInputModeFromViewport' Sources/UT99Host; then
    echo "Touch interface mode must be changed explicitly from the host menu" >&2
    exit 1
fi
rg -Fq 'controller.handlerQueue = controllerMonitorQueue' Sources/UT99Host/GameViewController.swift
rg -Fq 'private var controllerAutoHideActive = false' Sources/UT99Host/GameViewController.swift
rg -Fq 'controllerAutoHideActive = false' Sources/UT99Host/GameViewController.swift
rg -Fq 'menuButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 40)' Sources/UT99Host/GameViewController.swift
rg -Fq 'safeAreaInsets.top + 40 + 40 + 12' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'if self.originalMenuInputActive {' Sources/UT99Host/GameViewController.swift
if rg -Fq 'if !self.engineBridge.isGameplayMouseCaptureEnabled()' Sources/UT99Host/GameViewController.swift; then
    echo "Controller routing must follow the explicit Menu/Gameplay mode" >&2
    exit 1
fi
if rg -Fq 'SDL_GetRelativeMouseMode' Sources/UT99Host; then
    echo "Menu cursor routing must not depend on SDL's global relative-mouse mode" >&2
    exit 1
fi
rg -Fq 'buttons[.primaryFire]?.setTitle(active ? "SELECT" : "FIRE")' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'buttons[.pause]?.setTitle(active ? "BACK" : "GAME MENU")' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq '? action != .primaryFire && action != .pause' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'return "menuSelect"' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'return "menuBack"' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq '.union(["move", "menuSelect", "menuBack"])' Sources/UT99Host/UT99TouchProfileStore.swift
rg -Fq 'func publishTextEntry(_ text: String)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'engineBridge.publishTextEntry(key.characters)' Sources/UT99Host/GameViewController.swift
rg -Fq 'SDL_UT99SendKeyboardText' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'for character in text {' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'let result = String(character).withCString { sendText($0) }' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'SDL_EventState(SDL_TEXTINPUT, SDL_ENABLE)' third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'SDL_SendKeyboardKeyInternal(KEYBOARD_VIRTUAL, SDL_PRESSED, code, SDLK_UNKNOWN);' third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'posted = SDL_SendKeyboardText(text);' third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'SDL_SendKeyboardKeyInternal(KEYBOARD_VIRTUAL, SDL_RELEASED, code, SDLK_UNKNOWN);' third_party/patches/sdl2-ut99-ios.patch
keyboard_text_body="$(sed -n '/DECLSPEC int SDLCALL SDL_UT99SendKeyboardText/,/DECLSPEC int SDLCALL SDL_UT99SendHardwareKey/p' third_party/patches/sdl2-ut99-ios.patch)"
keyboard_down_line="$(printf '%s\n' "$keyboard_text_body" | rg -n -F 'SDL_SendKeyboardKeyInternal(KEYBOARD_VIRTUAL, SDL_PRESSED, code, SDLK_UNKNOWN);' | cut -d: -f1)"
keyboard_text_line="$(printf '%s\n' "$keyboard_text_body" | rg -n -F 'posted = SDL_SendKeyboardText(text);' | cut -d: -f1)"
keyboard_up_line="$(printf '%s\n' "$keyboard_text_body" | rg -n -F 'SDL_SendKeyboardKeyInternal(KEYBOARD_VIRTUAL, SDL_RELEASED, code, SDLK_UNKNOWN);' | cut -d: -f1)"
if (( keyboard_down_line >= keyboard_text_line || keyboard_text_line >= keyboard_up_line )); then
    echo "UWindow printable input must remain KeyDown -> TextInput -> KeyUp" >&2
    exit 1
fi
rg -Fq 'UT99KeyboardBridge dequeue type=text' third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'UT99KeyboardBridge dequeue type=%s' third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'SDL_ut99_input_dequeue_log_budget = 256' third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'private func claimKeyboardResponder(reason: String)' Sources/UT99Host/GameViewController.swift
rg -Fq 'UT99KeyboardBridge responder reason=%@ accepted=%@ first=%@ keyWindow=%@' Sources/UT99Host/GameViewController.swift
rg -Fq 'UT99 touch text keyboard presented mode=host-panel' Sources/UT99Host/GameViewController.swift
rg -Fq 'CommandLine.arguments.contains("-UT99MenuKeyboardAcceptance")' Sources/UT99Host/GameViewController.swift
rg -Fq 'engineBridge.runPlayerNameNavigationSmokeTest()' Sources/UT99Host/GameViewController.swift
rg -Fq 'UT99 player-name acceptance target=Name route=production-text accepted=%@' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'private var menuKeyboardPanel: UIVisualEffectView?' Sources/UT99Host/GameViewController.swift
rg -Fq 'private func menuKeyboardKey' Sources/UT99Host/GameViewController.swift
rg -Fq 'engineBridge.publishMenuBackspace()' Sources/UT99Host/GameViewController.swift
rg -Fq 'engineBridge.publishMenuReturn()' Sources/UT99Host/GameViewController.swift
rg -Fq 'engineBridge.publishMenuCharacter(text)' Sources/UT99Host/GameViewController.swift
rg -Fq 'engineBridge.publishMenuCharacter(" ")' Sources/UT99Host/GameViewController.swift
rg -Fq 'func publishMenuCharacter(_ text: String) -> Bool' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'let accepted = publishTextEntry(text)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'UT99KeyboardBridge menu character characters=%lu route=text accepted=%@' Sources/UT99Host/UT99EngineBridge.swift
if rg -Fq 'dlsym(handle, "_ZN7UEngine3KeyEP9UViewport9EInputKey")' Sources/UT99Host/UT99EngineBridge.swift; then
    echo "Rejected direct UEngine::Key software-keyboard experiment returned" >&2
    exit 1
fi
if rg -Fq 'SDL_UT99SendSoftwareText' Sources/UT99Host/UT99EngineBridge.swift third_party/patches/sdl2-ut99-ios.patch; then
    echo "Rejected Unicode-plus-text software-keyboard path returned" >&2
    exit 1
fi
if rg -Fq 'Thread.sleep(forTimeInterval: 0.055)' Sources/UT99Host/UT99EngineBridge.swift; then
    echo "Rejected synthetic keyboard timing experiment returned" >&2
    exit 1
fi
rg -Fq 'engineBridge.publishMenuCursor(vector, active: magnitude > 0)' Sources/UT99Host/GameViewController.swift
rg -Fq 'touchOverlay.onMenuCursorNudge' Sources/UT99Host/GameViewController.swift
rg -Fq 'func nudgeMenuCursor(by offset: CGPoint)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'menuCursorNudgeAccessibilityAction(name: "Nudge down"' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'UT99 controller fallback cursor vector=' Sources/UT99Host/GameViewController.swift
rg -Fq 'reason=ambiguous-sticks' Sources/UT99Host/GameViewController.swift
rg -Fq 'prepareResponderFallbackGameplay()' Sources/UT99Host/GameViewController.swift
rg -Fq 'controller responder fallback gameplay protected touch=true' Sources/UT99Host/GameViewController.swift
fallback_body="$(sed -n '/private func publishControllerFallbackPress/,/private func updateControllerFallbackMenuCursor/p' Sources/UT99Host/GameViewController.swift)"
if printf '%s\n' "$fallback_body" | rg -q 'toggleInputModeFromController\(|publishTouchAction\(\.(jump|crouch|primaryFire|alternateFire)'; then
    echo "Responder-only controller input must remain menu-only" >&2
    exit 1
fi
printf '%s\n' "$fallback_body" | rg -Fq 'controller fallback mode switch ignored reason=responder-only'
rg -Fq 'UT99 controller probe armed engineStarted=false' Sources/UT99Host/GameViewController.swift
rg -Fq 'RunLoop.main.perform(inModes: [.default], block: invoke)' Sources/UT99Host/UT99EngineBridge.swift
if rg -Fq 'DispatchQueue.main.async(execute: invoke)' Sources/UT99Host/UT99EngineBridge.swift; then
    echo "Engine entry must not permanently occupy the serial main dispatch queue" >&2
    exit 1
fi
rg -Fq 'UT99 controller lifecycle smoke main-queue=alive' Sources/UT99Host/GameViewController.swift
rg -Fq 'GCVirtualController(configuration: configuration)' Sources/UT99Host/GameViewController.swift
rg -Fq 'CONTROLLER PROBE · extended profile ready' Sources/UT99Host/GameViewController.swift
rg -Fq 'extendedControllerConnected' Sources/UT99Host/GameViewController.swift
rg -Fq 'responderFallback=%@' Sources/UT99Host/GameViewController.swift
rg -Fq 'pointerMode=%@ pointerSurface=%@' Sources/UT99Host/GameViewController.swift
rg -Fq 'UT99 controller sample kind=%@' Sources/UT99Host/GameViewController.swift
rg -Fq 'Controller: discovered=\(controllers.count) extended=\(extendedControllers.count)' Sources/UT99Host/GameViewController.swift
rg -Fq 'Pointer: owner=host-uikit mode=' Sources/UT99Host/GameViewController.swift
rg -Fq 'clearControllerFallbackPresses(reason: "release-gameplay-inputs", rearmMenuCursor: false)' Sources/UT99Host/GameViewController.swift
if rg -Fq 'UT99KeyboardBridge text=%@' Sources/UT99Host/GameViewController.swift; then
    echo "Raw text must not be written to diagnostics" >&2
    exit 1
fi
if rg -Fq 'let controllerConnected = controllerFallbackConnected ||' Sources/UT99Host/GameViewController.swift; then
    echo "Responder-only controller fallback must not auto-hide complete touch controls" >&2
    exit 1
fi
if rg -Fq 'menuTextField.becomeFirstResponder()' Sources/UT99Host/GameViewController.swift; then
    echo "Open Keyboard must not depend on deferred iPadOS keyboard presentation" >&2
    exit 1
fi
rg -Fq 'SDL_UT99SendHardwareKey' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'UT99 pointer owner=host-uikit sdl-gcmouse=disabled' third_party/patches/sdl2-ut99-ios.patch
rg -Fq "Registering SDL's GCMouse handlers as a second producer" third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'DECLSPEC int SDLCALL SDL_UT99SendKeyboardText' third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'DECLSPEC int SDLCALL SDL_UT99SendHardwareKey' third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'private func pushHardwareKey(usage: Int, key: Int32, pressed: Bool)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'write32(UInt32(usage), at: 16, into: &event)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'pad.buttonOptions?.valueChangedHandler' Sources/UT99Host/GameViewController.swift
rg -Fq 'self?.toggleInputModeFromController()' Sources/UT99Host/GameViewController.swift
rg -Fq 'UT99TouchInputTuning.controllerMovement' Sources/UT99Host/GameViewController.swift
rg -Fq 'UT99TouchInputTuning.controllerMenuCursor' Sources/UT99Host/GameViewController.swift
rg -Fq 'phoneDefaultPlacements' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'tabletDefaultPlacements' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq '"menuBack": .init(x: 0.9300878477306003, y: 0.53955078125, scale: 1)' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq '"menuSelect": .init(x: 0.8814055636896047, y: 0.63525390625, scale: 1)' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'currentRendererViewportFrame()' Sources/UT99Host/GameViewController.swift
rg -Fq 'engineBridge.updateMenuCursorCanvasSize(rendererFrame.size)' Sources/UT99Host/GameViewController.swift
rg -Fq 'for name in ["User.ini", "UnrealTournament.ini"]' Sources/UT99Host/GameViewController.swift
rg -Fq 'func publishExternalMenuPointer(location: CGPoint' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq '<key>CFBundleDisplayName</key><string>UTP</string>' Sources/UT99Host/Info.plist
rg -Fq 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon' UT99Apple.xcodeproj/project.pbxproj
rg -Fq 'usage <= UIKeyboardHIDUsage.keyboardZ.rawValue' Sources/UT99Host/UT99EngineBridge.swift
if rg -Fq 'menuPointerView' Sources/UT99Host; then
    echo "Host targeting circle returned; menus must draw only UWindow's stock cursor" >&2
    exit 1
fi
if rg -Fq 'UT99MenuPointerCalibration' Sources/UT99Host Tests --glob '*.swift'; then
    echo "A second host-side pointer transform returned" >&2
    exit 1
fi
rg -Fq 'SDL_GetMouseState' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'UWindow, SDL_GetMouseState, and UIKit use SDL window points here' third_party/patches/sdl2-ut99-ios.patch
if rg -q 'SDL_Metal_GetDrawableSize\(window, &drawable_w, &drawable_h\)' third_party/patches/sdl2-ut99-ios.patch; then
  echo "UT99 pointer bridge must not scale UIKit points to drawable pixels" >&2
  exit 1
fi
rg -Fq 'SDL_PrivateSendMouseMotion(window, 0, SDL_FALSE, x, y)' third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'try? Data().write(to: stdoutURL, options: .atomic)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'appendingPathComponent("UT99FontSupport", isDirectory: true)' Sources/UT99Host/GameViewController.swift
rg -Fq 'UT99FontSupport' UT99Apple.xcodeproj/project.pbxproj
rg -Fq 'desired.insert((1 << 30) | 82)' Sources/UT99Host/UT99EngineBridge.swift
if rg -Fq 'UIKeyboardHIDUsage.keyboardW.rawValue: return (1 << 30) | 82' Sources/UT99Host/UT99EngineBridge.swift; then
    echo "Hardware W must remain W so the preserved User.ini decides its binding" >&2
    exit 1
fi
rg -Fq 'func publishControllerLook(_ value: CGPoint, active: Bool)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'repeating: .milliseconds(16)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'applyAppleKeyboardBindings' Sources/UT99Host/UT99DataImporter.swift
rg -Fq 'let configuredValue = "3.0"' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq -- '-UT99ServerBrowserPointerSmokeTest' Sources/UT99Host/GameViewController.swift
rg -Fq 'func runServerBrowserPointerSmokeTest()' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq -- '-UT99ServerBrowserJoinSmokeTest' Sources/UT99Host/GameViewController.swift
rg -Fq 'func runServerBrowserJoinSmokeTest()' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq -- '-UT99NetworkSessionSmokeTest' Sources/UT99Host/GameViewController.swift
rg -Fq 'func runNetworkSessionSmokeTest()' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'text[welcome.upperBound...].contains("Possessed PlayerPawn")' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'submitConsoleCommand("say ios469 session check")' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'submitConsoleCommand("suicide")' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'submitConsoleCommand("stat net")' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'func runStockMenuDisconnect()' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'phase=disconnect route=stock-menu submitted=true' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'phase=session-input-sequence complete=true' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'phase=disconnect verified=true route=stock-menu destination=Entry' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'press UT Servers x=480 y=23' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'move to UT Servers x=480 y=23' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'move to first server row x=600 y=60' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'applyAppleNetworkProfile(to: URL(fileURLWithPath: iniPath))' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'bShownWindow=True' Sources/UT99Host/UT99EngineBridge.swift
if rg -q 'return "EctoPad|message: "EctoPad|title: "EctoPad|text = "EctoPad' Sources/UT99Host/GameViewController.swift; then
    echo "Reference implementation name leaked into player-facing UI" >&2
    exit 1
fi
if rg -q 'NSLog\("EctoPad|profile=ectoPad|ectoPad=true' Sources/UT99Host/GameViewController.swift; then
    echo "Reference implementation name leaked into runtime diagnostics" >&2
    exit 1
fi
if rg -q 'UIBlurEffect|innerRing|captionLabel|glyphView' Sources/UT99Host/GoldenPadTouchOverlay.swift; then
    echo "obsolete touch material implementation remains" >&2
    exit 1
fi
if rg -q 'UIButton\.Configuration|configuration\.image|layer\.shadow' Sources/UT99Host/GoldenPadTouchOverlay.swift; then
    echo "unsupported touch button styling remains" >&2
    exit 1
fi
rg -q 'UIImpactFeedbackGenerator' Sources/UT99Host/GoldenPadTouchOverlay.swift
