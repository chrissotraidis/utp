import UIKit

/// An EctoPad/SunPad-style control face mapped to UT-specific actions.
///
/// EctoPad's strength is its legible physical-controller hierarchy: one solid
/// translucent face, one restrained white rim, one centered mark, and an
/// obvious pressed state. Avoid stacking a symbol and caption into a badge.
private final class UT99TouchActionButton: UIButton {
    enum Role {
        case primary, secondary, utility, dPad, start
    }

    private let markView = UIImageView()
    private let actionLabel = UILabel()
    private var accent = UIColor.white
    private var foreground = UIColor.white
    private var visualRole: Role = .secondary
    private var pressed = false
    private var editing = false
    var onAccessibilityActivate: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        isOpaque = false
        layer.cornerCurve = .continuous

        markView.contentMode = .scaleAspectFit
        markView.isUserInteractionEnabled = false
        addSubview(markView)
        actionLabel.textAlignment = .center
        actionLabel.adjustsFontSizeToFitWidth = true
        actionLabel.minimumScaleFactor = 0.72
        actionLabel.isUserInteractionEnabled = false
        addSubview(actionLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func accessibilityActivate() -> Bool {
        guard let onAccessibilityActivate else { return super.accessibilityActivate() }
        onAccessibilityActivate()
        return true
    }

    func configure(symbol: String, title: String, accent: UIColor, foreground: UIColor, role: Role) {
        self.accent = accent
        self.foreground = foreground
        self.visualRole = role
        if role == .dPad {
            markView.image = UIImage(
                systemName: symbol,
                withConfiguration: UIImage.SymbolConfiguration(weight: .bold)
            )
            actionLabel.text = nil
        } else {
            markView.image = nil
            actionLabel.text = title
        }
        setPressed(false)
    }

    func setPressed(_ pressed: Bool) {
        self.pressed = pressed
        applyAppearance()
    }

    func setEditing(_ editing: Bool) {
        self.editing = editing
        applyAppearance()
    }

    func setTitle(_ title: String) {
        guard visualRole != .dPad else { return }
        actionLabel.text = title
        accessibilityLabel = title
    }

    private func applyAppearance() {
        backgroundColor = pressed ? accent.withAlphaComponent(1.0) : accent
        markView.tintColor = foreground
        actionLabel.textColor = foreground
        layer.borderColor = editing
            ? UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 0.96).cgColor
            : UIColor.white.withAlphaComponent(pressed ? 0.68 : 0.36).cgColor
        layer.borderWidth = editing ? 3 : 2
        alpha = pressed ? 1 : 0.96
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        layer.cornerRadius = side / 2
        // The phone START/MENU surface is intentionally a wide EctoPad pill.
        // Its short side is below 54pt, but it must retain its caption; only
        // genuinely compact round controls collapse to an icon-only face.
        let compact = visualRole == .dPad
        let symbolSide = min(max(side * 0.34, 13), 22)
        markView.frame = CGRect(x: bounds.midX - symbolSide / 2,
                                y: bounds.midY - symbolSide / 2,
                                width: symbolSide,
                                height: symbolSide)
        actionLabel.font = .systemFont(ofSize: max(10, min(18, side * 0.22)), weight: .bold)
        actionLabel.frame = compact
            ? .zero
            : bounds.insetBy(dx: 6, dy: 4)
    }
}

/// UIKit adaptation of EctoPad's current SunPad controller layout.
///
/// The overlay owns touch tracking and publishes semantic actions. The engine
/// input adapter can consume these values without knowing where a control was
/// drawn. This keeps the host UI and the original engine boundary separate.
final class GoldenPadTouchOverlay: UIView, UIGestureRecognizerDelegate {
    enum TouchProfile: String {
        case standard
        /// Legacy import aliases. New preferences and exports use `standard`.
        case ectoPad
        case goldenPad
        case compact
        case highVisibility

        var canonical: TouchProfile {
            switch self {
            case .ectoPad, .goldenPad: .standard
            default: self
            }
        }

        var title: String {
            switch self {
            case .standard, .ectoPad: "Standard"
            case .goldenPad: "Legacy"
            case .compact: "Compact"
            case .highVisibility: "High visibility"
            }
        }

        var scale: CGFloat {
            switch self {
            case .standard, .ectoPad, .goldenPad: 1.0
            case .compact: 0.86
            case .highVisibility: 1.12
            }
        }

        var opacity: CGFloat {
            switch self {
            // EctoPad's source default is 0.82. Keeping the same composed
            // opacity prevents solid action faces from reading as opaque HUD
            // panels over a visually dense arena.
            case .standard, .ectoPad, .goldenPad: 0.82
            case .compact: 0.68
            case .highVisibility: 0.96
            }
        }
    }

    enum Action: String, CaseIterable {
        case primaryFire, leftPrimaryFire, alternateFire, jump, crouch
        case use, nextWeapon, previousWeapon, scoreboard, pause
    }

    var onAction: ((Action, Bool) -> Void)?
    var onMove: ((CGPoint, Bool) -> Void)?
    var onLook: ((CGPoint, Bool) -> Void)?

    private let movePad = UIView()
    private let moveRing = UIView()
    private let moveThumb = UIView()
    private let moveGlyph = UIImageView(image: UIImage(systemName: "figure.walk"))
    private let moveLabel = UILabel()
    private let lookPad = UIView()
    private let lookRing = UIView()
    private let lookThumb = UIView()
    private let lookGlyph = UIImageView(image: UIImage(systemName: "scope"))
    private let safeAreaGuide = UIView()
    private let weaponRail = UIView()
    private let weaponRailDivider = UIView()
    private var moveAnchor: CGPoint?
    private var lookAnchor: CGPoint?
    private var lookValue = CGPoint.zero
    private var lookDisplayLink: CADisplayLink?
    private var pointerLastLocation: CGPoint?
    private var accessibilityMovement = CGPoint.zero
    private var buttons: [Action: UT99TouchActionButton] = [:]
    private var activeActions = Set<Action>()
    private var menuInteractionActive = false
    private var placements: [String: UT99TouchPlacement] = [:]
    private let actionHaptic = UIImpactFeedbackGenerator(style: .light)
    private(set) var editingLayout = false
    private(set) var testingLayout = false
    private let layoutBanner = UILabel()
    private let layoutDoneButton = UIButton(type: .system)
    private let layoutSizeControls = UIStackView()
    private let layoutSizeLabel = UILabel()
    private let layoutSizeSlider = UISlider()
    private var selectedLayoutKey = "move"
    private var moveDiameter: CGFloat = 172
    private var lookDiameter: CGFloat = 156
    private static let layoutDefaultsKey = "ut99.touch.layout.v1"
    /// Captured from the accepted physical iPhone 14 layout on 2026-08-25.
    /// These are device-class defaults only: an existing saved placement
    /// always wins, and the iPad reference layout remains unchanged.
    private static let phoneDefaultPlacements: [String: UT99TouchPlacement] = [
        "menuBack": .init(x: 0.8590047393364929, y: 0.3128205128205128, scale: 1),
        "menuSelect": .init(x: 0.7847551342812006, y: 0.5931623931623932, scale: 1),
        "move": .init(x: 0.15639810426540285, y: 0.7470085470085469, scale: 1),
        "primaryFire": .init(x: 0.8175355450236966, y: 0.6376068376068377, scale: 1),
        "alternateFire": .init(x: 0.75, y: 0.5367521367521367, scale: 1),
        "jump": .init(x: 0.8554502369668247, y: 0.4675213675213675, scale: 1.2872077226638794),
        "crouch": .init(x: 0.7942338072669826, y: 0.4273504273504274, scale: 1),
        "previousWeapon": .init(x: 0.22946287519747235, y: 0.5863247863247864, scale: 1.1761363744735718),
        "nextWeapon": .init(x: 0.28080568720379145, y: 0.5923076923076923, scale: 1.226136326789856),
        "use": .init(x: 0.2531595576619273, y: 0.7059829059829059, scale: 1.3332443237304688),
    ]
    private(set) var touchProfile: TouchProfile

    private static let profileDefaultsKey = "ut99.touch.profile"
    private static let opacityDefaultsKey = "ut99.touch.opacity"
    private static let scaleDefaultsKey = "ut99.touch.scale"
    private(set) var touchOpacity: CGFloat
    private(set) var globalScale: CGFloat
    private(set) var touchConfiguration: UT99TouchConfiguration

    override init(frame: CGRect) {
        let savedProfile = TouchProfile(rawValue: UserDefaults.standard.string(forKey: Self.profileDefaultsKey) ?? "")
        touchProfile = (savedProfile ?? .standard).canonical
        let storedOpacity = UserDefaults.standard.object(forKey: Self.opacityDefaultsKey) as? Double
        touchOpacity = CGFloat(max(0.25, min(1.0, storedOpacity ?? Double(touchProfile.opacity))))
        let storedScale = UserDefaults.standard.object(forKey: Self.scaleDefaultsKey) as? Double
        globalScale = CGFloat(max(0.75, min(1.35, storedScale ?? 1.0)))
        touchConfiguration = UT99TouchConfiguration.load()
        super.init(frame: frame)
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        loadPlacements()
        alpha = touchOpacity
        configureSurface()
        configureButtons()
        configureLayoutEditor()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Keep the full-screen overlay visually composited without swallowing
    /// touches between controls. Those touches fall through to the host's
    /// game-surface pointer view and drive Unreal's original UWindow UI.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }

        if traitCollection.userInterfaceIdiom != .pad || size.height < 500 {
            layoutPhoneControls(in: size)
            return
        }

        updateSafeAreaGuide()
        let safe = bounds.inset(by: safeAreaInsets)
        let scale = touchProfile.scale * globalScale
        applyReferenceFrames(UT99EctoPadReferenceLayout.tabletFrames(
            safeRect: safe,
            scale: scale,
            leftHanded: touchConfiguration.leftHanded
        ))
        layoutLookZone()
        weaponRail.isHidden = true
    }

    /// EctoPad's phone layout scales from an 800x380 safe reference rather
    /// than shrinking the iPad coordinates. Retain that exact construction so
    /// notches and the home indicator do not crush the action cluster.
    private func layoutPhoneControls(in size: CGSize) {
        updateSafeAreaGuide()
        let safe = bounds.inset(by: safeAreaInsets)
        applyReferenceFrames(UT99EctoPadReferenceLayout.phoneFrames(
            safeRect: safe,
            profileScale: touchProfile.scale * globalScale,
            leftHanded: touchConfiguration.leftHanded
        ))
        layoutLookZone()
        weaponRail.isHidden = true
    }

    private func layoutLookZone() {
        lookPad.frame = touchConfiguration.leftHanded
            ? CGRect(x: 0, y: 0, width: bounds.midX, height: bounds.height)
            : CGRect(x: bounds.midX, y: 0, width: bounds.width - bounds.midX, height: bounds.height)
        lookDiameter = min(172, max(112, bounds.height * 0.19)) * touchProfile.scale * globalScale
        lookRing.bounds = CGRect(x: 0, y: 0, width: lookDiameter, height: lookDiameter)
        lookRing.layer.cornerRadius = lookDiameter / 2
        if lookAnchor == nil {
            lookRing.center = CGPoint(x: lookPad.bounds.midX, y: lookPad.bounds.height * 0.70)
        }
        let thumbDiameter = lookDiameter * 0.42
        lookThumb.bounds = CGRect(x: 0, y: 0, width: thumbDiameter, height: thumbDiameter)
        lookThumb.center = CGPoint(x: lookRing.bounds.midX, y: lookRing.bounds.midY)
        lookThumb.layer.cornerRadius = thumbDiameter / 2
        let glyphSide = min(22, max(14, thumbDiameter * 0.34))
        lookGlyph.bounds = CGRect(x: 0, y: 0, width: glyphSide, height: glyphSide)
        lookGlyph.center = CGPoint(x: lookThumb.bounds.midX, y: lookThumb.bounds.midY)
        lookRing.isHidden = menuInteractionActive || (!testingLayout && lookAnchor == nil)
    }

    private func applyReferenceFrames(_ frames: [String: CGRect]) {
        if let frame = frames["move"] {
            placeStick(movePad, ring: moveRing, key: "move",
                       center: CGPoint(x: frame.midX, y: frame.midY), diameter: frame.width)
        }
        for action in Action.allCases {
            guard let frame = frames[action.rawValue] else { continue }
            setButton(action, center: CGPoint(x: frame.midX, y: frame.midY), size: frame.size)
        }
    }

    private func placeStick(_ view: UIView, ring: UIView, key: String, center fallback: CGPoint, diameter: CGFloat) {
        let placement = resolvedPlacement(for: key)
        let resolvedCenter = placement.map { CGPoint(x: $0.x * bounds.width, y: $0.y * bounds.height) } ??
            UT99TouchLayoutGeometry.mirroredCenter(fallback, canvasWidth: bounds.width, leftHanded: false)
        let resolvedDiameter = diameter * (placement?.scale ?? 1)
        moveDiameter = resolvedDiameter
        // The movement surface is a forgiving half-screen activation zone.
        // Its visual stick is independent and appears wherever the thumb lands.
        view.frame = touchConfiguration.leftHanded
            ? CGRect(x: bounds.midX, y: 0, width: bounds.width - bounds.midX, height: bounds.height)
            : CGRect(x: 0, y: 0, width: bounds.midX, height: bounds.height)
        ring.bounds = CGRect(x: 0, y: 0, width: resolvedDiameter, height: resolvedDiameter)
        if moveAnchor == nil {
            ring.center = CGPoint(x: resolvedCenter.x - view.frame.minX, y: resolvedCenter.y - view.frame.minY)
        }
        ring.layer.cornerRadius = resolvedDiameter / 2
        let thumbDiameter = resolvedDiameter * 0.42
        moveThumb.bounds = CGRect(x: 0, y: 0, width: thumbDiameter, height: thumbDiameter)
        moveThumb.center = CGPoint(x: moveRing.bounds.midX, y: moveRing.bounds.midY)
        moveThumb.layer.cornerRadius = thumbDiameter / 2
        let glyphSide = min(22, max(14, thumbDiameter * 0.34))
        moveGlyph.bounds = CGRect(x: 0, y: 0, width: glyphSide, height: glyphSide)
        moveGlyph.center = CGPoint(x: moveThumb.bounds.midX, y: moveThumb.bounds.midY)
        if moveAnchor == nil {
            moveThumb.transform = stickThumbTransform(
                value: accessibilityMovement,
                surface: moveRing,
                thumb: moveThumb,
                invertY: true
            )
        }
        moveRing.isHidden = !editingLayout && !testingLayout && moveAnchor == nil
    }

    private func configureSurface() {
        safeAreaGuide.isHidden = true
        safeAreaGuide.isUserInteractionEnabled = false
        safeAreaGuide.backgroundColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 0.035)
        safeAreaGuide.layer.borderColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 0.70).cgColor
        safeAreaGuide.layer.borderWidth = 1
        safeAreaGuide.layer.cornerRadius = 14
        addSubview(safeAreaGuide)

        movePad.backgroundColor = .clear
        movePad.isOpaque = false
        movePad.isAccessibilityElement = true
        movePad.accessibilityLabel = "Movement"
        movePad.accessibilityValue = "Stopped"
        movePad.accessibilityHint = "Choose a direction from Actions. Choose Stop movement to release it."
        movePad.accessibilityIdentifier = "ut99.touch.move"
        movePad.accessibilityCustomActions = [
            movementAccessibilityAction(name: "Move forward", value: CGPoint(x: 0, y: 1)),
            movementAccessibilityAction(name: "Move backward", value: CGPoint(x: 0, y: -1)),
            movementAccessibilityAction(name: "Strafe left", value: CGPoint(x: -1, y: 0)),
            movementAccessibilityAction(name: "Strafe right", value: CGPoint(x: 1, y: 0)),
            movementAccessibilityAction(name: "Stop movement", value: .zero)
        ]
        addSubview(movePad)

        // The ring is a floating stick: invisible at rest, centered under the
        // player's thumb on contact, and removed immediately on release.
        moveRing.backgroundColor = UIColor(white: 0.13, alpha: 0.86)
        moveRing.layer.cornerRadius = 100
        moveRing.layer.borderWidth = 2
        moveRing.layer.borderColor = UIColor.white.withAlphaComponent(0.34).cgColor
        moveRing.isUserInteractionEnabled = false
        moveThumb.backgroundColor = UIColor(white: 0.58, alpha: 0.94)
        moveThumb.layer.cornerRadius = 100
        moveRing.addSubview(moveThumb)
        moveGlyph.tintColor = UIColor.white.withAlphaComponent(0.80)
        moveGlyph.contentMode = .scaleAspectFit
        moveThumb.addSubview(moveGlyph)
        moveRing.isHidden = true
        movePad.addSubview(moveRing)
        let movePan = UIPanGestureRecognizer(target: self, action: #selector(moveChanged(_:)))
        movePan.delegate = self
        movePad.addGestureRecognizer(movePan)
        let movePinch = UIPinchGestureRecognizer(target: self, action: #selector(layoutZonePinchChanged(_:)))
        movePinch.cancelsTouchesInView = false
        movePad.addGestureRecognizer(movePinch)

        lookPad.backgroundColor = .clear
        lookPad.isOpaque = false
        lookPad.isMultipleTouchEnabled = true
        lookPad.accessibilityIdentifier = "ut99.touch.lookStick"
        lookPad.accessibilityLabel = "Look"
        lookPad.accessibilityHint = "Touch anywhere on this side and move the floating stick to look around."
        addSubview(lookPad)
        lookRing.backgroundColor = UIColor(red: 0.08, green: 0.23, blue: 0.30, alpha: 0.84)
        lookRing.layer.borderWidth = 2
        lookRing.layer.borderColor = UIColor.white.withAlphaComponent(0.34).cgColor
        lookRing.isUserInteractionEnabled = false
        lookThumb.backgroundColor = UIColor(red: 0.28, green: 0.72, blue: 0.78, alpha: 0.94)
        lookRing.addSubview(lookThumb)
        lookGlyph.tintColor = UIColor.white.withAlphaComponent(0.86)
        lookGlyph.contentMode = .scaleAspectFit
        lookThumb.addSubview(lookGlyph)
        lookRing.isHidden = true
        lookPad.addSubview(lookRing)
        let lookPan = UIPanGestureRecognizer(target: self, action: #selector(lookChanged(_:)))
        lookPan.delegate = self
        lookPad.addGestureRecognizer(lookPan)

        weaponRail.isUserInteractionEnabled = false
        weaponRail.isOpaque = false
        weaponRail.backgroundColor = UIColor.black.withAlphaComponent(0.38)
        weaponRail.layer.borderWidth = 0.8
        weaponRail.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor
        weaponRail.layer.cornerCurve = .continuous
        weaponRail.clipsToBounds = true
        weaponRailDivider.isUserInteractionEnabled = false
        weaponRailDivider.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        weaponRail.addSubview(weaponRailDivider)
        addSubview(weaponRail)

        // SDL's renderer window is intentionally non-interactive so the host
        // owns touch/menu input. Keep iPad trackpad/mouse aiming on the same
        // host path by converting hover deltas into relative-look events;
        // touch pan gestures remain independent.
        let pointer = UIHoverGestureRecognizer(target: self, action: #selector(pointerChanged(_:)))
        pointer.cancelsTouchesInView = false
        addGestureRecognizer(pointer)
    }

    private func movementAccessibilityAction(name: String, value: CGPoint) -> UIAccessibilityCustomAction {
        UIAccessibilityCustomAction(name: name) { [weak self] _ in
            guard let self, !self.editingLayout else { return false }
            self.accessibilityMovement = value
            self.moveRing.isHidden = value == .zero
            self.moveThumb.transform = self.stickThumbTransform(
                value: value,
                surface: self.moveRing,
                thumb: self.moveThumb,
                invertY: true
            )
            self.movePad.accessibilityValue = value == .zero ? "Stopped" : name
            self.onMove?(value, value != .zero)
            return true
        }
    }

    private func stickThumbTransform(value: CGPoint, surface: UIView, thumb: UIView, invertY: Bool) -> CGAffineTransform {
        let travel = max(0, surface.bounds.width * 0.5 - thumb.bounds.width * 0.5 - 4)
        return CGAffineTransform(
            translationX: value.x * travel,
            y: (invertY ? -value.y : value.y) * travel
        )
    }

    private func configureButtons() {
        for action in Action.allCases {
            let button = UT99TouchActionButton(frame: .zero)
            button.configure(
                symbol: symbol(for: action),
                title: title(for: action),
                accent: tint(for: action),
                foreground: foreground(for: action),
                role: visualRole(for: action)
            )
            updateAppearance(of: button, for: action, pressed: false)
            button.layer.cornerRadius = 44
            button.layer.cornerCurve = .continuous
            button.isHidden = false // the host's three-dot button remains a separate host surface
            button.accessibilityLabel = title(for: action)
            button.accessibilityHint = accessibilityHint(for: action)
            button.accessibilityIdentifier = "ut99.touch.\(action.rawValue)"
            button.addTarget(self, action: #selector(buttonDown(_:)), for: [.touchDown, .touchDragEnter])
            button.addTarget(self, action: #selector(buttonUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
            button.tag = actionTag(action)
            button.onAccessibilityActivate = { [weak self, weak button] in
                guard let self, let button, !self.activeActions.contains(action) else { return }
                // The original SDL entry owns the main thread once gameplay
                // starts, so a main-queue delayed release cannot be trusted.
                // Queue both edges synchronously; SDL preserves their order.
                self.buttonDown(button)
                self.buttonUp(button)
            }
            let layoutPan = UIPanGestureRecognizer(target: self, action: #selector(layoutPanChanged(_:)))
            layoutPan.cancelsTouchesInView = false
            button.addGestureRecognizer(layoutPan)
            let layoutPinch = UIPinchGestureRecognizer(target: self, action: #selector(layoutPinchChanged(_:)))
            layoutPinch.cancelsTouchesInView = false
            button.addGestureRecognizer(layoutPinch)
            let layoutSelect = UITapGestureRecognizer(target: self, action: #selector(layoutControlSelected(_:)))
            layoutSelect.cancelsTouchesInView = false
            button.addGestureRecognizer(layoutSelect)
            buttons[action] = button
            addSubview(button)
        }
    }

    private func configureLayoutEditor() {
        layoutBanner.text = "EDIT TOUCH LAYOUT"
        layoutBanner.textColor = .white.withAlphaComponent(0.88)
        layoutBanner.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        layoutBanner.textAlignment = .center
        layoutBanner.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        layoutBanner.layer.cornerRadius = 8
        layoutBanner.clipsToBounds = true
        layoutBanner.isHidden = true
        layoutBanner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(layoutBanner)

        layoutDoneButton.setTitle("DONE", for: .normal)
        layoutDoneButton.setTitleColor(.white, for: .normal)
        layoutDoneButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        layoutDoneButton.backgroundColor = UIColor(red: 0.10, green: 0.52, blue: 0.48, alpha: 0.92)
        layoutDoneButton.layer.cornerRadius = 8
        layoutDoneButton.isHidden = true
        layoutDoneButton.translatesAutoresizingMaskIntoConstraints = false
        layoutDoneButton.addTarget(self, action: #selector(finishLayoutEditing), for: .touchUpInside)
        addSubview(layoutDoneButton)

        layoutSizeLabel.textColor = .white
        layoutSizeLabel.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        layoutSizeLabel.text = "SIZE · MOVE"
        layoutSizeLabel.setContentHuggingPriority(.required, for: .horizontal)
        layoutSizeSlider.minimumValue = 0.70
        layoutSizeSlider.maximumValue = 1.50
        layoutSizeSlider.value = 1
        layoutSizeSlider.minimumTrackTintColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 1)
        layoutSizeSlider.accessibilityLabel = "Selected control size"
        layoutSizeSlider.addTarget(self, action: #selector(layoutSizeChanged(_:)), for: .valueChanged)
        layoutSizeSlider.addTarget(self, action: #selector(layoutSizeFinished(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        layoutSizeControls.addArrangedSubview(layoutSizeLabel)
        layoutSizeControls.addArrangedSubview(layoutSizeSlider)
        layoutSizeControls.axis = .horizontal
        layoutSizeControls.alignment = .center
        layoutSizeControls.spacing = 12
        layoutSizeControls.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        layoutSizeControls.layer.cornerRadius = 10
        layoutSizeControls.isLayoutMarginsRelativeArrangement = true
        layoutSizeControls.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        layoutSizeControls.isHidden = true
        layoutSizeControls.translatesAutoresizingMaskIntoConstraints = false
        addSubview(layoutSizeControls)

        let moveSelect = UITapGestureRecognizer(target: self, action: #selector(layoutMoveSelected(_:)))
        moveSelect.cancelsTouchesInView = false
        movePad.addGestureRecognizer(moveSelect)
        NSLayoutConstraint.activate([
            // Center the two editor controls as one compact strip. Side-based
            // placement collides with MENU when the southpaw preset mirrors it;
            // SCORE moves just below this strip while a layout mode is active.
            layoutBanner.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor, constant: -128),
            layoutBanner.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 14),
            layoutBanner.widthAnchor.constraint(equalToConstant: 170),
            layoutBanner.heightAnchor.constraint(equalToConstant: 32),
            layoutDoneButton.leadingAnchor.constraint(equalTo: layoutBanner.trailingAnchor, constant: 10),
            layoutDoneButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 14),
            layoutDoneButton.widthAnchor.constraint(equalToConstant: 76),
            layoutDoneButton.heightAnchor.constraint(equalToConstant: 32),
            layoutSizeControls.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
            layoutSizeControls.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            layoutSizeControls.widthAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.widthAnchor, constant: -32),
            layoutSizeControls.widthAnchor.constraint(equalToConstant: 360),
            layoutSizeControls.heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    private func setButton(_ action: Action, center: CGPoint, size: CGSize, scale: CGFloat = 1) {
        guard let button = buttons[action] else { return }
        button.isHidden = menuInteractionActive
            ? action != .primaryFire && action != .pause
            : touchConfiguration.hiddenActions.contains(action.rawValue)
        if menuInteractionActive && (action == .primaryFire || action == .pause) {
            let safe = bounds.inset(by: safeAreaInsets).insetBy(dx: 18, dy: 18)
            let menuSize = action == .primaryFire
                ? CGSize(width: 104, height: 104)
                : CGSize(width: 132, height: 64)
            let fallbackCenter = action == .primaryFire
                ? CGPoint(x: safe.maxX - menuSize.width * 0.5, y: safe.midY)
                : CGPoint(
                    x: safe.maxX - menuSize.width * 0.5,
                    // The host menu starts 40 points below the safe-area top
                    // and is 40 points tall. Keep BACK below its full target.
                    y: max(safe.minY, safeAreaInsets.top + 40 + 40 + 12) + menuSize.height * 0.5
                )
            let placement = resolvedPlacement(for: layoutKey(for: action)) ?? UT99TouchPlacement(
                x: fallbackCenter.x / max(bounds.width, 1),
                y: fallbackCenter.y / max(bounds.height, 1),
                scale: 1
            )
            button.bounds.size = CGSize(
                width: menuSize.width * placement.scale,
                height: menuSize.height * placement.scale
            )
            button.center = CGPoint(x: placement.x * bounds.width, y: placement.y * bounds.height)
            button.center.x = min(max(button.center.x, safe.minX + button.bounds.width * 0.5),
                                  safe.maxX - button.bounds.width * 0.5)
            button.center.y = min(max(button.center.y, safe.minY + button.bounds.height * 0.5),
                                  safe.maxY - button.bounds.height * 0.5)
            keepButtonBelowHostMenu(button)
            button.layer.cornerRadius = min(button.bounds.width, button.bounds.height) / 2
            updateAppearance(of: button, for: action, pressed: activeActions.contains(action))
            return
        }
        let fallback = UT99TouchPlacement(x: center.x / max(bounds.width, 1), y: center.y / max(bounds.height, 1), scale: 1)
        let placement = resolvedPlacement(for: action.rawValue) ?? fallback
        button.bounds.size = CGSize(width: size.width * scale * placement.scale,
                                    height: size.height * scale * placement.scale)
        button.center = CGPoint(x: placement.x * bounds.width, y: placement.y * bounds.height)
        if action == .pause { keepButtonBelowHostMenu(button) }
        button.layer.cornerRadius = min(button.bounds.width, button.bounds.height) / 2
        updateAppearance(of: button, for: action, pressed: activeActions.contains(action))
    }

    private func layoutKey(for action: Action) -> String {
        guard menuInteractionActive else { return action.rawValue }
        if action == .primaryFire { return "menuSelect" }
        if action == .pause { return "menuBack" }
        return action.rawValue
    }

    private func action(forLayoutKey key: String) -> Action? {
        if key == "menuSelect" { return .primaryFire }
        if key == "menuBack" { return .pause }
        return Action(rawValue: key)
    }

    private func keepButtonBelowHostMenu(_ button: UIButton) {
        let safe = bounds.inset(by: safeAreaInsets)
        let hostButton = CGRect(
            x: safe.maxX - 52,
            y: safe.minY + 40,
            width: 40,
            height: 40
        ).insetBy(dx: -8, dy: -8)
        guard button.frame.intersects(hostButton) else { return }
        button.center.y = min(
            safe.maxY - button.bounds.height * 0.5 - 8,
            hostButton.maxY + 8 + button.bounds.height * 0.5
        )
    }

    private func layoutWeaponRail() {
        guard let previous = buttons[.previousWeapon], let next = buttons[.nextWeapon] else {
            weaponRail.isHidden = true
            return
        }
        guard !previous.isHidden, !next.isHidden else {
            weaponRail.isHidden = true
            return
        }
        let hasCustomPlacement = placements[Action.previousWeapon.rawValue] != nil ||
            placements[Action.nextWeapon.rawValue] != nil
        weaponRail.isHidden = editingLayout || hasCustomPlacement
        guard !weaponRail.isHidden else { return }
        let union = previous.frame.union(next.frame)
        weaponRail.frame = union.insetBy(dx: -7, dy: -3)
        weaponRail.layer.cornerRadius = weaponRail.bounds.height / 2
        weaponRailDivider.frame = CGRect(
            x: weaponRail.bounds.midX - 0.5,
            y: weaponRail.bounds.height * 0.24,
            width: 1,
            height: weaponRail.bounds.height * 0.52
        )
        sendSubviewToBack(weaponRail)
    }

    private func center(forKey key: String, in size: CGSize, fallback: CGPoint) -> CGPoint {
        if let placement = resolvedPlacement(for: key) {
            return CGPoint(x: placement.x * size.width, y: placement.y * size.height)
        }
        return UT99TouchLayoutGeometry.mirroredCenter(
            fallback,
            canvasWidth: size.width,
            leftHanded: touchConfiguration.leftHanded
        )
    }

    private func resolvedPlacement(for key: String) -> UT99TouchPlacement? {
        if let placement = placements[key] { return placement }
        guard traitCollection.userInterfaceIdiom == .phone,
              var placement = Self.phoneDefaultPlacements[key] else { return nil }
        if touchConfiguration.leftHanded { placement.x = 1 - placement.x }
        return placement
    }

    private func loadPlacements() {
        guard let data = UserDefaults.standard.data(forKey: Self.layoutDefaultsKey),
              let saved = try? JSONDecoder().decode([String: UT99TouchPlacement].self, from: data) else { return }
        placements = saved
    }

    private func savePlacements() {
        guard let data = try? JSONEncoder().encode(placements) else { return }
        UserDefaults.standard.set(data, forKey: Self.layoutDefaultsKey)
        NSLog("UT99 touch layout persisted entries=%lu", placements.count)
    }

    func makeTouchProfile(named name: String) throws -> UT99TouchProfileDocument {
        let defaults = UserDefaults.standard
        return try UT99TouchProfileStore.validated(UT99TouchProfileDocument(
            name: name,
            preset: touchProfile.rawValue,
            opacity: touchOpacity,
            globalScale: globalScale,
            configuration: touchConfiguration,
            lookSensitivity: defaults.double(forKey: "ut99.input.lookSensitivity"),
            invertLookY: defaults.bool(forKey: "ut99.input.invertLookY"),
            placements: placements
        ))
    }

    func applyTouchProfileDocument(_ source: UT99TouchProfileDocument) throws {
        let profile = try UT99TouchProfileStore.validated(source)
        guard let preset = TouchProfile(rawValue: profile.preset) else {
            throw UT99TouchProfileError.unsupportedPreset(profile.preset)
        }
        releaseActiveInputs()
        editingLayout = false
        testingLayout = false
        touchProfile = preset
        touchOpacity = profile.opacity
        globalScale = profile.globalScale
        touchConfiguration = profile.configuration.sanitized()
        placements = profile.placements

        let defaults = UserDefaults.standard
        defaults.set(touchProfile.rawValue, forKey: Self.profileDefaultsKey)
        defaults.set(Double(touchOpacity), forKey: Self.opacityDefaultsKey)
        defaults.set(Double(globalScale), forKey: Self.scaleDefaultsKey)
        defaults.set(profile.lookSensitivity, forKey: "ut99.input.lookSensitivity")
        defaults.set(profile.invertLookY, forKey: "ut99.input.invertLookY")
        touchConfiguration.save(to: defaults)
        savePlacements()
        alpha = touchOpacity
        updateLayoutModeAppearance()
        NSLog("UT99 touch named profile applied name=%@ preset=%@ placements=%lu",
              profile.name, profile.preset, placements.count)
    }

    func resetTouchLayout() {
        releaseActiveInputs()
        placements.removeAll()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.layoutDefaultsKey)
        touchProfile = .standard
        touchOpacity = TouchProfile.standard.opacity
        globalScale = 1.0
        defaults.set(touchProfile.rawValue, forKey: Self.profileDefaultsKey)
        defaults.set(Double(touchOpacity), forKey: Self.opacityDefaultsKey)
        defaults.set(Double(globalScale), forKey: Self.scaleDefaultsKey)
        touchConfiguration = .standard
        touchConfiguration.save(to: defaults)
        alpha = touchOpacity
        setNeedsLayout()
    }

    func setLeftHanded(_ enabled: Bool) {
        guard touchConfiguration.leftHanded != enabled else { return }
        releaseActiveInputs()
        touchConfiguration.leftHanded = enabled
        touchConfiguration.save()
        // Handedness is a complete spatial preset. Clear custom coordinates so
        // it always produces a coherent mirror instead of a half-custom mix.
        placements.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.layoutDefaultsKey)
        setNeedsLayout()
    }

    func isActionVisible(_ action: Action) -> Bool {
        !touchConfiguration.hiddenActions.contains(action.rawValue)
    }

    func setAction(_ action: Action, visible: Bool) {
        if visible {
            touchConfiguration.hiddenActions.remove(action.rawValue)
        } else {
            if activeActions.remove(action) != nil { onAction?(action, false) }
            touchConfiguration.hiddenActions.insert(action.rawValue)
        }
        touchConfiguration.save()
        setNeedsLayout()
    }

    func setTouchConfiguration(_ source: UT99TouchConfiguration) {
        releaseActiveInputs()
        touchConfiguration = source.sanitized()
        touchConfiguration.save()
        setNeedsLayout()
    }

    func displayTitle(for action: Action) -> String { title(for: action) }

    func setTouchOpacity(_ value: CGFloat) {
        touchOpacity = max(0.25, min(1.0, value))
        UserDefaults.standard.set(Double(touchOpacity), forKey: Self.opacityDefaultsKey)
        alpha = touchOpacity
    }

    func setGlobalScale(_ value: CGFloat) {
        globalScale = max(0.75, min(1.35, value))
        UserDefaults.standard.set(Double(globalScale), forKey: Self.scaleDefaultsKey)
        setNeedsLayout()
    }

    func setLayoutEditing(_ editing: Bool) {
        releaseActiveInputs()
        editingLayout = editing
        testingLayout = false
        updateLayoutModeAppearance()
    }

    func setLayoutTesting(_ testing: Bool) {
        releaseActiveInputs()
        editingLayout = false
        testingLayout = testing
        updateLayoutModeAppearance()
    }

    func setMenuInteractionActive(_ active: Bool) {
        guard menuInteractionActive != active else { return }
        releaseActiveInputs()
        menuInteractionActive = active
        movePad.isHidden = false
        lookPad.isHidden = active
        movePad.accessibilityLabel = active ? "Menu cursor" : "Movement"
        movePad.accessibilityHint = active
            ? "Move the Unreal Tournament menu cursor."
            : "Choose a direction from Actions. Choose Stop movement to release it."
        for (action, button) in buttons {
            button.isHidden = active
                ? action != .primaryFire && action != .pause
                : touchConfiguration.hiddenActions.contains(action.rawValue)
        }
        buttons[.primaryFire]?.setTitle(active ? "SELECT" : "FIRE")
        buttons[.primaryFire]?.accessibilityLabel = active ? "Select" : title(for: .primaryFire)
        buttons[.primaryFire]?.accessibilityHint = active
            ? "Clicks the current Unreal Tournament menu item."
            : accessibilityHint(for: .primaryFire)
        buttons[.pause]?.setTitle(active ? "BACK" : "GAME MENU")
        setNeedsLayout()
    }

    private func updateLayoutModeAppearance() {
        let active = editingLayout || testingLayout
        layoutBanner.text = editingLayout ? "EDIT TOUCH LAYOUT" : "TEST TOUCH LAYOUT"
        backgroundColor = editingLayout
            ? UIColor.black.withAlphaComponent(0.28)
            : (testingLayout ? UIColor.black.withAlphaComponent(0.08) : .clear)
        safeAreaGuide.isHidden = !active
        layoutBanner.isHidden = !active
        layoutDoneButton.isHidden = !active
        layoutSizeControls.isHidden = !editingLayout
        if editingLayout { selectLayoutControl(selectedLayoutKey) }
        for button in buttons.values {
            button.isUserInteractionEnabled = true
            button.setEditing(editingLayout)
        }
        weaponRail.isHidden = true
        movePad.backgroundColor = editingLayout ? UIColor.black.withAlphaComponent(0.12) : .clear
        movePad.layer.borderWidth = editingLayout ? 1 : 0
        movePad.layer.borderColor = UIColor(red: 0.35, green: 0.92, blue: 0.88, alpha: 0.42).cgColor
        movePad.layer.cornerRadius = 14
        moveRing.isHidden = !active && moveAnchor == nil && accessibilityMovement == .zero
        lookRing.isHidden = !testingLayout && lookAnchor == nil
        setNeedsLayout()
    }

    private func updateSafeAreaGuide() {
        safeAreaGuide.frame = bounds.inset(by: safeAreaInsets).insetBy(dx: 8, dy: 8)
    }

    @objc private func finishLayoutEditing() {
        if editingLayout { savePlacements() }
        editingLayout = false
        testingLayout = false
        updateLayoutModeAppearance()
    }

    @objc private func layoutControlSelected(_ gesture: UITapGestureRecognizer) {
        guard editingLayout, let button = gesture.view as? UIButton,
              let action = action(for: button.tag) else { return }
        selectLayoutControl(layoutKey(for: action))
    }

    @objc private func layoutMoveSelected(_ gesture: UITapGestureRecognizer) {
        guard editingLayout else { return }
        selectLayoutControl("move")
    }

    private func selectLayoutControl(_ key: String) {
        selectedLayoutKey = key
        let title: String
        if key == "move" {
            title = "MOVE"
        } else if key == "menuSelect" {
            title = "SELECT"
        } else if key == "menuBack" {
            title = "BACK"
        } else if let action = Action(rawValue: key) {
            title = self.title(for: action)
        } else {
            title = key.uppercased()
        }
        layoutSizeLabel.text = "SIZE · \(title)"
        layoutSizeSlider.value = Float(resolvedPlacement(for: key)?.scale ?? 1)
        layoutSizeSlider.accessibilityValue = "\(Int(layoutSizeSlider.value * 100)) percent"
    }

    @objc private func layoutSizeChanged(_ sender: UISlider) {
        guard editingLayout, bounds.width > 0, bounds.height > 0 else { return }
        var placement: UT99TouchPlacement
        if let existing = resolvedPlacement(for: selectedLayoutKey) {
            placement = existing
        } else if selectedLayoutKey == "move" {
            let center = CGPoint(x: movePad.frame.minX + moveRing.center.x,
                                 y: movePad.frame.minY + moveRing.center.y)
            placement = UT99TouchPlacement(x: center.x / bounds.width, y: center.y / bounds.height, scale: 1)
        } else if let action = action(forLayoutKey: selectedLayoutKey), let button = buttons[action] {
            placement = UT99TouchPlacement(x: button.center.x / bounds.width,
                                           y: button.center.y / bounds.height,
                                           scale: 1)
        } else {
            return
        }
        placement.scale = CGFloat(sender.value)
        placements[selectedLayoutKey] = placement
        sender.accessibilityValue = "\(Int(sender.value * 100)) percent"
        setNeedsLayout()
    }

    @objc private func layoutSizeFinished(_ sender: UISlider) {
        guard editingLayout else { return }
        savePlacements()
    }

    @objc private func layoutPanChanged(_ gesture: UIPanGestureRecognizer) {
        guard editingLayout, let button = gesture.view as? UIButton,
              let action = action(for: button.tag), bounds.width > 0, bounds.height > 0 else { return }
        let point = gesture.location(in: self)
        let halfWidth = button.bounds.width / 2
        let halfHeight = button.bounds.height / 2
        let x = min(max(point.x, halfWidth), bounds.width - halfWidth) / bounds.width
        let y = min(max(point.y, halfHeight), bounds.height - halfHeight) / bounds.height
        let key = layoutKey(for: action)
        var placement = resolvedPlacement(for: key) ?? UT99TouchPlacement(x: x, y: y, scale: 1)
        placement.x = x
        placement.y = y
        placements[key] = placement
        selectLayoutControl(key)
        button.center = CGPoint(x: x * bounds.width, y: y * bounds.height)
        if gesture.state == .ended || gesture.state == .cancelled {
            NSLog("UT99 touch layout moved action=%@ x=%.3f y=%.3f", key, placement.x, placement.y)
            savePlacements()
        }
    }

    @objc private func layoutPinchChanged(_ gesture: UIPinchGestureRecognizer) {
        guard editingLayout, let button = gesture.view as? UIButton,
              let action = action(for: button.tag) else { return }
        let key = layoutKey(for: action)
        var placement = resolvedPlacement(for: key) ?? UT99TouchPlacement(
            x: button.center.x / max(bounds.width, 1),
            y: button.center.y / max(bounds.height, 1),
            scale: 1
        )
        placement.scale = min(max(placement.scale * gesture.scale, 0.70), 1.50)
        placements[key] = placement
        selectLayoutControl(key)
        button.bounds.size = CGSize(width: button.bounds.width * gesture.scale,
                                    height: button.bounds.height * gesture.scale)
        button.layer.cornerRadius = button.bounds.width / 2
        gesture.scale = 1
        if gesture.state == .ended || gesture.state == .cancelled { savePlacements() }
    }

    @objc private func layoutZonePinchChanged(_ gesture: UIPinchGestureRecognizer) {
        guard editingLayout, let view = gesture.view else { return }
        let key = "move"
        var placement = resolvedPlacement(for: key) ?? UT99TouchPlacement(
            x: view.center.x / max(bounds.width, 1),
            y: view.center.y / max(bounds.height, 1),
            scale: 1
        )
        placement.scale = min(max(placement.scale * gesture.scale, 0.70), 1.40)
        placements[key] = placement
        selectLayoutControl(key)
        gesture.scale = 1
        setNeedsLayout()
        if gesture.state == .ended || gesture.state == .cancelled { savePlacements() }
    }

    @objc private func moveChanged(_ gesture: UIPanGestureRecognizer) {
        if editingLayout {
            let point = gesture.location(in: self)
            let radius = moveDiameter / 2
            let zone = movePad.frame
            let clampedX = min(max(point.x, zone.minX + radius), zone.maxX - radius)
            let clampedY = min(max(point.y, radius), bounds.height - radius)
            let x = clampedX / max(bounds.width, 1)
            let y = clampedY / max(bounds.height, 1)
            let scale = resolvedPlacement(for: "move")?.scale ?? 1
            placements["move"] = UT99TouchPlacement(x: x, y: y, scale: scale)
            moveRing.center = CGPoint(x: clampedX - zone.minX, y: clampedY)
            selectLayoutControl("move")
            if gesture.state == .ended || gesture.state == .cancelled { savePlacements() }
            return
        }
        // Direct stick input takes ownership from any held accessibility
        // direction. Without this reset, a later layout pass could redraw a
        // stale assistive direction after the physical pan had released it.
        accessibilityMovement = .zero
        movePad.accessibilityValue = gesture.state == .ended || gesture.state == .cancelled
            ? "Stopped"
            : "Touch input"
        let point = gesture.location(in: movePad)
        if gesture.state == .began || moveAnchor == nil {
            moveAnchor = point
            moveRing.center = point
            moveRing.isHidden = false
            moveThumb.transform = .identity
            onMove?(.zero, true)
        }
        guard let anchor = moveAnchor else { return }
        let value = normalizedStickValue(
            point: point,
            center: anchor,
            radius: moveDiameter * 0.5,
            invertY: true
        )
        let travel = max(0, moveDiameter * 0.5 - moveThumb.bounds.width * 0.5 - 4)
        moveThumb.transform = CGAffineTransform(translationX: value.x * travel,
                                                y: -value.y * travel)
        onMove?(value, gesture.state != .ended && gesture.state != .cancelled)
        if gesture.state == .ended || gesture.state == .cancelled {
            moveAnchor = nil
            moveThumb.transform = .identity
            moveRing.isHidden = true
            onMove?(.zero, false)
        }
    }

    @objc private func lookChanged(_ gesture: UIPanGestureRecognizer) {
        guard !editingLayout, !menuInteractionActive else { return }
        let point = gesture.location(in: lookPad)
        if gesture.state == .began || lookAnchor == nil {
            lookAnchor = point
            lookValue = .zero
            lookRing.center = point
            lookRing.isHidden = false
            lookThumb.transform = .identity
            startLookDisplayLink()
        }
        guard let anchor = lookAnchor else { return }
        lookValue = normalizedStickValue(
            point: point,
            center: anchor,
            radius: lookDiameter * 0.5,
            invertY: false
        )
        let travel = max(0, lookDiameter * 0.5 - lookThumb.bounds.width * 0.5 - 4)
        lookThumb.transform = CGAffineTransform(
            translationX: lookValue.x * travel,
            y: lookValue.y * travel
        )
        if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
            finishLookInput()
        }
    }

    private func startLookDisplayLink() {
        guard lookDisplayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(publishFloatingLook))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        lookDisplayLink = link
    }

    @objc private func publishFloatingLook() {
        guard lookAnchor != nil else { return }
        // The engine bridge consumes relative mouse deltas. Convert the
        // floating stick's held displacement into a small per-frame value so
        // movement is smooth and simultaneous with the independent left stick.
        onLook?(UT99TouchInputTuning.floatingStickLook(lookValue), true)
    }

    private func finishLookInput() {
        lookDisplayLink?.invalidate()
        lookDisplayLink = nil
        lookAnchor = nil
        lookValue = .zero
        lookThumb.transform = .identity
        lookRing.isHidden = !testingLayout
        onLook?(.zero, false)
    }

    private func normalizedStickValue(point: CGPoint, center: CGPoint, radius: CGFloat, invertY: Bool) -> CGPoint {
        let safeRadius = max(radius, 1)
        var x = (point.x - center.x) / safeRadius
        var y = (point.y - center.y) / safeRadius
        let length = hypot(x, y)
        if length > 1 {
            x /= length
            y /= length
        }
        return CGPoint(x: x, y: invertY ? -y : y)
    }

    @objc private func pointerChanged(_ gesture: UIHoverGestureRecognizer) {
        let point = gesture.location(in: self)
        switch gesture.state {
        case .began:
            pointerLastLocation = point
        case .changed:
            guard let previous = pointerLastLocation else {
                pointerLastLocation = point
                return
            }
            pointerLastLocation = point
            let value = CGPoint(
                x: (point.x - previous.x) / max(bounds.width, 1),
                y: (previous.y - point.y) / max(bounds.height, 1)
            )
            guard abs(value.x) > 0.0001 || abs(value.y) > 0.0001 else { return }
            onLook?(value, true)
        case .ended, .cancelled, .failed:
            pointerLastLocation = nil
            onLook?(.zero, false)
        default:
            break
        }
    }

    @objc private func buttonDown(_ rawSender: UIButton) {
        guard !editingLayout else { return }
        guard let sender = rawSender as? UT99TouchActionButton else { return }
        guard let action = action(for: sender.tag) else { return }
        activeActions.insert(action)
        actionHaptic.impactOccurred(intensity: action == .primaryFire ? 0.72 : 0.46)
        updateAppearance(of: sender, for: action, pressed: true)
        UIView.animate(
            withDuration: 0.09,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            // Match the reference control's unmistakable down state while the
            // haptic confirms the press under the player's thumb.
            sender.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }
        onAction?(action, true)
    }

    @objc private func buttonUp(_ rawSender: UIButton) {
        guard !editingLayout else { return }
        guard let sender = rawSender as? UT99TouchActionButton else { return }
        guard let action = action(for: sender.tag) else { return }
        activeActions.remove(action)
        updateAppearance(of: sender, for: action, pressed: false)
        UIView.animate(
            withDuration: 0.16,
            delay: 0,
            usingSpringWithDamping: 0.72,
            initialSpringVelocity: 0.6,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            sender.transform = .identity
        }
        onAction?(action, false)
    }

    /// Release every host-owned gameplay input before a menu, lifecycle
    /// transition, or controller takeover. UIKit does not guarantee that a
    /// button receives touchUp after another view becomes interactive, so the
    /// bridge must not depend on UIButton's normal end-of-touch callbacks.
    func releaseActiveInputs() {
        let actions = activeActions
        activeActions.removeAll()
        for action in actions {
            onAction?(action, false)
            if let button = buttons[action] {
                button.transform = .identity
                updateAppearance(of: button, for: action, pressed: false)
            }
        }
        moveAnchor = nil
        finishLookInput()
        accessibilityMovement = .zero
        pointerLastLocation = nil
        moveThumb.transform = .identity
        movePad.accessibilityValue = "Stopped"
        moveRing.isHidden = !(editingLayout || testingLayout)
        onMove?(.zero, false)
        onLook?(.zero, false)
    }

    func applyTouchProfile(_ profile: TouchProfile) {
        releaseActiveInputs()
        let canonical = profile.canonical
        touchProfile = canonical
        UserDefaults.standard.set(canonical.rawValue, forKey: Self.profileDefaultsKey)
        setTouchOpacity(canonical.opacity)
        setNeedsLayout()
    }

    private func actionTag(_ action: Action) -> Int { Action.allCases.firstIndex(of: action) ?? 0 }
    private func action(for tag: Int) -> Action? { Action.allCases.indices.contains(tag) ? Action.allCases[tag] : nil }

    private func title(for action: Action) -> String {
        switch action {
        case .primaryFire, .leftPrimaryFire: "FIRE"
        case .alternateFire: "ALT"
        case .jump: "JUMP"
        case .use: "USE"
        case .crouch: "DUCK"
        case .nextWeapon: "WPN +"
        case .previousWeapon: "WPN −"
        case .scoreboard: "SCORE"
        case .pause: "GAME MENU"
        }
    }

    private func symbol(for action: Action) -> String {
        switch action {
        case .primaryFire, .leftPrimaryFire: "scope"
        case .alternateFire: "bolt.fill"
        case .jump: "arrow.up"
        case .use: "hand.tap.fill"
        case .crouch: "arrow.down"
        case .nextWeapon: "chevron.forward"
        case .previousWeapon: "chevron.backward"
        case .scoreboard: "list.number"
        case .pause: "pause.fill"
        }
    }

    private func visualRole(for action: Action) -> UT99TouchActionButton.Role {
        switch action {
        case .primaryFire: .primary
        case .leftPrimaryFire: .secondary
        case .pause: .start
        case .scoreboard, .nextWeapon, .previousWeapon, .use: .utility
        case .alternateFire: .secondary
        default: .utility
        }
    }

    private func accessibilityHint(for action: Action) -> String {
        switch action {
        case .primaryFire, .leftPrimaryFire: "Shoots the current weapon"
        case .alternateFire: "Uses the current weapon's alternate fire"
        case .jump: "Jumps"
        case .use: "Activates doors, lifts, and inventory"
        case .crouch: "Crouches while held"
        case .nextWeapon: "Selects the next weapon"
        case .previousWeapon: "Selects the previous weapon"
        case .scoreboard: "Shows the match scoreboard"
        case .pause: "Opens the original Unreal Tournament menu"
        }
    }

    private func updateAppearance(of button: UT99TouchActionButton, for action: Action, pressed: Bool) {
        button.setPressed(pressed)
        button.setEditing(editingLayout)
    }

    private func tint(for action: Action) -> UIColor {
        switch action {
        case .primaryFire, .leftPrimaryFire: UIColor(red: 0.08, green: 0.56, blue: 0.29, alpha: 0.92)
        case .alternateFire: UIColor(red: 0.78, green: 0.10, blue: 0.13, alpha: 0.92)
        case .jump, .crouch: UIColor(white: 0.72, alpha: 0.92)
        case .use, .scoreboard, .nextWeapon, .previousWeapon: UIColor(white: 0.22, alpha: 0.88)
        case .pause: UIColor(white: 0.28, alpha: 0.92)
        }
    }

    private func foreground(for action: Action) -> UIColor {
        switch action {
        case .jump, .crouch: UIColor(white: 0.12, alpha: 1)
        default: .white
        }
    }

}
