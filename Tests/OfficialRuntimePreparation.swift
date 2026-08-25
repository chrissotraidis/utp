import Foundation

@main
struct OfficialRuntimePreparation {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            throw Failure("usage: OfficialRuntimePreparation GOTY.iso output-root")
        }
        let fileManager = FileManager.default
        let image = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
        let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true).standardizedFileURL
        guard fileManager.fileExists(atPath: image.path),
              !fileManager.fileExists(atPath: output.path) else {
            throw Failure("input must exist and output must not already exist")
        }

        let extraction = output.deletingLastPathComponent()
            .appendingPathComponent(".official-runtime-extraction-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: extraction) }
        let extractedCount = try UT99ISO9660Extractor.extractDataDirectories(
            from: image,
            to: extraction
        )
        try fileManager.createDirectory(at: output, withIntermediateDirectories: true)
        let importedCount = try UT99DataImporter.importFolder(
            extraction,
            to: output,
            cancellation: UT99ImportCancellation()
        ) { _ in }
        let inspection = try UT99DataImportTransaction.inspectInstalledManifest(at: output)
        guard extractedCount == importedCount,
              extractedCount >= 620,
              inspection.isValid,
              UT99RuntimeSupport.isReady(at: output) else {
            throw Failure(
                "official runtime preparation failed extracted=\(extractedCount) " +
                    "imported=\(importedCount) valid=\(inspection.validFiles)/\(inspection.expectedFiles) " +
                    "missingRuntime=\(UT99RuntimeSupport.missingRequiredFiles(at: output))"
            )
        }
        print(
            "UT99 official runtime preparation PASS files=\(importedCount) " +
                "bytes=\(inspection.totalBytes) output=\(output.path)"
        )
    }

    private struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
