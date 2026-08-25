import Foundation

enum UT99AuthorizedGameData {
    static let sourcePageURL = URL(string: "https://www.oldunreal.com/downloads/unrealtournament/full-game-installers/")!
    static let termsURL = URL(string: "https://legal.epicgames.com/en-US/epicgames/tos")!
    static let expectedISOBytes: Int64 = 649_633_792
    static let expectedISOSHA256 = "e184984ca88f001c5ddd52035d76cd64e266e26c74975161b5ed72366c74704f"
    static let isoMirrors = [
        URL(string: "https://files.oldunreal.net/UT_GOTY_CD1.ISO")!,
        URL(string: "https://files2.oldunreal.net/UT_GOTY_CD1.ISO")!,
        URL(string: "https://files3.oldunreal.net/UT_GOTY_CD1.ISO")!,
        URL(string: "https://archive.org/download/ut-goty/UT_GOTY_CD1.iso")!,
    ]
}

/// Downloads the exact GOTY image published by OldUnreal's own installers.
/// The caller must present the Epic terms/source disclosure before starting.
final class UT99GameDataDownload {
    enum Error: LocalizedError {
        case cancelled
        case allMirrorsFailed
        case invalidSize(Int64)
        case invalidDigest

        var errorDescription: String? {
            switch self {
            case .cancelled: "Game-data download cancelled"
            case .allMirrorsFailed: "All approved OldUnreal download mirrors failed"
            case let .invalidSize(actual): "Downloaded image has the wrong size (\(actual) bytes)"
            case .invalidDigest: "Downloaded image failed its SHA-256 integrity check"
            }
        }
    }

    private let lock = NSLock()
    private var task: URLSessionDownloadTask?
    private var cancelled = false
    private(set) var currentMirrorIndex = 0

    var progress: Progress? {
        lock.lock()
        defer { lock.unlock() }
        return task?.progress
    }

    var currentSourceHost: String {
        lock.lock()
        defer { lock.unlock() }
        guard UT99AuthorizedGameData.isoMirrors.indices.contains(currentMirrorIndex) else { return "OldUnreal" }
        return UT99AuthorizedGameData.isoMirrors[currentMirrorIndex].host ?? "OldUnreal"
    }

    func start(
        destinationDirectory: URL,
        completion: @escaping (Result<URL, Swift.Error>) -> Void
    ) {
        lock.lock()
        cancelled = false
        currentMirrorIndex = 0
        lock.unlock()
        attemptDownload(to: destinationDirectory, completion: completion)
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let currentTask = task
        lock.unlock()
        currentTask?.cancel()
    }

    private func attemptDownload(
        to destinationDirectory: URL,
        completion: @escaping (Result<URL, Swift.Error>) -> Void
    ) {
        lock.lock()
        let index = currentMirrorIndex
        let isCancelled = cancelled
        lock.unlock()
        guard !isCancelled else {
            completion(.failure(Error.cancelled))
            return
        }
        guard UT99AuthorizedGameData.isoMirrors.indices.contains(index) else {
            completion(.failure(Error.allMirrorsFailed))
            return
        }

        let source = UT99AuthorizedGameData.isoMirrors[index]
        let request = URLRequest(url: source, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 300)
        let nextTask = URLSession.shared.downloadTask(with: request) { [weak self] temporaryURL, _, error in
            guard let self else { return }
            self.lock.lock()
            let wasCancelled = self.cancelled
            self.lock.unlock()
            if wasCancelled {
                completion(.failure(Error.cancelled))
                return
            }
            guard error == nil, let temporaryURL else {
                self.tryNextMirror(destinationDirectory, completion: completion)
                return
            }

            do {
                try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
                let destination = destinationDirectory.appendingPathComponent("UT_GOTY_CD1.ISO")
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: temporaryURL, to: destination)
                let size = (try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? -1
                guard size == UT99AuthorizedGameData.expectedISOBytes else {
                    try? FileManager.default.removeItem(at: destination)
                    throw Error.invalidSize(size)
                }
                let digest = try UT99DataImportTransaction.fingerprint(of: destination) { [weak self] in
                    guard let self else { return true }
                    self.lock.lock()
                    defer { self.lock.unlock() }
                    return self.cancelled
                }.sha256
                guard digest == UT99AuthorizedGameData.expectedISOSHA256 else {
                    try? FileManager.default.removeItem(at: destination)
                    throw Error.invalidDigest
                }
                completion(.success(destination))
            } catch is UT99ImportCancelled {
                completion(.failure(Error.cancelled))
            } catch {
                self.tryNextMirror(destinationDirectory, completion: completion)
            }
        }
        lock.lock()
        task = nextTask
        lock.unlock()
        nextTask.resume()
    }

    private func tryNextMirror(
        _ destinationDirectory: URL,
        completion: @escaping (Result<URL, Swift.Error>) -> Void
    ) {
        lock.lock()
        currentMirrorIndex += 1
        lock.unlock()
        attemptDownload(to: destinationDirectory, completion: completion)
    }
}

/// Minimal read-only ISO-9660/Joliet extractor for the four data directories
/// in the exact, hash-verified OldUnreal GOTY image. It deliberately cannot
/// extract arbitrary paths or executable content.
enum UT99ISO9660Extractor {
    struct Update {
        let currentFile: String
        let completedFiles: Int
        let totalFiles: Int

        var fractionCompleted: Float {
            guard totalFiles > 0 else { return 0 }
            return Float(completedFiles) / Float(totalFiles)
        }
    }

    enum Error: LocalizedError {
        case invalidImage
        case missingDataDirectory(String)
        case unsafeName(String)

        var errorDescription: String? {
            switch self {
            case .invalidImage: "The downloaded image is not a supported ISO-9660/Joliet image"
            case let .missingDataDirectory(name): "The game image is missing \(name)"
            case let .unsafeName(name): "The game image contains an unsafe path: \(name)"
            }
        }
    }

    private struct Record {
        let extent: UInt32
        let size: UInt32
        let isDirectory: Bool
        let name: String
    }

    private struct PendingFile {
        let record: Record
        let relativePath: String
    }

    static func extractDataDirectories(
        from imageURL: URL,
        to destination: URL,
        cancellationRequested: () -> Bool = { false },
        progress: (Update) -> Void = { _ in }
    ) throws -> Int {
        let handle = try FileHandle(forReadingFrom: imageURL)
        defer { try? handle.close() }
        let descriptor = try preferredVolumeDescriptor(from: handle)
        let blockSize = Int(uint16LE(descriptor.data, 128))
        guard blockSize >= 512, blockSize <= 4096,
              let root = record(from: descriptor.data, offset: 156, joliet: descriptor.isJoliet) else {
            throw Error.invalidImage
        }

        let rootRecords = try records(in: root, handle: handle, blockSize: blockSize, joliet: descriptor.isJoliet)
        var pending: [PendingFile] = []
        for requiredName in UT99DataImportTransaction.contentDirectoryNames {
            guard let directory = rootRecords.first(where: {
                $0.isDirectory && $0.name.caseInsensitiveCompare(requiredName) == .orderedSame
            }) else {
                throw Error.missingDataDirectory(requiredName)
            }
            try collectFiles(
                in: directory,
                relativeDirectory: requiredName,
                handle: handle,
                blockSize: blockSize,
                joliet: descriptor.isJoliet,
                cancellationRequested: cancellationRequested,
                into: &pending
            )
        }

        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for (index, item) in pending.enumerated() {
            if cancellationRequested() { throw UT99ImportCancelled() }
            progress(Update(currentFile: item.relativePath, completedFiles: index, totalFiles: pending.count))
            let output = destination.appendingPathComponent(item.relativePath)
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: output.path, contents: nil)
            let writer = try FileHandle(forWritingTo: output)
            try handle.seek(toOffset: UInt64(item.record.extent) * UInt64(blockSize))
            var remaining = Int(item.record.size)
            while remaining > 0 {
                if cancellationRequested() { throw UT99ImportCancelled() }
                let chunk = try handle.read(upToCount: min(1_048_576, remaining)) ?? Data()
                guard !chunk.isEmpty else { throw Error.invalidImage }
                try writer.write(contentsOf: chunk)
                remaining -= chunk.count
            }
            try writer.close()
            progress(Update(currentFile: item.relativePath, completedFiles: index + 1, totalFiles: pending.count))
        }
        return pending.count
    }

    private static func preferredVolumeDescriptor(from handle: FileHandle) throws -> (data: Data, isJoliet: Bool) {
        var primary: Data?
        var joliet: Data?
        for sector in 16..<80 {
            try handle.seek(toOffset: UInt64(sector * 2048))
            guard let data = try handle.read(upToCount: 2048), data.count == 2048,
                  String(data: data[1..<6], encoding: .ascii) == "CD001" else {
                throw Error.invalidImage
            }
            let type = data[0]
            if type == 1 { primary = data }
            if type == 2, data.count > 91 {
                let escape = Array(data[88...90])
                if escape == [0x25, 0x2f, 0x40] || escape == [0x25, 0x2f, 0x43] || escape == [0x25, 0x2f, 0x45] {
                    joliet = data
                }
            }
            if type == 255 { break }
        }
        if let joliet { return (joliet, true) }
        if let primary { return (primary, false) }
        throw Error.invalidImage
    }

    private static func collectFiles(
        in directory: Record,
        relativeDirectory: String,
        handle: FileHandle,
        blockSize: Int,
        joliet: Bool,
        cancellationRequested: () -> Bool,
        into pending: inout [PendingFile]
    ) throws {
        for child in try records(in: directory, handle: handle, blockSize: blockSize, joliet: joliet) {
            if cancellationRequested() { throw UT99ImportCancelled() }
            guard child.name != ".", child.name != ".." else { continue }
            try validateComponent(child.name)
            let relative = relativeDirectory + "/" + child.name
            if child.isDirectory {
                try collectFiles(
                    in: child,
                    relativeDirectory: relative,
                    handle: handle,
                    blockSize: blockSize,
                    joliet: joliet,
                    cancellationRequested: cancellationRequested,
                    into: &pending
                )
            } else if !UT99DataImporter.shouldSkipContentFile(named: child.name) {
                try UT99DataImporter.validateContentFileName(child.name)
                pending.append(PendingFile(record: child, relativePath: relative))
            }
        }
    }

    private static func records(
        in directory: Record,
        handle: FileHandle,
        blockSize: Int,
        joliet: Bool
    ) throws -> [Record] {
        try handle.seek(toOffset: UInt64(directory.extent) * UInt64(blockSize))
        guard let data = try handle.read(upToCount: Int(directory.size)), data.count == Int(directory.size) else {
            throw Error.invalidImage
        }
        var result: [Record] = []
        var offset = 0
        while offset < data.count {
            let length = Int(data[offset])
            if length == 0 {
                offset = ((offset / blockSize) + 1) * blockSize
                continue
            }
            guard offset + length <= data.count else { throw Error.invalidImage }
            if let parsed = record(from: data, offset: offset, joliet: joliet) {
                result.append(parsed)
            }
            offset += length
        }
        return result
    }

    private static func record(from data: Data, offset: Int, joliet: Bool) -> Record? {
        guard offset >= 0, offset + 34 <= data.count else { return nil }
        let length = Int(data[offset])
        guard length >= 34, offset + length <= data.count else { return nil }
        let identifierLength = Int(data[offset + 32])
        guard identifierLength > 0, offset + 33 + identifierLength <= offset + length else { return nil }
        let identifier = Data(data[(offset + 33)..<(offset + 33 + identifierLength)])
        let name: String
        if identifier.count == 1, identifier[0] == 0 {
            name = "."
        } else if identifier.count == 1, identifier[0] == 1 {
            name = ".."
        } else if joliet {
            var scalars: [UnicodeScalar] = []
            var index = identifier.startIndex
            while index + 1 < identifier.endIndex {
                let value = UInt16(identifier[index]) << 8 | UInt16(identifier[index + 1])
                if let scalar = UnicodeScalar(value) { scalars.append(scalar) }
                index += 2
            }
            name = String(String.UnicodeScalarView(scalars))
        } else {
            name = String(data: identifier, encoding: .ascii) ?? ""
        }
        let normalized = name.replacingOccurrences(of: #";[0-9]+$"#, with: "", options: .regularExpression)
        guard !normalized.isEmpty else { return nil }
        return Record(
            extent: uint32LE(data, offset + 2),
            size: uint32LE(data, offset + 10),
            isDirectory: data[offset + 25] & 0x02 != 0,
            name: normalized
        )
    }

    private static func validateComponent(_ name: String) throws {
        guard name != ".", name != "..", !name.isEmpty,
              !name.contains("/"), !name.contains("\\"), !name.contains(":") else {
            throw Error.unsafeName(name)
        }
    }

    private static func uint16LE(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func uint32LE(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset]) |
            UInt32(data[offset + 1]) << 8 |
            UInt32(data[offset + 2]) << 16 |
            UInt32(data[offset + 3]) << 24
    }
}
