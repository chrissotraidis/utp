import Foundation

@main
struct GameDataAcquisitionTests {
    static func main() throws {
        guard CommandLine.arguments.count >= 2 else { throw Failure("missing ISO fixture") }
        let image = URL(fileURLWithPath: CommandLine.arguments[1])
        let official = CommandLine.arguments.contains("--official")
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("UT99ISOExtractionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: destination) }

        var finalProgress = 0
        let count = try UT99ISO9660Extractor.extractDataDirectories(
            from: image,
            to: destination,
            progress: { update in finalProgress = update.completedFiles }
        )
        guard count == finalProgress else { throw Failure("progress did not reach extracted file count") }
        for directory in UT99DataImportTransaction.contentDirectoryNames {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(
                atPath: destination.appendingPathComponent(directory).path,
                isDirectory: &isDirectory
            ), isDirectory.boolValue else {
                throw Failure("missing extracted directory \(directory)")
            }
        }
        guard !FileManager.default.fileExists(
            atPath: destination.appendingPathComponent("Textures/LadderFonts.utx").path
        ), !FileManager.default.fileExists(
            atPath: destination.appendingPathComponent("Textures/UWindowFonts.utx").path
        ) else {
            throw Failure("incompatible font textures were extracted")
        }

        if official {
            guard count >= 280 else { throw Failure("official image extracted too few files: \(count)") }
            guard FileManager.default.fileExists(
                atPath: destination.appendingPathComponent("Maps/DM-Deck16][.unr.uz").path
            ) else {
                throw Failure("official image is missing compressed Deck16")
            }
        } else {
            guard count == 4 else { throw Failure("fixture expected 4 files, got \(count)") }
            guard try String(
                contentsOf: destination.appendingPathComponent("Maps/DM-Fixture.unr.uz"),
                encoding: .utf8
            ) == "map" else {
                throw Failure("fixture map contents changed")
            }
        }

        guard UT99AuthorizedGameData.expectedISOBytes == 649_633_792,
              UT99AuthorizedGameData.expectedISOSHA256 == "e184984ca88f001c5ddd52035d76cd64e266e26c74975161b5ed72366c74704f",
              UT99AuthorizedGameData.isoMirrors.first?.host == "files.oldunreal.net" else {
            throw Failure("authorized-source contract changed")
        }
        print("UT99 game-data acquisition PASS files=\(count) official=\(official)")
    }

    private struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
