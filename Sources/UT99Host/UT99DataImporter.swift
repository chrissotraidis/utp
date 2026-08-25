import Foundation

final class UT99ImportCancellation: @unchecked Sendable {
    private enum State {
        case preparing
        case cancelled
        case committing
    }

    private let lock = NSLock()
    private var state = State.preparing

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return state == .cancelled
    }

    @discardableResult
    func cancel() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard state == .preparing else { return false }
        state = .cancelled
        return true
    }

    /// Atomically closes cancellation before the journaled commit starts.
    /// A cancellation and commit can therefore never both win the boundary.
    func beginCommit() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard state == .preparing else { return false }
        state = .committing
        return true
    }
}

/// Prepares and validates user-owned content away from the live installation.
/// Cancellation is accepted only while staging; the transaction commit remains
/// deliberately non-cancellable so it can finish atomically or recover later.
enum UT99DataImporter {
    enum Phase: String {
        case discovering
        case extracting
        case copying
        case installing
    }

    struct Update {
        let phase: Phase
        let currentFile: String
        let completedFiles: Int
        let totalFiles: Int

        var fractionCompleted: Float {
            guard totalFiles > 0 else { return 0 }
            return Float(completedFiles) / Float(totalFiles)
        }

        var canCancel: Bool { phase != .installing }
    }

    enum Error: LocalizedError {
        case noContentRoot
        case noContentFiles
        case unsupportedFile(String)

        var errorDescription: String? {
            switch self {
            case .noContentRoot: "No Maps, Music, Sounds, and Textures root found"
            case .noContentFiles: "The selected folder contains no supported UT99 content"
            case let .unsupportedFile(name): "Unsupported executable content: \(name)"
            }
        }
    }

    typealias ProgressHandler = (Update) -> Void

    static func importFolder(
        _ source: URL,
        to supportRoot: URL,
        cancellation: UT99ImportCancellation,
        progress: @escaping ProgressHandler
    ) throws -> Int {
        let fileManager = FileManager.default
        let contentDirectories = UT99DataImportTransaction.contentDirectoryNames
        progress(Update(phase: .discovering, currentFile: source.lastPathComponent,
                        completedFiles: 0, totalFiles: 0))
        try checkCancellation(cancellation)

        let root = try findContentRoot(
            under: source,
            contentDirectories: contentDirectories,
            cancellation: cancellation
        )
        let files = try collectContentFiles(
            under: root,
            contentDirectories: contentDirectories,
            cancellation: cancellation
        )
        guard !files.isEmpty else { throw Error.noContentFiles }

        try fileManager.createDirectory(at: supportRoot, withIntermediateDirectories: true)
        let staging = supportRoot.appendingPathComponent(".import-staging-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: staging) }
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)

        var manifest: [[String: Any]] = []
        for (index, file) in files.enumerated() {
            try checkCancellation(cancellation)
            progress(Update(phase: .copying, currentFile: file.relativePath,
                            completedFiles: index, totalFiles: files.count))
            try checkCancellation(cancellation)

            let staged = staging.appendingPathComponent(file.relativePath)
            try fileManager.createDirectory(at: staged.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: file.source, to: staged)
            let fingerprint = try UT99DataImportTransaction.fingerprint(of: staged) {
                cancellation.isCancelled
            }
            manifest.append([
                "path": file.relativePath,
                "size": fingerprint.size,
                "sha256": fingerprint.sha256
            ])
            progress(Update(phase: .copying, currentFile: file.relativePath,
                            completedFiles: index + 1, totalFiles: files.count))
        }

        // This is the cancellation boundary. Once installing is announced,
        // the journaled transaction must not be interrupted by the UI.
        guard cancellation.beginCommit() else { throw UT99ImportCancelled() }
        progress(Update(phase: .installing, currentFile: "Publishing verified data",
                        completedFiles: files.count, totalFiles: files.count))

        let manifestData = try JSONSerialization.data(withJSONObject: [
            "format": 1,
            "source_root_name": root.lastPathComponent,
            "files": manifest
        ], options: [.prettyPrinted, .sortedKeys])
        try UT99DataImportTransaction.commit(
            stagedRoot: staging,
            manifestData: manifestData,
            to: supportRoot
        )
        return manifest.count
    }

    private struct ContentFile {
        let source: URL
        let relativePath: String
    }

    private static func findContentRoot(
        under source: URL,
        contentDirectories: [String],
        cancellation: UT99ImportCancellation
    ) throws -> URL {
        if contentDirectories.allSatisfy({ isDirectory(source.appendingPathComponent($0)) }) {
            return source
        }
        guard let enumerator = FileManager.default.enumerator(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw Error.noContentRoot
        }
        for case let candidate as URL in enumerator {
            try checkCancellation(cancellation)
            if contentDirectories.allSatisfy({ isDirectory(candidate.appendingPathComponent($0)) }) {
                return candidate
            }
        }
        throw Error.noContentRoot
    }

    private static func collectContentFiles(
        under root: URL,
        contentDirectories: [String],
        cancellation: UT99ImportCancellation
    ) throws -> [ContentFile] {
        var files: [ContentFile] = []
        let fileManager = FileManager.default
        for dirname in contentDirectories {
            let directory = root.appendingPathComponent(dirname, isDirectory: true)
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let item as URL in enumerator {
                try checkCancellation(cancellation)
                let values = try item.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                if shouldSkipContentFile(named: item.lastPathComponent) { continue }
                try validateContentFileName(item.lastPathComponent)
                let prefix = directory.standardizedFileURL.path + "/"
                let itemPath = item.standardizedFileURL.path
                guard itemPath.hasPrefix(prefix) else { continue }
                let relative = String(itemPath.dropFirst(prefix.count))
                files.append(ContentFile(source: item, relativePath: "\(dirname)/\(relative)"))
            }
        }
        return files.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    static func shouldSkipContentFile(named name: String) -> Bool {
        ["ladderfonts.utx", "uwindowfonts.utx"].contains(name.lowercased())
    }

    static func validateContentFileName(_ name: String) throws {
        let lowerExtension = URL(fileURLWithPath: name).pathExtension.lowercased()
        if ["exe", "dll", "dylib", "app", "iso", "bin"].contains(lowerExtension) {
            throw Error.unsupportedFile(name)
        }
    }

    private static func checkCancellation(_ cancellation: UT99ImportCancellation) throws {
        if cancellation.isCancelled { throw UT99ImportCancelled() }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
