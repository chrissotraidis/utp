import CryptoKit
import Foundation

struct UT99ImportCancelled: LocalizedError {
    var errorDescription: String? { "Import cancelled; installed data was unchanged" }
}

struct UT99ImportRecoveryRequired: LocalizedError {
    var errorDescription: String? {
        "An interrupted import needs repair. Existing files and recovery backups were retained. Use Get Game Data or Import Files to install a verified replacement."
    }
}

/// Installs user-owned UT99 content without exposing the live data set to a
/// partial merge. A complete backup and an atomic journal are written before
/// any live content is replaced. An interrupted commit is either rolled back
/// or finalized on the next host launch according to the journal phase.
enum UT99DataImportTransaction {
    static let contentDirectoryNames = ["Maps", "Music", "Sounds", "Textures"]
    static let manifestName = "UT99-import-manifest.json"

    struct Inspection {
        let sourceName: String
        let expectedFiles: Int
        let validFiles: Int
        let missingFiles: Int
        let mismatchedFiles: Int
        let totalBytes: UInt64

        var isValid: Bool {
            expectedFiles > 0 && validFiles == expectedFiles &&
                missingFiles == 0 && mismatchedFiles == 0
        }
    }

    private enum Phase: String, Codable {
        case committing
        case installed
        case restored
    }

    private struct Journal: Codable {
        let format: Int
        let backupDirectoryName: String
        let stagingDirectoryName: String
        let managedItemNames: [String]?
        let originalItemNames: [String]?
        let priorJournalName: String?
        var phase: Phase
    }

    private static let journalName = ".ut99-import-transaction.json"

    static func commit(
        stagedRoot: URL,
        manifestData: Data,
        to supportRoot: URL,
        failAfterInstalledItemCount: Int? = nil,
        recoverAfterFailure: Bool = true
    ) throws {
        let fileManager = FileManager.default
        guard stagedRoot.deletingLastPathComponent().standardizedFileURL == supportRoot.standardizedFileURL else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        try fileManager.createDirectory(at: supportRoot, withIntermediateDirectories: true)
        let journalURL = supportRoot.appendingPathComponent(journalName)
        var priorJournalName: String?
        do {
            _ = try recoverInterruptedCommit(at: supportRoot)
        } catch is UT99ImportRecoveryRequired {
            // Only an explicitly prepared replacement may supersede unresolved
            // recovery. Keep the active journal until the new one replaces it.
            let archiveName = ".ut99-import-preserved-\(UUID().uuidString).json"
            try fileManager.copyItem(at: journalURL, to: supportRoot.appendingPathComponent(archiveName))
            priorJournalName = archiveName
        }

        let transactionID = UUID().uuidString
        let backupName = ".import-backup-\(transactionID)"
        let backupRoot = supportRoot.appendingPathComponent(backupName, isDirectory: true)
        try fileManager.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        var journalPublished = false
        defer {
            if !journalPublished {
                let activeBackup = (try? Data(contentsOf: journalURL))
                    .flatMap { try? JSONDecoder().decode(Journal.self, from: $0) }?.backupDirectoryName
                // If atomic publication failed ambiguously, retain the backup
                // unless the active journal is absent or belongs to another set.
                if !fileManager.fileExists(atPath: journalURL.path) || (activeBackup != nil && activeBackup != backupName) {
                    try? fileManager.removeItem(at: backupRoot)
                }
            }
        }

        let manifestURL = stagedRoot.appendingPathComponent(manifestName)
        try manifestData.write(to: manifestURL, options: .atomic)
        var managedItemNames = contentDirectoryNames + [manifestName]
        if fileManager.fileExists(
            atPath: stagedRoot.appendingPathComponent(UT99RuntimeSupport.systemDirectoryName).path
        ) {
            managedItemNames.append(UT99RuntimeSupport.systemDirectoryName)
        }

        // Copy the complete last-known-good set before publishing a journal.
        // Therefore a committing journal always points at a usable rollback.
        var originalItemNames: [String] = []
        for name in managedItemNames {
            let current = supportRoot.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: current.path) else { continue }
            try fileManager.copyItem(at: current, to: backupRoot.appendingPathComponent(name))
            originalItemNames.append(name)
        }

        var journal = Journal(
            format: 3,
            backupDirectoryName: backupName,
            stagingDirectoryName: stagedRoot.lastPathComponent,
            managedItemNames: managedItemNames,
            originalItemNames: originalItemNames,
            priorJournalName: priorJournalName,
            phase: .committing
        )
        try writeJournal(journal, to: journalURL)
        journalPublished = true

        do {
            for name in managedItemNames {
                let current = supportRoot.appendingPathComponent(name)
                if fileManager.fileExists(atPath: current.path) {
                    try fileManager.removeItem(at: current)
                }
            }

            var installedItems = 0
            for name in managedItemNames {
                let staged = stagedRoot.appendingPathComponent(name)
                guard fileManager.fileExists(atPath: staged.path) else { continue }
                try fileManager.moveItem(at: staged, to: supportRoot.appendingPathComponent(name))
                installedItems += 1
                if failAfterInstalledItemCount == installedItems {
                    throw CocoaError(.fileWriteUnknown)
                }
            }

            journal.phase = .installed
            try writeJournal(journal, to: journalURL)
            try fileManager.removeItem(at: backupRoot)
            try? fileManager.removeItem(at: stagedRoot)
            try fileManager.removeItem(at: journalURL)
        } catch {
            if recoverAfterFailure {
                _ = try? recoverInterruptedCommit(at: supportRoot)
            }
            throw error
        }
    }

    @discardableResult
    static func recoverInterruptedCommit(
        at supportRoot: URL,
        failAfterRestoredItemCount: Int? = nil
    ) throws -> Bool {
        let fileManager = FileManager.default
        let journalURL = supportRoot.appendingPathComponent(journalName)
        guard fileManager.fileExists(atPath: journalURL.path) else { return false }

        var journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: journalURL))
        let backupRoot = supportRoot.appendingPathComponent(journal.backupDirectoryName, isDirectory: true)
        let stagedRoot = supportRoot.appendingPathComponent(journal.stagingDirectoryName, isDirectory: true)
        let managedItemNames = journal.managedItemNames ?? (contentDirectoryNames + [manifestName])
        var priorJournalData: Data?
        if journal.phase != .installed, let priorName = journal.priorJournalName {
            guard priorName.hasPrefix(".ut99-import-preserved-"), priorName.hasSuffix(".json"),
                  !priorName.contains("/"), !priorName.contains("\\"),
                  let data = try? Data(contentsOf: supportRoot.appendingPathComponent(priorName)),
                  (try? JSONDecoder().decode(Journal.self, from: data)) != nil else {
                throw UT99ImportRecoveryRequired()
            }
            priorJournalData = data
        }

        if journal.phase == .committing {
            if journal.format >= 3 {
                guard journal.format == 3, let originalNames = journal.originalItemNames,
                      Set(originalNames).count == originalNames.count,
                      Set(originalNames).isSubset(of: Set(managedItemNames)),
                      Set(originalNames) == Set(managedItemNames.filter {
                          fileManager.fileExists(atPath: backupRoot.appendingPathComponent($0).path)
                      }) else {
                    throw UT99ImportRecoveryRequired()
                }
            } else if managedItemNames.contains(where: {
                !fileManager.fileExists(atPath: backupRoot.appendingPathComponent($0).path)
            }) {
                // Older recovery consumed backups as it restored them. A missing
                // backup might mean this live item is the last original copy.
                throw UT99ImportRecoveryRequired()
            }
            var restoredItems = 0
            for name in managedItemNames {
                let current = supportRoot.appendingPathComponent(name)
                if fileManager.fileExists(atPath: current.path) {
                    try fileManager.removeItem(at: current)
                }
                let backup = backupRoot.appendingPathComponent(name)
                if fileManager.fileExists(atPath: backup.path) {
                    // Keep the rollback source intact until every item has been
                    // restored. A failed recovery can then safely retry.
                    try fileManager.copyItem(at: backup, to: current)
                }
                restoredItems += 1
                if failAfterRestoredItemCount == restoredItems {
                    throw CocoaError(.fileWriteUnknown)
                }
            }
            // Checkpoint before removing any backups: an interrupted cleanup
            // must never replay rollback from an incomplete backup directory.
            journal.phase = .restored
            try writeJournal(journal, to: journalURL)
        }

        if fileManager.fileExists(atPath: backupRoot.path) {
            try fileManager.removeItem(at: backupRoot)
        }
        if fileManager.fileExists(atPath: stagedRoot.path) {
            try fileManager.removeItem(at: stagedRoot)
        }
        if journal.phase == .restored, let priorJournalData {
            // A failed replacement must not make unresolved older data look ready.
            // Keep the restored checkpoint active until the prior journal returns.
            try priorJournalData.write(to: journalURL, options: .atomic)
            throw UT99ImportRecoveryRequired()
        }
        try fileManager.removeItem(at: journalURL)
        return true
    }

    static func hasInterruptedCommit(at supportRoot: URL) -> Bool {
        FileManager.default.fileExists(atPath: supportRoot.appendingPathComponent(journalName).path)
    }

    static func inspectInstalledManifest(at supportRoot: URL) throws -> Inspection {
        let manifestURL = supportRoot.appendingPathComponent(manifestName)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL))
        guard let dictionary = object as? [String: Any],
              let files = dictionary["files"] as? [[String: Any]] else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var valid = 0
        var missing = 0
        var mismatched = 0
        var totalBytes: UInt64 = 0
        for entry in files {
            guard let relative = entry["path"] as? String,
                  let expectedHash = entry["sha256"] as? String,
                  !relative.hasPrefix("/"),
                  !relative.split(separator: "/").contains("..") else {
                mismatched += 1
                continue
            }
            let fileURL = supportRoot.appendingPathComponent(relative)
            guard let fingerprint = try? fingerprint(of: fileURL) else {
                missing += 1
                continue
            }
            let expectedSize = (entry["size"] as? NSNumber)?.uint64Value
            if fingerprint.sha256 == expectedHash && (expectedSize == nil || expectedSize == fingerprint.size) {
                valid += 1
                totalBytes += fingerprint.size
            } else {
                mismatched += 1
            }
        }

        return Inspection(
            sourceName: dictionary["source_root_name"] as? String ?? "unknown",
            expectedFiles: files.count,
            validFiles: valid,
            missingFiles: missing,
            mismatchedFiles: mismatched,
            totalBytes: totalBytes
        )
    }

    static func installedManifestURL(at supportRoot: URL) -> URL {
        supportRoot.appendingPathComponent(manifestName)
    }

    static func fingerprint(
        of url: URL,
        cancellationRequested: () -> Bool = { false }
    ) throws -> (sha256: String, size: UInt64) {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var size: UInt64 = 0
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            if cancellationRequested() { throw UT99ImportCancelled() }
            hasher.update(data: chunk)
            size += UInt64(chunk.count)
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return (digest, size)
    }

    private static func writeJournal(_ journal: Journal, to url: URL) throws {
        try JSONEncoder().encode(journal).write(to: url, options: .atomic)
    }
}
