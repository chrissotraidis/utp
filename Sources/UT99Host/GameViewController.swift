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
    /// `pressed == nil` is motion, otherwise it is the left-button edge.
    var onPointer: ((CGPoint, Bool?) -> Void)?
    private weak var trackedTouch: UITouch?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = false
        accessibilityIdentifier = "ut99.gameSurfacePointer"

        // iPad trackpads and mice deliver an indirect-pointer tap rather than
        // the direct UITouch sequence used by a finger. Convert that click to
        // the same absolute SDL left-button pair so stock UWindow controls are
        // usable with both input classes.
        let pointerTap = UITapGestureRecognizer(target: self, action: #selector(pointerTapped(_:)))
        pointerTap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)]
        addGestureRecognizer(pointerTap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard trackedTouch == nil,
              let touch = touches.first(where: { $0.type != .indirectPointer }) else { return }
        trackedTouch = touch
        onPointer?(touch.location(in: self), true)
    }

    @objc private func pointerTapped(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let location = gesture.location(in: self)
        onPointer?(location, true)
        onPointer?(location, false)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let trackedTouch, touches.contains(trackedTouch) else { return }
        onPointer?(trackedTouch.location(in: self), nil)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTrackedTouch(in: touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTrackedTouch(in: touches)
    }

    private func finishTrackedTouch(in touches: Set<UITouch>) {
        guard let trackedTouch, touches.contains(trackedTouch) else { return }
        onPointer?(trackedTouch.location(in: self), false)
        self.trackedTouch = nil
    }

    func releasePointer() {
        guard let trackedTouch else { return }
        onPointer?(trackedTouch.location(in: self), false)
        self.trackedTouch = nil
    }
}

final class GameViewController: UIViewController, MTKViewDelegate, UIDocumentPickerDelegate {
    private let gameView = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    private let gameSurfaceInputView = UT99GameSurfaceInputView()
    private lazy var hostMetalCommandQueue = gameView.device?.makeCommandQueue()
    private var hostMetalPresentationRecorded = false
    private var pendingG2DiagnosticsExport = false
    private let statusLabel = UILabel()
    private let menuButton = UT99HostMenuButton(type: .system)
    private var touchSettingsPanel: UIView?
    private weak var touchOpacitySlider: UISlider?
    private weak var touchScaleSlider: UISlider?
    private let engineBridge = UT99EngineBridge()
    private let backdropLayer = CAGradientLayer()
    private let touchOverlay = GoldenPadTouchOverlay()
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
        becomeFirstResponder()
        presentSDLWindowIfAvailable()
        presentRecoveryPromptIfNeeded()
        // The host shell has its own bounded Metal presentation requirement
        // before the transformed engine takes ownership of the SDL window.
        // Request one frame after layout so currentDrawable is available.
        gameView.setNeedsDisplay()
        presentRequestedMenuSmokeStateIfNeeded()
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
        for press in presses {
            if let key = press.key {
                engineBridge.publishHardwareKey(usage: key.keyCode.rawValue, pressed: true)
            }
        }
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        NSLog("UT99KeyboardBridge pressesEnded count=%lu", presses.count)
        for press in presses {
            if let key = press.key {
                engineBridge.publishHardwareKey(usage: key.keyCode.rawValue, pressed: false)
            }
        }
        super.pressesEnded(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        NSLog("UT99KeyboardBridge pressesCancelled count=%lu", presses.count)
        for press in presses {
            if let key = press.key {
                engineBridge.publishHardwareKey(usage: key.keyCode.rawValue, pressed: false)
            }
        }
        super.pressesCancelled(presses, with: event)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
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
        gameSurfaceInputView.onPointer = { [weak self] location, pressed in
            self?.engineBridge.publishGameSurfacePointer(location: location, pressed: pressed)
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
            NSLog("UT99 touch action=%@ pressed=%@", action.rawValue, pressed ? "true" : "false")
            self?.engineBridge.publishTouchAction(action, pressed: pressed)
        }
        touchOverlay.onMove = { [weak self] value, active in
            self?.engineBridge.publishTouchMove(value, active: active)
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

        if let recoveredSession {
            transition(to: .crashed, reason: "previous active session marker recovered")
            let mode = recoveredSession.safeMode ? "safe mode" : "normal mode"
            statusLabel.text = "Previous \(mode) session ended unexpectedly · recovery available"
            writeRecoverySmokeResultIfRequested(recoveredSession)
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
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.changesSelectionAsPrimaryAction = false
        menuButton.menu = buildHostMenu()
        menuButton.addTarget(self, action: #selector(hostMenuWillOpen), for: .menuActionTriggered)
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
            menuButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
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
        if g2SmokeRequested {
            pendingG2DiagnosticsExport = true
            NSLog("UT99 G2 host smoke started importer=true diagnostics=true metal=true standardTouch=true")
        }
        if CommandLine.arguments.contains("-UT99AutoStart") {
            waitForLandscapeAndAutoStart(attempt: 0)
        }
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
            DispatchQueue.main.async { self?.toggleMenu() }
        })
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
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
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            self?.configureController(controller)
            self?.updateTouchVisibility()
            NSLog("UT99 controller connected: %@", controller.vendorName ?? "unknown")
        })
        appleIntegrationObservers.append(center.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] note in
            let controller = note.object as? GCController
            self?.engineBridge.releaseMovementKeys()
            self?.engineBridge.publishTouchLook(.zero, active: false)
            NSLog("UT99 controller disconnected: %@", controller?.vendorName ?? "unknown")
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
            self?.touchOverlay.isUserInteractionEnabled = true
            self?.gameSurfaceInputView.isUserInteractionEnabled = self?.hostState == .running
            self?.activateGameAudioSession()
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
            // SDL may reclaim key status while rotating or rebuilding its
            // UIKit window. Wait for its layout pass, then restore host input.
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
        for controller in GCController.controllers() {
            configureController(controller)
        }
        updateTouchVisibility()
        GCController.startWirelessControllerDiscovery { NSLog("UT99 controller discovery finished") }
        activateGameAudioSession()
    }

    private func updateTouchVisibility() {
        // The simulator can expose a virtual controller profile even when no
        // hardware is attached. Keep touch controls visible in that case;
        // only a real attached extended gamepad should take over the screen.
        let controllerConnected = GCController.controllers().contains {
            $0.isAttachedToDevice && $0.extendedGamepad != nil
        }
        let engineActive = hostState == .startingEngine || hostState == .running || hostState == .pausedBySystem
        let shouldHide = !engineActive || (controllerConnected && UT99TouchConfiguration.load().autoHideForController)
        if shouldHide {
            releaseGameplayInputs()
        }
        touchOverlay.isHidden = shouldHide
        NSLog("UT99 touch overlay %@ controller=%@ autoHide=%@",
              shouldHide ? "hidden" : "visible",
              controllerConnected ? "true" : "false",
              UT99TouchConfiguration.load().autoHideForController ? "true" : "false")
    }

    private func releaseGameplayInputs() {
        gameSurfaceInputView.releasePointer()
        touchOverlay.releaseActiveInputs()
        engineBridge.releaseMovementKeys()
        engineBridge.publishTouchLook(.zero, active: false)
    }

    private func configureController(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        pad.valueChangedHandler = { [weak self] _, element in
            guard let self else { return }
            if element === pad.leftThumbstick {
                let x = CGFloat(pad.leftThumbstick.xAxis.value)
                let y = CGFloat(-pad.leftThumbstick.yAxis.value)
                self.engineBridge.publishTouchMove(CGPoint(x: x, y: y), active: max(abs(x), abs(y)) > 0.08)
            } else if element === pad.dpad {
                // Preserve the physical D-pad path instead of reading the
                // unrelated stick axes when a D-pad element changes.
                let stickX = CGFloat(pad.leftThumbstick.xAxis.value)
                let stickY = CGFloat(-pad.leftThumbstick.yAxis.value)
                let stickActive = max(abs(stickX), abs(stickY)) > 0.08
                let x = stickActive ? stickX : CGFloat(pad.dpad.xAxis.value)
                let y = stickActive ? stickY : CGFloat(-pad.dpad.yAxis.value)
                self.engineBridge.publishTouchMove(CGPoint(x: x, y: y), active: max(abs(x), abs(y)) > 0.08)
            } else if element === pad.rightThumbstick {
                let x = CGFloat(pad.rightThumbstick.xAxis.value)
                let y = CGFloat(-pad.rightThumbstick.yAxis.value)
                self.engineBridge.publishTouchLook(CGPoint(x: x, y: y), active: max(abs(x), abs(y)) > 0.08)
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
        // Keep the platform/menu button for the host surface, while the
        // controller's secondary options button opens the original Unreal
        // game menu through the same Escape semantic as touch MENU.
        pad.buttonOptions?.valueChangedHandler = { [weak self] _, _, pressed in
            self?.engineBridge.publishTouchAction(.pause, pressed: pressed)
        }
        pad.buttonMenu.valueChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.toggleMenu() }
        }
    }

    private func bind(_ input: GCControllerButtonInput,
                      to action: GoldenPadTouchOverlay.Action,
        controller: GCController) {
        input.valueChangedHandler = { [weak self] _, _, pressed in
            self?.engineBridge.publishTouchAction(action, pressed: pressed)
        }
    }

    private func activateGameAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .gameChat, options: [.mixWithOthers, .allowBluetoothHFP])
            try session.setActive(true, options: [])
            NSLog("UT99 audio session active route=%@", session.currentRoute.outputs.map(\.portType.rawValue).joined(separator: ","))
        } catch {
            NSLog("UT99 audio session unavailable: %@", error.localizedDescription)
        }
    }

    @objc private func hostMenuWillOpen() {
        releaseGameplayInputs()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        eyebrow.text = "UT99 · NATIVE APPLE CLIENT"
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
           FileManager.default.fileExists(atPath: bundledData.appendingPathComponent("Maps").path) {
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
        return UT99DataImportTransaction.contentDirectoryNames.allSatisfy { name in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(
                atPath: root.appendingPathComponent(name, isDirectory: true).path,
                isDirectory: &isDirectory
            ) && isDirectory.boolValue
        }
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
            onboardingDetailLabel?.text = "UT99Apple needs the original GOTY maps, music, sounds, and textures. Download the verified OldUnreal release or import files you already have."
            onboardingPrimaryButton?.setTitle("GET GAME DATA", for: .normal)
            onboardingSecondaryButton?.setTitle("IMPORT FILES", for: .normal)
            onboardingTertiaryButton?.setTitle("Why game data is separate", for: .normal)
            onboardingPrimaryButton?.accessibilityHint = "Explains the approved source and asks before downloading"
            onboardingSecondaryButton?.accessibilityHint = "Selects an existing Unreal Tournament folder or ZIP from Files"
        }
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
        let message = "OldUnreal's approved installer sources publish the original Unreal Tournament GOTY disc image. The download is 620 MiB and temporary setup may use about 2 GB. UT99Apple verifies the exact SHA-256, extracts only maps/music/sounds/textures, and deletes the image after installation. The Epic Games Terms of Service apply."
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
        let download = UT99GameDataDownload()
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
                    self?.extractAndInstallAuthorizedGameData(imageURL, workspace: workspace, cancellation: cancellation)
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
        let total = progress?.totalUnitCount ?? UT99AuthorizedGameData.expectedISOBytes
        let fraction = total > 0 ? Float(received) / Float(total) : 0
        importProgressView?.setProgress(max(0, min(1, fraction)), animated: true)
        importPhaseLabel?.text = "Downloading \(Int(fraction * 100))%"
        importFileLabel?.text = "\(download.currentSourceHost) · \(received / 1_048_576) of \(UT99AuthorizedGameData.expectedISOBytes / 1_048_576) MiB"
    }

    private func extractAndInstallAuthorizedGameData(
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
            let result: Result<Int, Swift.Error>
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
                let imported = try UT99DataImporter.importFolder(
                    extracted,
                    to: self.dataSupportRoot(),
                    cancellation: cancellation
                ) { update in
                    DispatchQueue.main.async { [weak self] in self?.applyImportProgress(update) }
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
                self?.refreshHostMenu()
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

        let touchMenu = UIMenu(title: "Touch Controls", image: UIImage(systemName: "hand.draw"), children: [
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
            action("Export Diagnostic Log…", symbol: "square.and.arrow.up") { [weak self] in
                self?.exportDiagnostics()
            },
            action("Prepare Safe Mode", symbol: "shield") { [weak self] in
                self?.enableSafeMode()
            },
        ])

        return UIMenu(title: "UT99Apple", children: [
            primaryAction,
            unrealMenu,
            touchMenu,
            systemMenu,
            action("Multiplayer…", symbol: "network") { [weak self] in
                self?.showMultiplayerInfo()
            },
            dataMenu,
            diagnosticsMenu,
            action("About UT99Apple", symbol: "info.circle") { [weak self] in
                self?.showAboutInfo()
            },
        ])
    }

    private func refreshHostMenu() {
        menuButton.menu = buildHostMenu()
    }

    @objc private func toggleMenu() {
        NSLog("UT99 host menu fallback mainThread=%@", Thread.isMainThread ? "true" : "false")
        releaseGameplayInputs()

        let sheet = UIAlertController(title: "UT99Apple", message: nil, preferredStyle: .actionSheet)
        sheet.overrideUserInterfaceStyle = .dark
        sheet.addAction(UIAlertAction(title: "Resume Game", style: .cancel))
        sheet.addAction(UIAlertAction(title: "Unreal Tournament Menu", style: .default) { [weak self] _ in
            self?.engineBridge.publishTouchAction(.pause, pressed: true)
            self?.engineBridge.publishTouchAction(.pause, pressed: false)
        })
        sheet.addAction(UIAlertAction(title: "Touch Controls", style: .default) { [weak self] _ in
            self?.showTouchSettings()
        })
        sheet.addAction(UIAlertAction(title: "Arrange Controls", style: .default) { [weak self] _ in
            self?.editTouchLayout()
        })
        sheet.addAction(UIAlertAction(title: "Controls & Display", style: .default) { [weak self] _ in
            self?.showControlsInfo()
        })
        sheet.addAction(UIAlertAction(title: "Game Data & Saves", style: .default) { [weak self] _ in
            self?.showDataInfo()
        })
        sheet.addAction(UIAlertAction(title: "Multiplayer", style: .default) { [weak self] _ in
            self?.showMultiplayerInfo()
        })
        sheet.addAction(UIAlertAction(title: "About UT99Apple", style: .default) { [weak self] _ in
            self?.showAboutInfo()
        })
        presentActionSheet(sheet)
    }

    @objc private func showControlsInfo() {
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
        for value in [0.16, 0.22, 0.28, 0.36] {
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
        title.text = "Touch Controls"
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

        let leftHanded = UISwitch()
        leftHanded.isOn = touchOverlay.touchConfiguration.leftHanded
        leftHanded.accessibilityLabel = "Left-handed layout"
        leftHanded.addTarget(self, action: #selector(touchHandednessChanged(_:)), for: .valueChanged)

        let hideForController = UISwitch()
        hideForController.isOn = touchOverlay.touchConfiguration.autoHideForController
        hideForController.accessibilityLabel = "Hide touch controls when controller connected"
        hideForController.addTarget(self, action: #selector(touchAutoHideChanged(_:)), for: .valueChanged)

        let edit = touchSettingsButton("Arrange Controls", symbol: "move.3d", selector: #selector(editTouchLayoutFromSettings))
        let saved = touchSettingsButton("Saved Layouts", symbol: "square.and.arrow.down", selector: #selector(showNamedTouchProfilesFromSettings))
        let reset = touchSettingsButton("Restore Default Layout", symbol: "arrow.counterclockwise", selector: #selector(resetTouchLayoutFromSettings))
        reset.backgroundColor = UIColor(white: 0.18, alpha: 0.88)

        let stack = UIStackView(arrangedSubviews: [
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
            : min(390, max(300, view.bounds.height * 0.56))
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
        updateTouchVisibility()
        refreshHostMenu()
    }

    @objc private func touchOpacityChanged(_ sender: UISlider) {
        touchOverlay.setTouchOpacity(CGFloat(sender.value))
    }

    @objc private func touchScaleChanged(_ sender: UISlider) {
        touchOverlay.setGlobalScale(CGFloat(sender.value))
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
        guard isGameDataReady() else {
            transition(to: .needsData, reason: "multiplayer requested before game-data setup")
            statusLabel.text = "Set up game data before playing online"
            showAuthorizedGameDataOptions()
            return
        }
        let network = networkMonitor.currentPath.status == .satisfied ? "Online" : "Network unavailable"
        let engineActive = hostState == .startingEngine || hostState == .running || hostState == .pausedBySystem
        let message = engineActive
            ? "\(network). Open Unreal Tournament's Multiplayer menu to browse or join servers with the original v469 network stack."
            : "\(network). Enter a hostname or unreal:// address to join directly with the original v469 network stack."
        let alert = UIAlertController(title: "Multiplayer", message: message, preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .dark

        if engineActive {
            alert.addAction(UIAlertAction(title: "Open Unreal Tournament Menu", style: .default) { [weak self] _ in
                self?.engineBridge.publishTouchAction(.pause, pressed: true)
                self?.engineBridge.publishTouchAction(.pause, pressed: false)
            })
        } else {
            alert.addTextField { field in
                field.placeholder = "unreal://server.example:7777/"
                field.text = UserDefaults.standard.string(forKey: "ut99.multiplayer.lastServerURL")
                field.keyboardType = .URL
                field.textContentType = .URL
                field.autocapitalizationType = .none
                field.autocorrectionType = .no
                field.clearButtonMode = .whileEditing
                field.accessibilityLabel = "Server address"
            }
            alert.addAction(UIAlertAction(title: "Join Server", style: .default) { [weak self, weak alert] _ in
                self?.connectToServer(alert?.textFields?.first?.text ?? "")
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
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
            title: "UT99Apple",
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
        touchOverlay.isHidden = false
        touchOverlay.isUserInteractionEnabled = true
        touchOverlay.setLayoutEditing(true)
        statusLabel.text = "Drag controls; pinch to resize; tap DONE to save"
    }

    @objc private func testTouchLayout() {
        touchOverlay.isHidden = false
        touchOverlay.isUserInteractionEnabled = true
        touchOverlay.setLayoutTesting(true)
        statusLabel.text = "Live test · movement, look, and actions are active · tap DONE to finish"
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
    /// not replace UIKit taps: it exercises the same menu construction and
    /// persisted profile application when simulator pointer injection is
    /// unavailable, while leaving the real button/action-sheet path intact.
    private func runMenuSmokeTest() {
        toggleMenu()
        let menuConstructed = menuButton.menu != nil || presentedViewController is UIAlertController
        let originalProfile = touchOverlay.touchProfile
        let profile = GoldenPadTouchOverlay.TouchProfile.compact
        touchOverlay.applyTouchProfile(profile)
        statusLabel.text = "Touch layout: \(profile.title)"
        let persisted = UserDefaults.standard.string(forKey: "ut99.touch.profile") == profile.rawValue
        NSLog("UT99 menu smoke menuConstructed=%@ profile=%@ persisted=%@",
              menuConstructed ? "true" : "false", profile.rawValue, persisted ? "true" : "false")
        touchOverlay.applyTouchProfile(originalProfile)
        presentedViewController?.dismiss(animated: false)
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
        let menuConstructed = menuButton.menu != nil
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
        var output = "UT99Apple diagnostics\nGenerated: \(ISO8601DateFormatter().string(from: Date()))\nPrivacy: paths and common secret fields are redacted; review server addresses before sharing.\n\n\(diagnosticsSummary())\n"
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
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("UT99Apple-Diagnostics-\(Int(Date().timeIntervalSince1970)).zip")
        do {
            try writeDiagnosticsArchive(to: zipURL)
            statusLabel.text = "Diagnostics exported"
            let share = UIActivityViewController(activityItems: [zipURL], applicationActivities: nil)
            if let popover = share.popoverPresentationController {
                popover.sourceView = menuButton
                popover.sourceRect = menuButton.bounds
            }
            present(share, animated: true)
        } catch {
            presentMenuInfo(title: "Diagnostics", message: "Export failed: \(error.localizedDescription)")
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
        ["ut99.input.lookSensitivity", "ut99.input.invertLookY", "ut99.graphics.safeTextures", "ut99.graphics.vsync", "ut99.audio.enabled", "ut99.graphics.frameCap", "ut99.touch.opacity", "ut99.touch.scale", "ut99.touch.profile", "ut99.touch.layout", "ut99.touch.layout.v1", UT99TouchConfiguration.defaultsKey, UT99TouchProfileStore.defaultsKey].forEach { defaults.removeObject(forKey: $0) }
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
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "ut99.graphics.safeTextures")
        defaults.set(true, forKey: "ut99.graphics.vsync")
        defaults.set(false, forKey: "ut99.audio.enabled")
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
        transition(to: .startingEngine, reason: connectURL == nil ? "local engine launch" : "direct connect launch")
        prepareEngineSurfaceOverlay()
        if CommandLine.arguments.contains("-UT99TouchSettingsPanelSmokeTest"),
           !hasPresentedMenuSmokeState {
            hasPresentedMenuSmokeState = true
            showTouchSettings()
        }
        let result = engineBridge.startOriginalEntry(connectURL: connectURL) { [weak self] exitCode in
            self?.engineDidExit(exitCode)
        }
        statusLabel.text = result.statusText
        switch result {
        case .started:
            transition(to: .running, reason: "original entry started")
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
            subview !== menuButton {
            subview.isHidden = true
        }
        view.isUserInteractionEnabled = true
        gameSurfaceInputView.isHidden = false
        gameSurfaceInputView.isUserInteractionEnabled = true
        touchOverlay.isUserInteractionEnabled = true
        touchOverlay.isHidden = false
        view.bringSubviewToFront(gameSurfaceInputView)
        view.bringSubviewToFront(touchOverlay)
        view.bringSubviewToFront(menuButton)
        hostWindow.windowLevel = UIWindow.Level.normal + 1
        hostWindow.makeKeyAndVisible()
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
        let hostBounds = hostWindow.bounds
        // Match EctoPad's real composition: renderer fills landscape and
        // controls float above it. The old 4:3 island/control bay made the
        // original renderer appear detached and approximately half-size.
        if let engineView = engineWindow.rootViewController?.view {
            engineView.transform = .identity
            engineView.frame = hostBounds
            engineView.bounds = CGRect(origin: .zero, size: hostBounds.size)
            engineView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            engineView.setNeedsLayout()
            engineView.layoutIfNeeded()
            NSLog("UT99EngineBridge full-bleed renderer frame=%@ bounds=%@ scale=%.2f",
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
        for subview in view.subviews where subview !== gameView && subview !== touchOverlay &&
            subview !== menuButton {
            subview.isHidden = true
        }
        // SDL can recreate or reorder its window after the first scene
        // presentation. Reassert the host's interaction surface every time
        // the renderer is attached so visible controls remain real UIKit hit
        // targets rather than a screenshot-only overlay.
        view.isUserInteractionEnabled = true
        gameSurfaceInputView.isUserInteractionEnabled = true
        touchOverlay.isUserInteractionEnabled = true
        view.bringSubviewToFront(touchOverlay)
        view.bringSubviewToFront(menuButton)
        hostWindow.windowLevel = UIWindow.Level.normal + 1
        hostWindow.makeKeyAndVisible()
        hostWindow.rootViewController?.becomeFirstResponder()
        NSLog("UT99EngineBridge attached SDL window to active scene hostKey=%@ hostBounds=%@ engineBounds=%@ orientation=%ld",
              hostWindow.isKeyWindow ? "true" : "false",
              hostWindow.bounds.debugDescription, engineWindow.bounds.debugDescription,
              Int(scene.interfaceOrientation.rawValue))
    }

    private func prepareBundledData() {
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
            if !FileManager.default.fileExists(atPath: marker.path) {
                for item in try FileManager.default.contentsOfDirectory(at: bundledData, includingPropertiesForKeys: nil) {
                    let destination = supportRoot.appendingPathComponent(item.lastPathComponent)
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: item, to: destination)
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
        } catch {
            NSLog("UT99 bundled data preparation failed: %@", error.localizedDescription)
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
