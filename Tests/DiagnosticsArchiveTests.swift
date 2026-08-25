import Foundation

private struct TestFailure: Error { let message: String }

@main
private enum DiagnosticsArchiveTests {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("ut99-diagnostics-archive-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let archiveURL = root.appendingPathComponent("diagnostics.zip")
        let diagnosticText = "path=/Users/tester/Library old=/Users/another/Build linux=/home/player/Data token=abc123 password:seekrit server=192.0.2.1"
        let redacted = UT99DiagnosticRedactor.redact(diagnosticText, homeDirectory: "/container/home")
        try require(redacted.contains("<home>/Library"), "home directory was not redacted")
        try require(redacted.contains("old=<home>/Build"), "historical macOS home path was not redacted")
        try require(redacted.contains("linux=<home>/Data"), "Linux home path was not redacted")
        try require(redacted.contains("token=<redacted>"), "token was not redacted")
        try require(redacted.contains("password=<redacted>"), "password was not redacted")
        try require(!redacted.contains("tester") && !redacted.contains("another") && !redacted.contains("player"), "account name survived redaction")
        try require(!redacted.contains("abc123") && !redacted.contains("seekrit"), "secret survived redaction")

        try UT99DiagnosticsArchive.write(entries: [
            ("diagnostics.txt", Data(redacted.utf8)),
            ("recovery/UT99-last-failure.json", Data(#"{"state":"Crashed"}"#.utf8))
        ], to: archiveURL)
        let bytes = try Data(contentsOf: archiveURL)
        try require(bytes.starts(with: [0x50, 0x4b, 0x03, 0x04]), "local ZIP header missing")
        try require(bytes.suffix(22).starts(with: [0x50, 0x4b, 0x05, 0x06]), "ZIP end record missing")

        try requireRejected("../escape.txt", root: root)
        try requireRejected("/absolute.txt", root: root)
        try requireRejected("nested\\windows.txt", root: root)
        do {
            try UT99DiagnosticsArchive.write(entries: [], to: root.appendingPathComponent("empty.zip"))
            throw TestFailure(message: "empty archive was accepted")
        } catch is UT99DiagnosticsArchiveError {}
        do {
            try UT99DiagnosticsArchive.write(entries: [
                ("same.txt", Data()), ("same.txt", Data())
            ], to: root.appendingPathComponent("duplicate.zip"))
            throw TestFailure(message: "duplicate names were accepted")
        } catch is UT99DiagnosticsArchiveError {}

        guard CommandLine.arguments.count > 1 else {
            throw TestFailure(message: "expected output archive path")
        }
        let requestedURL = URL(fileURLWithPath: CommandLine.arguments[1])
        try fileManager.createDirectory(at: requestedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.copyItem(at: archiveURL, to: requestedURL)
        print("UT99 diagnostics archive PASS redaction=true traversal=true empty=true duplicates=true zip=\(requestedURL.path)")
    }

    private static func requireRejected(_ name: String, root: URL) throws {
        do {
            try UT99DiagnosticsArchive.write(
                entries: [(name, Data("unsafe".utf8))],
                to: root.appendingPathComponent("unsafe.zip")
            )
            throw TestFailure(message: "unsafe entry accepted: \(name)")
        } catch is UT99DiagnosticsArchiveError {}
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure(message: message) }
    }
}
