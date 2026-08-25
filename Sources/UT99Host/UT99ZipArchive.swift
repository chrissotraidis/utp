import Foundation

/// Minimal, deterministic ZIP reader for user-owned UT99 content packs.
/// It intentionally supports only stored and raw-deflate files and never
/// follows links or writes outside the caller-provided extraction directory.
enum UT99ZipArchive {
    enum Error: LocalizedError {
        case malformed
        case unsupportedCompression(UInt16)
        case encrypted
        case unsafePath(String)
        case unsupportedFile(String)
        case incompatibleRuntime
        case sizeMismatch(String)
        case inflateFailed(String)

        var errorDescription: String? {
            switch self {
            case .malformed: "Malformed ZIP archive"
            case let .unsupportedCompression(method): "Unsupported ZIP compression method \(method)"
            case .encrypted: "Encrypted ZIP archives are not supported"
            case let .unsafePath(path): "Unsafe ZIP path: \(path)"
            case let .unsupportedFile(name): "Unsupported executable content: \(name)"
            case .incompatibleRuntime: "The archive does not contain the matching Unreal Tournament v469e runtime"
            case let .sizeMismatch(name): "ZIP size mismatch: \(name)"
            case let .inflateFailed(name): "Could not inflate ZIP entry: \(name)"
            }
        }
    }

    private struct Entry {
        let name: String
        let flags: UInt16
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localOffset: Int
    }

    static func extract(
        _ archiveURL: URL,
        to destination: URL,
        cancellationRequested: () -> Bool = { false },
        progress: (_ currentFile: String, _ completedFiles: Int, _ totalFiles: Int) -> Void = { _, _, _ in }
    ) throws -> Int {
        if cancellationRequested() { throw UT99ImportCancelled() }
        let data = try Data(contentsOf: archiveURL, options: [.mappedIfSafe])
        let entries = try centralDirectory(in: data)
        let fileEntries = entries.filter { !$0.name.hasSuffix("/") }
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        var files = 0
        for entry in fileEntries {
            if cancellationRequested() { throw UT99ImportCancelled() }
            progress(entry.name, files, fileEntries.count)
            let relative = try safeRelativePath(entry.name)
            try validateContentPath(relative)
            guard entry.flags & 0x1 == 0 else { throw Error.encrypted }
            let bytes = try read(entry, from: data)
            let output = destination.appendingPathComponent(relative)
            try fileManager.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: output, options: [.atomic])
            files += 1
            progress(entry.name, files, fileEntries.count)
        }
        guard files > 0 else { throw Error.malformed }
        return files
    }

    /// Extracts only platform-neutral v469e packages, font textures, and English localization
    /// from OldUnreal's hash-pinned Windows ZIP. Native executables, DLLs,
    /// editor resources, and every unrelated archive entry are ignored.
    static func extractV469eRuntimePatch(
        _ archiveURL: URL,
        to destination: URL,
        cancellationRequested: () -> Bool = { false },
        progress: (_ currentFile: String, _ completedFiles: Int, _ totalFiles: Int) -> Void = { _, _, _ in }
    ) throws -> Int {
        if cancellationRequested() { throw UT99ImportCancelled() }
        let data = try Data(contentsOf: archiveURL, options: [.mappedIfSafe])
        let selected = try centralDirectory(in: data).compactMap { entry -> (Entry, String)? in
            guard !entry.name.hasSuffix("/"),
                  let destinationPath = try v469eRuntimeDestination(for: entry.name) else {
                return nil
            }
            return (entry, destinationPath)
        }
        guard !selected.isEmpty else { throw Error.incompatibleRuntime }

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        var writtenPaths = Set<String>()
        for (index, item) in selected.enumerated() {
            if cancellationRequested() { throw UT99ImportCancelled() }
            let (entry, relativePath) = item
            guard writtenPaths.insert(relativePath.lowercased()).inserted else {
                throw Error.malformed
            }
            progress(entry.name, index, selected.count)
            guard entry.flags & 0x1 == 0 else { throw Error.encrypted }
            let bytes = try read(entry, from: data)
            let output = destination.appendingPathComponent(relativePath)
            try fileManager.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: output, options: [.atomic])
            progress(entry.name, index + 1, selected.count)
        }

        try UT99RuntimeSupport.replaceStagedMutableConfigurations(at: destination)
        guard try UT99RuntimeSupport.refreshV469eMarkerIfMatching(at: destination) else {
            throw Error.incompatibleRuntime
        }
        return selected.count
    }

    private static func centralDirectory(in data: Data) throws -> [Entry] {
        let minimum = 22
        guard data.count >= minimum else { throw Error.malformed }
        let start = max(0, data.count - 65_557)
        var eocd: Int?
        if data.count >= minimum {
            for offset in stride(from: data.count - minimum, through: start, by: -1) {
                if u32(data, offset) == 0x06054b50 { eocd = offset; break }
            }
        }
        guard let end = eocd,
              u16(data, end + 8) == u16(data, end + 10) else { throw Error.malformed }
        let count = Int(u16(data, end + 10))
        let directorySize = Int(u32(data, end + 12))
        let directoryOffset = Int(u32(data, end + 16))
        guard directoryOffset >= 0, directorySize >= 0,
              directoryOffset + directorySize <= data.count else { throw Error.malformed }
        var entries: [Entry] = []
        var cursor = directoryOffset
        for _ in 0..<count {
            guard cursor + 46 <= data.count, u32(data, cursor) == 0x02014b50 else { throw Error.malformed }
            let flags = u16(data, cursor + 8)
            let method = u16(data, cursor + 10)
            let compressedSize = Int(u32(data, cursor + 20))
            let uncompressedSize = Int(u32(data, cursor + 24))
            let nameLength = Int(u16(data, cursor + 28))
            let extraLength = Int(u16(data, cursor + 30))
            let commentLength = Int(u16(data, cursor + 32))
            let localOffset = Int(u32(data, cursor + 42))
            let end = cursor + 46 + nameLength + extraLength + commentLength
            guard end <= data.count else { throw Error.malformed }
            let nameData = data.subdata(in: (cursor + 46)..<(cursor + 46 + nameLength))
            guard let name = String(data: nameData, encoding: .utf8), !name.isEmpty else { throw Error.malformed }
            entries.append(Entry(name: name, flags: flags, method: method,
                                 compressedSize: compressedSize,
                                 uncompressedSize: uncompressedSize,
                                 localOffset: localOffset))
            cursor = end
        }
        return entries
    }

    private static func read(_ entry: Entry, from data: Data) throws -> Data {
        guard entry.method == 0 || entry.method == 8 else { throw Error.unsupportedCompression(entry.method) }
        guard entry.localOffset + 30 <= data.count,
              u32(data, entry.localOffset) == 0x04034b50 else { throw Error.malformed }
        let nameLength = Int(u16(data, entry.localOffset + 26))
        let extraLength = Int(u16(data, entry.localOffset + 28))
        let start = entry.localOffset + 30 + nameLength + extraLength
        let end = start + entry.compressedSize
        guard start >= 0, end <= data.count else { throw Error.malformed }
        let compressed = data.subdata(in: start..<end)
        if entry.method == 0 {
            guard compressed.count == entry.uncompressedSize else { throw Error.sizeMismatch(entry.name) }
            return compressed
        }
        var output = Data(count: entry.uncompressedSize)
        let outputSize = output.count
        let written = output.withUnsafeMutableBytes { outputBytes in
            compressed.withUnsafeBytes { inputBytes in
                UT99InflateRaw(inputBytes.bindMemory(to: UInt8.self).baseAddress,
                               compressed.count,
                               outputBytes.bindMemory(to: UInt8.self).baseAddress,
                               outputSize)
            }
        }
        guard written >= 0, written == entry.uncompressedSize else { throw Error.inflateFailed(entry.name) }
        return output
    }

    private static func safeRelativePath(_ path: String) throws -> String {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        let components = normalized.split(separator: "/").map(String.init)
        guard !components.isEmpty, !normalized.hasPrefix("/"), !normalized.contains(":") else {
            throw Error.unsafePath(path)
        }
        guard !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw Error.unsafePath(path)
        }
        return components.joined(separator: "/")
    }

    private static func v469eRuntimeDestination(for archivePath: String) throws -> String? {
        let relative = try safeRelativePath(archivePath)
        let components = relative.split(separator: "/").map(String.init)
        let filename: String
        if components.count == 2,
           components[0].caseInsensitiveCompare("System") == .orderedSame {
            filename = components[1]
            guard ["u", "ini"].contains(URL(fileURLWithPath: filename).pathExtension.lowercased()) else {
                return nil
            }
        } else if components.count == 3,
                  components[0].caseInsensitiveCompare("SystemLocalized") == .orderedSame,
                  components[1].caseInsensitiveCompare("int") == .orderedSame {
            filename = components[2]
            guard URL(fileURLWithPath: filename).pathExtension.lowercased() == "int" else { return nil }
        } else if components.count == 2,
                  components[0].caseInsensitiveCompare("Textures") == .orderedSame {
            filename = components[1]
            guard UT99RuntimeSupport.requiredTextureFileNames.contains(where: {
                $0.caseInsensitiveCompare(filename) == .orderedSame
            }) else { return nil }
            try UT99DataImporter.validateContentFileName(filename)
            return "Textures/\(filename)"
        } else {
            return nil
        }
        try UT99DataImporter.validateContentFileName(filename)
        return "\(UT99RuntimeSupport.systemDirectoryName)/\(filename)"
    }

    private static func validateContentPath(_ path: String) throws {
        let lower = path.lowercased()
        let ext = (lower as NSString).pathExtension
        if ["exe", "dll", "dylib", "app", "iso", "bin"].contains(ext) ||
            ["ladderfonts.utx", "uwindowfonts.utx"].contains((lower as NSString).lastPathComponent) {
            throw Error.unsupportedFile(path)
        }
    }

    private static func u16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func u32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8) |
        (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
    }
}
