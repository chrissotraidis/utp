import Foundation

enum UT99RuntimeSupport {
    static let systemDirectoryName = "System"
    static let versionMarkerName = "UT99-v469e-runtime.json"
    static let v469ePatchSHA256 = "8c94eb7e990f5480b1fb7bcb1bd15c2512da134dbf01bfa16e7f99f0a8a0ee86"
    static let allowedSystemExtensions: Set<String> = [
        "u", "ini", "int", "est", "frt", "itt", "url"
    ]
    static let requiredSystemFileNames = [
        "Default.ini", "DefUser.ini", "UnrealTournament.ini", "User.ini",
        "Core.u", "Engine.u", "BotPack.u", "UWindow.u", "UMenu.u", "UTMenu.u"
    ]
    static let requiredTextureFileNames = ["LadderFonts.utx", "UWindowFonts.utx"]

    private static let v469ePackageDigests = [
        "System/Core.u": "7b2d4962cb82dda81d522361ee9a1008605e35ba0aacbccd0d53d3b9854b73e0",
        "System/Engine.u": "ad7bba28bd636fc0dd9fb854e2b9fbd2219dee50ca9c15b7fef2f63e951bb1a1",
        "System/Botpack.u": "dd85f62659953e476a4ae6ba18635a3617b6e0c8f1bb53ffe21cd7a3e2cd5bc6",
        "System/UWindow.u": "215adcfa9c73904ab739ba6b1bec38f939578a47a0daea259d8f89dcb0772840",
        "System/UMenu.u": "18145f11affbd3adf4b46737eb33f91637bd1eb0a090d375e51c6a6e221f4e0f",
        "System/UTMenu.u": "d6159cef2a8c94fa1caeded0f4408cb3c893153c9b2b48dbdfd45dfa793817fa",
        "System/Default.ini": "9cf93803573d986c95dea4accfc934c67ee3afec3bb37297cfed3e8b4e0f6323",
        "System/DefUser.ini": "65fbed3c4098c5df111d98887936ac8f0c90ebb5cf7e267032a67f552af3a366",
        "Textures/LadderFonts.utx": "5c5f2a36bba19ae16cb5d6c58832d0cb00a0573029f52f9450052b5530e92193",
        "Textures/UWindowFonts.utx": "67187424ee70b54f07c6a49cabc6738e41ff5cdf26f29d591df5de230280a9c7",
    ]

    private struct VersionMarker: Codable {
        let format: Int
        let version: String
        let patchSHA256: String
    }

    static func shouldImportSystemFile(named name: String) -> Bool {
        name.caseInsensitiveCompare(versionMarkerName) == .orderedSame ||
            allowedSystemExtensions.contains(URL(fileURLWithPath: name).pathExtension.lowercased())
    }

    static func missingRequiredFiles(at supportRoot: URL) -> [String] {
        let systemRoot = supportRoot.appendingPathComponent(systemDirectoryName, isDirectory: true)
        let textureRoot = supportRoot.appendingPathComponent("Textures", isDirectory: true)
        return requiredSystemFileNames.filter { file(named: $0, in: systemRoot) == nil } +
            requiredTextureFileNames.filter { file(named: $0, in: textureRoot) == nil }
    }

    static func isReady(at supportRoot: URL) -> Bool {
        missingRuntimeFiles(at: supportRoot).isEmpty
    }

    static func missingRuntimeFiles(at supportRoot: URL) -> [String] {
        var missing = missingRequiredFiles(at: supportRoot)
        if !hasVerifiedV469eMarker(at: supportRoot) {
            missing.append(versionMarkerName)
        }
        return missing
    }

    /// Writes generated provenance only after the matching v469e script
    /// packages have been hash-verified. The marker makes normal readiness
    /// checks cheap while keeping retail GOTY packages from reaching the
    /// transformed v469e engine.
    @discardableResult
    static func ensureV469eMarkerIfMatching(at supportRoot: URL) throws -> Bool {
        if hasVerifiedV469eMarker(at: supportRoot) { return true }
        return try refreshV469eMarkerIfMatching(at: supportRoot)
    }

    /// Revalidates every pinned package before replacing generated provenance.
    /// Import staging uses this form so a copied or stale marker can never
    /// bless retail or mismatched packages.
    @discardableResult
    static func refreshV469eMarkerIfMatching(at supportRoot: URL) throws -> Bool {
        let systemRoot = supportRoot.appendingPathComponent(systemDirectoryName, isDirectory: true)
        let markerURL = systemRoot.appendingPathComponent(versionMarkerName)
        if FileManager.default.fileExists(atPath: markerURL.path) {
            try FileManager.default.removeItem(at: markerURL)
        }
        for (relativePath, expectedDigest) in v469ePackageDigests {
            let package = supportRoot.appendingPathComponent(relativePath)
            guard FileManager.default.fileExists(atPath: package.path) else { return false }
            let actual = try UT99DataImportTransaction.fingerprint(of: package).sha256
            guard actual == expectedDigest else { return false }
        }
        let marker = VersionMarker(format: 2, version: "469e", patchSHA256: v469ePatchSHA256)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(marker).write(to: markerURL, options: .atomic)
        return true
    }

    static func prepareMutableConfigurations(at supportRoot: URL) throws {
        let fileManager = FileManager.default
        let systemRoot = supportRoot.appendingPathComponent(systemDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: systemRoot, withIntermediateDirectories: true)
        try copyIfMissing(sourceName: "Default.ini", destinationName: "UnrealTournament.ini", in: systemRoot)
        try copyIfMissing(sourceName: "DefUser.ini", destinationName: "User.ini", in: systemRoot)
        try copyIfMissing(sourceName: "DefUser.ini", destinationName: "DefaultUser.ini", in: systemRoot)
        try applyAppleKeyboardBindings(to: systemRoot.appendingPathComponent("User.ini"))
        try applyAppleKeyboardBindings(to: systemRoot.appendingPathComponent("DefaultUser.ini"))
    }

    /// Automatic acquisition starts from a retail ISO. Once the matching
    /// patch has been overlaid, seed fresh mutable configs from v469e rather
    /// than retaining the ISO's 1999 Windows templates. Existing installed
    /// player configs are preserved later by the transactional importer.
    static func replaceStagedMutableConfigurations(at supportRoot: URL) throws {
        let fileManager = FileManager.default
        let systemRoot = supportRoot.appendingPathComponent(systemDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: systemRoot, withIntermediateDirectories: true)
        try copyReplacing(sourceName: "Default.ini", destinationName: "UnrealTournament.ini", in: systemRoot)
        try copyReplacing(sourceName: "DefUser.ini", destinationName: "User.ini", in: systemRoot)
        try copyReplacing(sourceName: "DefUser.ini", destinationName: "DefaultUser.ini", in: systemRoot)
    }

    static func shouldPreserveExistingFile(named name: String) -> Bool {
        let lower = name.lowercased()
        return ["unrealtournament.ini", "user.ini", "udemo.ini", "default.metallib"].contains(lower) ||
            lower.hasSuffix(".log") || lower.hasSuffix(".tmp")
    }

    private static func copyIfMissing(sourceName: String, destinationName: String, in systemRoot: URL) throws {
        let fileManager = FileManager.default
        guard file(named: destinationName, in: systemRoot) == nil,
              let source = file(named: sourceName, in: systemRoot) else { return }
        try fileManager.copyItem(at: source, to: systemRoot.appendingPathComponent(destinationName))
    }

    /// Fill only empty or known stock v469e desktop bindings. Existing custom
    /// player bindings remain untouched while an attached iPad keyboard gets
    /// the familiar WASD, E, Space, and Shift control surface.
    static func applyAppleKeyboardBindings(to url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let original = try String(contentsOf: url, encoding: .utf8)
        let replacements: [String: String] = [
            "W=": "W=MoveForward",
            "A=": "A=StrafeLeft",
            "S=": "S=MoveBackward",
            "S=Axis aUp Speed=+300.0": "S=MoveBackward",
            "D=": "D=StrafeRight",
            "E=": "E=InventoryActivate",
        ]
        var changed = false
        let lines = original.components(separatedBy: "\n").map { line -> String in
            let carriageReturn = line.hasSuffix("\r")
            let key = carriageReturn ? String(line.dropLast()) : line
            guard let replacement = replacements[key] else { return line }
            changed = true
            return replacement + (carriageReturn ? "\r" : "")
        }
        if changed {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static func copyReplacing(sourceName: String, destinationName: String, in systemRoot: URL) throws {
        guard let source = file(named: sourceName, in: systemRoot) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try Data(contentsOf: source).write(
            to: systemRoot.appendingPathComponent(destinationName),
            options: .atomic
        )
    }

    private static func hasVerifiedV469eMarker(at supportRoot: URL) -> Bool {
        let markerURL = supportRoot
            .appendingPathComponent(systemDirectoryName, isDirectory: true)
            .appendingPathComponent(versionMarkerName)
        guard let data = try? Data(contentsOf: markerURL),
              let marker = try? JSONDecoder().decode(VersionMarker.self, from: data) else {
            return false
        }
        return marker.format == 2 && marker.version == "469e" &&
            marker.patchSHA256 == v469ePatchSHA256
    }

    private static func file(named name: String, in directory: URL) -> URL? {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        return items.first {
            $0.lastPathComponent.caseInsensitiveCompare(name) == .orderedSame &&
                (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
    }
}

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
            progress(Update(phase: .copying, currentFile: file.relativePath,
                            completedFiles: index + 1, totalFiles: files.count))
        }

        if fileManager.fileExists(
            atPath: staging.appendingPathComponent(UT99RuntimeSupport.systemDirectoryName).path
        ) {
            try preserveExistingSystemFiles(from: supportRoot, in: staging)
            try UT99RuntimeSupport.prepareMutableConfigurations(at: staging)
            _ = try UT99RuntimeSupport.refreshV469eMarkerIfMatching(at: staging)
        }
        for file in files {
            let staged = staging.appendingPathComponent(file.relativePath)
            let fingerprint = try UT99DataImportTransaction.fingerprint(of: staged) {
                cancellation.isCancelled
            }
            manifest.append([
                "path": file.relativePath,
                "size": fingerprint.size,
                "sha256": fingerprint.sha256
            ])
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
                try validateContentFileName(item.lastPathComponent)
                let prefix = directory.standardizedFileURL.path + "/"
                let itemPath = item.standardizedFileURL.path
                guard itemPath.hasPrefix(prefix) else { continue }
                let relative = String(itemPath.dropFirst(prefix.count))
                files.append(ContentFile(source: item, relativePath: "\(dirname)/\(relative)"))
            }
        }
        let systemDirectory = root.appendingPathComponent(UT99RuntimeSupport.systemDirectoryName, isDirectory: true)
        if isDirectory(systemDirectory), let enumerator = fileManager.enumerator(
            at: systemDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let item as URL in enumerator {
                try checkCancellation(cancellation)
                let values = try item.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true,
                      UT99RuntimeSupport.shouldImportSystemFile(named: item.lastPathComponent) else { continue }
                try validateContentFileName(item.lastPathComponent)
                let prefix = systemDirectory.standardizedFileURL.path + "/"
                let itemPath = item.standardizedFileURL.path
                guard itemPath.hasPrefix(prefix) else { continue }
                let relative = String(itemPath.dropFirst(prefix.count))
                files.append(ContentFile(
                    source: item,
                    relativePath: "\(UT99RuntimeSupport.systemDirectoryName)/\(relative)"
                ))
            }
        }
        return files.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    private static func preserveExistingSystemFiles(from supportRoot: URL, in stagingRoot: URL) throws {
        let fileManager = FileManager.default
        let existingRoot = supportRoot.appendingPathComponent(UT99RuntimeSupport.systemDirectoryName, isDirectory: true)
        guard isDirectory(existingRoot), let enumerator = fileManager.enumerator(
            at: existingRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let stagedRoot = stagingRoot.appendingPathComponent(UT99RuntimeSupport.systemDirectoryName, isDirectory: true)
        for case let item as URL in enumerator {
            let values = try item.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            let prefix = existingRoot.standardizedFileURL.path + "/"
            let itemPath = item.standardizedFileURL.path
            guard itemPath.hasPrefix(prefix) else { continue }
            let relative = String(itemPath.dropFirst(prefix.count))
            let destination = stagedRoot.appendingPathComponent(relative)
            let destinationExists = fileManager.fileExists(atPath: destination.path)
            guard !destinationExists || UT99RuntimeSupport.shouldPreserveExistingFile(named: item.lastPathComponent) else {
                continue
            }
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if destinationExists { try fileManager.removeItem(at: destination) }
            try fileManager.copyItem(at: item, to: destination)
        }
    }

    static func validateContentFileName(_ name: String) throws {
        let lowerExtension = URL(fileURLWithPath: name).pathExtension.lowercased()
        if ["exe", "dll", "dylib", "app", "iso", "bin"].contains(lowerExtension) {
            throw Error.unsupportedFile(name)
        }
    }

    /// Retail GOTY font textures are incompatible with the transformed v469e
    /// engine. The ISO extractor omits them; the hash-verified v469e patch then
    /// supplies the matching replacements through the normal importer.
    static func shouldSkipRetailContentFile(named name: String) -> Bool {
        ["ladderfonts.utx", "uwindowfonts.utx"].contains(name.lowercased())
    }

    private static func checkCancellation(_ cancellation: UT99ImportCancellation) throws {
        if cancellation.isCancelled { throw UT99ImportCancelled() }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
