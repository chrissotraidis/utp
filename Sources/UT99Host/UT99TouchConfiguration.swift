import Foundation

struct UT99TouchConfiguration: Codable, Equatable {
    static let defaultsKey = "ut99.touch.configuration.v1"
    static let supportedActionIDs: Set<String> = [
        "primaryFire", "alternateFire", "jump", "crouch", "use",
        "nextWeapon", "previousWeapon", "scoreboard", "pause"
    ]

    var leftHanded: Bool
    var hiddenActions: Set<String>
    var lookAcceleration: Double
    var lookDeadZone: Double
    var movementDeadZone: Double
    var autoHideForController: Bool

    init(
        leftHanded: Bool,
        hiddenActions: Set<String>,
        lookAcceleration: Double,
        lookDeadZone: Double,
        movementDeadZone: Double,
        autoHideForController: Bool
    ) {
        self.leftHanded = leftHanded
        self.hiddenActions = hiddenActions
        self.lookAcceleration = lookAcceleration
        self.lookDeadZone = lookDeadZone
        self.movementDeadZone = movementDeadZone
        self.autoHideForController = autoHideForController
    }

    static let standard = UT99TouchConfiguration(
        leftHanded: false,
        hiddenActions: [],
        lookAcceleration: 0.45,
        lookDeadZone: 0.0025,
        movementDeadZone: 0.28,
        autoHideForController: true
    )

    func sanitized() -> UT99TouchConfiguration {
        UT99TouchConfiguration(
            leftHanded: leftHanded,
            hiddenActions: hiddenActions.intersection(Self.supportedActionIDs),
            lookAcceleration: min(max(lookAcceleration, 0), 1.5),
            lookDeadZone: min(max(lookDeadZone, 0), 0.03),
            movementDeadZone: min(max(movementDeadZone, 0.08), 0.45),
            autoHideForController: autoHideForController
        )
    }

    static func load(from defaults: UserDefaults = .standard) -> UT99TouchConfiguration {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(Self.self, from: data) else {
            return .standard
        }
        return decoded.sanitized()
    }

    func save(to defaults: UserDefaults = .standard) {
        let value = sanitized()
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    private enum CodingKeys: String, CodingKey {
        case leftHanded, hiddenActions, lookAcceleration, lookDeadZone, movementDeadZone, autoHideForController
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        leftHanded = try container.decode(Bool.self, forKey: .leftHanded)
        hiddenActions = Set(try container.decode([String].self, forKey: .hiddenActions))
        lookAcceleration = try container.decode(Double.self, forKey: .lookAcceleration)
        lookDeadZone = try container.decode(Double.self, forKey: .lookDeadZone)
        movementDeadZone = try container.decode(Double.self, forKey: .movementDeadZone)
        autoHideForController = try container.decode(Bool.self, forKey: .autoHideForController)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(leftHanded, forKey: .leftHanded)
        try container.encode(hiddenActions.sorted(), forKey: .hiddenActions)
        try container.encode(lookAcceleration, forKey: .lookAcceleration)
        try container.encode(lookDeadZone, forKey: .lookDeadZone)
        try container.encode(movementDeadZone, forKey: .movementDeadZone)
        try container.encode(autoHideForController, forKey: .autoHideForController)
    }
}

enum UT99TouchInputTuning {
    static func transformedLook(
        _ value: CGPoint,
        sensitivity: Double,
        configuration: UT99TouchConfiguration,
        invertY: Bool
    ) -> CGPoint {
        let config = configuration.sanitized()
        let magnitude = hypot(value.x, value.y)
        guard Double(magnitude) > config.lookDeadZone else { return CGPoint(x: 0, y: 0) }

        let clampedSensitivity = min(max(sensitivity, 0.25), 3.0)
        // Pan deltas are normalized against the live look surface. Scale their
        // speed into a bounded curve so slow aim stays precise while a quick
        // swipe can still turn fast enough for UT combat.
        let normalizedSpeed = min(Double(magnitude) * 12.0, 1.5)
        let gain = clampedSensitivity * (1.0 + config.lookAcceleration * normalizedSpeed)
        let yDirection: CGFloat = invertY ? -1 : 1
        return CGPoint(
            x: value.x * CGFloat(gain),
            y: value.y * CGFloat(gain) * yDirection
        )
    }
}
