import CryptoKit
import Foundation

@main
struct DataImportTransactionTests {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("UT99DataImportTransactionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let system = root.appendingPathComponent("System", isDirectory: true)
        let oldMaps = root.appendingPathComponent("Maps", isDirectory: true)
        try fileManager.createDirectory(at: system, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: oldMaps, withIntermediateDirectories: true)
        try Data("system-must-survive".utf8).write(to: system.appendingPathComponent("keep.txt"))
        try Data("old-map".utf8).write(to: oldMaps.appendingPathComponent("old.unr"))
        try manifest(source: "old", files: [("Maps/old.unr", Data("old-map".utf8))])
            .write(to: root.appendingPathComponent(UT99DataImportTransaction.manifestName))

        let interrupted = try staging(in: root, name: ".import-staging-interrupted", marker: "interrupted")
        do {
            try UT99DataImportTransaction.commit(
                stagedRoot: interrupted.root,
                manifestData: interrupted.manifest,
                to: root,
                failAfterInstalledItemCount: 2,
                recoverAfterFailure: false
            )
            throw TestFailure("forced interruption unexpectedly committed")
        } catch is TestFailure {
            throw TestFailure("forced interruption unexpectedly committed")
        } catch {
            // The incomplete transaction and journal deliberately remain.
        }

        guard try UT99DataImportTransaction.recoverInterruptedCommit(at: root) else {
            throw TestFailure("interrupted transaction was not discovered")
        }
        try expect(root.appendingPathComponent("Maps/old.unr"), equals: "old-map")
        try expect(system.appendingPathComponent("keep.txt"), equals: "system-must-survive")
        guard !fileManager.fileExists(atPath: root.appendingPathComponent("Maps/interrupted.unr").path) else {
            throw TestFailure("partial replacement survived rollback")
        }

        let successful = try staging(in: root, name: ".import-staging-success", marker: "new")
        try UT99DataImportTransaction.commit(
            stagedRoot: successful.root,
            manifestData: successful.manifest,
            to: root
        )
        try expect(root.appendingPathComponent("Maps/new.unr"), equals: "new-Maps")
        try expect(system.appendingPathComponent("keep.txt"), equals: "system-must-survive")
        guard !fileManager.fileExists(atPath: root.appendingPathComponent("Maps/old.unr").path) else {
            throw TestFailure("successful replacement retained stale content")
        }

        let inspection = try UT99DataImportTransaction.inspectInstalledManifest(at: root)
        guard inspection.isValid, inspection.expectedFiles == 4, inspection.validFiles == 4 else {
            throw TestFailure("installed manifest did not verify")
        }

        let installedManifestBeforeCancellation = try Data(
            contentsOf: root.appendingPathComponent(UT99DataImportTransaction.manifestName)
        )
        let cancellationSource = root.appendingPathComponent("cancellation-source", isDirectory: true)
        try writeImportSource(at: cancellationSource, marker: "cancelled")
        let cancellation = UT99ImportCancellation()
        do {
            _ = try UT99DataImporter.importFolder(
                cancellationSource,
                to: root,
                cancellation: cancellation
            ) { update in
                if update.phase == .copying, update.completedFiles == 1 {
                    cancellation.cancel()
                }
            }
            throw TestFailure("cancelled preparation unexpectedly committed")
        } catch is UT99ImportCancelled {
            // Expected: staging is discarded before the transaction begins.
        }
        try expect(root.appendingPathComponent("Maps/new.unr"), equals: "new-Maps")
        let installedManifestAfterCancellation = try Data(
            contentsOf: root.appendingPathComponent(UT99DataImportTransaction.manifestName)
        )
        guard installedManifestAfterCancellation == installedManifestBeforeCancellation else {
            throw TestFailure("cancelled import replaced the installed manifest")
        }

        let hashCancellationFile = root.appendingPathComponent("hash-cancellation.bin")
        try Data(repeating: 0x5a, count: 2_200_000).write(to: hashCancellationFile)
        var hashChecks = 0
        do {
            _ = try UT99DataImportTransaction.fingerprint(of: hashCancellationFile) {
                hashChecks += 1
                return hashChecks > 1
            }
            throw TestFailure("streaming hash ignored cancellation")
        } catch is UT99ImportCancelled {
            // Expected between the first and second 1 MiB chunks.
        }
        try fileManager.removeItem(at: hashCancellationFile)

        let committingBoundary = UT99ImportCancellation()
        guard committingBoundary.beginCommit(), !committingBoundary.cancel(), !committingBoundary.isCancelled else {
            throw TestFailure("commit boundary did not atomically reject late cancellation")
        }
        let cancelledBoundary = UT99ImportCancellation()
        guard cancelledBoundary.cancel(), !cancelledBoundary.beginCommit(), cancelledBoundary.isCancelled else {
            throw TestFailure("cancel boundary did not atomically reject commit")
        }

        let leftovers = try fileManager.contentsOfDirectory(atPath: root.path)
            .filter { $0.hasPrefix(".import-") || $0 == ".ut99-import-transaction.json" }
        guard leftovers.isEmpty else {
            throw TestFailure("transaction debris remained: \(leftovers)")
        }

        print("UT99 data transaction PASS rollback=true replacement=true cancellation=true atomicBoundary=true hashCancellation=true manifest=4/4 systemPreserved=true")
    }

    private static func staging(in root: URL, name: String, marker: String) throws -> (root: URL, manifest: Data) {
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
        return (staging, try manifest(source: marker, files: files))
    }

    private static func manifest(source: String, files: [(String, Data)]) throws -> Data {
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

    private static func writeImportSource(at root: URL, marker: String) throws {
        for directory in UT99DataImportTransaction.contentDirectoryNames {
            let folder = root.appendingPathComponent(directory, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let filename = directory == "Maps" ? "\(marker).unr" : "\(marker).dat"
            try Data("\(marker)-\(directory)".utf8).write(to: folder.appendingPathComponent(filename))
        }
    }

    private static func expect(_ url: URL, equals expected: String) throws {
        guard let actual = try? String(contentsOf: url, encoding: .utf8), actual == expected else {
            throw TestFailure("unexpected contents at \(url.lastPathComponent)")
        }
    }

    private struct TestFailure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
