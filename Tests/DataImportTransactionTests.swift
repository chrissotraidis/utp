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

        try legacyRecoveryTests(in: root)

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

        // A failed rollback must itself be safely retryable. The old implementation
        // consumed each backup as it restored it, then deleted that restored data
        // when a later launch retried the still-committing journal.
        do {
            _ = try UT99DataImportTransaction.recoverInterruptedCommit(
                at: root,
                failAfterRestoredItemCount: 1
            )
            throw TestFailure("forced recovery interruption unexpectedly completed")
        } catch is TestFailure {
            throw TestFailure("forced recovery interruption unexpectedly completed")
        } catch {
            // Simulates termination or an I/O error after restoring Maps.
        }
        try expect(root.appendingPathComponent("Maps/old.unr"), equals: "old-map")

        guard try UT99DataImportTransaction.recoverInterruptedCommit(at: root) else {
            throw TestFailure("interrupted transaction was not discovered")
        }
        try expect(root.appendingPathComponent("Maps/old.unr"), equals: "old-map")
        try expect(system.appendingPathComponent("keep.txt"), equals: "system-must-survive")
        guard !fileManager.fileExists(atPath: root.appendingPathComponent("Maps/interrupted.unr").path) else {
            throw TestFailure("partial replacement survived rollback")
        }

        // Simulate a crash during cleanup after the completed-rollback checkpoint.
        // An incomplete backup must be cleaned up without touching restored data.
        let cleanupBackup = root.appendingPathComponent(".import-backup-cleanup", isDirectory: true)
        let cleanupStaging = root.appendingPathComponent(".import-staging-cleanup", isDirectory: true)
        try fileManager.createDirectory(at: cleanupBackup, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cleanupStaging, withIntermediateDirectories: true)
        let cleanupJournal: [String: Any] = [
            "format": 2,
            "backupDirectoryName": cleanupBackup.lastPathComponent,
            "stagingDirectoryName": cleanupStaging.lastPathComponent,
            "managedItemNames": UT99DataImportTransaction.contentDirectoryNames + [UT99DataImportTransaction.manifestName],
            "phase": "restored"
        ]
        try JSONSerialization.data(withJSONObject: cleanupJournal).write(
            to: root.appendingPathComponent(".ut99-import-transaction.json")
        )
        guard try UT99DataImportTransaction.recoverInterruptedCommit(at: root) else {
            throw TestFailure("interrupted rollback cleanup was not discovered")
        }
        try expect(root.appendingPathComponent("Maps/old.unr"), equals: "old-map")
        guard !fileManager.fileExists(atPath: cleanupBackup.path),
              !fileManager.fileExists(atPath: cleanupStaging.path) else {
            throw TestFailure("interrupted rollback cleanup left transaction data")
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

        try Data("player-user-settings".utf8).write(to: system.appendingPathComponent("User.ini"))
        let runtimeSource = root.appendingPathComponent("runtime-source", isDirectory: true)
        try writeRuntimeImportSource(at: runtimeSource)
        let runtimeImported = try UT99DataImporter.importFolder(
            runtimeSource,
            to: root,
            cancellation: UT99ImportCancellation()
        ) { _ in }
        guard runtimeImported == 16,
              UT99RuntimeSupport.missingRequiredFiles(at: root).isEmpty,
              !UT99RuntimeSupport.isReady(at: root) else {
            throw TestFailure("runtime-support import was incomplete: \(runtimeImported)")
        }
        try expect(system.appendingPathComponent("User.ini"), equals: "player-user-settings")
        try expect(system.appendingPathComponent("Core.u"), equals: "runtime-Core.u")
        try expect(system.appendingPathComponent("keep.txt"), equals: "system-must-survive")
        guard !fileManager.fileExists(atPath: system.appendingPathComponent("Engine.dll").path),
              fileManager.fileExists(atPath: system.appendingPathComponent("DefaultUser.ini").path) else {
            throw TestFailure("runtime native-code filter or DefaultUser alias failed")
        }
        let runtimeInspection = try UT99DataImportTransaction.inspectInstalledManifest(at: root)
        guard runtimeInspection.isValid, runtimeInspection.expectedFiles == 16 else {
            throw TestFailure("runtime-support manifest did not verify")
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

        print("UT99 data transaction PASS rollback=true rollbackRetry=true rollbackCleanup=true replacement=true cancellation=true atomicBoundary=true hashCancellation=true runtimeSupport=true systemPreserved=true")
    }

    private static func legacyRecoveryTests(in parent: URL) throws {
        let fm = FileManager.default
        let root = parent.appendingPathComponent("legacy-recovery")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let journalURL = root.appendingPathComponent(".ut99-import-transaction.json")
        let backup = root.appendingPathComponent(".import-backup-legacy")
        let oldStaging = try staging(in: root, name: ".import-staging-legacy", marker: "interrupted")
        for name in ["Maps", "Music"] {
            try fm.createDirectory(at: backup.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        try Data("old-map".utf8).write(to: backup.appendingPathComponent("Maps/old.unr"))
        try Data("old-music".utf8).write(to: backup.appendingPathComponent("Music/old.umx"))
        try fm.createDirectory(at: root.appendingPathComponent("Maps"), withIntermediateDirectories: true)
        try Data("partial-new-map".utf8).write(to: root.appendingPathComponent("Maps/interrupted.unr"))
        let legacy: [String: Any] = [
            "format": 2, "phase": "committing",
            "backupDirectoryName": backup.lastPathComponent,
            "stagingDirectoryName": oldStaging.root.lastPathComponent,
            "managedItemNames": UT99DataImportTransaction.contentDirectoryNames + [UT99DataImportTransaction.manifestName]
        ]
        let legacyData = try JSONSerialization.data(withJSONObject: legacy, options: .sortedKeys)
        try legacyData.write(to: journalURL)
        // Exactly the first v0.1.0 rollback iteration: remove the new Maps and
        // consume its backup. Simulate interruption before the Music iteration.
        try fm.removeItem(at: root.appendingPathComponent("Maps"))
        try fm.moveItem(at: backup.appendingPathComponent("Maps"), to: root.appendingPathComponent("Maps"))
        do {
            _ = try UT99DataImportTransaction.recoverInterruptedCommit(at: root)
            throw TestFailure("legacy rollback unexpectedly completed; restored Maps survives=\(fm.fileExists(atPath: root.appendingPathComponent("Maps/old.unr").path))")
        } catch is TestFailure {
            throw TestFailure("legacy consumed-backup recovery did not preserve-and-stop")
        } catch {
            guard error.localizedDescription.contains("repair") else { throw error }
        }
        try expect(root.appendingPathComponent("Maps/old.unr"), equals: "old-map")
        try expect(backup.appendingPathComponent("Music/old.umx"), equals: "old-music")
        guard try Data(contentsOf: journalURL) == legacyData else { throw TestFailure("legacy journal changed") }

        // A replacement that fails even before new backups are ready must leave
        // the old active journal and its recovery sources untouched.
        do {
            try UT99DataImportTransaction.commit(stagedRoot: root.appendingPathComponent(".import-staging-missing"),
                                                manifestData: Data("{}".utf8), to: root)
            throw TestFailure("missing staged replacement unexpectedly committed")
        } catch is TestFailure { throw TestFailure("missing staged replacement unexpectedly committed") }
        catch { }
        guard try Data(contentsOf: journalURL) == legacyData else { throw TestFailure("preparation failure removed legacy marker") }
        let backupNames = try fm.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix(".import-backup-") }
        guard backupNames == [backup.lastPathComponent] else { throw TestFailure("failed preparation leaked a backup") }
        try expect(root.appendingPathComponent("Maps/old.unr"), equals: "old-map")

        let failed = try staging(in: root, name: ".import-staging-repair-failed", marker: "failed")
        do {
            try UT99DataImportTransaction.commit(stagedRoot: failed.root, manifestData: failed.manifest, to: root,
                                                failAfterInstalledItemCount: 1)
            throw TestFailure("failed repair unexpectedly committed")
        } catch is TestFailure { throw TestFailure("failed repair unexpectedly committed") }
        catch { }
        guard try Data(contentsOf: journalURL) == legacyData else { throw TestFailure("failed repair did not restore prior journal") }
        try expect(root.appendingPathComponent("Maps/old.unr"), equals: "old-map")
        try expect(backup.appendingPathComponent("Music/old.umx"), equals: "old-music")

        // Reproduce a crash during new rollback cleanup: restored live files and
        // checkpoint remain, but that new backup has already been removed.
        let cleanup = try staging(in: root, name: ".import-staging-repair-cleanup", marker: "cleanup")
        do {
            try UT99DataImportTransaction.commit(stagedRoot: cleanup.root, manifestData: cleanup.manifest, to: root,
                                                failAfterInstalledItemCount: 1, recoverAfterFailure: false)
        } catch { }
        var cleanupJournal = try JSONSerialization.jsonObject(with: Data(contentsOf: journalURL)) as! [String: Any]
        let cleanupBackup = root.appendingPathComponent(cleanupJournal["backupDirectoryName"] as! String)
        try fm.removeItem(at: root.appendingPathComponent("Maps"))
        try fm.copyItem(at: cleanupBackup.appendingPathComponent("Maps"), to: root.appendingPathComponent("Maps"))
        cleanupJournal["phase"] = "restored"
        try JSONSerialization.data(withJSONObject: cleanupJournal).write(to: journalURL, options: .atomic)
        try fm.removeItem(at: cleanupBackup)
        do {
            _ = try UT99DataImportTransaction.recoverInterruptedCommit(at: root)
            throw TestFailure("unfinished older repair was cleared by cleanup")
        } catch is TestFailure { throw TestFailure("unfinished older repair was cleared by cleanup") }
        catch { }
        guard try Data(contentsOf: journalURL) == legacyData else { throw TestFailure("cleanup did not restore prior journal") }
        try expect(root.appendingPathComponent("Maps/old.unr"), equals: "old-map")

        let repaired = try staging(in: root, name: ".import-staging-repaired", marker: "repaired")
        try UT99DataImportTransaction.commit(stagedRoot: repaired.root, manifestData: repaired.manifest, to: root)
        try expect(root.appendingPathComponent("Maps/repaired.unr"), equals: "repaired-Maps")
        guard !fm.fileExists(atPath: journalURL.path),
              try UT99DataImportTransaction.inspectInstalledManifest(at: root).isValid else {
            throw TestFailure("valid explicit repair did not become ready")
        }
        try expect(backup.appendingPathComponent("Music/old.umx"), equals: "old-music")
        guard fm.fileExists(atPath: oldStaging.root.path),
              try fm.contentsOfDirectory(atPath: root.path).contains(where: { $0.hasPrefix(".ut99-import-preserved-") }) else {
            throw TestFailure("successful repair erased legacy recovery sources")
        }

        let incomplete = try staging(in: root, name: ".import-staging-incomplete-backup", marker: "incomplete")
        do {
            try UT99DataImportTransaction.commit(stagedRoot: incomplete.root, manifestData: incomplete.manifest, to: root,
                                                failAfterInstalledItemCount: 2, recoverAfterFailure: false)
        } catch { }
        let journalData = try Data(contentsOf: journalURL)
        let journal = try JSONSerialization.jsonObject(with: journalData) as! [String: Any]
        guard journal["format"] as? Int == 3,
              (journal["originalItemNames"] as? [String])?.contains("Music") == true else {
            throw TestFailure("new journal did not record original items")
        }
        let missingBackup = root.appendingPathComponent(journal["backupDirectoryName"] as! String)
        try fm.removeItem(at: missingBackup.appendingPathComponent("Music"))
        do {
            _ = try UT99DataImportTransaction.recoverInterruptedCommit(at: root)
            throw TestFailure("incomplete recorded backup was accepted")
        } catch is TestFailure { throw TestFailure("incomplete recorded backup was accepted") }
        catch { }
        try expect(root.appendingPathComponent("Maps/incomplete.unr"), equals: "incomplete-Maps")
        try expect(root.appendingPathComponent("Music/incomplete.dat"), equals: "incomplete-Music")
        guard try Data(contentsOf: journalURL) == journalData else { throw TestFailure("incomplete-backup journal changed") }
        for format in [1, 2] {
            let compatible = root.appendingPathComponent("complete-legacy-\(format)")
            try fm.createDirectory(at: compatible, withIntermediateDirectories: true)
            let completeBackup = try staging(in: compatible, name: ".import-backup-complete", marker: "original")
            try completeBackup.manifest.write(to: completeBackup.root.appendingPathComponent(UT99DataImportTransaction.manifestName))
            let completeStaging = try staging(in: compatible, name: ".import-staging-complete", marker: "replacement")
            let compatibleJournal: [String: Any] = [
                "format": format, "phase": "committing",
                "backupDirectoryName": completeBackup.root.lastPathComponent,
                "stagingDirectoryName": completeStaging.root.lastPathComponent
            ]
            try JSONSerialization.data(withJSONObject: compatibleJournal)
                .write(to: compatible.appendingPathComponent(".ut99-import-transaction.json"))
            guard try UT99DataImportTransaction.recoverInterruptedCommit(at: compatible),
                  try UT99DataImportTransaction.inspectInstalledManifest(at: compatible).isValid else {
                throw TestFailure("complete legacy backup did not recover")
            }
            try expect(compatible.appendingPathComponent("Maps/original.unr"), equals: "original-Maps")
        }
        let empty = root.appendingPathComponent("originally-empty")
        try fm.createDirectory(at: empty, withIntermediateDirectories: true)
        let firstImport = try staging(in: empty, name: ".import-staging-first", marker: "first")
        do {
            try UT99DataImportTransaction.commit(stagedRoot: firstImport.root, manifestData: firstImport.manifest, to: empty,
                                                failAfterInstalledItemCount: 1, recoverAfterFailure: false)
        } catch { }
        guard try UT99DataImportTransaction.recoverInterruptedCommit(at: empty),
              !fm.fileExists(atPath: empty.appendingPathComponent("Maps").path),
              !fm.fileExists(atPath: empty.appendingPathComponent(".ut99-import-transaction.json").path) else {
            throw TestFailure("format-3 rollback did not remove an originally absent item")
        }
        print("UT99 legacy recovery PASS consumedBackup=true preparationFailure=true repairRollback=true cleanupRetry=true explicitRepair=true missingBackup=true completeLegacy=true originallyAbsent=true")
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

    private static func writeRuntimeImportSource(at root: URL) throws {
        try writeImportSource(at: root, marker: "runtime")
        let system = root.appendingPathComponent(UT99RuntimeSupport.systemDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: system, withIntermediateDirectories: true)
        for name in UT99RuntimeSupport.requiredSystemFileNames {
            try Data("runtime-\(name)".utf8).write(to: system.appendingPathComponent(name))
        }
        let textures = root.appendingPathComponent("Textures", isDirectory: true)
        for name in UT99RuntimeSupport.requiredTextureFileNames {
            try Data("runtime-\(name)".utf8).write(to: textures.appendingPathComponent(name))
        }
        try Data("native".utf8).write(to: system.appendingPathComponent("Engine.dll"))
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
