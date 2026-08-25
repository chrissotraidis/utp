import Foundation

private struct TestFailure: Error { let message: String }

@main
private enum RuntimeRecoveryTests {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("ut99-runtime-recovery-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        var tick: TimeInterval = 1_700_000_000
        var identifier = 0
        let recovery = UT99RuntimeRecovery(
            root: root,
            now: { tick += 1; return Date(timeIntervalSince1970: tick) },
            makeSessionID: { identifier += 1; return "session-\(identifier)" }
        )

        let first = try recovery.beginSession(appVersion: "test", appBuild: "1", safeMode: false)
        try require(first.state == "StartingEngine", "session did not begin in StartingEngine")
        try require(fileManager.fileExists(atPath: recovery.activeMarkerURL.path), "active marker missing")
        _ = try recovery.updateActiveState("Running")
        let recovered = try recovery.recoverAbandonedSession()
        try require(recovered?.state == "Crashed", "abandoned marker did not recover as Crashed")
        try require(recovered?.terminationReason?.contains("without controlled") == true, "recovery reason missing")
        try require(!fileManager.fileExists(atPath: recovery.activeMarkerURL.path), "recovered active marker survived")
        try require(fileManager.fileExists(atPath: recovery.lastFailureURL.path), "last-failure marker missing")

        _ = try recovery.beginSession(appVersion: "test", appBuild: "2", safeMode: true)
        let failed = try recovery.recordFailure("dyld failed\nsecret second line")
        try require(failed?.safeMode == true, "safe-mode session was not recorded")
        try require(failed?.terminationReason == "dyld failed secret second line", "failure reason was not sanitized")

        _ = try recovery.beginSession(appVersion: "test", appBuild: "3", safeMode: false)
        _ = try recovery.updateActiveState("Running")
        let clean = try recovery.finishCleanly("engine returned 0")
        try require(clean?.state == "StoppingEngine", "clean session did not record StoppingEngine")
        try require(!fileManager.fileExists(atPath: recovery.activeMarkerURL.path), "clean active marker survived")
        try require(fileManager.fileExists(atPath: recovery.lastCleanSessionURL.path), "clean-session archive missing")

        try Data("not json".utf8).write(to: recovery.activeMarkerURL, options: .atomic)
        let corrupt = try recovery.recoverAbandonedSession()
        try require(corrupt?.sessionID == "unreadable-marker", "corrupt marker fallback missing")
        try require(!fileManager.fileExists(atPath: recovery.activeMarkerURL.path), "corrupt marker survived recovery")

        let summary = recovery.diagnosticSummary()
        try require(summary.contains("active=none"), "diagnostics report a stale active marker")
        try require(summary.contains("lastFailure=Crashed"), "diagnostics omit last failure")
        try require(summary.contains("lastClean=StoppingEngine"), "diagnostics omit clean session")
        let artifacts = recovery.diagnosticArtifacts()
        let artifactNames = Set(artifacts.map(\.0))
        try require(artifactNames.contains("recovery/UT99-last-failure.json"), "failure artifact missing")
        try require(artifactNames.contains("recovery/UT99-last-clean-session.json"), "clean artifact missing")
        try require(!artifactNames.contains("recovery/UT99-active-session.json"), "stale active artifact exported")
        try require(artifacts.allSatisfy { !$0.1.isEmpty }, "empty recovery artifact exported")
        print("UT99 runtime recovery PASS abandoned=true corrupt=true safeMode=true clean=true diagnostics=true artifacts=true")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure(message: message) }
    }
}
