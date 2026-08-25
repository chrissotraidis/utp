import Foundation

struct UT99RuntimeSessionRecord: Codable, Equatable {
    static let formatVersion = 1

    let format: Int
    let sessionID: String
    let startedAt: String
    var updatedAt: String
    var state: String
    let appVersion: String
    let appBuild: String
    let safeMode: Bool
    var terminationReason: String?
}

/// Persists only bounded, redacted host state. An active marker is created
/// before the original entry is invoked and removed only after a controlled
/// return/failure. If it survives process death, the next host launch archives
/// it as the last interrupted session before offering recovery choices.
final class UT99RuntimeRecovery {
    static let activeMarkerName = "UT99-active-session.json"
    static let lastFailureName = "UT99-last-failure.json"
    static let lastCleanSessionName = "UT99-last-clean-session.json"

    private let root: URL
    private let now: () -> Date
    private let makeSessionID: () -> String
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    init(
        root: URL,
        now: @escaping () -> Date = Date.init,
        makeSessionID: @escaping () -> String = { UUID().uuidString }
    ) {
        self.root = root
        self.now = now
        self.makeSessionID = makeSessionID
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    var activeMarkerURL: URL { root.appendingPathComponent(Self.activeMarkerName) }
    var lastFailureURL: URL { root.appendingPathComponent(Self.lastFailureName) }
    var lastCleanSessionURL: URL { root.appendingPathComponent(Self.lastCleanSessionName) }

    @discardableResult
    func beginSession(appVersion: String, appBuild: String, safeMode: Bool) throws -> UT99RuntimeSessionRecord {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let timestamp = timestampNow()
        let record = UT99RuntimeSessionRecord(
            format: UT99RuntimeSessionRecord.formatVersion,
            sessionID: makeSessionID(),
            startedAt: timestamp,
            updatedAt: timestamp,
            state: "StartingEngine",
            appVersion: appVersion,
            appBuild: appBuild,
            safeMode: safeMode,
            terminationReason: nil
        )
        try write(record, to: activeMarkerURL)
        return record
    }

    @discardableResult
    func updateActiveState(_ state: String) throws -> UT99RuntimeSessionRecord? {
        guard var record = try readActiveRecord() else { return nil }
        record.state = state
        record.updatedAt = timestampNow()
        try write(record, to: activeMarkerURL)
        return record
    }

    @discardableResult
    func recoverAbandonedSession() throws -> UT99RuntimeSessionRecord? {
        guard FileManager.default.fileExists(atPath: activeMarkerURL.path) else { return nil }
        let record: UT99RuntimeSessionRecord
        do {
            guard var decoded = try readActiveRecord() else { return nil }
            decoded.state = "Crashed"
            decoded.updatedAt = timestampNow()
            decoded.terminationReason = "Previous process ended without controlled engine completion"
            record = decoded
        } catch {
            let timestamp = timestampNow()
            record = UT99RuntimeSessionRecord(
                format: UT99RuntimeSessionRecord.formatVersion,
                sessionID: "unreadable-marker",
                startedAt: timestamp,
                updatedAt: timestamp,
                state: "Crashed",
                appVersion: "unknown",
                appBuild: "unknown",
                safeMode: false,
                terminationReason: "Previous active-session marker was unreadable"
            )
        }
        try write(record, to: lastFailureURL)
        try FileManager.default.removeItem(at: activeMarkerURL)
        return record
    }

    @discardableResult
    func recordFailure(_ reason: String) throws -> UT99RuntimeSessionRecord? {
        guard var record = try readActiveRecord() else { return nil }
        record.state = "Crashed"
        record.updatedAt = timestampNow()
        record.terminationReason = sanitized(reason)
        try write(record, to: lastFailureURL)
        try FileManager.default.removeItem(at: activeMarkerURL)
        return record
    }

    @discardableResult
    func finishCleanly(_ reason: String) throws -> UT99RuntimeSessionRecord? {
        guard var record = try readActiveRecord() else { return nil }
        record.state = "StoppingEngine"
        record.updatedAt = timestampNow()
        record.terminationReason = sanitized(reason)
        try write(record, to: lastCleanSessionURL)
        try FileManager.default.removeItem(at: activeMarkerURL)
        return record
    }

    func diagnosticSummary() -> String {
        let active = summary(at: activeMarkerURL, absent: "none")
        let failure = summary(at: lastFailureURL, absent: "none")
        let clean = summary(at: lastCleanSessionURL, absent: "none")
        return "Recovery active=\(active) lastFailure=\(failure) lastClean=\(clean)"
    }

    /// Include the bounded session records themselves in diagnostic exports.
    /// These files contain no paths, arguments, account data, or engine logs.
    func diagnosticArtifacts() -> [(String, Data)] {
        [activeMarkerURL, lastFailureURL, lastCleanSessionURL].compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return ("recovery/\(url.lastPathComponent)", data)
        }
    }

    func seedAbandonedSessionForTesting(appVersion: String, appBuild: String) throws {
        _ = try beginSession(appVersion: appVersion, appBuild: appBuild, safeMode: false)
        _ = try updateActiveState("Running")
    }

    private func readActiveRecord() throws -> UT99RuntimeSessionRecord? {
        guard FileManager.default.fileExists(atPath: activeMarkerURL.path) else { return nil }
        return try decoder.decode(UT99RuntimeSessionRecord.self, from: Data(contentsOf: activeMarkerURL))
    }

    private func write(_ record: UT99RuntimeSessionRecord, to url: URL) throws {
        try encoder.encode(record).write(to: url, options: .atomic)
    }

    private func summary(at url: URL, absent: String) -> String {
        guard let data = try? Data(contentsOf: url),
              let record = try? decoder.decode(UT99RuntimeSessionRecord.self, from: data) else {
            return FileManager.default.fileExists(atPath: url.path) ? "unreadable" : absent
        }
        let mode = record.safeMode ? "safe" : "normal"
        return "\(record.state)/\(mode)/\(record.updatedAt)"
    }

    private func timestampNow() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: now())
    }

    private func sanitized(_ text: String) -> String {
        String(text.replacingOccurrences(of: "\n", with: " ").prefix(240))
    }
}
