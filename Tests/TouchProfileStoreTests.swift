import Foundation

enum Failure: Error { case message(String) }

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw Failure.message(message) }
}

func profile(named name: String = "Arena") -> UT99TouchProfileDocument {
    UT99TouchProfileDocument(
        name: name,
        preset: "standard",
        opacity: 0.72,
        globalScale: 0.94,
        configuration: .standard,
        lookSensitivity: 1.25,
        invertLookY: false,
        placements: ["primaryFire": .init(x: 0.9, y: 0.7, scale: 1.1)]
    )
}

@main
struct TouchProfileStoreTests {
    static func main() throws {
        let suite = "UT99TouchProfileStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { throw Failure.message("defaults") }
        defer { defaults.removePersistentDomain(forName: suite) }

        let encoded = try UT99TouchProfileStore.encode(profile())
        let encodedAgain = try UT99TouchProfileStore.encode(profile())
        let decoded = try UT99TouchProfileStore.decode(encoded)
        try expect(encoded == encodedAgain, "encoding must be deterministic")
        try expect(decoded == profile(), "round trip")
        try expect(String(data: encoded, encoding: .utf8)?.contains("\"schemaVersion\" : 1") == true, "versioned JSON")
        try expect(String(data: encoded, encoding: .utf8)?.contains("\"preset\" : \"standard\"") == true, "player-facing preset id")

        var legacy = profile(named: "Imported")
        legacy.preset = "ectoPad"
        let migrated = try UT99TouchProfileStore.validated(legacy)
        let migratedJSON = try UT99TouchProfileStore.encode(legacy)
        try expect(migrated.preset == "standard", "legacy preset migration")
        try expect(String(data: migratedJSON, encoding: .utf8)?.contains("ectoPad") == false,
                   "legacy name must not survive export")

        var unsafe = profile(named: "  Clamped  ")
        unsafe.opacity = 9
        unsafe.globalScale = 0
        unsafe.lookSensitivity = 99
        unsafe.configuration.lookAcceleration = 8
        unsafe.configuration.hiddenActions = ["jump", "unknown"]
        unsafe.placements["jump"] = .init(x: -2, y: 7, scale: 9)
        let safe = try UT99TouchProfileStore.validated(unsafe)
        try expect(safe.name == "Clamped", "trim name")
        try expect(safe.opacity == 1 && safe.globalScale == 0.75 && safe.lookSensitivity == 3, "clamp scalar settings")
        try expect(safe.configuration.hiddenActions == ["jump"], "filter hidden actions")
        try expect(safe.placements["jump"] == .init(x: 0.02, y: 0.96, scale: 1.5), "clamp placement")

        let inserted = try UT99TouchProfileStore.upsert(profile(), in: defaults)
        let replaced = try UT99TouchProfileStore.upsert(profile(named: "arena"), in: defaults)
        try expect(inserted == false, "first insert")
        try expect(replaced == true, "case-insensitive replacement")
        try expect(UT99TouchProfileStore.profiles(from: defaults).count == 1, "deduplicate")
        try expect(UT99TouchProfileStore.delete(named: "ARENA", from: defaults), "case-insensitive delete")
        try expect(UT99TouchProfileStore.profiles(from: defaults).isEmpty, "delete persistence")

        var bad = profile()
        bad.schemaVersion = 2
        do { _ = try UT99TouchProfileStore.validated(bad); throw Failure.message("schema accepted") }
        catch UT99TouchProfileError.unsupportedSchema(2) {}
        bad = profile(); bad.preset = "mystery"
        do { _ = try UT99TouchProfileStore.validated(bad); throw Failure.message("preset accepted") }
        catch UT99TouchProfileError.unsupportedPreset("mystery") {}
        bad = profile(); bad.placements["mystery"] = .init(x: 0.5, y: 0.5, scale: 1)
        do { _ = try UT99TouchProfileStore.validated(bad); throw Failure.message("control accepted") }
        catch UT99TouchProfileError.unsupportedControl("mystery") {}
        do { _ = try UT99TouchProfileStore.decode(Data(repeating: 0, count: UT99TouchProfileStore.maxImportBytes + 1)); throw Failure.message("oversize accepted") }
        catch UT99TouchProfileError.oversizedImport {}

        try expect(UT99TouchProfileStore.exportFileName(for: profile(named: "Arena / Southpaw")) == "Arena--Southpaw.ut99touch", "safe filename")
        print("TouchProfileStoreTests: PASS")
    }
}
