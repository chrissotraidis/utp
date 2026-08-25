import Foundation

struct UT99TouchPlacement: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat

    func sanitized() throws -> UT99TouchPlacement {
        guard x.isFinite, y.isFinite, scale.isFinite else {
            throw UT99TouchProfileError.invalidPlacement
        }
        return UT99TouchPlacement(
            x: min(max(x, 0.02), 0.98),
            y: min(max(y, 0.04), 0.96),
            scale: min(max(scale, 0.70), 1.50)
        )
    }
}

struct UT99TouchProfileDocument: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var name: String
    var preset: String
    var opacity: CGFloat
    var globalScale: CGFloat
    var configuration: UT99TouchConfiguration
    var lookSensitivity: Double
    var invertLookY: Bool
    var placements: [String: UT99TouchPlacement]

    init(
        name: String,
        preset: String,
        opacity: CGFloat,
        globalScale: CGFloat,
        configuration: UT99TouchConfiguration,
        lookSensitivity: Double,
        invertLookY: Bool,
        placements: [String: UT99TouchPlacement],
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.preset = preset
        self.opacity = opacity
        self.globalScale = globalScale
        self.configuration = configuration
        self.lookSensitivity = lookSensitivity
        self.invertLookY = invertLookY
        self.placements = placements
    }
}

enum UT99TouchProfileError: Error, LocalizedError, Equatable {
    case emptyName
    case nameTooLong
    case invalidName
    case unsupportedSchema(Int)
    case unsupportedPreset(String)
    case unsupportedControl(String)
    case invalidPlacement
    case oversizedImport
    case tooManyProfiles
    case invalidDocument

    var errorDescription: String? {
        switch self {
        case .emptyName: "Enter a profile name."
        case .nameTooLong: "Profile names are limited to 32 characters."
        case .invalidName: "The profile name contains unsupported control characters."
        case let .unsupportedSchema(version): "Touch profile version \(version) is not supported."
        case .unsupportedPreset: "This touch layout type is not supported."
        case let .unsupportedControl(control): "Touch control ‘\(control)’ is not supported."
        case .invalidPlacement: "The profile contains an invalid control placement."
        case .oversizedImport: "Touch profile files are limited to 64 KiB."
        case .tooManyProfiles: "Delete a saved profile before adding another."
        case .invalidDocument: "The selected file is not a valid UT99 touch profile."
        }
    }
}

enum UT99TouchProfileStore {
    static let defaultsKey = "ut99.touch.namedProfiles.v1"
    static let maxProfiles = 12
    static let maxImportBytes = 64 * 1024
    static let fileExtension = "ut99touch"

    static let supportedPresets: Set<String> = ["standard", "ectoPad", "goldenPad", "compact", "highVisibility"]
    static let supportedControls: Set<String> = UT99TouchConfiguration.supportedActionIDs
        .union(["move", "menuSelect", "menuBack"])

    static func validated(_ source: UT99TouchProfileDocument) throws -> UT99TouchProfileDocument {
        guard source.schemaVersion == UT99TouchProfileDocument.currentSchemaVersion else {
            throw UT99TouchProfileError.unsupportedSchema(source.schemaVersion)
        }
        let name = source.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw UT99TouchProfileError.emptyName }
        guard name.count <= 32 else { throw UT99TouchProfileError.nameTooLong }
        guard name.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw UT99TouchProfileError.invalidName
        }
        guard supportedPresets.contains(source.preset) else {
            throw UT99TouchProfileError.unsupportedPreset(source.preset)
        }
        guard source.opacity.isFinite, source.globalScale.isFinite, source.lookSensitivity.isFinite else {
            throw UT99TouchProfileError.invalidDocument
        }

        var placements: [String: UT99TouchPlacement] = [:]
        for (control, placement) in source.placements {
            guard supportedControls.contains(control) else {
                throw UT99TouchProfileError.unsupportedControl(control)
            }
            placements[control] = try placement.sanitized()
        }

        let canonicalPreset = ["ectoPad", "goldenPad"].contains(source.preset)
            ? "standard"
            : source.preset
        return UT99TouchProfileDocument(
            name: name,
            preset: canonicalPreset,
            opacity: min(max(source.opacity, 0.25), 1.0),
            globalScale: min(max(source.globalScale, 0.75), 1.35),
            configuration: source.configuration.sanitized(),
            lookSensitivity: min(max(source.lookSensitivity, 0.25), 3.0),
            invertLookY: source.invertLookY,
            placements: placements
        )
    }

    static func encode(_ profile: UT99TouchProfileDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(validated(profile))
    }

    static func decode(_ data: Data) throws -> UT99TouchProfileDocument {
        guard data.count <= maxImportBytes else { throw UT99TouchProfileError.oversizedImport }
        do {
            return try validated(JSONDecoder().decode(UT99TouchProfileDocument.self, from: data))
        } catch let error as UT99TouchProfileError {
            throw error
        } catch {
            throw UT99TouchProfileError.invalidDocument
        }
    }

    static func profiles(from defaults: UserDefaults = .standard) -> [UT99TouchProfileDocument] {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([UT99TouchProfileDocument].self, from: data) else {
            return []
        }
        var names = Set<String>()
        let sanitized = decoded.compactMap { try? validated($0) }.filter {
            names.insert($0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)).inserted
        }
        return Array(sanitized.prefix(maxProfiles)).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    @discardableResult
    static func upsert(
        _ source: UT99TouchProfileDocument,
        in defaults: UserDefaults = .standard
    ) throws -> Bool {
        let profile = try validated(source)
        var stored = profiles(from: defaults)
        let foldedName = profile.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let replacement = stored.firstIndex {
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == foldedName
        }
        if let replacement {
            stored[replacement] = profile
        } else {
            guard stored.count < maxProfiles else { throw UT99TouchProfileError.tooManyProfiles }
            stored.append(profile)
        }
        stored.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        defaults.set(try JSONEncoder().encode(stored), forKey: defaultsKey)
        return replacement != nil
    }

    @discardableResult
    static func delete(named name: String, from defaults: UserDefaults = .standard) -> Bool {
        var stored = profiles(from: defaults)
        let foldedName = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let oldCount = stored.count
        stored.removeAll {
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == foldedName
        }
        guard stored.count != oldCount else { return false }
        if stored.isEmpty {
            defaults.removeObject(forKey: defaultsKey)
        } else if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: defaultsKey)
        }
        return true
    }

    static func exportFileName(for profile: UT99TouchProfileDocument) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let scalars = profile.name.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let stem = String(scalars)
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(stem.isEmpty ? "UT99-Touch-Profile" : String(stem.prefix(48))).\(fileExtension)"
    }
}
