import CryptoKit
import Foundation

struct UT99ImportCancelled: LocalizedError {
    var errorDescription: String? { "Import cancelled; installed data was unchanged" }
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
    }

    private struct Journal: Codable {
        let format: Int
        let backupDirectoryName: String
        let stagingDirectoryName: String
        let managedItemNames: [String]?
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
        _ = try recoverInterruptedCommit(at: supportRoot)

        let transactionID = UUID().uuidString
        let backupName = ".import-backup-\(transactionID)"
        let backupRoot = supportRoot.appendingPathComponent(backupName, isDirectory: true)
        let journalURL = supportRoot.appendingPathComponent(journalName)
        try fileManager.createDirectory(at: backupRoot, withIntermediateDirectories: true)

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
        for name in managedItemNames {
            let current = supportRoot.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: current.path) else { continue }
            try fileManager.copyItem(at: current, to: backupRoot.appendingPathComponent(name))
        }

        var journal = Journal(
            format: 2,
            backupDirectoryName: backupName,
            stagingDirectoryName: stagedRoot.lastPathComponent,
            managedItemNames: managedItemNames,
            phase: .committing
        )
        try writeJournal(journal, to: journalURL)

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
    static func recoverInterruptedCommit(at supportRoot: URL) throws -> Bool {
        let fileManager = FileManager.default
        let journalURL = supportRoot.appendingPathComponent(journalName)
        guard fileManager.fileExists(atPath: journalURL.path) else { return false }

        let journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: journalURL))
        let backupRoot = supportRoot.appendingPathComponent(journal.backupDirectoryName, isDirectory: true)
        let stagedRoot = supportRoot.appendingPathComponent(journal.stagingDirectoryName, isDirectory: true)
        let managedItemNames = journal.managedItemNames ?? (contentDirectoryNames + [manifestName])

        if journal.phase == .committing {
            for name in managedItemNames {
                let current = supportRoot.appendingPathComponent(name)
                if fileManager.fileExists(atPath: current.path) {
                    try fileManager.removeItem(at: current)
                }
                let backup = backupRoot.appendingPathComponent(name)
                if fileManager.fileExists(atPath: backup.path) {
                    try fileManager.moveItem(at: backup, to: current)
                }
            }
        }

        if fileManager.fileExists(atPath: backupRoot.path) {
            try fileManager.removeItem(at: backupRoot)
        }
        if fileManager.fileExists(atPath: stagedRoot.path) {
            try fileManager.removeItem(at: stagedRoot)
        }
        try fileManager.removeItem(at: journalURL)
        return true
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
