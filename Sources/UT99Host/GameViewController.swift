import MetalKit
import UIKit
import CryptoKit
import UniformTypeIdentifiers
import GameController
import AVFAudio
import Network
import Darwin
import SafariServices

/// Accessibility activation must remain synchronous because the original SDL
/// main loop owns the application's main thread after engine entry.  A normal
/// UIButton activation can otherwise wait behind that loop in Simulator/AX.
private final class UT99HostMenuButton: UIButton {
    var onAccessibilityActivate: (() -> Void)?

    override func accessibilityActivate() -> Bool {
        // UIKit does not reliably open a primary-action UIMenu through the
        // Simulator accessibility bridge while the SDL loop owns main. Use a
        // native action-sheet mirror for VoiceOver/controller activation;
        // direct touch still opens the attached EctoPad-style UIMenu.
        if let onAccessibilityActivate {
            onAccessibilityActivate()
            return true
        }
        return super.accessibilityActivate()
    }
}

/// The SDL renderer window stays render-only so UIKit can keep the touch
/// controller and host menu above it. Forward otherwise-unclaimed surface
/// touches into SDL as an absolute mouse pointer so Unreal's original UWindow
/// menus, dialogs, server browser, and text fields remain directly tappable.
private final class UT99GameSurfaceInputView: UIView {
    enum InputMode {
        case originalMenu
        case gameplayLook
    }

    /// `pressed == nil` is motion, otherwise it is the left-button edge.
    var onPointer: ((CGPoint, Bool?, Bool) -> Void)?
    var onPrimaryAction: ((Bool) -> Void)?
    /// Gameplay fingers publish normalized relative deltas. They never click.
    var onLook: ((CGPoint, Bool) -> Void)?
    private weak var trackedTouch: UITouch?
    private var lastLookLocation: CGPoint?
    private var lastHoverLocation: CGPoint?
    private(set) var inputMode: InputMode = .originalMenu

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = true
        accessibilityIdentifier = "ut99.gameSurfacePointer"

        // iPad trackpads and mice deliver an indirect-pointer tap rather than
        // the direct UITouch sequence used by a finger. Convert that click to
        // the same absolute SDL left-button pair so stock UWindow controls are
        // usable with both input classes.
        let pointerPress = UILongPressGestureRecognizer(target: self, action: #selector(pointerPressed(_:)))
        pointerPress.minimumPressDuration = 0
        pointerPress.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)]
        addGestureRecognizer(pointerPress)
        let pointerHover = UIHoverGestureRecognizer(target: self, action: #selector(pointerHovered(_:)))
        addGestureRecognizer(pointerHover)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard trackedTouch == nil,
              let touch = touches.first(where: { $0.type != .indirectPointer }) else { return }
        let location = touch.location(in: self)
        // Direct menu touch is owned by the visible cursor stick and SELECT
        // button. Keep this surface for gameplay look and real pointer hover;
        // a finger must never create a second, competing absolute cursor.
        guard inputMode != .originalMenu else { return }
        if inputMode == .gameplayLook && location.x < bounds.midX { return }
        trackedTouch = touch
        lastLookLocation = location
    }

    @objc private func pointerPressed(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: self)
        switch gesture.state {
        case .began:
            if inputMode == .originalMenu {
                onPointer?(location, nil, true)
                onPointer?(location, true, false)
            } else {
                onPrimaryAction?(true)
            }
        case .ended, .cancelled, .failed:
            if inputMode == .originalMenu {
                onPointer?(location, false, false)
            } else {
                onPrimaryAction?(false)
            }
        default:
            break
        }
    }

    @objc private func pointerHovered(_ gesture: UIHoverGestureRecognizer) {
        let location = gesture.location(in: self)
        switch gesture.state {
        case .began:
            lastHoverLocation = location
            if inputMode == .originalMenu {
                onPointer?(location, nil, true)
            }
        case .changed:
            guard let previous = lastHoverLocation else {
                lastHoverLocation = location
                return
            }
            lastHoverLocation = location
            if inputMode == .originalMenu {
                // UWindow renders a relative software cursor. Re-anchor it to
                // every real pointer sample so it cannot drift away from the
                // system trackpad/mouse location after menus or gameplay.
                onPointer?(location, nil, true)
            } else {
                publishLookDelta(from: previous, to: location)
            }
        case .ended, .cancelled, .failed:
            lastHoverLocation = nil
            if inputMode == .gameplayLook { onLook?(.zero, false) }
        default:
            break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let trackedTouch, touches.contains(trackedTouch) else { return }
        let location = trackedTouch.location(in: self)
        if let previous = lastLookLocation {
            lastLookLocation = location
            publishLookDelta(from: previous, to: location)
        }
    }

    private func publishLookDelta(from previous: CGPoint, to location: CGPoint) {
        // The middle/right side is the player's virtual look pad. Normalize
        // against that usable thumb travel instead of the full iPad canvas.
        let value = CGPoint(
            x: (location.x - previous.x) / max(bounds.width * 0.5, 1),
            y: (location.y - previous.y) / max(bounds.height * 0.65, 1)
        )
        if abs(value.x) > 0.0001 || abs(value.y) > 0.0001 {
            onLook?(value, true)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTrackedTouch(in: touches, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTrackedTouch(in: touches, cancelled: true)
    }

    private func finishTrackedTouch(in touches: Set<UITouch>, cancelled: Bool) {
        guard let trackedTouch, touches.contains(trackedTouch) else { return }
        onLook?(.zero, false)
        self.trackedTouch = nil
        lastLookLocation = nil
        lastHoverLocation = nil
    }

    func releasePointer() {
        guard trackedTouch != nil else { return }
        onLook?(.zero, false)
        self.trackedTouch = nil
        lastLookLocation = nil
        lastHoverLocation = nil
    }

    func setInputMode(_ mode: InputMode) {
        guard inputMode != mode else { return }
        releasePointer()
        inputMode = mode
        accessibilityIdentifier = mode == .originalMenu
            ? "ut99.gameSurfacePointer"
            : "ut99.touch.lookArea"
        accessibilityLabel = mode == .originalMenu ? "Game menu" : "Look area"
        accessibilityHint = mode == .originalMenu
            ? "Touch an original Unreal Tournament menu item."
            : "Drag on the right half of the screen to look."
    }

}

/// Apple requires a GCEventViewController root when a game consumes physical
/// controller input through GCController profiles. Keeping controller UI
/// interaction disabled routes those events to the native game bindings
/// instead of UIKit focus navigation.
final class GameViewController: GCEventViewController, MTKViewDelegate, UIDocumentPickerDelegate {
    private let gameView = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    private let gameSurfaceInputView = UT99GameSurfaceInputView()
    private var originalMenuInputActive = true
    private lazy var hostMetalCommandQueue = gameView.device?.makeCommandQueue()
    private var hostMetalPresentationRecorded = false
    private var pendingG2DiagnosticsExport = false
    private let statusLabel = UILabel()
    private let menuButton = UT99HostMenuButton(type: .system)
    private var hostMenuPanel: UIVisualEffectView?
    private var supportExportNotice: String?
    private var touchSettingsPanel: UIView?
    private weak var touchOpacitySlider: UISlider?
    private weak var touchScaleSlider: UISlider?
    private let engineBridge = UT99EngineBridge()
    private let backdropLayer = CAGradientLayer()
    private let touchOverlay = GoldenPadTouchOverlay()
    private static let touchInputEnabledKey = "ut99.touch.enabled"
    private let controllerMonitorQueue = DispatchQueue(label: "com.ut99apple.controller-monitor")
    private var controllerMonitorTimer: DispatchSourceTimer?
    private var lastControllerMonitorSignature = ""
    private var configuredControllerIDs: Set<ObjectIdentifier> = []
    private let configuredControllerLock = NSLock()
    private var controllerAutoHideActive = false
    private var wasExtendedControllerConnected = false
    private var controllerFallbackConnected = false
    private var attemptedHotControllerDiscovery = false
    private var menuSelectPressed = false
    private var hardwareTextKeyUsages: Set<Int> = []
    private var activeControllerFallbackPresses: [ObjectIdentifier: UIPress.PressType] = [:]
    private var lastControllerFallbackMenuVector = CGPoint.zero
    private var controllerSampleLastLogAt: [String: TimeInterval] = [:]
    private var controllerSampleWasActive: [String: Bool] = [:]
    private var menuKeyboardPanel: UIVisualEffectView?
    private var menuKeyboardLetterButtons: [UIButton] = []
    private var menuKeyboardShifted = false
    private var menuKeyboardCompactOverride: Bool?
    private var lastKeyboardResponderDiagnostic = ""
    private var touchInputWasVisible = false
    private var appleIntegrationObservers: [NSObjectProtocol] = []
    private let networkMonitor = NWPathMonitor()
    private let networkMonitorQueue = DispatchQueue(label: "com.ut99apple.network-monitor")
    private let importQueue = DispatchQueue(label: "com.ut99apple.data-import", qos: .userInitiated)
    private var activeImportCancellation: UT99ImportCancellation?
    private enum DocumentPickerPurpose: Equatable {
        case gameData
        case touchProfile
    }
    private var documentPickerPurpose: DocumentPickerPurpose?
    private var importProgressPanel: UIView?
    private weak var importPhaseLabel: UILabel?
    private weak var importFileLabel: UILabel?
    private weak var importProgressView: UIProgressView?
    private weak var importSpinner: UIActivityIndicatorView?
    private weak var importCancelButton: UIButton?
    private var gameDataDownload: UT99GameDataDownload?
    private var gameDataDownloadProgressTimer: Timer?
    private var gameDataAcquisitionWorkspace: URL?
    private var onboardingPanel: UIVisualEffectView?
    private weak var onboardingTitleLabel: UILabel?
    private weak var onboardingDetailLabel: UILabel?
    private weak var onboardingPrimaryButton: UIButton?
    private weak var onboardingSecondaryButton: UIButton?
    private weak var onboardingTertiaryButton: UIButton?
    private var launchTransitionView: UIView?
    private var isReassertingSDLWindow = false
    private var hasAutoStartedFromArguments = false
    private var hasPresentedMenuSmokeState = false
    private lazy var runtimeRecovery = UT99RuntimeRecovery(root: dataSupportRoot())
    private var recoveredSession: UT99RuntimeSessionRecord?
    private var recoveryPromptPresented = false
    private var pendingSafeMode = false
    private enum HostState: String {
        case needsData = "NeedsData"
        case validatingData = "ValidatingData"
        case ready = "Ready"
        case startingEngine = "StartingEngine"
        case running = "Running"
        case pausedBySystem = "PausedBySystem"
        case stoppingEngine = "StoppingEngine"
        case crashed = "Crashed"
        case safeMode = "SafeMode"
        case unsupportedBuild = "UnsupportedBuild"
    }
    private var hostState: HostState = .ready

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeLeft }
    override var shouldAutorotate: Bool { true }
    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestLandscapeGeometryIfNeeded()
        claimKeyboardResponder(reason: "view-did-appear")
        presentSDLWindowIfAvailable()
        presentRecoveryPromptIfNeeded()
        // The host shell has its own bounded Metal presentation requirement
        // before the transformed engine takes ownership of the SDL window.
        // Request one frame after layout so currentDrawable is available.
        gameView.setNeedsDisplay()
        presentRequestedMenuSmokeStateIfNeeded()
    }

    /// Physical iPad keyboard events only reach `pressesBegan` while the host
    /// owns UIKit's responder chain. Record state transitions without logging
    /// any entered text so a missing callback can be distinguished from a
    /// character rejected later by SDL/UWindow.
    private func claimKeyboardResponder(reason: String) {
        let accepted = becomeFirstResponder()
        let signature = "\(isFirstResponder)|\(view.window?.isKeyWindow == true)"
        guard signature != lastKeyboardResponderDiagnostic else { return }
        lastKeyboardResponderDiagnostic = signature
        NSLog("UT99KeyboardBridge responder reason=%@ accepted=%@ first=%@ keyWindow=%@",
              reason,
              accepted ? "true" : "false",
              isFirstResponder ? "true" : "false",
              view.window?.isKeyWindow == true ? "true" : "false")
    }

    private func presentRequestedMenuSmokeStateIfNeeded() {
        guard !hasPresentedMenuSmokeState else { return }
        if CommandLine.arguments.contains("-UT99TouchSettingsPanelSmokeTest") {
            // Auto-start prepares the transparent host overlay after
            // viewDidAppear. Opening the panel before that transition makes
            // prepareEngineSurfaceOverlay hide the very state this smoke flag
            // is meant to verify. Auto-start launches present it immediately
            // after the host overlay has been prepared instead.
            guard !CommandLine.arguments.contains("-UT99AutoStart") else { return }
            hasPresentedMenuSmokeState = true
            showTouchSettings()
        } else if CommandLine.arguments.contains("-UT99NativeMenuSmokeTest") {
            hasPresentedMenuSmokeState = true
            toggleMenu()
        }
    }

    private func requestLandscapeGeometryIfNeeded() {
        guard let scene = view.window?.windowScene,
              !scene.interfaceOrientation.isLandscape else { return }
        setNeedsUpdateOfSupportedInterfaceOrientations()
        let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
        scene.requestGeometryUpdate(preferences) { error in
            NSLog("UT99 landscape geometry request failed: %@", error.localizedDescription)
        }
        NSLog("UT99 requested landscape scene geometry from orientation=%ld",
              Int(scene.interfaceOrientation.rawValue))
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        NSLog("UT99KeyboardBridge pressesBegan count=%lu", presses.count)
        var keyboardPresses = Set<UIPress>()
        for press in presses {
            NSLog("UT99KeyboardBridge began type=%ld key=%ld", press.type.rawValue,
                  press.key.map { Int($0.keyCode.rawValue) } ?? -1)
            if let key = press.key {
                keyboardPresses.insert(press)
                let usage = key.keyCode.rawValue
                if originalMenuInputActive && engineBridge.publishTextEntry(key.characters) {
                    hardwareTextKeyUsages.insert(usage)
                    NSLog("UT99KeyboardBridge text accepted characters=%lu usage=%hu",
                          key.characters.count, usage)
                } else {
                    engineBridge.publishHardwareKey(usage: usage, pressed: true)
                }
            } else {
                let nativeControllerOwnedEvent = prepareControllerFromActiveEvent()
                if nativeControllerOwnedEvent {
                    NSLog("UT99 controller responder fallback suppressed type=%ld owner=extended",
                          press.type.rawValue)
                } else {
                    activeControllerFallbackPresses[ObjectIdentifier(press)] = press.type
                    NSLog("UT99 controller responder fallback active type=%ld owner=responder",
                          press.type.rawValue)
                    publishControllerFallbackPress(press, pressed: true)
                }
            }
        }
        if !keyboardPresses.isEmpty { super.pressesBegan(keyboardPresses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        NSLog("UT99KeyboardBridge pressesEnded count=%lu", presses.count)
        var keyboardPresses = Set<UIPress>()
        for press in presses {
            NSLog("UT99KeyboardBridge ended type=%ld key=%ld", press.type.rawValue,
                  press.key.map { Int($0.keyCode.rawValue) } ?? -1)
            if let key = press.key {
                keyboardPresses.insert(press)
                let usage = key.keyCode.rawValue
                if hardwareTextKeyUsages.remove(usage) == nil {
                    engineBridge.publishHardwareKey(usage: usage, pressed: false)
                }
            } else {
                let identifier = ObjectIdentifier(press)
                if activeControllerFallbackPresses.removeValue(forKey: identifier) != nil {
                    publishControllerFallbackPress(press, pressed: false)
                } else {
                    NSLog("UT99 controller responder fallback release suppressed type=%ld",
                          press.type.rawValue)
                }
            }
        }
        if !keyboardPresses.isEmpty { super.pressesEnded(keyboardPresses, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        NSLog("UT99KeyboardBridge pressesCancelled count=%lu", presses.count)
        var keyboardPresses = Set<UIPress>()
        for press in presses {
            if let key = press.key {
                keyboardPresses.insert(press)
                let usage = key.keyCode.rawValue
                if hardwareTextKeyUsages.remove(usage) == nil {
                    engineBridge.publishHardwareKey(usage: usage, pressed: false)
                }
            } else {
                let identifier = ObjectIdentifier(press)
                if activeControllerFallbackPresses.removeValue(forKey: identifier) != nil {
                    publishControllerFallbackPress(press, pressed: false)
                } else {
                    NSLog("UT99 controller responder fallback cancel suppressed type=%ld",
                          press.type.rawValue)
                }
            }
        }
        if !keyboardPresses.isEmpty { super.pressesCancelled(keyboardPresses, with: event) }
    }

    private func publishControllerFallbackPress(_ press: UIPress, pressed: Bool) {
        // This path only exists for an OS/controller combination that emits
        // responder presses instead of an extended GameController profile.
        // It must follow the same explicit mode as touch and native controller
        // input, and it must never make the touch overlay blink on each press.
        if originalMenuInputActive {
            switch press.type {
            case .upArrow:
                updateControllerFallbackMenuCursor()
            case .downArrow:
                updateControllerFallbackMenuCursor()
            case .leftArrow:
                updateControllerFallbackMenuCursor()
            case .rightArrow:
                updateControllerFallbackMenuCursor()
            case .select:
                engineBridge.publishMenuCursorClick(pressed: pressed)
            case .menu:
                engineBridge.publishTouchAction(.pause, pressed: pressed)
            case .playPause:
                if pressed {
                    NSLog("UT99 controller fallback mode switch ignored reason=responder-only")
                }
            default:
                NSLog("UT99 controller press fallback unmapped type=%ld pressed=%@",
                      press.type.rawValue, pressed ? "true" : "false")
            }
            return
        }

        switch press.type {
        case .upArrow, .downArrow, .leftArrow, .rightArrow:
            // In responder-only hot-connect mode both physical sticks collapse
            // into these same four UIKit directions. Routing them as movement
            // makes right-stick look move the player too. Keep touch movement
            // and look active until iPadOS exposes the extended profile.
            if pressed {
                NSLog("UT99 controller fallback gameplay direction ignored type=%ld reason=ambiguous-sticks",
                      press.type.rawValue)
            }
            return
        default:
            if pressed {
                NSLog("UT99 controller press fallback unmapped type=%ld pressed=%@",
                      press.type.rawValue, pressed ? "true" : "false")
            }
            // Responder-only input contains no controller identity, separate
            // stick axes, or stable trigger/button profile. Touch owns all
            // gameplay until GameController publishes an extended profile.
            return
        }
    }

    private func updateControllerFallbackMenuCursor() {
        var raw = CGPoint.zero
        for type in activeControllerFallbackPresses.values {
            switch type {
            case .upArrow: raw.y += 1
            case .downArrow: raw.y -= 1
            case .leftArrow: raw.x -= 1
            case .rightArrow: raw.x += 1
            default: break
            }
        }
        let magnitude = sqrt(raw.x * raw.x + raw.y * raw.y)
        let vector: CGPoint
        if magnitude > 0 {
            let fallbackSpeed: CGFloat = 0.45
            vector = CGPoint(
                x: raw.x / magnitude * fallbackSpeed,
                y: raw.y / magnitude * fallbackSpeed
            )
        } else {
            vector = .zero
        }
        guard vector != lastControllerFallbackMenuVector else { return }
        lastControllerFallbackMenuVector = vector
        engineBridge.publishMenuCursor(vector, active: magnitude > 0)
        NSLog("UT99 controller fallback cursor vector=%.2f,%.2f activePresses=%lu",
              vector.x, vector.y, activeControllerFallbackPresses.count)
    }

    /// Hot-connected controllers can first arrive as responder presses after
    /// the legacy SDL loop takes over. Re-enumerate on that live main-thread
    /// event so the extended profile and its right-stick/trigger handlers are
    /// installed without requiring an app restart.
    @discardableResult
    private func prepareControllerFromActiveEvent() -> Bool {
        // Record ownership before re-enumeration. If this responder edge is
        // what discovers a hot-connected controller, the native handler could
        // not have delivered that first edge, so the fallback must carry it.
        let nativeControllerOwnedEvent = configuredExtendedControllerIsPresent()
        if nativeControllerOwnedEvent { return true }
        if controllerFallbackConnected { return false }
        reassertControllerEventRouting()
        let foundExtended = configureAvailableControllers(reason: "active responder event")
        if foundExtended {
            controllerFallbackConnected = false
            updateTouchVisibility()
            return nativeControllerOwnedEvent
        }

        if !controllerFallbackConnected {
            controllerFallbackConnected = true
            // A responder-only press proves that UIKit saw some controller
            // input, not that GameController published the separate sticks and
            // triggers required for gameplay. Never hide the complete touch
            // controls until a real extended profile exists.
            controllerAutoHideActive = false
            updateTouchVisibility()
        }
        guard !attemptedHotControllerDiscovery else { return false }
        attemptedHotControllerDiscovery = true
        GCController.startWirelessControllerDiscovery { [weak self] in
            guard let self else { return }
            let found = self.configureAvailableControllers(reason: "hot discovery completion")
            if found {
                self.controllerFallbackConnected = false
                DispatchQueue.main.async { [weak self] in self?.updateTouchVisibility() }
            }
        }
        return false
    }

    private func reassertControllerEventRouting() {
        controllerUserInteractionEnabled = false
        for window in view.window?.windowScene?.windows ?? [] {
            (window.rootViewController as? GCEventViewController)?.controllerUserInteractionEnabled = false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        controllerUserInteractionEnabled = false
        NSLog("UT99 controller event root active uiInteraction=false")
        // The game shell and EctoPad reference are deliberately dark. Pinning
        // the host to dark appearance also keeps native menus, popovers, and
        // segmented controls coherent over gameplay.
        overrideUserInterfaceStyle = .dark
        prepareBundledData()
        let identity = appIdentity()
        if CommandLine.arguments.contains("-UT99RecoverySmokeTest") {
            do {
                try runtimeRecovery.seedAbandonedSessionForTesting(
                    appVersion: identity.version,
                    appBuild: identity.build
                )
            } catch {
                NSLog("UT99 recovery smoke seed failed: %@", error.localizedDescription)
            }
        }
        do {
            recoveredSession = try runtimeRecovery.recoverAbandonedSession()
        } catch {
            NSLog("UT99 recovery marker inspection failed: %@", error.localizedDescription)
        }
        view.backgroundColor = UIColor(red: 0.02, green: 0.028, blue: 0.055, alpha: 1)

        backdropLayer.colors = [
            UIColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 1).cgColor,
            UIColor(red: 0.02, green: 0.16, blue: 0.22, alpha: 1).cgColor,
            UIColor(red: 0.04, green: 0.03, blue: 0.11, alpha: 1).cgColor
        ]
        backdropLayer.locations = [0, 0.55, 1]
        backdropLayer.startPoint = CGPoint(x: 0, y: 0)
        backdropLayer.endPoint = CGPoint(x: 1, y: 1)
        backdropLayer.frame = view.bounds
        view.layer.insertSublayer(backdropLayer, at: 0)

        gameView.translatesAutoresizingMaskIntoConstraints = false
        gameView.delegate = self
        gameView.isPaused = true
        gameView.enableSetNeedsDisplay = true
        // This MTKView is the transparent host shell, not FruCoRe's SDL Metal
        // surface. Keep its dormant cadence conventional; renderer timing is
        // measured at FruCoRe's actual presentDrawable boundary.
        gameView.preferredFramesPerSecond = 60
        gameView.isOpaque = false
        gameView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.addSubview(gameView)
        NSLayoutConstraint.activate([
            gameView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gameView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gameView.topAnchor.constraint(equalTo: view.topAnchor),
            gameView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        gameSurfaceInputView.translatesAutoresizingMaskIntoConstraints = false
        gameSurfaceInputView.isUserInteractionEnabled = false
        gameSurfaceInputView.onPointer = { [weak self] location, pressed, anchor in
            guard let self else { return }
            self.engineBridge.publishExternalMenuPointer(
                location: self.rendererPoint(fromHostPoint: location),
                pressed: pressed,
                anchor: anchor
            )
        }
        gameSurfaceInputView.onLook = { [weak self] value, active in
            self?.engineBridge.publishTouchLook(value, active: active)
        }
        gameSurfaceInputView.onPrimaryAction = { [weak self] pressed in
            self?.engineBridge.publishTouchAction(.primaryFire, pressed: pressed)
        }
        view.addSubview(gameSurfaceInputView)
        NSLayoutConstraint.activate([
            gameSurfaceInputView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gameSurfaceInputView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gameSurfaceInputView.topAnchor.constraint(equalTo: view.topAnchor),
            gameSurfaceInputView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        touchOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(touchOverlay)
        NSLayoutConstraint.activate([
            touchOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            touchOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            touchOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            touchOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        touchOverlay.onAction = { [weak self] action, pressed in
            guard let self else { return }
            NSLog("UT99 touch action=%@ pressed=%@", action.rawValue, pressed ? "true" : "false")
            let isSelect = action == .primaryFire || action == .leftPrimaryFire
            if isSelect && !pressed && self.menuSelectPressed {
                self.engineBridge.publishMenuCursorClick(pressed: false)
                self.menuSelectPressed = false
                return
            }
            if self.originalMenuInputActive,
               isSelect {
                if pressed { self.menuSelectPressed = true }
                self.engineBridge.publishMenuCursorClick(pressed: pressed)
                return
            }
            self.engineBridge.publishTouchAction(action, pressed: pressed)
        }
        touchOverlay.onMove = { [weak self] value, active in
            guard let self else { return }
            if self.originalMenuInputActive {
                self.engineBridge.publishMenuCursor(value, active: active)
            } else {
                self.engineBridge.publishTouchMove(value, active: active)
            }
        }
        touchOverlay.onMenuCursorNudge = { [weak self] offset in
            self?.engineBridge.nudgeMenuCursor(by: offset)
        }
        touchOverlay.onLook = { [weak self] value, active in
            self?.engineBridge.publishTouchLook(value, active: active)
        }
        configureAppleIntegrations()

        let eyebrow = UILabel()
        eyebrow.text = "OLDUNREAL  ·  v469e"
        eyebrow.textColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 1)
        eyebrow.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        eyebrow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(eyebrow)

        let title = UILabel()
        title.text = "UNREAL TOURNAMENT"
        title.textColor = .white
        title.font = .systemFont(ofSize: 32, weight: .black)
        title.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(title)

        statusLabel.text = "Metal host  ·  ready for original engine"
        statusLabel.textColor = UIColor(white: 0.72, alpha: 1)
        statusLabel.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        statusLabel.numberOfLines = 0
        statusLabel.lineBreakMode = .byCharWrapping
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        if let recoveredSession,
           isGameDataReady() || CommandLine.arguments.contains("-UT99RecoverySmokeTest") {
            transition(to: .crashed, reason: "previous active session marker recovered")
            let mode = recoveredSession.safeMode ? "safe mode" : "normal mode"
            statusLabel.text = "Previous \(mode) session ended unexpectedly · recovery available"
            writeRecoverySmokeResultIfRequested(recoveredSession)
        } else if recoveredSession != nil {
            self.recoveredSession = nil
            transition(to: .needsData, reason: "recovered session has incomplete runtime support")
            statusLabel.text = "Game-data repair required · runtime support was incomplete"
        }

        let rule = UIView()
        rule.backgroundColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 0.8)
        rule.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rule)

        // Match SunPad/EctoPad's persistent three-dot surface literally: a
        // 40-point neutral circle, one white hairline, and UIKit's own menu.
        menuButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        menuButton.imageView?.contentMode = .scaleAspectFit
        menuButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 19, weight: .bold),
            forImageIn: .normal
        )
        menuButton.tintColor = .white
        menuButton.backgroundColor = UIColor(white: 0.06, alpha: 0.72)
        menuButton.layer.cornerRadius = 20
        menuButton.layer.borderWidth = 1
        menuButton.layer.borderColor = UIColor.white.withAlphaComponent(0.30).cgColor
        menuButton.layer.masksToBounds = true
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.accessibilityLabel = "Menu"
        // A native UIMenu is composited in a separate system window. Above
        // SDL's renderer that window can stretch into an unusable oval on
        // iPadOS. Keep the same three-dot affordance, but open a bounded host
        // panel inside our stable overlay window.
        menuButton.showsMenuAsPrimaryAction = false
        menuButton.menu = nil
        menuButton.addTarget(self, action: #selector(toggleMenu), for: .touchUpInside)
        menuButton.onAccessibilityActivate = { [weak self] in
            self?.toggleMenu()
        }
        view.addSubview(menuButton)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            eyebrow.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 32),
            eyebrow.topAnchor.constraint(equalTo: safe.topAnchor, constant: 24),
            title.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 32),
            title.topAnchor.constraint(equalTo: eyebrow.bottomAnchor, constant: 6),
            statusLabel.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            statusLabel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            rule.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            rule.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 14),
            rule.widthAnchor.constraint(equalToConstant: 84),
            rule.heightAnchor.constraint(equalToConstant: 3),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: menuButton.leadingAnchor, constant: -18),
            menuButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            // Clear UT's own top title/menu strip instead of covering the
            // version/release text at the upper-right corner.
            menuButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 40),
            menuButton.widthAnchor.constraint(equalToConstant: 40),
            menuButton.heightAnchor.constraint(equalToConstant: 40)
        ])

        configureOnboardingPanel()
        if recoveredSession == nil {
            reconcileGameDataState(reason: "initial data readiness check")
        } else {
            updateOnboardingPanel()
        }

        let g2SmokeRequested = CommandLine.arguments.contains("-UT99G2SmokeTest")
        if g2SmokeRequested || CommandLine.arguments.contains("-UT99ImportTransactionSmokeTest") {
            runDataImportTransactionSmokeTest()
        }
        if CommandLine.arguments.contains("-UT99ImportProgressSmokeTest") {
            runImportProgressUISmokeTest()
        }
        if g2SmokeRequested || CommandLine.arguments.contains("-UT99TouchDefaultSmokeTest") {
            touchOverlay.resetTouchLayout()
            touchOverlay.applyTouchProfile(.standard)
            touchOverlay.setGlobalScale(1.0)
            statusLabel.text = "Touch visual smoke · Standard · 100%"
            NSLog("UT99 touch visual smoke profile=standard userScale=1.0")
        } else if CommandLine.arguments.contains("-UT99TouchGeometrySmokeTest") {
            touchOverlay.applyTouchProfile(.highVisibility)
            touchOverlay.setGlobalScale(1.35)
            statusLabel.text = "Touch geometry smoke · High visibility · 135%"
            NSLog("UT99 touch geometry smoke profile=highVisibility userScale=1.35")
        }
        if CommandLine.arguments.contains("-UT99TouchEditorSmokeTest") {
            touchOverlay.setLayoutEditing(true)
            statusLabel.text = "Drag controls · pinch to resize · safe area shown"
            NSLog("UT99 touch editor smoke presented=true")
        }
        if CommandLine.arguments.contains("-UT99TouchConfigurationSmokeTest") {
            touchOverlay.resetTouchLayout()
            touchOverlay.setLeftHanded(true)
            touchOverlay.setAction(.scoreboard, visible: false)
            touchOverlay.setAction(.crouch, visible: false)
            touchOverlay.setLayoutTesting(true)
            statusLabel.text = "Live test · left-handed · SCORE and DUCK hidden"
            let configuration = touchOverlay.touchConfiguration
            NSLog("UT99 touch configuration smoke leftHanded=%@ hidden=%lu testing=%@",
                  configuration.leftHanded ? "true" : "false",
                  configuration.hiddenActions.count,
                  touchOverlay.testingLayout ? "true" : "false")
        }
        if CommandLine.arguments.contains("-UT99TouchProfileSmokeTest") {
            runTouchProfileSmokeTest()
        }
        if CommandLine.arguments.contains("-UT99DiagnosticsExportSmokeTest") {
            runDiagnosticsExportSmokeTest()
        }
        if CommandLine.arguments.contains("-UT99ControllerProbe") {
            statusLabel.text = "CONTROLLER PROBE · connect the Xbox controller now"
            _ = configureAvailableControllers(reason: "pre-engine controller probe")
            NSLog("UT99 controller probe armed engineStarted=false")
        }
        if g2SmokeRequested {
            pendingG2DiagnosticsExport = true
            NSLog("UT99 G2 host smoke started importer=true diagnostics=true metal=true standardTouch=true")
        }
        let normalVerifiedLaunch = recoveredSession == nil && isGameDataReady() &&
            !CommandLine.arguments.dropFirst().contains { $0.hasPrefix("-UT99") }
        if CommandLine.arguments.contains("-UT99AutoStart") || normalVerifiedLaunch {
            if normalVerifiedLaunch { showLaunchTransition() }
            waitForLandscapeAndAutoStart(attempt: 0)
        }
    }

    private func showLaunchTransition() {
        guard launchTransitionView == nil else { return }
        let curtain = UIView()
        curtain.backgroundColor = .black
        curtain.isUserInteractionEnabled = false
        curtain.translatesAutoresizingMaskIntoConstraints = false

        let mark = UILabel()
        mark.text = "UTP"
        mark.textColor = .white
        mark.font = .systemFont(ofSize: 34, weight: .black)
        mark.translatesAutoresizingMaskIntoConstraints = false
        curtain.addSubview(mark)

        let detail = UILabel()
        detail.text = "STARTING UNREAL TOURNAMENT"
        detail.textColor = UIColor.white.withAlphaComponent(0.58)
        detail.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        detail.translatesAutoresizingMaskIntoConstraints = false
        curtain.addSubview(detail)

        view.addSubview(curtain)
        NSLayoutConstraint.activate([
            curtain.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            curtain.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            curtain.topAnchor.constraint(equalTo: view.topAnchor),
            curtain.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mark.centerXAnchor.constraint(equalTo: curtain.centerXAnchor),
            mark.centerYAnchor.constraint(equalTo: curtain.centerYAnchor, constant: -10),
            detail.centerXAnchor.constraint(equalTo: curtain.centerXAnchor),
            detail.topAnchor.constraint(equalTo: mark.bottomAnchor, constant: 8),
        ])
        launchTransitionView = curtain
        view.bringSubviewToFront(curtain)
    }

    private func waitForLandscapeAndAutoStart(attempt: Int) {
        guard !hasAutoStartedFromArguments else { return }
        view.layoutIfNeeded()
        let sceneOrientation = view.window?.windowScene?.interfaceOrientation
        let isLandscapeScene = sceneOrientation?.isLandscape == true
        if !isLandscapeScene {
            if attempt < 40 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.waitForLandscapeAndAutoStart(attempt: attempt + 1)
                }
                return
            }
            NSLog("UT99EngineBridge auto-start landscape wait timed out bounds=%@ orientation=%ld",
                  self.view.bounds.debugDescription,
                  Int(sceneOrientation?.rawValue ?? 0))
        }

        hasAutoStartedFromArguments = true
        let connectURL = CommandLine.arguments.first(where: { $0.hasPrefix("-UT99Connect=") })
            .map { String($0.dropFirst("-UT99Connect=".count)) }
        guard let result = launchEngine(connectURL: connectURL) else { return }
        NSLog("UT99EngineBridge auto-start result: %@ bounds=%@ orientation=%ld",
              result.statusText,
              view.bounds.debugDescription,
              Int(view.window?.windowScene?.interfaceOrientation.rawValue ?? 0))
        if CommandLine.arguments.contains("-UT99DuplicateStartSmokeTest") {
            let blocked = launchEngine() == nil
            let line = "UT99 duplicate engine start smoke blocked=\(blocked) state=\(hostState.rawValue)\n"
            let supportRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Unreal Tournament", isDirectory: true)
            try? Data(line.utf8).write(
                to: supportRoot.appendingPathComponent("UT99-duplicate-start-smoke.log"),
                options: .atomic
            )
            NSLog("%@", line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if CommandLine.arguments.contains("-UT99TouchSmokeTest") {
            engineBridge.runTouchSmokeTest()
        }
        if CommandLine.arguments.contains("-UT99ServerBrowserJoinSmokeTest") {
            engineBridge.runServerBrowserJoinSmokeTest()
        } else if CommandLine.arguments.contains("-UT99ServerBrowserPointerSmokeTest") {
            engineBridge.runServerBrowserPointerSmokeTest()
        }
        if CommandLine.arguments.contains("-UT99NetworkSessionSmokeTest") {
            engineBridge.runNetworkSessionSmokeTest()
        }
        if CommandLine.arguments.contains("-UT99MenuSmokeTest") {
            runMenuSmokeTest()
        }
        if CommandLine.arguments.contains("-UT99LayoutSmokeTest") {
            runLayoutSmokeTest()
        }
        if CommandLine.arguments.contains("-UT99SettingsSmokeTest") {
            runSettingsSmokeTest()
        }
        if CommandLine.arguments.contains("-UT99MenuKeyboardAcceptance") {
            // Preserve the older flag as an alias for the real edit-box test.
            // A console-only probe cannot prove that UWindowEditBox accepted
            // printable text.
            engineBridge.runPlayerNameNavigationSmokeTest()
        }
        if CommandLine.arguments.contains("-UT99PlayerNameNavigationSmokeTest") {
            engineBridge.runPlayerNameNavigationSmokeTest()
        }
        if CommandLine.arguments.contains("-UT99PerformanceSmokeTest") {
            engineBridge.runPerformanceSmokeTest()
        }
    }

    private func transition(to next: HostState, reason: String) {
        guard hostState != next else { return }
        NSLog("UT99 host state %@ -> %@ reason=%@", hostState.rawValue, next.rawValue, reason)
        hostState = next
        refreshHostMenu()
        updateOnboardingPanel()
    }

    private func appIdentity() -> (version: String, build: String) {
        let info = Bundle.main.infoDictionary ?? [:]
        return (
            info["CFBundleShortVersionString"] as? String ?? "dev",
            info["CFBundleVersion"] as? String ?? "unknown"
        )
    }

    private func presentRecoveryPromptIfNeeded() {
        guard !CommandLine.arguments.contains("-UT99G2SmokeTest"),
              !CommandLine.arguments.contains("-UT99AutoStart"),
              let recoveredSession,
              !recoveryPromptPresented,
              presentedViewController == nil,
              hostState == .crashed else { return }
        recoveryPromptPresented = true
        let mode = recoveredSession.safeMode ? "safe-mode" : "normal"
        let message = "The previous \(mode) engine session did not reach a controlled stop. No imported data was changed. You can retry with conservative graphics and audio disabled, try the normal profile, or inspect diagnostics first."
        let alert = UIAlertController(
            title: "Previous Session Interrupted",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Start in Safe Mode", style: .default) { [weak self] _ in
            self?.prepareSafeModePreferences()
            _ = self?.launchEngine(safeMode: true)
        })
        alert.addAction(UIAlertAction(title: "Try Normal Start", style: .default) { [weak self] _ in
            self?.pendingSafeMode = false
            _ = self?.launchEngine()
        })
        alert.addAction(UIAlertAction(title: "Diagnostics", style: .default) { [weak self] _ in
            DispatchQueue.main.async {
                self?.supportExportNotice = "RECOVERY DIAGNOSTICS\nExport logs if needed, then start normally or in Safe Mode below."
                self?.toggleMenu()
            }
        })
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { [weak self] _ in
            guard let self else { return }
            self.transition(to: .ready, reason: "recovery deferred by player")
            // UIAlertController runs its action before the dismissal animation
            // has fully restored the presenting hierarchy. Reassert the Ready
            // surface on the next main-loop turn so the landing panel cannot
            // remain hidden behind the dismissed recovery sheet.
            DispatchQueue.main.async { [weak self] in
                self?.updateOnboardingPanel()
            }
        })
        present(alert, animated: true)
    }

    private func writeRecoverySmokeResultIfRequested(_ record: UT99RuntimeSessionRecord) {
        guard CommandLine.arguments.contains("-UT99RecoverySmokeTest") else { return }
        let line = [
            "recovered=true",
            "state=\(hostState.rawValue)",
            "previousState=\(record.state)",
            "safeMode=\(record.safeMode)",
            runtimeRecovery.diagnosticSummary()
        ].joined(separator: " ") + "\n"
        let url = dataSupportRoot().appendingPathComponent("UT99-recovery-smoke.log")
        try? Data(line.utf8).write(to: url, options: .atomic)
        NSLog("UT99 recovery smoke %@", line.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    deinit {
        engineBridge.releaseMovementKeys()
        controllerMonitorTimer?.cancel()
        for observer in appleIntegrationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        networkMonitor.cancel()
    }

    private func configureAppleIntegrations() {
        networkMonitor.pathUpdateHandler = { path in
            let interfaces = path.availableInterfaces.map { String(describing: $0.type) }.joined(separator: ",")
            NSLog("UT99 network path status=%@ constrained=%@ expensive=%@ interfaces=%@",
                  path.status == .satisfied ? "satisfied" : "unsatisfied",
                  path.isConstrained ? "true" : "false",
                  path.isExpensive ? "true" : "false",
                  interfaces)
        }
        networkMonitor.start(queue: networkMonitorQueue)
        GCController.shouldMonitorBackgroundEvents = true
        let center = NotificationCenter.default
        appleIntegrationObservers.append(center.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: nil
        ) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            self?.controllerFallbackConnected = false
            self?.configureController(controller)
            DispatchQueue.main.async { [weak self] in self?.updateTouchVisibility() }
            NSLog("UT99 controller connected: %@", controller.vendorName ?? "unknown")
        })
        appleIntegrationObservers.append(center.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: nil
        ) { [weak self] note in
            let controller = note.object as? GCController
            if let controller { self?.removeConfiguredController(controller) }
            self?.controllerFallbackConnected = false
            self?.attemptedHotControllerDiscovery = false
            self?.engineBridge.releaseMovementKeys()
            self?.engineBridge.releaseControllerLook()
            NSLog("UT99 controller disconnected: %@", controller?.vendorName ?? "unknown")
            DispatchQueue.main.async { [weak self] in
                self?.clearControllerFallbackPresses(reason: "controller-disconnect", rearmMenuCursor: true)
                self?.updateTouchVisibility()
            }
        })
        appleIntegrationObservers.append(center.addObserver(
            forName: .GCControllerDidBecomeCurrent, object: nil, queue: nil
        ) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            self?.controllerFallbackConnected = false
            self?.configureController(controller)
            NSLog("UT99 controller became current: %@", controller.vendorName ?? "unknown")
            DispatchQueue.main.async { [weak self] in self?.updateTouchVisibility() }
        })
        appleIntegrationObservers.append(center.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            if self?.hostState == .running {
                self?.transition(to: .pausedBySystem, reason: "application resigned active")
            }
            self?.releaseGameplayInputs()
            self?.touchOverlay.isUserInteractionEnabled = false
            self?.gameSurfaceInputView.isUserInteractionEnabled = false
            NSLog("UT99 lifecycle: resign-active")
        })
        appleIntegrationObservers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            if self?.hostState == .pausedBySystem {
                self?.transition(to: .running, reason: "application became active")
            }
            guard let self else { return }
            self.reassertControllerEventRouting()
            _ = self.configureAvailableControllers(reason: "application became active")
            self.updateTouchVisibility()
            self.activateGameAudioSession()
            self.presentSDLWindowIfAvailable()
            NSLog("UT99 lifecycle: active")
        })
        appleIntegrationObservers.append(center.addObserver(
            forName: UIApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self,
                  self.hostState == .startingEngine || self.hostState == .running || self.hostState == .pausedBySystem else {
                return
            }
            self.transition(to: .stoppingEngine, reason: "application termination callback")
            do {
                try self.runtimeRecovery.finishCleanly("application termination callback")
            } catch {
                NSLog("UT99 clean termination marker failed: %@", error.localizedDescription)
            }
            NSLog("UT99 lifecycle: terminate")
        })
        appleIntegrationObservers.append(center.addObserver(
            forName: UIWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let becameKey = note.object as? UIWindow,
                  becameKey !== self.view.window else { return }
            // Only SDL's renderer window needs this repair. System menu and
            // alert windows also become key briefly; stealing key status back
            // from those windows made the three-dot menu appear to crash.
            let rootName = becameKey.rootViewController.map { String(describing: type(of: $0)) } ?? ""
            guard rootName.contains("SDL") else { return }
            DispatchQueue.main.async { [weak self] in
                self?.presentSDLWindowIfAvailable()
            }
        })
        appleIntegrationObservers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue ?? 0
            NSLog("UT99 audio interruption type=%lu", type)
            if type == AVAudioSession.InterruptionType.ended.rawValue {
                self?.activateGameAudioSession()
            }
        })
        appleIntegrationObservers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue ?? 0
            NSLog("UT99 audio route changed reason=%lu", reason)
        })
        let controllerPresentAtLaunch = configureAvailableControllers(reason: "initial integration")
        if !controllerPresentAtLaunch {
            // Touch is the safe input baseline for a controller-free launch.
            // A prior session may have hidden it while a controller was in
            // use; do not strand the next controller-free startup.
            UserDefaults.standard.set(true, forKey: Self.touchInputEnabledKey)
        }
        startControllerMonitor()
        updateTouchVisibility()
        GCController.startWirelessControllerDiscovery { NSLog("UT99 controller discovery finished") }
        activateGameAudioSession()
    }

    private func updateTouchVisibility() {
        // The simulator can expose a virtual controller profile even when no
        // hardware is attached. Keep touch controls visible in that case;
        // only a real attached extended gamepad should take over the screen.
        #if targetEnvironment(simulator)
        let extendedControllerConnected = false
        let extendedControllerDescription = "ignored-virtual-profile"
        #else
        let extendedControllerConnected =
            GCController.controllers().contains { $0.extendedGamepad != nil } ||
            GCController.current?.extendedGamepad != nil
        let extendedControllerDescription = extendedControllerConnected ? "true" : "false"
        #endif
        let engineActive = hostState == .startingEngine || hostState == .running || hostState == .pausedBySystem
        let configuration = UT99TouchConfiguration.load()
        if extendedControllerConnected && !wasExtendedControllerConnected && configuration.autoHideForController {
            controllerAutoHideActive = true
        } else if !extendedControllerConnected {
            controllerAutoHideActive = false
        }
        wasExtendedControllerConnected = extendedControllerConnected
        let touchEnabled = isTouchInputEnabled
        let shouldHide = !engineActive || !touchEnabled || controllerAutoHideActive
        if shouldHide && touchInputWasVisible {
            releaseTouchInputs()
        }
        touchInputWasVisible = !shouldHide
        touchOverlay.isHidden = shouldHide
        touchOverlay.isUserInteractionEnabled = !shouldHide
        // Keep a visible, usable menu pointer when touch controls are disabled
        // or controller input hides the combat overlay. This also prevents a
        // BACK press that merely closes a stock dialog from stranding the user
        // on another UWindow menu without any pointer surface.
        let pointerFallbackActive = originalMenuInputActive || !touchEnabled || controllerAutoHideActive
        gameSurfaceInputView.setInputMode(pointerFallbackActive ? .originalMenu : .gameplayLook)
        // This transparent surface is also the hardware mouse/trackpad bridge
        // in gameplay, so it must remain active even when touch controls show.
        gameSurfaceInputView.isUserInteractionEnabled = engineActive
        NSLog("UT99 touch overlay %@ enabled=%@ extendedController=%@ responderFallback=%@ autoHide=%@ autoHideActive=%@ pointerMode=%@ pointerSurface=%@",
              shouldHide ? "hidden" : "visible",
              touchEnabled ? "true" : "false",
              extendedControllerDescription,
              controllerFallbackConnected ? "true" : "false",
              configuration.autoHideForController ? "true" : "false",
              controllerAutoHideActive ? "true" : "false",
              pointerFallbackActive ? "menu" : "gameplay",
              gameSurfaceInputView.isUserInteractionEnabled ? "true" : "false")
    }

    private var isTouchInputEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.touchInputEnabledKey) as? Bool ?? true
    }

    private func setTouchInputEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.touchInputEnabledKey)
        if enabled {
            // A deliberate Turn On wins over the automatic controller hide.
            // The next disconnect/reconnect may auto-hide again.
            controllerAutoHideActive = false
        }
        updateTouchVisibility()
        refreshHostMenu()
        NSLog("UT99 touch input user toggle enabled=%@", enabled ? "true" : "false")
    }

    @objc private func toggleTouchInputEnabled() {
        setTouchInputEnabled(!isTouchInputEnabled)
    }

    private func releaseGameplayInputs() {
        clearControllerFallbackPresses(reason: "release-gameplay-inputs", rearmMenuCursor: false)
        gameSurfaceInputView.releasePointer()
        touchOverlay.releaseActiveInputs()
        engineBridge.releaseMovementKeys()
        engineBridge.releaseControllerLook()
        engineBridge.releaseMenuCursor()
        engineBridge.publishTouchLook(.zero, active: false)
    }

    private func clearControllerFallbackPresses(reason: String, rearmMenuCursor: Bool) {
        let count = activeControllerFallbackPresses.count
        activeControllerFallbackPresses.removeAll()
        lastControllerFallbackMenuVector = .zero
        engineBridge.releaseMenuCursor()
        if rearmMenuCursor && originalMenuInputActive {
            engineBridge.beginMenuCursor(canvasSize: currentRendererViewportFrame().size)
        }
        if count > 0 {
            NSLog("UT99 controller fallback cleared reason=%@ presses=%lu rearmed=%@",
                  reason, count, rearmMenuCursor ? "true" : "false")
        }
    }

    private func releaseTouchInputs() {
        gameSurfaceInputView.releasePointer()
        touchOverlay.releaseActiveInputs()
        engineBridge.releaseMenuCursor()
        engineBridge.publishTouchLook(.zero, active: false)
    }

    private func setOriginalMenuInputActive(_ active: Bool) {
        originalMenuInputActive = active
        gameSurfaceInputView.setInputMode(active ? .originalMenu : .gameplayLook)
        touchOverlay.setMenuInteractionActive(active)
        if active {
            engineBridge.beginMenuCursor(canvasSize: currentRendererViewportFrame().size)
            updateControllerFallbackMenuCursor()
        } else {
            lastControllerFallbackMenuVector = .zero
            engineBridge.releaseMenuCursor()
        }
        updateTouchVisibility()
        NSLog("UT99 touch surface mode=%@", active ? "original-menu" : "gameplay-look")
    }

    private func selectTouchInterfaceMode(menu: Bool) {
        // Mode selects routing for touch, controller, mouse, and trackpad.
        // Visibility is an independent user choice; changing controller mode
        // must not unexpectedly turn the touch overlay back on.
        setOriginalMenuInputActive(menu)
        if !menu { prepareResponderFallbackGameplay() }
        refreshHostMenu()
        closeHostMenuPanel()
        NSLog("UT99 touch interface manually selected mode=%@",
              originalMenuInputActive ? "menu" : "gameplay")
    }

    private func toggleTouchInterfaceMode() {
        selectTouchInterfaceMode(menu: !originalMenuInputActive)
    }

    private func startControllerMonitor() {
        let timer = DispatchSource.makeTimerSource(queue: controllerMonitorQueue)
        timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            var controllers = GCController.controllers()
            if let current = GCController.current,
               !controllers.contains(where: { $0 === current }) {
                controllers.append(current)
            }
            for controller in controllers where controller.extendedGamepad != nil {
                self.configureController(controller)
            }
            let signature = controllers.map {
                "\($0.vendorName ?? "unknown"):\($0.extendedGamepad != nil)"
            }.joined(separator: ",")
            if signature != self.lastControllerMonitorSignature {
                self.lastControllerMonitorSignature = signature
                let extendedCount = controllers.filter { $0.extendedGamepad != nil }.count
                NSLog("UT99 controller monitor count=%lu names=%@",
                      controllers.count, signature.isEmpty ? "none" : signature)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.updateTouchVisibility()
                    if CommandLine.arguments.contains("-UT99ControllerProbe") {
                        self.statusLabel.text = extendedCount > 0
                            ? "CONTROLLER PROBE · extended profile ready"
                            : "CONTROLLER PROBE · waiting for extended profile"
                    }
                }
            }
        }
        controllerMonitorTimer = timer
        timer.resume()
    }

    @discardableResult
    private func configureAvailableControllers(reason: String) -> Bool {
        var controllers = GCController.controllers()
        if let current = GCController.current,
           !controllers.contains(where: { $0 === current }) {
            controllers.append(current)
        }
        let extended = controllers.filter { $0.extendedGamepad != nil }
        for controller in extended { configureController(controller) }
        NSLog("UT99 controller enumerate reason=%@ main=%@ count=%lu extended=%lu",
              reason, Thread.isMainThread ? "true" : "false",
              controllers.count, extended.count)
        return !extended.isEmpty
    }

    private func removeConfiguredController(_ controller: GCController) {
        configuredControllerLock.lock()
        configuredControllerIDs.remove(ObjectIdentifier(controller))
        configuredControllerLock.unlock()
    }

    private func configuredExtendedControllerIsPresent() -> Bool {
        var controllers = GCController.controllers()
        if let current = GCController.current,
           !controllers.contains(where: { $0 === current }) {
            controllers.append(current)
        }
        let connectedIDs = controllers.compactMap { controller -> ObjectIdentifier? in
            guard controller.extendedGamepad != nil else { return nil }
            return ObjectIdentifier(controller)
        }
        configuredControllerLock.lock()
        let present = connectedIDs.contains { configuredControllerIDs.contains($0) }
        configuredControllerLock.unlock()
        return present
    }

    private func configureController(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        let identifier = ObjectIdentifier(controller)
        configuredControllerLock.lock()
        let inserted = configuredControllerIDs.insert(identifier).inserted
        configuredControllerLock.unlock()
        guard inserted else { return }
        // GCController defaults handlers to the main queue. The original UT
        // loop owns that thread, so physical input must use the independent
        // monitor queue or button/stick callbacks can appear connected yet
        // never execute.
        controller.handlerQueue = controllerMonitorQueue
        NSLog("UT99 controller configured vendor=%@ attached=%@",
              controller.vendorName ?? "unknown",
              controller.isAttachedToDevice ? "true" : "false")
        pad.valueChangedHandler = { [weak self] _, element in
            guard let self else { return }
            if element === pad.leftThumbstick {
                let x = CGFloat(pad.leftThumbstick.xAxis.value)
                let y = CGFloat(pad.leftThumbstick.yAxis.value)
                let movement = UT99TouchInputTuning.controllerMovement(CGPoint(x: x, y: y))
                let active = movement.x != 0 || movement.y != 0
                self.logControllerSample(
                    kind: "left-stick",
                    raw: CGPoint(x: x, y: y),
                    transformed: movement,
                    active: active
                )
                if self.originalMenuInputActive {
                    let cursor = UT99TouchInputTuning.controllerMenuCursor(CGPoint(x: x, y: y))
                    self.engineBridge.publishMenuCursor(cursor, active: cursor != .zero)
                } else {
                    self.engineBridge.publishTouchMove(movement, active: active)
                }
            } else if element === pad.dpad {
                // Preserve the physical D-pad path instead of reading the
                // unrelated stick axes when a D-pad element changes.
                let stickX = CGFloat(pad.leftThumbstick.xAxis.value)
                let stickY = CGFloat(pad.leftThumbstick.yAxis.value)
                let stickActive = max(abs(stickX), abs(stickY)) > 0.08
                let raw = stickActive
                    ? CGPoint(x: stickX, y: stickY)
                    : CGPoint(x: CGFloat(pad.dpad.xAxis.value), y: CGFloat(pad.dpad.yAxis.value))
                let movement = stickActive ? UT99TouchInputTuning.controllerMovement(raw) : raw
                let x = movement.x
                let y = movement.y
                let active = max(abs(x), abs(y)) > 0.08
                self.logControllerSample(kind: "dpad", raw: raw, transformed: movement, active: active)
                if self.originalMenuInputActive {
                    self.engineBridge.publishMenuCursor(CGPoint(x: x, y: y), active: active)
                } else {
                    self.engineBridge.publishTouchMove(CGPoint(x: x, y: y), active: active)
                }
            } else if element === pad.rightThumbstick {
                let raw = CGPoint(
                    x: CGFloat(pad.rightThumbstick.xAxis.value),
                    y: CGFloat(pad.rightThumbstick.yAxis.value)
                )
                let transformed = CGPoint(x: raw.x, y: -raw.y)
                let active = max(abs(transformed.x), abs(transformed.y)) > 0.08
                self.logControllerSample(
                    kind: "right-stick",
                    raw: raw,
                    transformed: transformed,
                    active: active
                )
                if !self.originalMenuInputActive {
                    self.engineBridge.publishControllerLook(
                        transformed,
                        active: active
                    )
                }
            }
        }
        bind(pad.buttonA, to: .jump, controller: controller)
        bind(pad.buttonB, to: .crouch, controller: controller)
        bind(pad.buttonX, to: .use, controller: controller)
        bind(pad.buttonY, to: .alternateFire, controller: controller)
        bind(pad.rightTrigger, to: .primaryFire, controller: controller)
        bind(pad.leftTrigger, to: .alternateFire, controller: controller)
        // UT's weapon wheel is edge-triggered, so use the physical bumpers
        // for previous/next rather than synthesizing a held key. This keeps
        // the controller path equivalent to the touch rail's shoulder-style
        // PREV/NEXT controls.
        bind(pad.leftShoulder, to: .previousWeapon, controller: controller)
        bind(pad.rightShoulder, to: .nextWeapon, controller: controller)
        // Xbox View/Select is the explicit mode switch. This avoids guessing
        // whether a particular UWindow page or live match currently owns the
        // renderer while still making the transition one controller press.
        pad.buttonOptions?.valueChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.toggleInputModeFromController()
        }
        pad.buttonMenu.valueChangedHandler = { [weak self] _, _, pressed in
            NSLog("UT99 controller menu pressed=%@", pressed ? "true" : "false")
            self?.engineBridge.publishTouchAction(.pause, pressed: pressed)
        }
    }

    private func logControllerSample(
        kind: String,
        raw: CGPoint,
        transformed: CGPoint,
        active: Bool
    ) {
        let now = ProcessInfo.processInfo.systemUptime
        let stateChanged = controllerSampleWasActive[kind] != active
        let intervalElapsed = now - (controllerSampleLastLogAt[kind] ?? 0) >= 0.5
        guard stateChanged || intervalElapsed else { return }
        controllerSampleWasActive[kind] = active
        controllerSampleLastLogAt[kind] = now
        NSLog("UT99 controller sample kind=%@ raw=%.3f,%.3f transformed=%.3f,%.3f active=%@ mode=%@",
              kind, raw.x, raw.y, transformed.x, transformed.y,
              active ? "true" : "false",
              originalMenuInputActive ? "menu" : "gameplay")
    }

    private func toggleInputModeFromController() {
        let menu = !originalMenuInputActive
        // Route the controller immediately on its handler queue. UIKit's main
        // queue can be occupied by the legacy SDL loop, so waiting for it here
        // would make the View button appear inert.
        originalMenuInputActive = menu
        if menu {
            engineBridge.beginMenuCursor(canvasSize: currentRendererViewportFrame().size)
        } else {
            engineBridge.releaseMenuCursor()
            prepareResponderFallbackGameplay()
        }
        NSLog("UT99 controller input mode=%@", menu ? "original-menu" : "gameplay-look")
        DispatchQueue.main.async { [weak self] in
            guard let self, self.originalMenuInputActive == menu else { return }
            self.gameSurfaceInputView.setInputMode(menu ? .originalMenu : .gameplayLook)
            self.touchOverlay.setMenuInteractionActive(menu)
            self.updateTouchVisibility()
            self.refreshHostMenu()
        }
    }

    private func prepareResponderFallbackGameplay() {
        guard controllerFallbackConnected else { return }
        UserDefaults.standard.set(true, forKey: Self.touchInputEnabledKey)
        controllerAutoHideActive = false
        supportExportNotice = "CONTROLLER MENU-ONLY\nThis controller connected after UTP started, so iPadOS did not expose its separate sticks and triggers. Touch gameplay controls remain on. For full Xbox gameplay, reopen UTP with the controller already connected."
        updateTouchVisibility()
        NSLog("UT99 controller responder fallback gameplay protected touch=true")
    }

    private func bind(_ input: GCControllerButtonInput,
                      to action: GoldenPadTouchOverlay.Action,
        controller: GCController) {
        input.valueChangedHandler = { [weak self] _, _, pressed in
            guard let self else { return }
            NSLog("UT99 controller action=%@ pressed=%@",
                  action.rawValue, pressed ? "true" : "false")
            if self.originalMenuInputActive {
                switch action {
                case .primaryFire, .jump:
                    self.engineBridge.publishMenuCursorClick(pressed: pressed)
                case .crouch:
                    self.engineBridge.publishTouchAction(.pause, pressed: pressed)
                default:
                    break
                }
                return
            }
            self.engineBridge.publishTouchAction(action, pressed: pressed)
        }
    }

    private func activateGameAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Retain the session configuration that reached the physical and
            // simulator OpenAL baseline. The playback-only experiment was not
            // accepted and could leave this port with a route but no engine
            // output on the current iPad build.
            try session.setCategory(
                .playAndRecord,
                mode: .gameChat,
                options: [.mixWithOthers, .allowBluetoothHFP, .defaultToSpeaker]
            )
            try session.setActive(true, options: [])
            NSLog("UT99 audio session active route=%@", session.currentRoute.outputs.map(\.portType.rawValue).joined(separator: ","))
        } catch {
            NSLog("UT99 audio session unavailable: %@", error.localizedDescription)
        }
    }

    private func configureOnboardingPanel() {
        let panel = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.layer.cornerRadius = 24
        panel.layer.cornerCurve = .continuous
        panel.layer.borderWidth = 1
        panel.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        panel.clipsToBounds = true

        let eyebrow = UILabel()
        eyebrow.text = "UTP · NATIVE APPLE CLIENT"
        eyebrow.textColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 1)
        eyebrow.font = .monospacedSystemFont(ofSize: 11, weight: .bold)

        let title = UILabel()
        title.textColor = .white
        title.font = .systemFont(ofSize: 25, weight: .bold)
        title.numberOfLines = 1

        let detail = UILabel()
        detail.textColor = UIColor(white: 0.78, alpha: 1)
        detail.font = .systemFont(ofSize: 14, weight: .regular)
        detail.numberOfLines = 0

        let primary = onboardingButton(primary: true)
        primary.addTarget(self, action: #selector(onboardingPrimaryTapped), for: .touchUpInside)
        let secondary = onboardingButton(primary: false)
        secondary.addTarget(self, action: #selector(onboardingSecondaryTapped), for: .touchUpInside)
        let buttons = UIStackView(arrangedSubviews: [primary, secondary])
        buttons.axis = .horizontal
        buttons.spacing = 12
        buttons.distribution = .fillEqually

        let tertiary = UIButton(type: .system)
        tertiary.setTitleColor(UIColor(white: 0.82, alpha: 1), for: .normal)
        tertiary.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        tertiary.contentHorizontalAlignment = .leading
        tertiary.addTarget(self, action: #selector(onboardingTertiaryTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [eyebrow, title, detail, buttons, tertiary])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(5, after: eyebrow)
        stack.setCustomSpacing(18, after: detail)
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView.addSubview(stack)
        view.addSubview(panel)

        let preferredWidth = panel.widthAnchor.constraint(equalToConstant: 620)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor, constant: 22),
            preferredWidth,
            panel.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, constant: -48),
            stack.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 26),
            stack.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -26),
            stack.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -20),
            primary.heightAnchor.constraint(equalToConstant: 48),
            secondary.heightAnchor.constraint(equalToConstant: 48),
            tertiary.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),
        ])

        panel.accessibilityIdentifier = "ut99.onboarding.panel"
        primary.accessibilityIdentifier = "ut99.onboarding.primary"
        secondary.accessibilityIdentifier = "ut99.onboarding.secondary"
        tertiary.accessibilityIdentifier = "ut99.onboarding.tertiary"
        onboardingPanel = panel
        onboardingTitleLabel = title
        onboardingDetailLabel = detail
        onboardingPrimaryButton = primary
        onboardingSecondaryButton = secondary
        onboardingTertiaryButton = tertiary
    }

    private func onboardingButton(primary: Bool) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = primary ? UIButton.Configuration.filled() : UIButton.Configuration.tinted()
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = primary
            ? UIColor(red: 0.04, green: 0.58, blue: 0.69, alpha: 1)
            : UIColor(white: 0.24, alpha: 1)
        configuration.baseForegroundColor = .white
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 14, weight: .bold)
            return outgoing
        }
        button.configuration = configuration
        return button
    }

    private func isGameDataReady() -> Bool {
        if CommandLine.arguments.contains("-UT99OnboardingSmokeTest") {
            return false
        }
        if let bundledData = Bundle.main.url(forResource: "UT99Data", withExtension: nil),
           UT99DataImportTransaction.contentDirectoryNames.allSatisfy({ name in
               FileManager.default.fileExists(atPath: bundledData.appendingPathComponent(name).path)
           }),
           UT99RuntimeSupport.isReady(at: bundledData),
           Bundle.main.url(forResource: "default", withExtension: "metallib") != nil {
            return true
        }
        let root = dataSupportRoot()
        let manifestURL = UT99DataImportTransaction.installedManifestURL(at: root)
        guard let manifestData = try? Data(contentsOf: manifestURL),
              let object = try? JSONSerialization.jsonObject(with: manifestData),
              let dictionary = object as? [String: Any],
              let files = dictionary["files"] as? [[String: Any]],
              !files.isEmpty else {
            return false
        }
        let contentReady = UT99DataImportTransaction.contentDirectoryNames.allSatisfy { name in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(
                atPath: root.appendingPathComponent(name, isDirectory: true).path,
                isDirectory: &isDirectory
            ) && isDirectory.boolValue
        }
        let shader = root
            .appendingPathComponent(UT99RuntimeSupport.systemDirectoryName, isDirectory: true)
            .appendingPathComponent("default.metallib")
        return contentReady && UT99RuntimeSupport.isReady(at: root) &&
            FileManager.default.fileExists(atPath: shader.path)
    }

    private func reconcileGameDataState(reason: String) {
        guard hostState != .running, hostState != .startingEngine, hostState != .pausedBySystem,
              hostState != .crashed, hostState != .safeMode else {
            updateOnboardingPanel()
            return
        }
        transition(to: isGameDataReady() ? .ready : .needsData, reason: reason)
        updateOnboardingPanel()
    }

    private func updateOnboardingPanel() {
        guard let panel = onboardingPanel else { return }
        let landingState = hostState == .ready || hostState == .needsData
        panel.isHidden = !landingState
        if landingState {
            touchOverlay.isHidden = true
            gameSurfaceInputView.isUserInteractionEnabled = false
            view.bringSubviewToFront(panel)
            view.bringSubviewToFront(menuButton)
        }
        guard landingState else { return }

        if hostState == .ready {
            statusLabel.text = "Game data verified · offline and online play ready"
            onboardingTitleLabel?.text = "Ready for the Tournament"
            onboardingDetailLabel?.text = "Original v469e gameplay, offline bots, and community multiplayer are ready."
            onboardingPrimaryButton?.setTitle("PLAY OFFLINE", for: .normal)
            onboardingSecondaryButton?.setTitle("PLAY ONLINE", for: .normal)
            onboardingTertiaryButton?.setTitle("Verify or replace game data", for: .normal)
            onboardingPrimaryButton?.accessibilityHint = "Starts the original Unreal Tournament menu and offline game"
            onboardingSecondaryButton?.accessibilityHint = "Opens direct connect and the original community server browser"
        } else {
            statusLabel.text = "Game data required · download or import to continue"
            onboardingTitleLabel?.text = "Finish game setup"
            onboardingDetailLabel?.text = "UTP needs the original GOTY maps, music, sounds, and textures. Download the verified OldUnreal release or import files you already have."
            onboardingPrimaryButton?.setTitle("GET GAME DATA", for: .normal)
            onboardingSecondaryButton?.setTitle("IMPORT FILES", for: .normal)
            onboardingTertiaryButton?.setTitle("Why game data is separate", for: .normal)
            onboardingPrimaryButton?.accessibilityHint = "Explains the approved source and asks before downloading"
            onboardingSecondaryButton?.accessibilityHint = "Selects an existing Unreal Tournament folder or ZIP from Files"
        }
        NSLog("UT99 onboarding state=%@ landing=%@ hidden=%@ frame=%@ window=%@",
              hostState.rawValue,
              landingState ? "true" : "false",
              panel.isHidden ? "true" : "false",
              panel.frame.debugDescription,
              panel.window == nil ? "none" : "attached")
    }

    @objc private func onboardingPrimaryTapped() {
        if hostState == .ready {
            startEngine()
        } else {
            showAuthorizedGameDataOptions()
        }
    }

    @objc private func onboardingSecondaryTapped() {
        if hostState == .ready {
            showMultiplayerInfo()
        } else {
            importData()
        }
    }

    @objc private func onboardingTertiaryTapped() {
        if hostState == .ready {
            showDataInfo()
        } else {
            showAuthorizedGameDataOptions()
        }
    }

    private func showAuthorizedGameDataOptions() {
        guard hostState != .running && hostState != .startingEngine && hostState != .pausedBySystem else { return }
        let message = "OldUnreal's approved sources publish the original Unreal Tournament GOTY disc image and the matching v469e patch. The downloads total about 721 MiB and temporary setup may use about 2 GB. UTP verifies both exact SHA-256 hashes, installs only game data and platform-neutral runtime packages, rejects Windows executables and DLLs, and deletes both downloads after setup. The Epic Games Terms of Service apply."
        let alert = UIAlertController(title: "Get Game Data", message: message, preferredStyle: .actionSheet)
        alert.overrideUserInterfaceStyle = .dark
        alert.addAction(UIAlertAction(title: "Accept Terms & Download", style: .default) { [weak self] _ in
            self?.startAuthorizedGameDataDownload()
        })
        alert.addAction(UIAlertAction(title: "Read Epic Games Terms", style: .default) { [weak self] _ in
            self?.presentWebPage(UT99AuthorizedGameData.termsURL)
        })
        alert.addAction(UIAlertAction(title: "View OldUnreal Source", style: .default) { [weak self] _ in
            self?.presentWebPage(UT99AuthorizedGameData.sourcePageURL)
        })
        alert.addAction(UIAlertAction(title: "View v469e Patch", style: .default) { [weak self] _ in
            self?.presentWebPage(UT99AuthorizedGameData.patchPageURL)
        })
        alert.addAction(UIAlertAction(title: "Import Existing Files", style: .default) { [weak self] _ in
            self?.importData()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = onboardingPrimaryButton ?? menuButton
            popover.sourceRect = (onboardingPrimaryButton ?? menuButton).bounds
        }
        present(alert, animated: true)
    }

    private func presentWebPage(_ url: URL) {
        present(SFSafariViewController(url: url), animated: true)
    }

    private func startAuthorizedGameDataDownload() {
        guard activeImportCancellation == nil, gameDataDownload == nil else {
            statusLabel.text = "Game-data setup is already in progress"
            return
        }
        let workspace = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UT99AuthorizedData-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        } catch {
            statusLabel.text = "Cannot prepare download storage: \(error.localizedDescription)"
            return
        }

        let cancellation = UT99ImportCancellation()
        let download = UT99GameDataDownload(source: UT99AuthorizedGameData.gotyISO)
        activeImportCancellation = cancellation
        gameDataDownload = download
        gameDataAcquisitionWorkspace = workspace
        transition(to: .validatingData, reason: "authorized OldUnreal download accepted")
        presentImportProgress()
        importPhaseLabel?.text = "Downloading verified GOTY data…"
        importFileLabel?.text = "Connecting to \(download.currentSourceHost) · 620 MiB"
        importProgressView?.isHidden = false
        importProgressView?.progress = 0
        importSpinner?.stopAnimating()
        statusLabel.text = "Downloading game data from OldUnreal"

        gameDataDownloadProgressTimer?.invalidate()
        gameDataDownloadProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.refreshGameDataDownloadProgress()
        }
        download.start(destinationDirectory: workspace) { [weak self] result in
            DispatchQueue.main.async {
                self?.gameDataDownloadProgressTimer?.invalidate()
                self?.gameDataDownloadProgressTimer = nil
                self?.gameDataDownload = nil
                switch result {
                case let .success(imageURL):
                    self?.extractAuthorizedGameData(
                        imageURL,
                        workspace: workspace,
                        cancellation: cancellation
                    )
                case let .failure(error):
                    self?.finishDataImport(.failure(error), returnState: .needsData, cancellation: cancellation)
                }
            }
        }
    }

    private func refreshGameDataDownloadProgress() {
        guard let download = gameDataDownload else { return }
        let progress = download.progress
        let received = progress?.completedUnitCount ?? 0
        let total = progress?.totalUnitCount ?? download.expectedBytes
        let fraction = total > 0 ? Float(received) / Float(total) : 0
        importProgressView?.setProgress(max(0, min(1, fraction)), animated: true)
        importPhaseLabel?.text = "Downloading \(download.displayName) · \(Int(fraction * 100))%"
        importFileLabel?.text = "\(download.currentSourceHost) · \(received / 1_048_576) of \(download.expectedBytes / 1_048_576) MiB"
    }

    private func extractAuthorizedGameData(
        _ imageURL: URL,
        workspace: URL,
        cancellation: UT99ImportCancellation
    ) {
        importPhaseLabel?.text = "Verifying and extracting data…"
        importFileLabel?.text = "The signed source image matched its SHA-256"
        importProgressView?.progress = 0
        importQueue.async { [weak self] in
            guard let self else { return }
            let extracted = workspace.appendingPathComponent("Extracted", isDirectory: true)
            do {
                _ = try UT99ISO9660Extractor.extractDataDirectories(
                    from: imageURL,
                    to: extracted,
                    cancellationRequested: { cancellation.isCancelled },
                    progress: { update in
                        DispatchQueue.main.async { [weak self] in
                            self?.importPhaseLabel?.text = "Extracting \(update.completedFiles) of \(update.totalFiles)"
                            self?.importFileLabel?.text = update.currentFile
                            self?.importProgressView?.setProgress(update.fractionCompleted, animated: true)
                        }
                    }
                )
                try? FileManager.default.removeItem(at: imageURL)
                DispatchQueue.main.async { [weak self] in
                    self?.startAuthorizedRuntimePatchDownload(
                        extracted: extracted,
                        workspace: workspace,
                        cancellation: cancellation
                    )
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.finishDataImport(.failure(error), returnState: .needsData, cancellation: cancellation)
                }
            }
        }
    }

    private func startAuthorizedRuntimePatchDownload(
        extracted: URL,
        workspace: URL,
        cancellation: UT99ImportCancellation
    ) {
        guard activeImportCancellation === cancellation else { return }
        guard !cancellation.isCancelled else {
            finishDataImport(.failure(UT99ImportCancelled()), returnState: .needsData, cancellation: cancellation)
            return
        }
        let download = UT99GameDataDownload(source: UT99AuthorizedGameData.v469ePatch)
        gameDataDownload = download
        importPhaseLabel?.text = "Downloading matching v469e runtime…"
        importFileLabel?.text = "GitHub · \(download.expectedBytes / 1_048_576) MiB"
        importProgressView?.progress = 0
        statusLabel.text = "Downloading matching runtime from OldUnreal"
        gameDataDownloadProgressTimer?.invalidate()
        gameDataDownloadProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.refreshGameDataDownloadProgress()
        }
        download.start(destinationDirectory: workspace) { [weak self] result in
            DispatchQueue.main.async {
                self?.gameDataDownloadProgressTimer?.invalidate()
                self?.gameDataDownloadProgressTimer = nil
                self?.gameDataDownload = nil
                switch result {
                case let .success(archiveURL):
                    self?.installAuthorizedRuntimePatch(
                        archiveURL,
                        extracted: extracted,
                        cancellation: cancellation
                    )
                case let .failure(error):
                    self?.finishDataImport(.failure(error), returnState: .needsData, cancellation: cancellation)
                }
            }
        }
    }

    private func installAuthorizedRuntimePatch(
        _ archiveURL: URL,
        extracted: URL,
        cancellation: UT99ImportCancellation
    ) {
        importPhaseLabel?.text = "Verifying and applying v469e runtime…"
        importFileLabel?.text = "The official patch matched its SHA-256"
        importProgressView?.progress = 0
        importQueue.async { [weak self] in
            guard let self else { return }
            let result: Result<Int, Swift.Error>
            do {
                _ = try UT99ZipArchive.extractV469eRuntimePatch(
                    archiveURL,
                    to: extracted,
                    cancellationRequested: { cancellation.isCancelled },
                    progress: { file, completed, total in
                        DispatchQueue.main.async { [weak self] in
                            self?.importPhaseLabel?.text = "Applying runtime \(completed) of \(total)"
                            self?.importFileLabel?.text = file
                            let fraction = total > 0 ? Float(completed) / Float(total) : 0
                            self?.importProgressView?.setProgress(fraction, animated: true)
                        }
                    }
                )
                try? FileManager.default.removeItem(at: archiveURL)
                let imported = try UT99DataImporter.importFolder(
                    extracted,
                    to: self.dataSupportRoot(),
                    cancellation: cancellation
                ) { update in
                    DispatchQueue.main.async { [weak self] in self?.applyImportProgress(update) }
                }
                guard UT99RuntimeSupport.isReady(at: self.dataSupportRoot()) else {
                    throw UT99ZipArchive.Error.incompatibleRuntime
                }
                result = .success(imported)
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async { [weak self] in
                self?.finishDataImport(result, returnState: .needsData, cancellation: cancellation)
            }
        }
    }

    private func buildHostMenu() -> UIMenu {
        func action(
            _ title: String,
            symbol: String,
            attributes: UIMenuElement.Attributes = [],
            state: UIMenuElement.State = .off,
            handler: @escaping () -> Void
        ) -> UIAction {
            UIAction(
                title: title,
                image: UIImage(systemName: symbol),
                attributes: attributes,
                state: state
            ) { [weak self] _ in
                self?.releaseGameplayInputs()
                handler()
            }
        }

        let engineActive = hostState == .startingEngine || hostState == .running || hostState == .pausedBySystem
        let primaryAction: UIAction
        if engineActive {
            primaryAction = action("Resume Game", symbol: "play.fill") { }
        } else if isGameDataReady() {
            primaryAction = action("Play Offline", symbol: "play.fill") { [weak self] in
                self?.startEngine()
            }
        } else {
            primaryAction = action("Set Up Game Data", symbol: "arrow.down.circle") { [weak self] in
                self?.showAuthorizedGameDataOptions()
            }
        }
        let unrealMenu = action(
            "Unreal Tournament Menu",
            symbol: "pause.rectangle",
            attributes: engineActive ? [] : [.disabled]
        ) { [weak self] in
            self?.engineBridge.publishTouchAction(.pause, pressed: true)
            self?.engineBridge.publishTouchAction(.pause, pressed: false)
        }
        let touchInterface = action(
            originalMenuInputActive ? "Use Gameplay Touch Controls" : "Use Menu Touch Controls",
            symbol: originalMenuInputActive ? "gamecontroller.fill" : "cursorarrow.motionlines",
            attributes: engineActive ? [] : [.disabled]
        ) { [weak self] in
            self?.toggleTouchInterfaceMode()
        }

        let touchMenu = UIMenu(title: "Touch Controls", image: UIImage(systemName: "hand.draw"), children: [
            action(isTouchInputEnabled ? "Turn Touch Controls Off" : "Turn Touch Controls On",
                   symbol: isTouchInputEnabled ? "hand.raised.slash" : "hand.raised.fill") { [weak self] in
                self?.toggleTouchInputEnabled()
            },
            action("Touch Controls…", symbol: "slider.horizontal.3") { [weak self] in
                self?.showTouchSettings()
            },
            action("Arrange Controls…", symbol: "move.3d") { [weak self] in
                self?.editTouchLayout()
            },
            action("Test Layout", symbol: "hand.tap") { [weak self] in
                self?.testTouchLayout()
            },
            action("Visible Controls & Handedness…", symbol: "hand.raised") { [weak self] in
                self?.showTouchControlOptions()
            },
            action("Saved Layouts…", symbol: "square.and.arrow.down") { [weak self] in
                self?.showNamedTouchProfiles()
            },
            action("Reset Layout", symbol: "arrow.counterclockwise") { [weak self] in
                self?.resetTouchLayout()
            },
        ])

        let systemMenu = UIMenu(title: "Controls & Display", image: UIImage(systemName: "display"), children: [
            action("Aim, Controller & Pointer…", symbol: "scope") { [weak self] in
                self?.showControlsInfo()
            },
            action("Renderer & Frame Pacing…", symbol: "speedometer") { [weak self] in
                self?.showGraphicsInfo()
            },
            action("Audio…", symbol: "speaker.wave.2") { [weak self] in
                self?.showAudioInfo()
            },
        ])

        let dataMenu = UIMenu(title: "Game Data & Saves", image: UIImage(systemName: "externaldrive"), children: [
            action("Get Verified Game Data…", symbol: "arrow.down.circle") { [weak self] in
                self?.showAuthorizedGameDataOptions()
            },
            action("Import or Reimport Game Data…", symbol: "folder") { [weak self] in
                self?.importData()
            },
            action("Verify Installed Data", symbol: "checkmark.shield") { [weak self] in
                self?.showDataInfo()
            },
            action("Export Installed Manifest…", symbol: "square.and.arrow.up") { [weak self] in
                self?.exportInstalledManifest()
            },
        ])

        let diagnosticsMenu = UIMenu(title: "Diagnostics", image: UIImage(systemName: "stethoscope"), children: [
            action("Runtime Status", symbol: "waveform.path.ecg") { [weak self] in
                self?.probeEngine()
            },
            action("Copy Build & Runtime Info", symbol: "doc.on.doc") { [weak self] in
                self?.copyDiagnostics()
            },
            action("Export Logs…", symbol: "square.and.arrow.up") { [weak self] in
                self?.exportDiagnostics()
            },
            action("Prepare Safe Mode", symbol: "shield") { [weak self] in
                self?.enableSafeMode()
            },
        ])

        return UIMenu(title: "UTP", children: [
            primaryAction,
            unrealMenu,
            touchInterface,
            touchMenu,
            systemMenu,
            action("Multiplayer…", symbol: "network") { [weak self] in
                self?.showMultiplayerInfo()
            },
            dataMenu,
            diagnosticsMenu,
            action("About UTP", symbol: "info.circle") { [weak self] in
                self?.showAboutInfo()
            },
        ])
    }

    private func refreshHostMenu() {
        menuButton.menu = nil
        let engineActive = hostState == .startingEngine || hostState == .running || hostState == .pausedBySystem
        menuButton.accessibilityValue = engineActive ? "Game running" : nil
    }

    @objc private func toggleMenu() {
        if hostMenuPanel != nil {
            closeHostMenuPanel()
            return
        }
        NSLog("UT99 host panel open mainThread=%@", Thread.isMainThread ? "true" : "false")
        releaseGameplayInputs()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let panel = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.layer.cornerRadius = 18
        panel.layer.cornerCurve = .continuous
        panel.layer.borderWidth = 1
        panel.layer.borderColor = UIColor.white.withAlphaComponent(0.24).cgColor
        panel.clipsToBounds = true

        let title = UILabel()
        title.text = "UTP"
        title.textColor = .white
        title.font = .monospacedSystemFont(ofSize: 13, weight: .bold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = .white
        close.accessibilityLabel = "Close host menu"
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addAction(UIAction { [weak self] _ in self?.closeHostMenuPanel() }, for: .touchUpInside)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        if let supportExportNotice {
            stack.addArrangedSubview(hostPanelMessage(supportExportNotice))
            self.supportExportNotice = nil
        }

        let engineActive = hostState == .startingEngine || hostState == .running || hostState == .pausedBySystem
        if engineActive {
            stack.addArrangedSubview(hostPanelButton(
                originalMenuInputActive ? "USE GAMEPLAY CONTROLS" : "USE MENU CONTROLS",
                symbol: originalMenuInputActive ? "gamecontroller.fill" : "cursorarrow.motionlines"
            ) { [weak self] in
                self?.toggleTouchInterfaceMode()
            })
            stack.addArrangedSubview(hostPanelButton("ESCAPE / UT MENU", symbol: "escape") { [weak self] in
                self?.engineBridge.publishTouchAction(.pause, pressed: true)
                self?.engineBridge.publishTouchAction(.pause, pressed: false)
            })
            if originalMenuInputActive {
                let keyboardIsOpen = menuKeyboardPanel != nil
                stack.addArrangedSubview(hostPanelButton(
                    keyboardIsOpen ? "CLOSE KEYBOARD" : "OPEN KEYBOARD",
                    symbol: "keyboard"
                ) { [weak self] in
                    self?.toggleMenuTextKeyboard()
                })
            }
        } else if hostState == .crashed && isGameDataReady() {
            stack.addArrangedSubview(hostPanelButton("TRY NORMAL START", symbol: "play.fill") { [weak self] in
                self?.closeHostMenuPanel()
                _ = self?.launchEngine()
            })
            stack.addArrangedSubview(hostPanelButton("START IN SAFE MODE", symbol: "shield.fill") { [weak self] in
                self?.closeHostMenuPanel()
                _ = self?.launchEngine(safeMode: true)
            })
        } else if isGameDataReady() {
            stack.addArrangedSubview(hostPanelButton("PLAY OFFLINE", symbol: "play.fill") { [weak self] in
                self?.closeHostMenuPanel()
                self?.startEngine()
            })
        }
        stack.addArrangedSubview(hostPanelButton(
            isTouchInputEnabled ? "TURN TOUCH CONTROLS OFF" : "TURN TOUCH CONTROLS ON",
            symbol: isTouchInputEnabled ? "hand.raised.slash" : "hand.raised.fill"
        ) { [weak self] in
            self?.toggleTouchInputEnabled()
        })
        stack.addArrangedSubview(hostPanelButton("ARRANGE CONTROLS", symbol: "move.3d") { [weak self] in
            self?.editTouchLayout()
        })
        stack.addArrangedSubview(hostPanelButton("CONTROLS & DISPLAY", symbol: "display") { [weak self] in
            self?.showControlsInfo()
        })
        stack.addArrangedSubview(hostPanelButton("MULTIPLAYER", symbol: "network") { [weak self] in
            self?.showMultiplayerInfo()
        })
        stack.addArrangedSubview(hostPanelButton("EXPORT LOGS", symbol: "square.and.arrow.up") { [weak self] in
            self?.exportDiagnostics()
        })
        stack.addArrangedSubview(hostPanelButton("REPORT A PROBLEM", symbol: "exclamationmark.bubble") { [weak self] in
            self?.reportAProblem()
        })

        panel.contentView.addSubview(title)
        panel.contentView.addSubview(close)
        panel.contentView.addSubview(stack)
        view.addSubview(panel)
        let panelWidth = min(CGFloat(330), max(CGFloat(260), view.bounds.width - 32))
        NSLayoutConstraint.activate([
            panel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            panel.topAnchor.constraint(equalTo: menuButton.bottomAnchor, constant: 8),
            panel.widthAnchor.constraint(equalToConstant: panelWidth),
            title.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 16),
            title.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 14),
            close.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -10),
            close.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 38),
            close.heightAnchor.constraint(equalToConstant: 38),
            stack.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -12),
        ])
        hostMenuPanel = panel
        menuButton.accessibilityValue = "Open"
        view.bringSubviewToFront(panel)
        view.bringSubviewToFront(menuButton)
    }

    private func showMenuTextKeyboard() {
        closeHostMenuPanel()
        guard menuKeyboardPanel == nil else { return }
        let compact = menuKeyboardCompactOverride ?? (traitCollection.userInterfaceIdiom == .phone)
        let keyFontSize: CGFloat = compact ? 12 : 15
        menuKeyboardShifted = true
        menuKeyboardLetterButtons.removeAll()

        let panel = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        panel.layer.cornerRadius = 18
        panel.layer.masksToBounds = true
        panel.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = compact ? "UT TEXT INPUT" : "TYPE INTO THE SELECTED UT FIELD"
        title.textColor = UIColor.white.withAlphaComponent(0.78)
        title.font = .monospacedSystemFont(ofSize: compact ? 10 : 12, weight: .semibold)
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.75

        let size = menuKeyboardKey(compact ? "LARGE" : "SMALL", fontSize: keyFontSize) { [weak self] in
            self?.toggleMenuKeyboardSize()
        }
        let close = menuKeyboardKey("CLOSE", fontSize: keyFontSize) { [weak self] in
            self?.closeMenuTextKeyboard()
        }
        let header = UIStackView(arrangedSubviews: [title, size, close])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = compact ? 6 : 12

        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = compact ? 3 : 7
        for characters in ["1234567890", "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"] {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = compact ? 3 : 6
            for character in characters {
                let raw = String(character)
                let button = menuKeyboardKey(raw, fontSize: keyFontSize) { [weak self] in
                    guard let self else { return }
                    let text = self.menuKeyboardShifted ? raw.uppercased() : raw.lowercased()
                    _ = self.engineBridge.publishMenuCharacter(text)
                    if self.menuKeyboardShifted && raw.rangeOfCharacter(from: .letters) != nil {
                        self.menuKeyboardShifted = false
                        self.updateMenuKeyboardLetterCase()
                    }
                }
                if raw.rangeOfCharacter(from: .letters) != nil {
                    button.accessibilityIdentifier = raw.lowercased()
                    menuKeyboardLetterButtons.append(button)
                }
                row.addArrangedSubview(button)
            }
            row.heightAnchor.constraint(equalToConstant: compact ? 31 : 42).isActive = true
            rows.addArrangedSubview(row)
        }

        let shift = menuKeyboardKey("SHIFT", fontSize: keyFontSize) { [weak self] in
            guard let self else { return }
            self.menuKeyboardShifted.toggle()
            self.updateMenuKeyboardLetterCase()
        }
        let space = menuKeyboardKey("SPACE", fontSize: keyFontSize) { [weak self] in
            _ = self?.engineBridge.publishMenuCharacter(" ")
        }
        let backspace = menuKeyboardKey("DELETE", fontSize: keyFontSize) { [weak self] in
            self?.engineBridge.publishMenuBackspace()
        }
        let done = menuKeyboardKey("DONE", fontSize: keyFontSize) { [weak self] in
            self?.engineBridge.publishMenuReturn()
            self?.closeMenuTextKeyboard()
        }
        let actions = UIStackView(arrangedSubviews: [shift, space, backspace, done])
        actions.axis = .horizontal
        actions.distribution = .fillEqually
        actions.spacing = compact ? 3 : 7
        actions.heightAnchor.constraint(equalToConstant: compact ? 36 : 46).isActive = true

        let stack = UIStackView(arrangedSubviews: [header, rows, actions])
        stack.axis = .vertical
        stack.spacing = compact ? 6 : 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView.addSubview(stack)
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: compact ? 8 : 18),
            panel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: compact ? -8 : -18),
            panel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: compact ? -8 : -18),
            stack.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: compact ? 8 : 14),
            stack.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: compact ? -8 : -14),
            stack.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: compact ? 8 : 12),
            stack.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: compact ? -8 : -14),
        ])
        menuKeyboardPanel = panel
        updateMenuKeyboardLetterCase()
        view.bringSubviewToFront(panel)
        view.bringSubviewToFront(menuButton)
        NSLog("UT99 touch text keyboard presented mode=host-panel compact=%@",
              compact ? "true" : "false")
    }

    private func menuKeyboardKey(
        _ title: String,
        fontSize: CGFloat = 15,
        handler: @escaping () -> Void
    ) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = UIColor(white: 0.18, alpha: 0.94)
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .medium
        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .systemFont(ofSize: fontSize, weight: .semibold)
        button.addAction(UIAction { _ in handler() }, for: .touchUpInside)
        return button
    }

    private func updateMenuKeyboardLetterCase() {
        for button in menuKeyboardLetterButtons {
            guard let raw = button.accessibilityIdentifier else { continue }
            var configuration = button.configuration
            configuration?.title = menuKeyboardShifted ? raw.uppercased() : raw.lowercased()
            button.configuration = configuration
        }
    }

    private func closeMenuTextKeyboard() {
        menuKeyboardPanel?.removeFromSuperview()
        menuKeyboardPanel = nil
        menuKeyboardLetterButtons.removeAll()
        menuKeyboardShifted = false
        claimKeyboardResponder(reason: "host-keyboard-dismissed")
        NSLog("UT99 touch text keyboard dismissed mode=host-panel")
    }

    private func toggleMenuTextKeyboard() {
        closeHostMenuPanel()
        if menuKeyboardPanel == nil {
            showMenuTextKeyboard()
        } else {
            closeMenuTextKeyboard()
        }
    }

    private func toggleMenuKeyboardSize() {
        let compact = menuKeyboardCompactOverride ?? (traitCollection.userInterfaceIdiom == .phone)
        menuKeyboardCompactOverride = !compact
        menuKeyboardPanel?.removeFromSuperview()
        menuKeyboardPanel = nil
        showMenuTextKeyboard()
    }

    private func hostPanelButton(
        _ title: String,
        symbol: String,
        handler: @escaping () -> Void
    ) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 10
        configuration.baseBackgroundColor = UIColor(white: 0.18, alpha: 0.92)
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .medium
        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            NSLog("UT99 host panel action title=%@", title)
            self?.closeHostMenuPanel()
            // The original engine pumps UIKit events from its legacy main loop,
            // but that loop does not drain blocks queued with main.async. Run
            // the selected action inline after removing the source panel so a
            // visible tap always reaches its real handler.
            handler()
        })
        button.contentHorizontalAlignment = .leading
        button.heightAnchor.constraint(equalToConstant: 46).isActive = true
        return button
    }

    private func hostPanelMessage(_ message: String) -> UILabel {
        let label = UILabel()
        label.text = message
        label.textColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 1)
        label.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        label.numberOfLines = 0
        label.textAlignment = .left
        label.accessibilityLabel = message
        return label
    }

    private func closeHostMenuPanel() {
        hostMenuPanel?.removeFromSuperview()
        hostMenuPanel = nil
        menuButton.accessibilityValue = nil
    }

    @objc private func showControlsInfo() {
        showTouchSettings()
    }

    // The old action sheet remains only as implementation history. The live
    // route uses the bounded, scrollable panel on every device size.
    private func showLegacyControlsInfo() {
        let alert = UIAlertController(title: "Controls", message: controlsSummary(), preferredStyle: .actionSheet)
        let invert = UserDefaults.standard.bool(forKey: "ut99.input.invertLookY")
        let invertTitle = "Invert vertical look: " + (invert ? "On" : "Off")
        alert.addAction(UIAlertAction(title: invertTitle, style: .default) { [weak self] _ in
            UserDefaults.standard.set(!invert, forKey: "ut99.input.invertLookY")
            self?.showControlsInfo()
        })
        let sensitivity = max(0.25, min(3.0, UserDefaults.standard.double(forKey: "ut99.input.lookSensitivity")))
        for value in [0.75, 1.0, 1.5, 2.0] {
            let marker = abs(value - sensitivity) < 0.01 ? " ✓" : ""
            let sensitivityTitle = "Look sensitivity: " + String(format: "%.2gx", value) + marker
            alert.addAction(UIAlertAction(title: sensitivityTitle, style: .default) { [weak self] _ in
                UserDefaults.standard.set(value, forKey: "ut99.input.lookSensitivity")
                self?.showControlsInfo()
            })
        }
        let currentConfiguration = UT99TouchConfiguration.load()
        for value in [0.0, 0.45, 0.8, 1.2] {
            let marker = abs(value - currentConfiguration.lookAcceleration) < 0.01 ? " ✓" : ""
            alert.addAction(UIAlertAction(title: "Look acceleration: \(String(format: "%.2g", value))\(marker)", style: .default) { [weak self] _ in
                var configuration = self?.touchOverlay.touchConfiguration ?? .standard
                configuration.lookAcceleration = value
                self?.touchOverlay.setTouchConfiguration(configuration)
                self?.showControlsInfo()
            })
        }
        for value in [0.0, 0.0025, 0.006, 0.012] {
            let marker = abs(value - currentConfiguration.lookDeadZone) < 0.0001 ? " ✓" : ""
            let points = Int((value * 10000).rounded())
            alert.addAction(UIAlertAction(title: "Look dead zone: \(points)\(marker)", style: .default) { [weak self] _ in
                var configuration = self?.touchOverlay.touchConfiguration ?? .standard
                configuration.lookDeadZone = value
                self?.touchOverlay.setTouchConfiguration(configuration)
                self?.showControlsInfo()
            })
        }
        for value in [0.09, 0.16, 0.22, 0.28] {
            let marker = abs(value - currentConfiguration.movementDeadZone) < 0.001 ? " ✓" : ""
            alert.addAction(UIAlertAction(title: "Move dead zone: \(Int(value * 100))%\(marker)", style: .default) { [weak self] _ in
                var configuration = self?.touchOverlay.touchConfiguration ?? .standard
                configuration.movementDeadZone = value
                self?.touchOverlay.setTouchConfiguration(configuration)
                self?.showControlsInfo()
            })
        }
        let autoHideTitle = "Hide touch for controller: " + (currentConfiguration.autoHideForController ? "On" : "Off")
        alert.addAction(UIAlertAction(title: autoHideTitle, style: .default) { [weak self] _ in
            var configuration = self?.touchOverlay.touchConfiguration ?? .standard
            configuration.autoHideForController.toggle()
            self?.touchOverlay.setTouchConfiguration(configuration)
            self?.updateTouchVisibility()
            self?.showControlsInfo()
        })
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        presentActionSheet(alert)
    }

    @objc private func showGraphicsInfo() {
        let enabled = UserDefaults.standard.bool(forKey: "ut99.graphics.safeTextures")
        let verticalSync = UserDefaults.standard.bool(forKey: "ut99.graphics.vsync")
        let metrics = engineBridge.rendererMetrics()
        let measured: String
        if metrics.hasPresentedFrames {
            measured = String(
                format: "Produced frames: %.1f FPS average · %.1f FPS 1%% low\nFrame time: %.2f ms · %llu frames\nDrawable: %llux%llu",
                metrics.averageFPS, metrics.onePercentLowFPS,
                metrics.averageFrameTimeMS, metrics.frameCount,
                metrics.drawableWidth, metrics.drawableHeight
            )
        } else {
            measured = "Produced-frame metrics begin after FruCoRe presents its first drawable."
        }
        let alert = UIAlertController(
            title: "Graphics",
            message: "FruCoRe/Metal uses the native full-bleed landscape drawable. Compatibility and presentation-sync changes apply at the next engine start.\n\n\(measured)",
            preferredStyle: .actionSheet
        )
        let textureTitle = "Safe texture compatibility: " + (enabled ? "On" : "Off")
        alert.addAction(UIAlertAction(title: textureTitle, style: .default) { [weak self] _ in
            UserDefaults.standard.set(!enabled, forKey: "ut99.graphics.safeTextures")
            self?.showGraphicsInfo()
        })
        let syncTitle = "FruCoRe vertical sync: " + (verticalSync ? "On" : "Off")
        alert.addAction(UIAlertAction(title: syncTitle, style: .default) { [weak self] _ in
            UserDefaults.standard.set(!verticalSync, forKey: "ut99.graphics.vsync")
            self?.showGraphicsInfo()
        })
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        presentActionSheet(alert)
    }

    @objc private func showTouchSettings() {
        NSLog("UT99 touch settings opened")
        closeTouchSettingsPanel()
        releaseGameplayInputs()

        let panel = UIView()
        panel.backgroundColor = UIColor(white: 0.035, alpha: 0.94)
        panel.layer.cornerRadius = 16
        panel.layer.cornerCurve = .continuous
        panel.layer.borderWidth = 1
        panel.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.accessibilityViewIsModal = true
        view.addSubview(panel)

        let title = UILabel()
        title.text = "Controls & Display"
        title.textColor = .white
        title.font = .systemFont(ofSize: 18, weight: .bold)

        let close = UIButton(type: .custom)
        close.setImage(
            UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)),
            for: .normal
        )
        close.tintColor = .white
        close.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        close.layer.cornerRadius = 16
        close.accessibilityLabel = "Close touch control settings"
        close.addTarget(self, action: #selector(closeTouchSettingsPanel), for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [title, close])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 12
        header.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(header)

        let opacity = UISlider()
        opacity.minimumValue = 0.25
        opacity.maximumValue = 1
        opacity.value = Float(touchOverlay.touchOpacity)
        opacity.minimumTrackTintColor = UIColor(red: 0.10, green: 0.67, blue: 0.92, alpha: 1)
        opacity.accessibilityLabel = "Control opacity"
        opacity.addTarget(self, action: #selector(touchOpacityChanged(_:)), for: .valueChanged)
        touchOpacitySlider = opacity

        let size = UISlider()
        size.minimumValue = 0.75
        size.maximumValue = 1.35
        size.value = Float(touchOverlay.globalScale)
        size.minimumTrackTintColor = UIColor(red: 0.10, green: 0.67, blue: 0.92, alpha: 1)
        size.accessibilityLabel = "Control size"
        size.addTarget(self, action: #selector(touchScaleChanged(_:)), for: .valueChanged)
        touchScaleSlider = size

        let lookSensitivity = UISlider()
        lookSensitivity.minimumValue = 0.5
        lookSensitivity.maximumValue = 3.0
        lookSensitivity.value = Float(max(0.5, min(3.0, UserDefaults.standard.double(forKey: "ut99.input.lookSensitivity"))))
        lookSensitivity.minimumTrackTintColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 1)
        lookSensitivity.accessibilityLabel = "Look sensitivity"
        lookSensitivity.addTarget(self, action: #selector(touchLookSensitivityChanged(_:)), for: .valueChanged)

        let lookAcceleration = UISlider()
        lookAcceleration.minimumValue = 0
        lookAcceleration.maximumValue = 1.5
        lookAcceleration.value = Float(touchOverlay.touchConfiguration.lookAcceleration)
        lookAcceleration.minimumTrackTintColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 1)
        lookAcceleration.accessibilityLabel = "Look acceleration"
        lookAcceleration.addTarget(self, action: #selector(touchLookAccelerationChanged(_:)), for: .valueChanged)

        let moveSensitivity = UISlider()
        moveSensitivity.minimumValue = 1
        moveSensitivity.maximumValue = 10
        moveSensitivity.value = Float(min(10, max(1, 12 - touchOverlay.touchConfiguration.movementDeadZone * 100)))
        moveSensitivity.minimumTrackTintColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 1)
        moveSensitivity.accessibilityLabel = "Movement sensitivity"
        moveSensitivity.addTarget(self, action: #selector(touchMoveSensitivityChanged(_:)), for: .valueChanged)

        let invertLook = UISwitch()
        invertLook.isOn = UserDefaults.standard.bool(forKey: "ut99.input.invertLookY")
        invertLook.accessibilityLabel = "Invert vertical look"
        invertLook.addTarget(self, action: #selector(touchInvertLookChanged(_:)), for: .valueChanged)

        let leftHanded = UISwitch()
        leftHanded.isOn = touchOverlay.touchConfiguration.leftHanded
        leftHanded.accessibilityLabel = "Left-handed layout"
        leftHanded.addTarget(self, action: #selector(touchHandednessChanged(_:)), for: .valueChanged)

        let hideForController = UISwitch()
        hideForController.isOn = touchOverlay.touchConfiguration.autoHideForController
        hideForController.accessibilityLabel = "Hide touch controls when controller connected"
        hideForController.addTarget(self, action: #selector(touchAutoHideChanged(_:)), for: .valueChanged)

        let touchEnabled = UISwitch()
        touchEnabled.isOn = isTouchInputEnabled
        touchEnabled.accessibilityLabel = "Touch controls enabled"
        touchEnabled.addTarget(self, action: #selector(touchEnabledChanged(_:)), for: .valueChanged)

        let edit = touchSettingsButton("Arrange Controls", symbol: "move.3d", selector: #selector(editTouchLayoutFromSettings))
        let saved = touchSettingsButton("Saved Layouts", symbol: "square.and.arrow.down", selector: #selector(showNamedTouchProfilesFromSettings))
        let reset = touchSettingsButton("Restore Default Layout", symbol: "arrow.counterclockwise", selector: #selector(resetTouchLayoutFromSettings))
        reset.backgroundColor = UIColor(white: 0.18, alpha: 0.88)

        let stack = UIStackView(arrangedSubviews: [
            touchSettingsSection("AIM & MOVEMENT"),
            touchSettingsRow(title: "Look sensitivity", control: lookSensitivity),
            touchSettingsRow(title: "Look acceleration", control: lookAcceleration),
            touchSettingsRow(title: "Move sensitivity", control: moveSensitivity),
            touchSettingsRow(title: "Invert vertical look", control: invertLook),
            touchSettingsSection("TOUCH LAYOUT"),
            touchSettingsRow(title: "Touch controls", control: touchEnabled),
            touchSettingsRow(title: "Opacity", control: opacity),
            touchSettingsRow(title: "Size", control: size),
            touchSettingsRow(title: "Left-handed", control: leftHanded),
            touchSettingsRow(title: "Hide with controller", control: hideForController),
            edit,
            saved,
            reset,
        ])
        stack.axis = .vertical
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = false
        scroll.showsVerticalScrollIndicator = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(scroll)
        scroll.addSubview(stack)

        let safe = view.safeAreaLayoutGuide
        let width = min(360, max(300, view.bounds.width - 32))
        let isPhoneLandscape = traitCollection.userInterfaceIdiom == .phone
        let panelTop: CGFloat = isPhoneLandscape ? 8 : 60
        let panelTrailing: CGFloat = isPhoneLandscape ? -64 : -12
        let height = isPhoneLandscape
            ? min(350, max(300, view.bounds.height - 32))
            : min(620, max(420, view.bounds.height * 0.76))
        NSLayoutConstraint.activate([
            panel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: panelTrailing),
            panel.topAnchor.constraint(equalTo: safe.topAnchor, constant: panelTop),
            panel.widthAnchor.constraint(equalToConstant: width),
            panel.heightAnchor.constraint(equalToConstant: height),
            header.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            header.topAnchor.constraint(equalTo: panel.topAnchor, constant: 8),
            header.heightAnchor.constraint(equalToConstant: 40),
            close.widthAnchor.constraint(equalToConstant: 32),
            close.heightAnchor.constraint(equalToConstant: 32),
            scroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 2),
            scroll.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -8),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
            edit.heightAnchor.constraint(equalToConstant: 40),
            saved.heightAnchor.constraint(equalToConstant: 40),
            reset.heightAnchor.constraint(equalToConstant: 40),
        ])
        touchSettingsPanel = panel
        // Keep the configuration surface visually separate from active game
        // controls. Settings continue to persist while the overlay is hidden.
        touchOverlay.isHidden = true
        gameSurfaceInputView.isUserInteractionEnabled = false
        view.bringSubviewToFront(panel)
        view.bringSubviewToFront(menuButton)
    }

    private func touchSettingsRow(title: String, control: UIView) -> UIView {
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [label, control])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        return row
    }

    private func touchSettingsSection(_ title: String) -> UIView {
        let label = UILabel()
        label.text = title
        label.textColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 1)
        label.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        label.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return label
    }

    private func touchSettingsButton(_ title: String, symbol: String, selector: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = .white
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.backgroundColor = UIColor(white: 0.13, alpha: 0.76)
        button.layer.cornerRadius = 10
        button.contentHorizontalAlignment = .leading
        button.configuration = {
            var configuration = UIButton.Configuration.plain()
            configuration.imagePadding = 10
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
            configuration.baseForegroundColor = .white
            return configuration
        }()
        button.addTarget(self, action: selector, for: .touchUpInside)
        return button
    }

    @objc private func closeTouchSettingsPanel() {
        touchSettingsPanel?.removeFromSuperview()
        touchSettingsPanel = nil
        touchOpacitySlider = nil
        touchScaleSlider = nil
        gameSurfaceInputView.isUserInteractionEnabled = hostState == .startingEngine || hostState == .running || hostState == .pausedBySystem
        updateTouchVisibility()
        refreshHostMenu()
    }

    @objc private func touchOpacityChanged(_ sender: UISlider) {
        touchOverlay.setTouchOpacity(CGFloat(sender.value))
    }

    @objc private func touchScaleChanged(_ sender: UISlider) {
        touchOverlay.setGlobalScale(CGFloat(sender.value))
    }

    @objc private func touchLookSensitivityChanged(_ sender: UISlider) {
        UserDefaults.standard.set(Double(sender.value), forKey: "ut99.input.lookSensitivity")
        sender.accessibilityValue = String(format: "%.1f times", sender.value)
    }

    @objc private func touchLookAccelerationChanged(_ sender: UISlider) {
        var configuration = touchOverlay.touchConfiguration
        configuration.lookAcceleration = Double(sender.value)
        touchOverlay.setTouchConfiguration(configuration)
    }

    @objc private func touchMoveSensitivityChanged(_ sender: UISlider) {
        var configuration = touchOverlay.touchConfiguration
        configuration.movementDeadZone = Double(max(0.02, 0.12 - sender.value / 100))
        touchOverlay.setTouchConfiguration(configuration)
    }

    @objc private func touchInvertLookChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "ut99.input.invertLookY")
    }

    @objc private func touchHandednessChanged(_ sender: UISwitch) {
        touchOverlay.setLeftHanded(sender.isOn)
    }

    @objc private func touchAutoHideChanged(_ sender: UISwitch) {
        var configuration = touchOverlay.touchConfiguration
        configuration.autoHideForController = sender.isOn
        touchOverlay.setTouchConfiguration(configuration)
        updateTouchVisibility()
    }

    @objc private func touchEnabledChanged(_ sender: UISwitch) {
        setTouchInputEnabled(sender.isOn)
    }

    @objc private func editTouchLayoutFromSettings() {
        closeTouchSettingsPanel()
        editTouchLayout()
    }

    @objc private func showNamedTouchProfilesFromSettings() {
        closeTouchSettingsPanel()
        showNamedTouchProfiles()
    }

    @objc private func resetTouchLayoutFromSettings() {
        touchOverlay.resetTouchLayout()
        statusLabel.text = "Touch layout restored"
        touchOpacitySlider?.value = Float(touchOverlay.touchOpacity)
        touchScaleSlider?.value = Float(touchOverlay.globalScale)
        refreshHostMenu()
    }

    @objc private func showAudioInfo() {
        let route = AVAudioSession.sharedInstance().currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ", ")
        let routeDescription = route.isEmpty ? "not reported" : route
        let enabled = UserDefaults.standard.bool(forKey: "ut99.audio.enabled")
        let alert = UIAlertController(title: "Audio", message: "Route: \(routeDescription). Engine audio preference applies at the next engine start.", preferredStyle: .actionSheet)
        let audioTitle = "Engine audio on next start: " + (enabled ? "On" : "Off")
        alert.addAction(UIAlertAction(title: audioTitle, style: .default) { [weak self] _ in
            UserDefaults.standard.set(!enabled, forKey: "ut99.audio.enabled")
            self?.showAudioInfo()
        })
        alert.addAction(UIAlertAction(title: "Reactivate output route", style: .default) { _ in
            try? AVAudioSession.sharedInstance().setActive(true)
        })
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        presentActionSheet(alert)
    }

    private func controlsSummary() -> String {
        let sensitivity = max(0.25, min(3.0, UserDefaults.standard.double(forKey: "ut99.input.lookSensitivity")))
        let invert = UserDefaults.standard.bool(forKey: "ut99.input.invertLookY")
        let sensitivityText = String(format: "%.2gx", sensitivity)
        let configuration = UT99TouchConfiguration.load()
        return "Touch controls, Apple controllers, iPad keyboard, and pointer-look use the UT99 input bridge.\n\nSensitivity: " + sensitivityText +
            "\nAcceleration: " + String(format: "%.2g", configuration.lookAcceleration) +
            "\nLook dead zone: " + String(format: "%.4f", configuration.lookDeadZone) +
            "\nMove dead zone: " + String(format: "%.0f%%", configuration.movementDeadZone * 100) +
            "\nInvert Y: " + (invert ? "On" : "Off") +
            "\nController auto-hide: " + (configuration.autoHideForController ? "On" : "Off")
    }

    private func presentActionSheet(_ alert: UIAlertController) {
        if let popover = alert.popoverPresentationController {
            popover.sourceView = menuButton
            popover.sourceRect = menuButton.bounds
        }
        present(alert, animated: true)
    }

    @objc private func showMultiplayerInfo() {
        NSLog("UT99 multiplayer action requested menuAlreadyOpen=%@", originalMenuInputActive ? "true" : "false")
        guard isGameDataReady() else {
            transition(to: .needsData, reason: "multiplayer requested before game-data setup")
            statusLabel.text = "Set up game data before playing online"
            showAuthorizedGameDataOptions()
            return
        }
        let engineActive = hostState == .startingEngine || hostState == .running || hostState == .pausedBySystem
        if engineActive {
            releaseGameplayInputs()
            setOriginalMenuInputActive(true)
            // Input mode does not prove that Unreal's top menu is visibly
            // open. Always send Escape first, then take the tested stock
            // Multiplayer -> Find Internet Games keyboard route.
            engineBridge.openStockServerBrowser(originalMenuAlreadyOpen: false)
            statusLabel.text = "Opening Unreal Tournament server browser"
        } else {
            guard launchEngine() != nil else { return }
            // The original engine needs its first viewport before UBrowser can
            // construct. Input is scheduled off-main because the legacy loop
            // owns the main thread after launch.
            setOriginalMenuInputActive(true)
            engineBridge.openStockServerBrowser(initialDelayMilliseconds: 1_800)
            statusLabel.text = "Starting Unreal Tournament server browser"
        }
    }

    @objc private func showDataInfo() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Unreal Tournament", isDirectory: true)
        let priorState = hostState
        transition(to: .validatingData, reason: "user requested installed-data verification")
        do {
            let inspection = try UT99DataImportTransaction.inspectInstalledManifest(at: root)
            let sizeMiB = Double(inspection.totalBytes) / 1_048_576.0
            let result = inspection.isValid ? "Valid" : "Needs repair"
            presentMenuInfo(
                title: "Game Data — \(result)",
                message: "Source: \(inspection.sourceName)\nVerified: \(inspection.validFiles)/\(inspection.expectedFiles)\nMissing: \(inspection.missingFiles) · Mismatched: \(inspection.mismatchedFiles)\nStorage verified: \(String(format: "%.1f", sizeMiB)) MiB\n\nThe generated engine System tree is kept separate from imported content."
            )
            transition(to: priorState, reason: "installed-data verification completed")
        } catch {
            presentMenuInfo(title: "Game Data", message: "No verifiable imported manifest is installed. Use Import or Repair/Reimport.\n\n\(error.localizedDescription)")
            transition(to: .needsData, reason: "installed manifest unavailable")
        }
    }

    @objc private func exportInstalledManifest() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Unreal Tournament", isDirectory: true)
        let manifest = UT99DataImportTransaction.installedManifestURL(at: root)
        guard FileManager.default.fileExists(atPath: manifest.path) else {
            presentMenuInfo(title: "Game Data", message: "No imported manifest is available to export.")
            return
        }
        let share = UIActivityViewController(activityItems: [manifest], applicationActivities: nil)
        if let popover = share.popoverPresentationController {
            popover.sourceView = menuButton
            popover.sourceRect = menuButton.bounds
        }
        present(share, animated: true)
    }

    @objc private func showAboutInfo() {
        presentMenuInfo(
            title: "UTP",
            message: "Native Apple host for the official OldUnreal v469e runtime. Requires user-owned game data. Unreal Tournament and OldUnreal trademarks and licenses remain with their respective owners."
        )
    }

    private func presentMenuInfo(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Done", style: .default))
        present(alert, animated: true)
    }

    @objc private func showNamedTouchProfiles() {
        let profiles = UT99TouchProfileStore.profiles()
        let noun = profiles.count == 1 ? "layout" : "layouts"
        let alert = UIAlertController(
            title: "Saved touch layouts",
            message: String(profiles.count) + " " + noun + ". A saved layout includes placement, size, visibility, handedness, and aim tuning.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Save current layout…", style: .default) { [weak self] _ in
            self?.promptToSaveTouchProfile()
        })
        alert.addAction(UIAlertAction(title: "Import from Files…", style: .default) { [weak self] _ in
            self?.importTouchProfile()
        })
        alert.addAction(UIAlertAction(title: "Export current layout…", style: .default) { [weak self] _ in
            self?.promptToExportTouchProfile()
        })
        if !profiles.isEmpty {
            for profile in profiles {
                alert.addAction(UIAlertAction(title: "Apply · " + profile.name, style: .default) { [weak self] _ in
                    do {
                        try self?.touchOverlay.applyTouchProfileDocument(profile)
                        self?.statusLabel.text = "Touch layout applied: \(profile.name)"
                    } catch {
                        self?.presentMenuInfo(title: "Touch layout", message: error.localizedDescription)
                    }
                })
            }
            alert.addAction(UIAlertAction(title: "Delete a saved layout…", style: .destructive) { [weak self] _ in
                self?.showDeleteTouchProfileMenu()
            })
        }
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        presentActionSheet(alert)
    }

    private func promptToSaveTouchProfile() {
        let alert = UIAlertController(title: "Save touch layout", message: "Use a short name you will recognize.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Layout name"
            field.text = "My Touch Layout"
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            do {
                let profile = try touchOverlay.makeTouchProfile(named: alert?.textFields?.first?.text ?? "")
                let replaced = try UT99TouchProfileStore.upsert(profile)
                statusLabel.text = replaced ? "Touch layout updated: \(profile.name)" : "Touch layout saved: \(profile.name)"
                NSLog("UT99 touch named profile saved name=%@ replaced=%@", profile.name, replaced ? "true" : "false")
            } catch {
                presentMenuInfo(title: "Touch layout", message: error.localizedDescription)
            }
        })
        present(alert, animated: true)
    }

    private func showDeleteTouchProfileMenu() {
        let alert = UIAlertController(title: "Delete saved layout", message: "This does not change the layout currently on screen.", preferredStyle: .actionSheet)
        for profile in UT99TouchProfileStore.profiles() {
            alert.addAction(UIAlertAction(title: profile.name, style: .destructive) { [weak self] _ in
                if UT99TouchProfileStore.delete(named: profile.name) {
                    self?.statusLabel.text = "Touch layout deleted: \(profile.name)"
                }
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentActionSheet(alert)
    }

    private func promptToExportTouchProfile() {
        let alert = UIAlertController(title: "Export touch layout", message: "Name this portable layout file.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Layout name"
            field.text = "My Touch Layout"
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Export", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            do {
                let profile = try touchOverlay.makeTouchProfile(named: alert?.textFields?.first?.text ?? "")
                let directory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("UT99-Touch-Profile-Exports", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent(UT99TouchProfileStore.exportFileName(for: profile))
                try UT99TouchProfileStore.encode(profile).write(to: url, options: .atomic)
                let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let popover = share.popoverPresentationController {
                    popover.sourceView = menuButton
                    popover.sourceRect = menuButton.bounds
                }
                present(share, animated: true)
                statusLabel.text = "Touch layout ready to export"
                NSLog("UT99 touch named profile export file=%@", url.lastPathComponent)
            } catch {
                presentMenuInfo(title: "Touch layout", message: error.localizedDescription)
            }
        })
        present(alert, animated: true)
    }

    private func importTouchProfile() {
        documentPickerPurpose = .touchProfile
        let profileType = UTType(filenameExtension: UT99TouchProfileStore.fileExtension) ?? .json
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [profileType, .json], asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func finishTouchProfileImport(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let profile = try UT99TouchProfileStore.decode(Data(contentsOf: url))
            _ = try UT99TouchProfileStore.upsert(profile)
            try touchOverlay.applyTouchProfileDocument(profile)
            updateTouchVisibility()
            statusLabel.text = "Imported and applied: \(profile.name)"
            NSLog("UT99 touch named profile imported name=%@ file=%@", profile.name, url.lastPathComponent)
        } catch {
            presentMenuInfo(title: "Touch layout", message: "Import failed. \(error.localizedDescription)")
        }
    }

    @objc private func editTouchLayout() {
        prepareGameplayForTouchLayoutEditing()
        touchOverlay.isHidden = false
        touchOverlay.isUserInteractionEnabled = true
        view.bringSubviewToFront(touchOverlay)
        view.bringSubviewToFront(menuButton)
        touchOverlay.setLayoutEditing(true)
        statusLabel.text = "Tap a control, drag it, and use SIZE; tap DONE to save"
        NSLog("UT99 touch layout editor opened")
    }

    @objc private func testTouchLayout() {
        prepareGameplayForTouchLayoutEditing()
        touchOverlay.isHidden = false
        touchOverlay.isUserInteractionEnabled = true
        view.bringSubviewToFront(touchOverlay)
        view.bringSubviewToFront(menuButton)
        touchOverlay.setLayoutTesting(true)
        statusLabel.text = "Live test · movement, look, and actions are active · tap DONE to finish"
        NSLog("UT99 touch layout test opened")
    }

    private func prepareGameplayForTouchLayoutEditing() {
        // Editing is a temporary presentation state, not an input-mode
        // change. Preserve menu/gameplay mode so SELECT and BACK can be edited
        // independently from FIRE and GAME MENU.
        if !isTouchInputEnabled {
            setTouchInputEnabled(true)
        }
        touchOverlay.setMenuInteractionActive(originalMenuInputActive)
    }

    @objc private func showTouchControlOptions() {
        let configuration = touchOverlay.touchConfiguration
        let alert = UIAlertController(
            title: "Touch controls",
            message: "Choose a handedness preset and keep only the controls you use. The host menu always remains visible.",
            preferredStyle: .actionSheet
        )
        let handedness = configuration.leftHanded ? "Left-handed" : "Right-handed"
        alert.addAction(UIAlertAction(title: "Handedness: \(handedness)", style: .default) { [weak self] _ in
            self?.touchOverlay.setLeftHanded(!configuration.leftHanded)
            self?.showTouchControlOptions()
        })
        for action in GoldenPadTouchOverlay.Action.allCases {
            let visible = touchOverlay.isActionVisible(action)
            let title = touchOverlay.displayTitle(for: action)
            alert.addAction(UIAlertAction(title: "\(visible ? "✓" : "○") \(title)", style: .default) { [weak self] _ in
                self?.touchOverlay.setAction(action, visible: !visible)
                self?.showTouchControlOptions()
            })
        }
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        presentActionSheet(alert)
    }

    @objc private func resetTouchLayout() {
        touchOverlay.resetTouchLayout()
        statusLabel.text = "Touch layout restored"
    }

    /// Deterministic diagnostic for the host/menu state machine. This does
    /// not replace UIKit taps: it exercises the same bounded host panel and
    /// persisted profile application when simulator pointer injection is
    /// unavailable, while leaving the real button/action-sheet path intact.
    private func runMenuSmokeTest() {
        toggleMenu()
        let menuConstructed = hostMenuPanel != nil
        let originalProfile = touchOverlay.touchProfile
        let profile = GoldenPadTouchOverlay.TouchProfile.compact
        touchOverlay.applyTouchProfile(profile)
        statusLabel.text = "Touch layout: \(profile.title)"
        let persisted = UserDefaults.standard.string(forKey: "ut99.touch.profile") == profile.rawValue
        NSLog("UT99 menu smoke menuConstructed=%@ profile=%@ persisted=%@",
              menuConstructed ? "true" : "false", profile.rawValue, persisted ? "true" : "false")
        touchOverlay.applyTouchProfile(originalProfile)
        closeHostMenuPanel()
    }

    private func runTouchProfileSmokeTest() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UT99TouchProfileStore.defaultsKey)
        touchOverlay.resetTouchLayout()
        touchOverlay.setLeftHanded(true)
        touchOverlay.setAction(.scoreboard, visible: false)
        touchOverlay.setTouchOpacity(0.72)
        touchOverlay.setGlobalScale(0.92)
        defaults.set(1.15, forKey: "ut99.input.lookSensitivity")
        do {
            let profile = try touchOverlay.makeTouchProfile(named: "Southpaw Arena")
            let encoded = try UT99TouchProfileStore.encode(profile)
            let decoded = try UT99TouchProfileStore.decode(encoded)
            _ = try UT99TouchProfileStore.upsert(decoded)
            touchOverlay.resetTouchLayout()
            try touchOverlay.applyTouchProfileDocument(decoded)
            let exportURL = dataSupportRoot().appendingPathComponent(UT99TouchProfileStore.exportFileName(for: decoded))
            try encoded.write(to: exportURL, options: .atomic)
            statusLabel.text = "Saved layout · Southpaw Arena · left-handed"
            NSLog("UT99 touch profile smoke name=%@ roundTrip=true saved=%lu applied=true bytes=%lu",
                  decoded.name, UT99TouchProfileStore.profiles().count, encoded.count)
        } catch {
            statusLabel.text = "Touch layout profile smoke failed"
            NSLog("UT99 touch profile smoke failed: %@", error.localizedDescription)
        }
    }

    /// Exercises the real host-menu entry and overlay editor transition. A
    /// simulator command-line smoke test cannot synthesize a trustworthy
    /// finger drag, so placement changes themselves remain a UI/manual gate.
    private func runLayoutSmokeTest() {
        toggleMenu()
        let menuConstructed = hostMenuPanel != nil
        closeHostMenuPanel()
        editTouchLayout()
        let editorPresented = touchOverlay.editingLayout
        touchOverlay.setLayoutEditing(false)
        NSLog("UT99 layout smoke menuConstructed=%@ editorPresented=%@",
              menuConstructed ? "true" : "false", editorPresented ? "true" : "false")
    }

    private func runSettingsSmokeTest() {
        let defaults = UserDefaults.standard
        let oldSensitivity = defaults.object(forKey: "ut99.input.lookSensitivity")
        let oldInvert = defaults.object(forKey: "ut99.input.invertLookY")
        let oldTextures = defaults.object(forKey: "ut99.graphics.safeTextures")
        let oldVSync = defaults.object(forKey: "ut99.graphics.vsync")
        let oldAudio = defaults.object(forKey: "ut99.audio.enabled")
        let oldOpacity = defaults.object(forKey: "ut99.touch.opacity")
        let oldScale = defaults.object(forKey: "ut99.touch.scale")
        defaults.set(1.5, forKey: "ut99.input.lookSensitivity")
        defaults.set(true, forKey: "ut99.input.invertLookY")
        defaults.set(false, forKey: "ut99.graphics.safeTextures")
        defaults.set(false, forKey: "ut99.graphics.vsync")
        defaults.set(true, forKey: "ut99.audio.enabled")
        touchOverlay.setTouchOpacity(0.8)
        touchOverlay.setGlobalScale(1.15)
        let persisted = defaults.double(forKey: "ut99.input.lookSensitivity") == 1.5 &&
            defaults.bool(forKey: "ut99.input.invertLookY") &&
            !defaults.bool(forKey: "ut99.graphics.safeTextures") &&
            !defaults.bool(forKey: "ut99.graphics.vsync") &&
            defaults.bool(forKey: "ut99.audio.enabled") &&
            abs(defaults.double(forKey: "ut99.touch.opacity") - 0.8) < 0.01 &&
            abs(defaults.double(forKey: "ut99.touch.scale") - 1.15) < 0.01
        for (key, value) in [("ut99.input.lookSensitivity", oldSensitivity),
                             ("ut99.input.invertLookY", oldInvert),
                             ("ut99.graphics.safeTextures", oldTextures),
                             ("ut99.graphics.vsync", oldVSync),
                             ("ut99.audio.enabled", oldAudio),
                             ("ut99.touch.opacity", oldOpacity),
                             ("ut99.touch.scale", oldScale)] {
            if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        NSLog("UT99 settings smoke persisted=%@", persisted ? "true" : "false")
    }

    /// Exercises the same journaled commit path used by the Files picker. The
    /// fixture is isolated in tmp, forces an interruption after two installed
    /// items, verifies next-launch-style rollback, then performs a successful
    /// replacement while ensuring the generated System tree survives.
    private func runDataImportTransactionSmokeTest() {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("UT99ImportSmoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        var passed = false
        var detail = "not run"
        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            let system = root.appendingPathComponent("System", isDirectory: true)
            let oldMaps = root.appendingPathComponent("Maps", isDirectory: true)
            try fileManager.createDirectory(at: system, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: oldMaps, withIntermediateDirectories: true)
            try Data("system-preserved".utf8).write(to: system.appendingPathComponent("keep.txt"))
            let oldData = Data("old-map".utf8)
            try oldData.write(to: oldMaps.appendingPathComponent("old.unr"))
            try smokeManifest(source: "old", files: [("Maps/old.unr", oldData)])
                .write(to: root.appendingPathComponent(UT99DataImportTransaction.manifestName))

            let interrupted = try makeImportSmokeStaging(in: root, name: ".import-staging-interrupted", marker: "interrupted")
            var interruptionObserved = false
            do {
                try UT99DataImportTransaction.commit(
                    stagedRoot: interrupted.root,
                    manifestData: interrupted.manifest,
                    to: root,
                    failAfterInstalledItemCount: 2,
                    recoverAfterFailure: false
                )
            } catch {
                interruptionObserved = true
            }
            let recovered = try UT99DataImportTransaction.recoverInterruptedCommit(at: root)
            let rollbackPreserved = (try? String(contentsOf: oldMaps.appendingPathComponent("old.unr"), encoding: .utf8)) == "old-map"

            let successful = try makeImportSmokeStaging(in: root, name: ".import-staging-success", marker: "new")
            try UT99DataImportTransaction.commit(
                stagedRoot: successful.root,
                manifestData: successful.manifest,
                to: root
            )
            let inspection = try UT99DataImportTransaction.inspectInstalledManifest(at: root)
            let systemPreserved = (try? String(contentsOf: system.appendingPathComponent("keep.txt"), encoding: .utf8)) == "system-preserved"
            let oldRemoved = !fileManager.fileExists(atPath: oldMaps.appendingPathComponent("old.unr").path)
            let debris = try fileManager.contentsOfDirectory(atPath: root.path)
                .filter { $0.hasPrefix(".import-") || $0 == ".ut99-import-transaction.json" }
            passed = interruptionObserved && recovered && rollbackPreserved &&
                inspection.isValid && inspection.validFiles == 4 &&
                systemPreserved && oldRemoved && debris.isEmpty
            detail = "rollback=\(rollbackPreserved) replacement=\(inspection.validFiles)/\(inspection.expectedFiles) systemPreserved=\(systemPreserved) debris=\(debris.count)"
        } catch {
            detail = "error=\(error.localizedDescription)"
        }

        let line = "UT99 import transaction smoke passed=\(passed) \(detail)\n"
        let supportRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Unreal Tournament", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportRoot, withIntermediateDirectories: true)
        try? Data(line.utf8).write(
            to: supportRoot.appendingPathComponent("UT99-import-transaction-smoke.log"),
            options: .atomic
        )
        statusLabel.text = passed ? "Transactional import rollback and replacement passed" : "Transactional import smoke failed"
        NSLog("%@", line.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func makeImportSmokeStaging(
        in root: URL,
        name: String,
        marker: String
    ) throws -> (root: URL, manifest: Data) {
        let staging = root.appendingPathComponent(name, isDirectory: true)
        var files: [(String, Data)] = []
        for directory in UT99DataImportTransaction.contentDirectoryNames {
            let folder = staging.appendingPathComponent(directory, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let filename = directory == "Maps" ? "\(marker).unr" : "\(marker).dat"
            let data = Data("\(marker)-\(directory)".utf8)
            try data.write(to: folder.appendingPathComponent(filename))
            files.append(("\(directory)/\(filename)", data))
        }
        return (staging, try smokeManifest(source: marker, files: files))
    }

    private func smokeManifest(source: String, files: [(String, Data)]) throws -> Data {
        let entries: [[String: Any]] = files.map { path, data in
            [
                "path": path,
                "size": data.count,
                "sha256": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            ]
        }
        return try JSONSerialization.data(
            withJSONObject: ["format": 1, "source_root_name": source, "files": entries],
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private func connectToServer(_ rawValue: String) {
        guard isGameDataReady() else {
            transition(to: .needsData, reason: "direct connect requested before game-data setup")
            statusLabel.text = "Set up game data before joining a server"
            return
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.contains("://") ? trimmed : "unreal://" + trimmed
        guard !trimmed.isEmpty,
              let components = URLComponents(string: candidate),
              components.scheme?.lowercased() == "unreal",
              let host = components.host,
              !host.isEmpty,
              components.port.map({ (1...65_535).contains($0) }) ?? true else {
            statusLabel.text = "Enter a valid UT server hostname or unreal:// address"
            return
        }
        UserDefaults.standard.set(candidate, forKey: "ut99.multiplayer.lastServerURL")
        _ = launchEngine(connectURL: candidate)
    }

    @objc private func probeEngine() {
        statusLabel.text = engineBridge.probeEmbeddedImage().statusText
    }

    private func diagnosticsSummary() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info["CFBundleVersion"] as? String ?? "unknown"
        let engineURL = Bundle.main.bundleURL
            .appendingPathComponent("Frameworks", isDirectory: true)
            .appendingPathComponent("UnrealTournament.dylib")
        let engine: String
        if let data = try? Data(contentsOf: engineURL) {
            engine = "embedded sha256=\(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())"
        } else {
            engine = "missing"
        }
        let renderer = gameView.device?.name ?? "Metal unavailable"
        let metrics = engineBridge.rendererMetrics()
        let route = AVAudioSession.sharedInstance().currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ",")
        let network = networkMonitor.currentPath.status == .satisfied ? "satisfied" : "not satisfied"
        let thermal: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = "nominal"
        case .fair: thermal = "fair"
        case .serious: thermal = "serious"
        case .critical: thermal = "critical"
        @unknown default: thermal = "unknown"
        }
        let performance = metrics.hasPresentedFrames
            ? String(format: "Render: %.1f avg · %.1f 1%% low · %.2f ms · %llux%llu",
                     metrics.averageFPS, metrics.onePercentLowFPS,
                     metrics.averageFrameTimeMS, metrics.drawableWidth, metrics.drawableHeight)
            : "Render: awaiting FruCoRe presentation"
        return [
            "Host v\(version) (\(build))",
            "Host state: \(hostState.rawValue)",
            runtimeRecovery.diagnosticSummary(),
            "Engine image: \(engine)",
            "Metal: \(renderer)",
            performance,
            String(format: "Resident memory: %.1f MiB", residentMemoryMiB()),
            "Audio: \(route.isEmpty ? "not reported" : route)",
            "Network: \(network) · thermal: \(thermal)"
        ].joined(separator: "\n")
    }

    private func diagnosticsText() -> String {
        let supportRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Unreal Tournament", isDirectory: true)
        var output = "UTP diagnostics\nGenerated: \(ISO8601DateFormatter().string(from: Date()))\nPrivacy: paths and common secret fields are redacted; review server addresses before sharing.\n\n\(diagnosticsSummary())\n"
        let metrics = engineBridge.rendererMetrics()
        output += "\nDisplay points: \(UIScreen.main.bounds.width)x\(UIScreen.main.bounds.height) @\(UIScreen.main.scale)\n"
        output += String(format: "FruCoRe presentation: frames=%llu avgFPS=%.2f onePercentLowFPS=%.2f frameMS=%.3f drawable=%llux%llu\n",
                         metrics.frameCount, metrics.averageFPS, metrics.onePercentLowFPS,
                         metrics.averageFrameTimeMS, metrics.drawableWidth, metrics.drawableHeight)
        let touchConfiguration = UT99TouchConfiguration.load()
        output += "Touch profile: \(touchOverlay.touchProfile.rawValue), opacity=\(touchOverlay.touchOpacity), scale=\(touchOverlay.globalScale), handedness=\(touchConfiguration.leftHanded ? "left" : "right"), hidden=\(touchConfiguration.hiddenActions.sorted().joined(separator: ","))\n"
        output += String(format: "Touch tuning: acceleration=%.2f lookDeadZone=%.4f moveDeadZone=%.2f controllerAutoHide=%@\n",
                         touchConfiguration.lookAcceleration, touchConfiguration.lookDeadZone,
                         touchConfiguration.movementDeadZone,
                         touchConfiguration.autoHideForController ? "true" : "false")
        output += "\n--- recent logs (last 200 lines each) ---\n"
        for url in diagnosticLogURLs(at: supportRoot) {
            output += "\n[\(url.lastPathComponent)]\n"
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                output += text.split(whereSeparator: { $0.isNewline }).suffix(200).joined(separator: "\n") + "\n"
            } else {
                output += "<not present>\n"
            }
        }
        return UT99DiagnosticRedactor.redact(output)
    }

    @objc private func copyDiagnostics() {
        UIPasteboard.general.string = diagnosticsText()
        statusLabel.text = "Diagnostics copied to clipboard"
    }

    @objc private func exportDiagnostics() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let zipURL = documents.appendingPathComponent("UTP-Logs-Latest.zip")
        NSLog("UT99 support log export begin")
        do {
            try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            let entries = supportLogEntries()
            try UT99DiagnosticsArchive.write(entries: entries, to: zipURL)
            let bytes = entries.reduce(0) { $0 + $1.1.count }
            NSLog("UT99 support log archive ready entries=%lu inputBytes=%lu",
                  entries.count, bytes)
            NSLog("UT99 support log saved file=Documents/%@", zipURL.lastPathComponent)
            supportExportNotice = "LOGS SAVED\nFiles → On My iPad → UTP → \(zipURL.lastPathComponent)"
            toggleMenu()
        } catch {
            NSLog("UT99 support log export failed: %@", error.localizedDescription)
            supportExportNotice = "EXPORT FAILED\n\(error.localizedDescription)"
            toggleMenu()
        }
    }

    private func supportLogEntries() -> [(String, Data)] {
        let identity = appIdentity()
        let configuration = UT99TouchConfiguration.load()
        var controllers = GCController.controllers()
        if let current = GCController.current,
           !controllers.contains(where: { $0 === current }) {
            controllers.append(current)
        }
        let extendedControllers = controllers.filter { $0.extendedGamepad != nil }
        let summary = UT99DiagnosticRedactor.redact("""
        UTP support logs
        Generated: \(ISO8601DateFormatter().string(from: Date()))
        Privacy: paths and common secret fields are redacted; review server addresses before sharing.
        Host: v\(identity.version) (\(identity.build))
        Host state: \(hostState.rawValue)
        System: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Touch: enabled=\(isTouchInputEnabled) mode=\(originalMenuInputActive ? "menu" : "gameplay") autoHide=\(configuration.autoHideForController)
        Controller: discovered=\(controllers.count) extended=\(extendedControllers.count) responderFallback=\(controllerFallbackConnected) autoHideActive=\(controllerAutoHideActive)
        Pointer: owner=host-uikit mode=\(originalMenuInputActive ? "menu" : "gameplay") surfaceEnabled=\(gameSurfaceInputView.isUserInteractionEnabled)
        \(runtimeRecovery.diagnosticSummary())
        """)
        var entries = [("diagnostics.txt", Data(summary.utf8))]
        for url in diagnosticLogURLs(at: dataSupportRoot()) {
            guard let data = boundedLogData(at: url, maximumBytes: 524_288) else { continue }
            let text = String(decoding: data, as: UTF8.self)
            entries.append(("logs/\(url.lastPathComponent)", Data(UT99DiagnosticRedactor.redact(text).utf8)))
        }
        entries.append(contentsOf: runtimeRecovery.diagnosticArtifacts())
        return entries
    }

    private func boundedLogData(at url: URL, maximumBytes: Int) -> Data? {
        guard maximumBytes > 0,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let start = size > UInt64(maximumBytes) ? size - UInt64(maximumBytes) : 0
        try? handle.seek(toOffset: start)
        return try? handle.readToEnd()
    }

    @objc private func reportAProblem() {
        var components = URLComponents(string: "https://github.com/chrissotraidis/utp/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "body", value: """
            ### What happened?

            ### Steps to reproduce

            ### Device and controller

            ### Diagnostics
            Attach UTP-Logs-Latest.zip from Files → On My iPad → UTP.
            """)
        ]
        guard let url = components?.url else {
            presentMenuInfo(title: "Report a Problem", message: "The UTP issue page could not be opened.")
            return
        }
        UIApplication.shared.open(url, options: [:]) { [weak self] opened in
            guard !opened else { return }
            self?.presentMenuInfo(
                title: "Report a Problem",
                message: "Open github.com/chrissotraidis/utp/issues to report the problem."
            )
        }
    }

    private func diagnosticLogURLs(at supportRoot: URL) -> [URL] {
        [
            supportRoot.appendingPathComponent("UT99-engine.stdout"),
            supportRoot.appendingPathComponent("UnrealTournament.log"),
            supportRoot.appendingPathComponent("UT99-touch-smoke.log"),
            supportRoot.appendingPathComponent("UT99-performance.log"),
            supportRoot.appendingPathComponent("UT99-host-metal-smoke.log")
        ]
    }

    private func diagnosticEntries() -> [(String, Data)] {
        let supportRoot = dataSupportRoot()
        var entries = [("diagnostics.txt", Data(diagnosticsText().utf8))]
        for url in diagnosticLogURLs(at: supportRoot) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            entries.append(("logs/\(url.lastPathComponent)", Data(UT99DiagnosticRedactor.redact(text).utf8)))
        }
        let manifestURL = UT99DataImportTransaction.installedManifestURL(at: supportRoot)
        if let manifest = try? Data(contentsOf: manifestURL) {
            entries.append(("data/\(manifestURL.lastPathComponent)", manifest))
        }
        entries.append(contentsOf: runtimeRecovery.diagnosticArtifacts())
        return entries
    }

    private func writeDiagnosticsArchive(to url: URL) throws {
        try UT99DiagnosticsArchive.write(entries: diagnosticEntries(), to: url)
    }

    private func runDiagnosticsExportSmokeTest() {
        let archiveURL = dataSupportRoot().appendingPathComponent("UT99-diagnostics-smoke.zip")
        let resultURL = dataSupportRoot().appendingPathComponent("UT99-diagnostics-smoke.log")
        do {
            try writeDiagnosticsArchive(to: archiveURL)
            let size = (try? archiveURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let line = "exported=true bytes=\(size) entries=\(diagnosticEntries().count) archive=\(archiveURL.lastPathComponent)\n"
            try Data(line.utf8).write(to: resultURL, options: .atomic)
            statusLabel.text = "Diagnostics archive verified for inspection"
            NSLog("UT99 diagnostics export smoke %@", line.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            let line = "exported=false error=\(error.localizedDescription)\n"
            try? Data(line.utf8).write(to: resultURL, options: .atomic)
            statusLabel.text = "Diagnostics archive smoke failed"
            NSLog("UT99 diagnostics export smoke failed: %@", error.localizedDescription)
        }
    }

    @objc private func resetHostConfiguration() {
        let defaults = UserDefaults.standard
        ["ut99.input.lookSensitivity", "ut99.input.invertLookY", "ut99.graphics.safeTextures", "ut99.graphics.vsync", "ut99.audio.enabled", "ut99.graphics.frameCap", Self.touchInputEnabledKey, "ut99.touch.opacity", "ut99.touch.scale", "ut99.touch.profile", "ut99.touch.layout", "ut99.touch.layout.v1", UT99TouchConfiguration.defaultsKey, UT99TouchProfileStore.defaultsKey].forEach { defaults.removeObject(forKey: $0) }
        touchOverlay.applyTouchProfile(.standard)
        touchOverlay.resetTouchLayout()
        statusLabel.text = "Host configuration reset"
    }

    @objc private func enableSafeMode() {
        prepareSafeModePreferences()
        transition(to: .safeMode, reason: "safe texture mode requested")
        statusLabel.text = "Safe mode prepared · safe textures, VSync on, audio off"
    }

    @objc private func startEngineInSafeMode() {
        prepareSafeModePreferences()
        _ = launchEngine(safeMode: true)
    }

    private func prepareSafeModePreferences() {
        pendingSafeMode = true
    }

    private func residentMemoryMiB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1_048_576.0
    }

    @objc private func startEngine() {
        guard isGameDataReady() else {
            transition(to: .needsData, reason: "offline play requested before game-data setup")
            statusLabel.text = "Set up game data before starting Unreal Tournament"
            UIAccessibility.post(notification: .screenChanged, argument: onboardingTitleLabel)
            return
        }
        _ = launchEngine()
    }

    @discardableResult
    private func launchEngine(
        connectURL: String? = nil,
        safeMode requestedSafeMode: Bool = false
    ) -> UT99EngineBridge.ProbeResult? {
        guard hostState != .startingEngine && hostState != .running && hostState != .pausedBySystem else {
            statusLabel.text = "Original engine is already active"
            NSLog("UT99 host blocked duplicate engine start state=%@", hostState.rawValue)
            return nil
        }
        let safeMode = requestedSafeMode || pendingSafeMode
        if safeMode { prepareSafeModePreferences() }
        let identity = appIdentity()
        do {
            try runtimeRecovery.beginSession(
                appVersion: identity.version,
                appBuild: identity.build,
                safeMode: safeMode
            )
        } catch {
            NSLog("UT99 active session marker creation failed: %@", error.localizedDescription)
        }
        recoveredSession = nil
        recoveryPromptPresented = false
        pendingSafeMode = false
        releaseGameplayInputs()
        // The stock title screen is a UWindow menu. Start with the dedicated
        // cursor stick and SELECT button; gameplay restores the normal layout
        // as soon as SDL enters relative-mouse mode.
        setOriginalMenuInputActive(true)
        transition(to: .startingEngine, reason: connectURL == nil ? "local engine launch" : "direct connect launch")
        prepareEngineSurfaceOverlay()
        if CommandLine.arguments.contains("-UT99TouchSettingsPanelSmokeTest"),
           !hasPresentedMenuSmokeState {
            hasPresentedMenuSmokeState = true
            showTouchSettings()
        }
        let result = engineBridge.startOriginalEntry(connectURL: connectURL, safeMode: safeMode) { [weak self] exitCode in
            self?.engineDidExit(exitCode)
        }
        // UT owns the main thread after entry, so a deferred UIKit/SDL-window
        // callback cannot be responsible for dismissing the launch curtain.
        // The entry result is the last deterministic synchronous boundary.
        launchTransitionView?.removeFromSuperview()
        launchTransitionView = nil
        statusLabel.text = result.statusText
        switch result {
        case .started:
            transition(to: .running, reason: "original entry started")
            if connectURL == nil && !CommandLine.arguments.contains("-UT99AutoMatch") {
                engineBridge.scheduleInitialOriginalMenu()
            }
            do {
                try runtimeRecovery.updateActiveState("Running")
            } catch {
                NSLog("UT99 running session marker update failed: %@", error.localizedDescription)
            }
        case .notEmbedded:
            transition(to: .unsupportedBuild, reason: "engine image missing")
            _ = try? runtimeRecovery.finishCleanly("engine image was not embedded")
        case .loaded:
            transition(to: .ready, reason: "engine loaded without entry")
            _ = try? runtimeRecovery.finishCleanly("engine loaded without entry invocation")
        case let .failed(message):
            transition(to: .crashed, reason: "engine entry failed")
            _ = try? runtimeRecovery.recordFailure(message)
        }
        scheduleSDLWindowPresentation()
        return result
    }

    private func engineDidExit(_ exitCode: Int32) {
        guard hostState == .startingEngine || hostState == .running || hostState == .pausedBySystem else {
            NSLog("UT99 ignored engine return code=%d state=%@", exitCode, hostState.rawValue)
            return
        }
        releaseGameplayInputs()
        transition(to: .stoppingEngine, reason: "original entry returned code \(exitCode)")
        restoreHostAfterEngineExit()
        if exitCode == 0 {
            _ = try? runtimeRecovery.finishCleanly("original entry returned 0")
            transition(to: .ready, reason: "controlled engine return completed")
            statusLabel.text = "Original engine stopped cleanly · diagnostics available"
        } else {
            _ = try? runtimeRecovery.recordFailure("original entry returned \(exitCode)")
            transition(to: .crashed, reason: "original entry returned nonzero")
            statusLabel.text = "Original engine stopped with code \(exitCode) · safe mode available"
        }
    }

    private func restoreHostAfterEngineExit() {
        guard let hostWindow = view.window else { return }
        gameSurfaceInputView.isUserInteractionEnabled = false
        for window in hostWindow.windowScene?.windows ?? [] where window !== hostWindow {
            let rootName = window.rootViewController.map { String(describing: type(of: $0)) } ?? ""
            if rootName.contains("SDL") { window.isHidden = true }
        }
        view.backgroundColor = UIColor(red: 0.02, green: 0.028, blue: 0.055, alpha: 1)
        backdropLayer.isHidden = false
        for subview in view.subviews { subview.isHidden = false }
        touchOverlay.setLayoutEditing(false)
        hostWindow.windowLevel = .normal
        hostWindow.makeKeyAndVisible()
        view.bringSubviewToFront(touchOverlay)
        view.bringSubviewToFront(menuButton)
        reconcileGameDataState(reason: "engine session returned to host")
        NSLog("UT99 restored diagnosable host surface after engine return")
    }

    /// SDL creates its own UIKit window and then enters the original game's
    /// main loop on the main thread. Establish the host overlay's window level
    /// before that happens, so UIKit cannot put the touch layer behind SDL.
    private func prepareEngineSurfaceOverlay() {
        guard let hostWindow = view.window else { return }
        view.backgroundColor = .clear
        backdropLayer.isHidden = true
        for subview in view.subviews where subview !== gameView &&
            subview !== gameSurfaceInputView && subview !== touchOverlay &&
            subview !== touchSettingsPanel && subview !== menuKeyboardPanel &&
            subview !== launchTransitionView && subview !== menuButton {
            subview.isHidden = true
        }
        view.isUserInteractionEnabled = true
        gameSurfaceInputView.isHidden = false
        gameSurfaceInputView.isUserInteractionEnabled = true
        view.bringSubviewToFront(gameSurfaceInputView)
        view.bringSubviewToFront(touchOverlay)
        if let hostMenuPanel {
            hostMenuPanel.isHidden = false
            view.bringSubviewToFront(hostMenuPanel)
        }
        view.bringSubviewToFront(menuButton)
        if let launchTransitionView { view.bringSubviewToFront(launchTransitionView) }
        hostWindow.windowLevel = UIWindow.Level.normal + 1
        hostWindow.makeKeyAndVisible()
        updateTouchVisibility()
        NSLog("UT99EngineBridge prepared host touch overlay above SDL hostBounds=%@ overlay=%@ menu=%@",
              hostWindow.bounds.debugDescription, touchOverlay.frame.debugDescription,
              menuButton.frame.debugDescription)
    }

    /// SDL's UIKit backend creates its own UIWindow. Scene-based apps must
    /// attach that window to the active UIWindowScene or it can run the
    /// original renderer successfully while remaining hidden behind the host.
    /// The host window stays transparent and owns the touch overlay above it.
    private func scheduleSDLWindowPresentation() {
        for delay in [0.25, 0.75, 1.5, 3.0, 5.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.presentSDLWindowIfAvailable()
            }
        }
    }

    private func presentSDLWindowIfAvailable() {
        guard !isReassertingSDLWindow else { return }
        isReassertingSDLWindow = true
        defer { isReassertingSDLWindow = false }
        guard let hostWindow = view.window,
              let scene = hostWindow.windowScene else { return }
        // Inspect every connected scene because SDL can finish creating its
        // renderer window on a different scene callback than the host. Avoid
        // UIApplication's deprecated process-wide `windows` collection; if
        // SDL has not attached yet, the scheduled retries will find it once
        // UIKit publishes it through its UIWindowScene.
        var windows = scene.windows
        let sceneWindows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for candidate in sceneWindows where !windows.contains(where: { $0 === candidate }) {
            windows.append(candidate)
        }
        guard let engineWindow = windows.first(where: {
            guard let root = $0.rootViewController else { return false }
            return $0 !== hostWindow && String(describing: type(of: root)).contains("SDL")
        }) else {
            let inventory = windows.map { window in
                let root = window.rootViewController.map { String(describing: type(of: $0)) } ?? "nil"
                return "key=\(window.isKeyWindow) hidden=\(window.isHidden) level=\(window.windowLevel.rawValue) root=\(root)"
            }.joined(separator: " | ")
            NSLog("UT99EngineBridge SDL window search found none: %@", inventory)
            return
        }

        if #available(iOS 16.0, *) {
            hostWindow.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(
                UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscapeRight)
            ) { error in
                NSLog("UT99 post-SDL landscape geometry request: %@", error.localizedDescription)
            }
        }
        if engineWindow.windowScene == nil { engineWindow.windowScene = scene }
        engineWindow.windowLevel = .normal
        engineWindow.isHidden = false
        // SDL initially sizes its UIWindow to the renderer's desktop-style
        // default. The host scene is the authoritative tablet canvas;
        // resize the SDL window and its root view before compositing the
        // EctoPad-derived layer, otherwise the game remains marooned in the
        // upper-left corner while the controls fill the whole iPad.
        engineWindow.frame = hostWindow.bounds
        engineWindow.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let rendererFrame = currentRendererViewportFrame()
        // Match EctoPad's real composition: renderer fills landscape and
        // controls float above it. The old 4:3 island/control bay made the
        // original renderer appear detached and approximately half-size.
        if let engineView = engineWindow.rootViewController?.view {
            engineView.transform = .identity
            engineView.frame = rendererFrame
            engineView.bounds = CGRect(origin: .zero, size: rendererFrame.size)
            engineView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            engineView.setNeedsLayout()
            engineView.layoutIfNeeded()
            engineBridge.updateMenuCursorCanvasSize(rendererFrame.size)
            NSLog("UT99EngineBridge renderer frame=%@ bounds=%@ scale=%.2f",
                  engineView.frame.debugDescription,
                  engineView.bounds.debugDescription,
                  engineView.layer.contentsScale)
        }
        // SDL owns the renderer window, but the host overlay owns touch and
        // menu interaction. Keeping SDL render-only prevents the second
        // UIWindow from stealing UIKit's key-event routing after startup.
        engineWindow.isUserInteractionEnabled = false
        engineWindow.resignKey()
        view.backgroundColor = .clear
        backdropLayer.isHidden = true
        for subview in view.subviews where subview !== gameView &&
            subview !== gameSurfaceInputView && subview !== touchOverlay &&
            subview !== touchSettingsPanel && subview !== menuKeyboardPanel &&
            subview !== launchTransitionView && subview !== menuButton {
            subview.isHidden = true
        }
        // SDL can recreate or reorder its window after the first scene
        // presentation. Reassert the host's interaction surface every time
        // the renderer is attached so visible controls remain real UIKit hit
        // targets rather than a screenshot-only overlay.
        view.isUserInteractionEnabled = true
        gameSurfaceInputView.isUserInteractionEnabled = true
        gameSurfaceInputView.isHidden = false
        view.bringSubviewToFront(gameSurfaceInputView)
        view.bringSubviewToFront(touchOverlay)
        if let hostMenuPanel {
            hostMenuPanel.isHidden = false
            view.bringSubviewToFront(hostMenuPanel)
        }
        if let touchSettingsPanel {
            touchSettingsPanel.isHidden = false
            view.bringSubviewToFront(touchSettingsPanel)
        }
        if let menuKeyboardPanel { view.bringSubviewToFront(menuKeyboardPanel) }
        view.bringSubviewToFront(menuButton)
        launchTransitionView?.removeFromSuperview()
        launchTransitionView = nil
        hostWindow.windowLevel = UIWindow.Level.normal + 1
        hostWindow.makeKeyAndVisible()
        claimKeyboardResponder(reason: "sdl-window-attached")
        NSLog("UT99EngineBridge attached SDL window to active scene hostKey=%@ hostBounds=%@ engineBounds=%@ orientation=%ld",
              hostWindow.isKeyWindow ? "true" : "false",
              hostWindow.bounds.debugDescription, engineWindow.bounds.debugDescription,
              Int(scene.interfaceOrientation.rawValue))
    }

    private func currentRendererViewportFrame() -> CGRect {
        let insets = view.safeAreaInsets
        return UT99TouchLayoutGeometry.rendererFrame(
            canvasSize: view.bounds.size,
            safeInsets: UT99TouchInsets(
                top: insets.top,
                left: insets.left,
                bottom: insets.bottom,
                right: insets.right
            ),
            isPhone: traitCollection.userInterfaceIdiom == .phone
        )
    }

    private func rendererPoint(fromHostPoint point: CGPoint) -> CGPoint {
        let frame = currentRendererViewportFrame()
        return CGPoint(
            x: min(max(point.x - frame.minX, 0), frame.width),
            y: min(max(point.y - frame.minY, 0), frame.height)
        )
    }

    private func prepareBundledData() {
        prepareBundledRuntimeShader()
        do {
            if try UT99RuntimeSupport.ensureV469eMarkerIfMatching(at: dataSupportRoot()) {
                NSLog("UT99 matching v469e runtime provenance verified")
            }
        } catch {
            NSLog("UT99 v469e runtime verification failed: %@", error.localizedDescription)
        }
        guard let bundledData = Bundle.main.url(forResource: "UT99Data", withExtension: nil) else { return }
        let supportRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Unreal Tournament", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: supportRoot, withIntermediateDirectories: true)
            if try UT99DataImportTransaction.recoverInterruptedCommit(at: supportRoot) {
                NSLog("UT99 data import recovered an interrupted transaction before startup")
            }
            // v2 re-syncs the System tree for engine packages. Earlier shell
            // builds could leave the v1 marker with maps but no INI/packages,
            // which makes the original entry fail its first config read.
            let marker = supportRoot.appendingPathComponent(".ut99-bundled-data-v2")
            let forceBundledDataSync = CommandLine.arguments.contains("-UT99ForceBundledDataSync")
            if forceBundledDataSync || !FileManager.default.fileExists(atPath: marker.path) {
                for item in try FileManager.default.contentsOfDirectory(at: bundledData, includingPropertiesForKeys: nil) {
                    let destination = supportRoot.appendingPathComponent(item.lastPathComponent)
                    var mutableConfigurations: [String: Data] = [:]
                    if item.lastPathComponent.caseInsensitiveCompare("System") == .orderedSame,
                       FileManager.default.fileExists(atPath: destination.path) {
                        for name in ["User.ini", "UnrealTournament.ini"] {
                            let existing = destination.appendingPathComponent(name)
                            if let data = try? Data(contentsOf: existing) {
                                mutableConfigurations[name] = data
                            }
                        }
                    }
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: item, to: destination)
                    for (name, data) in mutableConfigurations {
                        try data.write(to: destination.appendingPathComponent(name), options: .atomic)
                    }
                }
                FileManager.default.createFile(atPath: marker.path, contents: Data())
            }
            // Keep this resource check independent of the data marker: older
            // markers may predate the Frucore shader library being bundled.
            let bundledShader = bundledData.appendingPathComponent("System/default.metallib")
            let supportSystem = supportRoot.appendingPathComponent("System", isDirectory: true)
            let supportShader = supportSystem.appendingPathComponent("default.metallib")
            if FileManager.default.fileExists(atPath: bundledShader.path) &&
                !FileManager.default.fileExists(atPath: supportShader.path) {
                try FileManager.default.createDirectory(at: supportSystem, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: bundledShader, to: supportShader)
            }
            // Preserve the desktop Contents/MacOS + Contents/Resources
            // relationship for Frucore paths that resolve one level above
            // System rather than through the current directory.
            let supportRootShader = supportRoot.appendingPathComponent("default.metallib")
            if FileManager.default.fileExists(atPath: bundledShader.path) &&
                !FileManager.default.fileExists(atPath: supportRootShader.path) {
                try FileManager.default.copyItem(at: bundledShader, to: supportRootShader)
            }
            // v469e keeps its English .int resources in SystemLocalized on
            // macOS. New packages stage them in UT99Data/System, but existing
            // installations may already carry the v2 marker. Backfill only
            // missing localization files so original UWindow captions stop
            // exposing raw <int?...> keys without replacing user data.
            let bundledSystem = bundledData.appendingPathComponent("System", isDirectory: true)
            let embeddedLocalization = try FileManager.default.contentsOfDirectory(
                at: bundledSystem,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension.lowercased() == "int" }
            try FileManager.default.createDirectory(at: supportSystem, withIntermediateDirectories: true)
            var installedLocalizationCount = 0
            for source in embeddedLocalization {
                let destination = supportSystem.appendingPathComponent(source.lastPathComponent)
                guard !FileManager.default.fileExists(atPath: destination.path) else { continue }
                try FileManager.default.copyItem(at: source, to: destination)
                installedLocalizationCount += 1
            }
            if installedLocalizationCount > 0 {
                NSLog("UT99 bundled localization backfilled files=%lu", installedLocalizationCount)
            }
            // The transformed macOS v469e engine creates LadderFonts from the
            // three open desktop fonts shipped with that build. The Windows
            // patch supplies the UTX packages but not these TTF resources.
            // Backfill them independently of the old v2 data marker so an
            // existing installation is repaired without replacing game data.
            if let bundledFonts = Bundle.main.resourceURL?
                .appendingPathComponent("UT99FontSupport", isDirectory: true),
               FileManager.default.fileExists(atPath: bundledFonts.path) {
                let supportFonts = supportSystem.appendingPathComponent("Fonts", isDirectory: true)
                try FileManager.default.createDirectory(at: supportFonts, withIntermediateDirectories: true)
                var installedFontCount = 0
                for source in try FileManager.default.contentsOfDirectory(
                    at: bundledFonts,
                    includingPropertiesForKeys: nil
                ).filter({ $0.pathExtension.lowercased() == "ttf" }) {
                    let destination = supportFonts.appendingPathComponent(source.lastPathComponent)
                    if FileManager.default.fileExists(atPath: destination.path),
                       FileManager.default.contentsEqual(atPath: source.path, andPath: destination.path) {
                        continue
                    }
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: source, to: destination)
                    installedFontCount += 1
                }
                NSLog("UT99 bundled font support backfilled files=%lu", installedFontCount)
            }
        } catch {
            NSLog("UT99 bundled data preparation failed: %@", error.localizedDescription)
        }
    }

    private func prepareBundledRuntimeShader() {
        guard let bundledShader = Bundle.main.url(forResource: "default", withExtension: "metallib") else {
            NSLog("UT99 bundled runtime shader is missing")
            return
        }
        let fileManager = FileManager.default
        let supportRoot = dataSupportRoot()
        let systemRoot = supportRoot.appendingPathComponent(UT99RuntimeSupport.systemDirectoryName, isDirectory: true)
        do {
            try fileManager.createDirectory(at: systemRoot, withIntermediateDirectories: true)
            for destination in [
                supportRoot.appendingPathComponent("default.metallib"),
                systemRoot.appendingPathComponent("default.metallib")
            ] {
                if fileManager.fileExists(atPath: destination.path),
                   fileManager.contentsEqual(atPath: bundledShader.path, andPath: destination.path) {
                    continue
                }
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: bundledShader, to: destination)
            }
        } catch {
            NSLog("UT99 bundled runtime shader staging failed: %@", error.localizedDescription)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backdropLayer.frame = view.bounds
        // Rotation and SDL fullscreen negotiation can reorder the renderer
        // window after the initial attachment. Reassert the host owner when
        // UIKit settles a new scene layout.
        presentSDLWindowIfAvailable()
    }

    private func presentImportProgress() {
        releaseGameplayInputs()
        touchOverlay.isUserInteractionEnabled = false
        gameSurfaceInputView.isUserInteractionEnabled = false

        let scrim = UIView()
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.58)
        scrim.translatesAutoresizingMaskIntoConstraints = false
        scrim.accessibilityViewIsModal = true
        view.addSubview(scrim)

        let card = UIView()
        card.backgroundColor = UIColor(red: 0.045, green: 0.06, blue: 0.095, alpha: 0.98)
        card.layer.cornerRadius = 22
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 0.32).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        scrim.addSubview(card)

        let eyebrow = UILabel()
        eyebrow.text = "GAME DATA"
        eyebrow.textColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 1)
        eyebrow.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        eyebrow.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(eyebrow)

        let title = UILabel()
        title.text = "Preparing Unreal Tournament"
        title.textColor = .white
        title.font = .systemFont(ofSize: 23, weight: .bold)
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.8
        title.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(title)

        let phase = UILabel()
        phase.text = "Discovering content…"
        phase.textColor = UIColor(white: 0.84, alpha: 1)
        phase.font = .systemFont(ofSize: 15, weight: .semibold)
        phase.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(phase)

        let file = UILabel()
        file.text = "Checking the selected pack"
        file.textColor = UIColor(white: 0.62, alpha: 1)
        file.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        file.lineBreakMode = .byTruncatingMiddle
        file.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(file)

        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progressTintColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 1)
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.14)
        progressView.progress = 0
        progressView.isHidden = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(progressView)

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 1)
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(spinner)

        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel import", for: .normal)
        cancel.setTitleColor(.white, for: .normal)
        cancel.setTitleColor(UIColor(white: 0.45, alpha: 1), for: .disabled)
        cancel.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        cancel.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        cancel.layer.cornerRadius = 11
        cancel.accessibilityLabel = "Cancel game data import"
        cancel.addTarget(self, action: #selector(cancelDataImport), for: .touchUpInside)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cancel)

        let preferredCardWidth = card.widthAnchor.constraint(equalToConstant: 500)
        preferredCardWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            scrim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrim.topAnchor.constraint(equalTo: view.topAnchor),
            scrim.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            card.centerXAnchor.constraint(equalTo: scrim.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: scrim.centerYAnchor),
            preferredCardWidth,
            card.widthAnchor.constraint(lessThanOrEqualTo: scrim.safeAreaLayoutGuide.widthAnchor, constant: -48),
            eyebrow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            eyebrow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
            eyebrow.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            title.leadingAnchor.constraint(equalTo: eyebrow.leadingAnchor),
            title.trailingAnchor.constraint(equalTo: eyebrow.trailingAnchor),
            title.topAnchor.constraint(equalTo: eyebrow.bottomAnchor, constant: 8),
            phase.leadingAnchor.constraint(equalTo: eyebrow.leadingAnchor),
            phase.trailingAnchor.constraint(equalTo: eyebrow.trailingAnchor),
            phase.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 24),
            file.leadingAnchor.constraint(equalTo: eyebrow.leadingAnchor),
            file.trailingAnchor.constraint(equalTo: eyebrow.trailingAnchor),
            file.topAnchor.constraint(equalTo: phase.bottomAnchor, constant: 7),
            progressView.leadingAnchor.constraint(equalTo: eyebrow.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: eyebrow.trailingAnchor),
            progressView.topAnchor.constraint(equalTo: file.bottomAnchor, constant: 18),
            spinner.leadingAnchor.constraint(equalTo: eyebrow.leadingAnchor),
            spinner.centerYAnchor.constraint(equalTo: progressView.centerYAnchor),
            cancel.trailingAnchor.constraint(equalTo: eyebrow.trailingAnchor),
            cancel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 24),
            cancel.widthAnchor.constraint(equalToConstant: 142),
            cancel.heightAnchor.constraint(equalToConstant: 42),
            cancel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24)
        ])

        importProgressPanel = scrim
        importPhaseLabel = phase
        importFileLabel = file
        importProgressView = progressView
        importSpinner = spinner
        importCancelButton = cancel
        view.bringSubviewToFront(scrim)
        UIAccessibility.post(notification: .screenChanged, argument: title)
    }

    private func applyImportProgress(_ update: UT99DataImporter.Update) {
        guard importProgressPanel != nil else { return }
        let phaseText: String
        switch update.phase {
        case .discovering: phaseText = "Discovering content…"
        case .extracting: phaseText = "Extracting \(update.completedFiles) of \(update.totalFiles)"
        case .copying: phaseText = "Validating \(update.completedFiles) of \(update.totalFiles)"
        case .installing: phaseText = "Installing verified data…"
        }
        importPhaseLabel?.text = phaseText
        importFileLabel?.text = update.currentFile
        importProgressView?.isHidden = update.totalFiles == 0
        importProgressView?.setProgress(update.fractionCompleted, animated: true)
        if update.totalFiles == 0 {
            importSpinner?.startAnimating()
        } else {
            importSpinner?.stopAnimating()
        }
        importCancelButton?.isEnabled = update.canCancel
        importCancelButton?.accessibilityHint = update.canCancel
            ? "Stops before verified data is installed"
            : "Installation is completing atomically"
    }

    @objc private func cancelDataImport() {
        guard let activeImportCancellation, !activeImportCancellation.isCancelled else { return }
        gameDataDownload?.cancel()
        guard activeImportCancellation.cancel() else {
            importCancelButton?.isEnabled = false
            importPhaseLabel?.text = "Installing verified data…"
            importFileLabel?.text = "The atomic install is completing"
            return
        }
        importCancelButton?.isEnabled = false
        importPhaseLabel?.text = "Cancelling safely…"
        importFileLabel?.text = "Finishing the current file; installed data is unchanged"
        statusLabel.text = "Cancelling game-data import"
    }

    private func finishDataImport(
        _ result: Result<Int, Swift.Error>,
        returnState: HostState,
        cancellation: UT99ImportCancellation
    ) {
        guard activeImportCancellation === cancellation else { return }
        activeImportCancellation = nil
        gameDataDownloadProgressTimer?.invalidate()
        gameDataDownloadProgressTimer = nil
        gameDataDownload = nil
        if let workspace = gameDataAcquisitionWorkspace {
            try? FileManager.default.removeItem(at: workspace)
            gameDataAcquisitionWorkspace = nil
        }
        importProgressPanel?.removeFromSuperview()
        importProgressPanel = nil
        touchOverlay.isUserInteractionEnabled = true
        switch result {
        case let .success(imported):
            statusLabel.text = "Imported and verified \(imported) UT99 content files"
            transition(to: .ready, reason: "background transactional data import committed")
            if !CommandLine.arguments.dropFirst().contains(where: { $0.hasPrefix("-UT99") }) {
                waitForLandscapeAndAutoStart(attempt: 0)
            }
        case let .failure(error):
            if error is UT99ImportCancelled {
                statusLabel.text = error.localizedDescription
                transition(to: returnState, reason: "data import cancelled before commit")
            } else {
                statusLabel.text = "Import failed: \(error.localizedDescription)"
                transition(to: returnState, reason: "data import rejected; installed data unchanged")
                NSLog("UT99 data import failed: %@", error.localizedDescription)
            }
        }
    }

    private func runImportProgressUISmokeTest() {
        let cancellation = UT99ImportCancellation()
        activeImportCancellation = cancellation
        transition(to: .validatingData, reason: "import progress UI smoke")
        presentImportProgress()
        applyImportProgress(.init(
            phase: .copying,
            currentFile: "Maps/DM-Deck16][.unr",
            completedFiles: 132,
            totalFiles: 283
        ))
        statusLabel.text = "Import progress UI smoke active"
    }

    @objc private func importData() {
        guard hostState != .running && hostState != .startingEngine && hostState != .pausedBySystem else {
            presentMenuInfo(
                title: "Game Data",
                message: "Import is disabled while the original engine is active. Relaunch the host, then use Repair or Reimport before starting the game."
            )
            return
        }
        guard activeImportCancellation == nil else {
            statusLabel.text = "A game-data import is already in progress"
            return
        }
        documentPickerPurpose = .gameData
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder, .zip], asCopy: false)
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let purpose = documentPickerPurpose
        documentPickerPurpose = nil
        if purpose == .touchProfile {
            finishTouchProfileImport(from: url)
            return
        }
        guard url.startAccessingSecurityScopedResource() else {
            statusLabel.text = "Cannot access selected data folder"
            return
        }
        let returnState = hostState
        let cancellation = UT99ImportCancellation()
        activeImportCancellation = cancellation
        transition(to: .validatingData, reason: "selected import opened")
        presentImportProgress()
        let progress: UT99DataImporter.ProgressHandler = { [weak self] update in
            DispatchQueue.main.async { self?.applyImportProgress(update) }
        }
        importQueue.async { [weak self] in
            defer { url.stopAccessingSecurityScopedResource() }
            guard let self else { return }
            let result: Result<Int, Swift.Error>
            do {
                let imported: Int
                if url.pathExtension.lowercased() == "zip" {
                    imported = try self.importContentArchive(url, cancellation: cancellation, progress: progress)
                } else {
                    imported = try self.importContentFolder(url, cancellation: cancellation, progress: progress)
                }
                result = .success(imported)
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async { [weak self] in
                self?.finishDataImport(result, returnState: returnState, cancellation: cancellation)
            }
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        let purpose = documentPickerPurpose
        documentPickerPurpose = nil
        statusLabel.text = purpose == .touchProfile
            ? "Touch layout import cancelled"
            : "Data import cancelled; installed data was unchanged"
    }

    private func importContentArchive(
        _ archive: URL,
        cancellation: UT99ImportCancellation,
        progress: @escaping UT99DataImporter.ProgressHandler
    ) throws -> Int {
        let supportRoot = dataSupportRoot()
        let extraction = supportRoot.appendingPathComponent(".zip-extract-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: extraction) }
        _ = try UT99ZipArchive.extract(
            archive,
            to: extraction,
            cancellationRequested: { cancellation.isCancelled },
            progress: { file, completed, total in
                progress(.init(phase: .extracting, currentFile: file,
                               completedFiles: completed, totalFiles: total))
            }
        )
        return try importContentFolder(extraction, cancellation: cancellation, progress: progress)
    }

    /// Import user-owned content without replacing the modern bundled System
    /// tree. The staging directory is completed before any files are merged
    /// into Application Support, so a failed import cannot leave a half-pack.
    private func importContentFolder(
        _ source: URL,
        cancellation: UT99ImportCancellation,
        progress: @escaping UT99DataImporter.ProgressHandler
    ) throws -> Int {
        try UT99DataImporter.importFolder(
            source,
            to: dataSupportRoot(),
            cancellation: cancellation,
            progress: progress
        )
    }

    private func dataSupportRoot() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Unreal Tournament", isDirectory: true)
    }

    func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = hostMetalCommandQueue?.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            if !hostMetalPresentationRecorded {
                NSLog("UT99 host Metal frame deferred drawable=%@ descriptor=%@ queue=%@",
                      view.currentDrawable == nil ? "nil" : "ready",
                      view.currentRenderPassDescriptor == nil ? "nil" : "ready",
                      hostMetalCommandQueue == nil ? "nil" : "ready")
            }
            return
        }

        encoder.label = "UT99Host shell clear"
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { [weak self, weak view] buffer in
            DispatchQueue.main.async {
                guard let self, !self.hostMetalPresentationRecorded else { return }
                self.hostMetalPresentationRecorded = true
                let size = view?.drawableSize ?? .zero
                let passed = buffer.status == .completed
                let line = "presented=\(passed) status=\(buffer.status.rawValue) drawable=\(Int(size.width))x\(Int(size.height)) device=\(view?.device?.name ?? "unavailable")\n"
                let resultURL = self.dataSupportRoot().appendingPathComponent("UT99-host-metal-smoke.log")
                try? Data(line.utf8).write(to: resultURL, options: .atomic)
                NSLog("UT99 host Metal first frame %@", line.trimmingCharacters(in: .whitespacesAndNewlines))
                if self.pendingG2DiagnosticsExport {
                    self.pendingG2DiagnosticsExport = false
                    self.finishG2SmokeAfterMetal(metalPresented: passed)
                }
            }
        }
        commandBuffer.commit()
    }

    private func finishG2SmokeAfterMetal(metalPresented: Bool) {
        runDiagnosticsExportSmokeTest()
        let supportRoot = dataSupportRoot()
        let importText = (try? String(
            contentsOf: supportRoot.appendingPathComponent("UT99-import-transaction-smoke.log"),
            encoding: .utf8
        )) ?? ""
        let diagnosticsText = (try? String(
            contentsOf: supportRoot.appendingPathComponent("UT99-diagnostics-smoke.log"),
            encoding: .utf8
        )) ?? ""
        let importPassed = importText.contains("passed=true")
        let diagnosticsPassed = diagnosticsText.contains("exported=true")
        let passed = metalPresented && importPassed && diagnosticsPassed
        let runIDPrefix = "-UT99G2RunID="
        let runID = CommandLine.arguments
            .first(where: { $0.hasPrefix(runIDPrefix) })
            .map { String($0.dropFirst(runIDPrefix.count)) }
            .flatMap { UUID(uuidString: $0)?.uuidString.lowercased() }
            ?? "unspecified"
        let line = "passed=\(passed) metal=\(metalPresented) importer=\(importPassed) diagnostics=\(diagnosticsPassed) standardTouch=true runID=\(runID)\n"
        try? Data(line.utf8).write(
            to: supportRoot.appendingPathComponent("UT99-g2-smoke.log"),
            options: .atomic
        )
        NSLog("UT99 G2 host smoke finished %@", line.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
