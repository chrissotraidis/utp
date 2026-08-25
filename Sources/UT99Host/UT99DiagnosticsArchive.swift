import Foundation

enum UT99DiagnosticsArchiveError: Error, LocalizedError {
    case emptyArchive
    case tooManyEntries
    case invalidEntryName(String)
    case duplicateEntryName(String)
    case entryTooLarge(String)
    case archiveTooLarge

    var errorDescription: String? {
        switch self {
        case .emptyArchive: return "The diagnostic archive has no entries."
        case .tooManyEntries: return "The diagnostic archive has too many entries."
        case .invalidEntryName(let name): return "Invalid diagnostic entry name: \(name)"
        case .duplicateEntryName(let name): return "Duplicate diagnostic entry name: \(name)"
        case .entryTooLarge(let name): return "Diagnostic entry is too large: \(name)"
        case .archiveTooLarge: return "The diagnostic archive exceeds the stored-ZIP size limit."
        }
    }
}

/// Writes a deliberately small, deterministic stored ZIP. Diagnostic bundles
/// are bounded host text/JSON artifacts, so compression and ZIP64 add needless
/// complexity. Every path is validated before bytes are emitted.
enum UT99DiagnosticsArchive {
    static func write(entries: [(String, Data)], to url: URL) throws {
        guard !entries.isEmpty else { throw UT99DiagnosticsArchiveError.emptyArchive }
        guard entries.count <= Int(UInt16.max) else { throw UT99DiagnosticsArchiveError.tooManyEntries }

        var seen = Set<String>()
        for (name, bytes) in entries {
            guard isSafeRelativePath(name) else {
                throw UT99DiagnosticsArchiveError.invalidEntryName(name)
            }
            guard seen.insert(name).inserted else {
                throw UT99DiagnosticsArchiveError.duplicateEntryName(name)
            }
            guard name.utf8.count <= Int(UInt16.max), bytes.count <= Int(UInt32.max) else {
                throw UT99DiagnosticsArchiveError.entryTooLarge(name)
            }
        }

        var archive = Data()
        var central = Data()
        var offsets: [UInt32] = []
        for (name, bytes) in entries {
            guard archive.count <= Int(UInt32.max) else {
                throw UT99DiagnosticsArchiveError.archiveTooLarge
            }
            offsets.append(UInt32(archive.count))
            let nameData = Data(name.utf8)
            let checksum = crc32(bytes)
            archive.appendLE(0x04034b50, width: 4)
            archive.appendLE(20, width: 2)
            archive.appendLE(0, width: 2)
            archive.appendLE(0, width: 2)
            archive.appendLE(0, width: 2)
            archive.appendLE(0x0021, width: 2) // 1980-01-01, deterministic.
            archive.appendLE(checksum, width: 4)
            archive.appendLE(UInt32(bytes.count), width: 4)
            archive.appendLE(UInt32(bytes.count), width: 4)
            archive.appendLE(UInt16(nameData.count), width: 2)
            archive.appendLE(0, width: 2)
            archive.append(nameData)
            archive.append(bytes)
        }

        let centralOffset = archive.count
        for ((name, bytes), offset) in zip(entries, offsets) {
            let nameData = Data(name.utf8)
            let checksum = crc32(bytes)
            central.appendLE(0x02014b50, width: 4)
            central.appendLE(20, width: 2)
            central.appendLE(20, width: 2)
            central.appendLE(0, width: 2)
            central.appendLE(0, width: 2)
            central.appendLE(0, width: 2)
            central.appendLE(0x0021, width: 2)
            central.appendLE(checksum, width: 4)
            central.appendLE(UInt32(bytes.count), width: 4)
            central.appendLE(UInt32(bytes.count), width: 4)
            central.appendLE(UInt16(nameData.count), width: 2)
            central.appendLE(0, width: 2)
            central.appendLE(0, width: 2)
            central.appendLE(0, width: 2)
            central.appendLE(0, width: 2)
            central.appendLE(0, width: 4)
            central.appendLE(offset, width: 4)
            central.append(nameData)
        }

        guard centralOffset <= Int(UInt32.max), central.count <= Int(UInt32.max) else {
            throw UT99DiagnosticsArchiveError.archiveTooLarge
        }
        archive.append(central)
        archive.appendLE(0x06054b50, width: 4)
        archive.appendLE(0, width: 2)
        archive.appendLE(0, width: 2)
        archive.appendLE(UInt16(entries.count), width: 2)
        archive.appendLE(UInt16(entries.count), width: 2)
        archive.appendLE(UInt32(central.count), width: 4)
        archive.appendLE(UInt32(centralOffset), width: 4)
        archive.appendLE(0, width: 2)
        try archive.write(to: url, options: .atomic)
    }

    private static func isSafeRelativePath(_ name: String) -> Bool {
        guard !name.isEmpty,
              !name.hasPrefix("/"),
              !name.hasSuffix("/"),
              !name.contains("\\"),
              !name.contains("\0") else { return false }
        return name.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
            !$0.isEmpty && $0 != "." && $0 != ".."
        }
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var checksum: UInt32 = 0xffff_ffff
        for byte in data {
            checksum ^= UInt32(byte)
            for _ in 0..<8 {
                checksum = (checksum >> 1) ^ (0xedb8_8320 & (0 &- (checksum & 1)))
            }
        }
        return ~checksum
    }
}

enum UT99DiagnosticRedactor {
    static func redact(_ text: String, homeDirectory: String = NSHomeDirectory()) -> String {
        var result = text
        if !homeDirectory.isEmpty && homeDirectory != "/" {
            result = result.replacingOccurrences(of: homeDirectory, with: "<home>")
        }
        let replacements = [
            (#"/Users/[^/\s]+"#, "<home>"),
            (#"/home/[^/\s]+"#, "<home>"),
            (#"(?i)\b(password|passwd|token|secret|authorization|development_team|teamidentifier)\s*[:=]\s*[^\s]+"#, "$1=<redacted>"),
            (#"(?i)(unreal://[^\s/:@]+:)[^\s@]+@"#, "$1<redacted>@")
        ]
        for (pattern, template) in replacements {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = expression.stringByReplacingMatches(in: result, range: range, withTemplate: template)
        }
        return result
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T, width: Int) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            append(contentsOf: bytes.bindMemory(to: UInt8.self).prefix(width))
        }
    }
}
