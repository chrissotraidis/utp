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
rg -Fq '.allowBluetoothHFP' Sources/UT99Host/GameViewController.swift
if rg -Fq '.allowBluetooth])' Sources/UT99Host/GameViewController.swift; then
    echo "Deprecated Bluetooth audio-session option returned" >&2
    exit 1
fi
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
rg -Fq 'field.placeholder = "unreal://server.example:7777/"' Sources/UT99Host/GameViewController.swift
rg -Fq 'components.scheme?.lowercased() == "unreal"' Sources/UT99Host/GameViewController.swift
rg -Fq 'Open Unreal Tournament Menu' Sources/UT99Host/GameViewController.swift
rg -q 'UT99TouchProfileStore\.decode' Sources/UT99Host/GameViewController.swift
rg -q 'lookAcceleration' Sources/UT99Host/UT99TouchConfiguration.swift
rg -q 'movementDeadZone' Sources/UT99Host/UT99EngineBridge.swift
rg -q 'safeAreaGuide\.isHidden = !active' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'layoutDoneButton.leadingAnchor.constraint(equalTo: layoutBanner.trailingAnchor' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'private final class UT99TouchActionButton: UIButton' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'case primary, secondary, utility, dPad, start' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'symbol: symbol(for: action)' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'case ectoPad' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'case .primaryFire: "scope"' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'override func accessibilityActivate() -> Bool' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'moveRing.isHidden = false' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'case .ectoPad, .goldenPad: 0.82' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'let thumbDiameter = resolvedDiameter * 0.42' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'let compact = visualRole == .dPad' Sources/UT99Host/GoldenPadTouchOverlay.swift
if rg -q 'moveThumb\.(widthAnchor|heightAnchor)|lookThumb\.(widthAnchor|heightAnchor)' Sources/UT99Host/GoldenPadTouchOverlay.swift; then
    echo "stick thumbs must use explicit bounds after reference-frame placement" >&2
    exit 1
fi
rg -Fq 'lookThumb.backgroundColor = UIColor(red: 1.00, green: 0.84, blue: 0.25, alpha: 0.98)' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq '0.8916544656' Sources/UT99Host/UT99TouchLayoutGeometry.swift
rg -Fq 'private final class UT99HostMenuButton: UIButton' Sources/UT99Host/GameViewController.swift
rg -Fq 'menuButton.onAccessibilityActivate' Sources/UT99Host/GameViewController.swift
rg -Fq 'menuButton.showsMenuAsPrimaryAction = true' Sources/UT99Host/GameViewController.swift
rg -Fq 'private func buildHostMenu() -> UIMenu' Sources/UT99Host/GameViewController.swift
rg -Fq 'title.text = "Touch Controls"' Sources/UT99Host/GameViewController.swift
rg -Fq 'touchSettingsRow(title: "Size", control: size)' Sources/UT99Host/GameViewController.swift
rg -Fq 'guard !CommandLine.arguments.contains("-UT99AutoStart") else { return }' Sources/UT99Host/GameViewController.swift
rg -Fq 'CommandLine.arguments.contains("-UT99TouchSettingsPanelSmokeTest"),' Sources/UT99Host/GameViewController.swift
rg -Fq 'touchOverlay.isHidden = true' Sources/UT99Host/GameViewController.swift
if rg -q 'Layout Preset|touchPresetChanged|UISegmentedControl\(items:' Sources/UT99Host/GameViewController.swift; then
    echo "Internal touch-layout terminology leaked into the player settings UI" >&2
    exit 1
fi
rg -Fq 'private final class UT99GameSurfaceInputView: UIView' Sources/UT99Host/GameViewController.swift
rg -Fq 'publishGameSurfacePointer(location: location, pressed: pressed)' Sources/UT99Host/GameViewController.swift
rg -Fq 'subview !== gameSurfaceInputView' Sources/UT99Host/GameViewController.swift
rg -Fq 'gameSurfaceInputView.isHidden = false' Sources/UT99Host/GameViewController.swift
rg -Fq 'UITouch.TouchType.indirectPointer.rawValue' Sources/UT99Host/GameViewController.swift
rg -Fq '@objc private func pointerTapped' Sources/UT99Host/GameViewController.swift
rg -Fq 'return hit === self ? nil : hit' Sources/UT99Host/GoldenPadTouchOverlay.swift
rg -Fq 'pushMouseMotion(windowID: windowID, x: x, y: y, xrel: 0, yrel: 0)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'let (window, windowID) = focusedSDLWindow()' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'SDL_WarpMouseInWindow' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'write32(windowID, at: 8, into: &event)' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'SDL_UT99SendMousePointer' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'SDL_UT99SendMousePointer' third_party/patches/sdl2-ut99-ios.patch
rg -Fq 'dirty_ref' tools/prepare_sdl2_source.sh
rg -Fq 'patch -s -d "$staging/source" -p1' tools/prepare_sdl2_source.sh
rg -Fq 'normalizedLines.append("MouseScale=1.000000")' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'let x = Int32(max(0, min(CGFloat(Int32.max), location.x)).rounded())' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'SDL_GetMouseState' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'SDL_SendMouseMotion(window, 0, SDL_FALSE, x, y)' third_party/patches/sdl2-ut99-ios.patch
rg -Fq -- '-UT99ServerBrowserPointerSmokeTest' Sources/UT99Host/GameViewController.swift
rg -Fq 'func runServerBrowserPointerSmokeTest()' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq -- '-UT99ServerBrowserJoinSmokeTest' Sources/UT99Host/GameViewController.swift
rg -Fq 'func runServerBrowserJoinSmokeTest()' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'press UT Servers x=480 y=23' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'move to UT Servers x=480 y=23' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'move to first server row x=600 y=60' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'applyAppleNetworkProfile(to: URL(fileURLWithPath: iniPath))' Sources/UT99Host/UT99EngineBridge.swift
rg -Fq 'bShownWindow=True' Sources/UT99Host/UT99EngineBridge.swift
if rg -q 'return "EctoPad|message: "EctoPad|title: "EctoPad|text = "EctoPad' Sources/UT99Host/GameViewController.swift; then
    echo "Reference implementation name leaked into player-facing UI" >&2
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
