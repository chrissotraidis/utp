import Foundation

@main
struct GameDataAcquisitionTests {
    static func main() throws {
        guard CommandLine.arguments.count >= 2 else { throw Failure("missing ISO fixture") }
        let image = URL(fileURLWithPath: CommandLine.arguments[1])
        let official = CommandLine.arguments.contains("--official")
        let patchIndex = CommandLine.arguments.firstIndex(of: "--patch")
        let patchURL = patchIndex.flatMap { index in
            CommandLine.arguments.indices.contains(index + 1)
                ? URL(fileURLWithPath: CommandLine.arguments[index + 1])
                : nil
        }
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
        let retailMissing = UT99RuntimeSupport.missingRequiredFiles(at: destination)
        guard Set(retailMissing) == Set(UT99RuntimeSupport.requiredTextureFileNames) else {
            throw Failure("retail extraction has unexpected runtime gaps: \(retailMissing)")
        }
        guard !UT99RuntimeSupport.isReady(at: destination) else {
            throw Failure("retail ISO packages were incorrectly accepted as matching v469e runtime")
        }
        guard !FileManager.default.fileExists(
            atPath: destination.appendingPathComponent("System/Engine.dll").path
        ), !FileManager.default.fileExists(
            atPath: destination.appendingPathComponent("System/Setup.exe").path
        ) else {
            throw Failure("native System content was extracted")
        }
        guard !FileManager.default.fileExists(
            atPath: destination.appendingPathComponent("Textures/LadderFonts.utx").path
        ), !FileManager.default.fileExists(
            atPath: destination.appendingPathComponent("Textures/UWindowFonts.utx").path
        ) else {
            throw Failure("incompatible font textures were extracted")
        }

        if official {
            guard count >= 620 else { throw Failure("official image extracted too few files: \(count)") }
            guard FileManager.default.fileExists(
                atPath: destination.appendingPathComponent("Maps/DM-Deck16][.unr.uz").path
            ) else {
                throw Failure("official image is missing compressed Deck16")
            }
        } else {
            guard count == 15 else { throw Failure("fixture expected 15 files, got \(count)") }
            guard try String(
                contentsOf: destination.appendingPathComponent("Maps/DM-Fixture.unr.uz"),
                encoding: .utf8
            ) == "map" else {
                throw Failure("fixture map contents changed")
            }
        }

        if let patchURL {
            let patchFiles = try UT99ZipArchive.extractV469eRuntimePatch(patchURL, to: destination)
            guard patchFiles == 189 else {
                throw Failure("official patch extracted unexpected runtime count: \(patchFiles)")
            }
            guard UT99RuntimeSupport.isReady(at: destination) else {
                throw Failure("official patch did not produce verified v469e runtime: \(UT99RuntimeSupport.missingRuntimeFiles(at: destination))")
            }
            guard !FileManager.default.fileExists(atPath: destination.appendingPathComponent("System/Core.dll").path),
                  !FileManager.default.fileExists(atPath: destination.appendingPathComponent("System/Setup.exe").path),
                  !FileManager.default.fileExists(atPath: destination.appendingPathComponent("SystemLocalized").path) else {
                throw Failure("patch extraction admitted native or non-canonical content")
            }
            for fontTexture in UT99RuntimeSupport.requiredTextureFileNames {
                guard FileManager.default.fileExists(
                    atPath: destination.appendingPathComponent("Textures/\(fontTexture)").path
                ) else {
                    throw Failure("patch extraction omitted required font texture \(fontTexture)")
                }
            }
            let installed = FileManager.default.temporaryDirectory
                .appendingPathComponent("UT99OfficialRuntimeImportTests-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: installed) }
            let imported = try UT99DataImporter.importFolder(
                destination,
                to: installed,
                cancellation: UT99ImportCancellation()
            ) { _ in }
            guard imported > count,
                  UT99RuntimeSupport.isReady(at: installed) else {
                throw Failure("verified runtime did not survive transactional import: \(imported) files")
            }
            for fontTexture in UT99RuntimeSupport.requiredTextureFileNames {
                guard FileManager.default.fileExists(
                    atPath: installed.appendingPathComponent("Textures/\(fontTexture)").path
                ) else {
                    throw Failure("transactional import omitted required font texture \(fontTexture)")
                }
            }
            let installedUser = try String(
                contentsOf: installed.appendingPathComponent("System/User.ini"),
                encoding: .utf8
            )
            for binding in ["W=MoveForward", "A=StrafeLeft", "S=MoveBackward", "D=StrafeRight", "E=InventoryActivate"] {
                guard installedUser.contains(binding) else {
                    throw Failure("Apple keyboard profile omitted \(binding)")
                }
            }
            let system = destination.appendingPathComponent("System", isDirectory: true)
            guard try Data(contentsOf: system.appendingPathComponent("Default.ini")) ==
                    Data(contentsOf: system.appendingPathComponent("UnrealTournament.ini")),
                  try Data(contentsOf: system.appendingPathComponent("DefUser.ini")) ==
                    Data(contentsOf: system.appendingPathComponent("User.ini")) else {
                throw Failure("automatic patch did not seed v469e mutable configs")
            }
        }

        guard UT99AuthorizedGameData.expectedISOBytes == 649_633_792,
              UT99AuthorizedGameData.expectedISOSHA256 == "e184984ca88f001c5ddd52035d76cd64e266e26c74975161b5ed72366c74704f",
              UT99AuthorizedGameData.isoMirrors.first?.host == "files.oldunreal.net",
              UT99AuthorizedGameData.expectedPatchBytes == 106_165_760,
              UT99AuthorizedGameData.expectedPatchSHA256 == "8c94eb7e990f5480b1fb7bcb1bd15c2512da134dbf01bfa16e7f99f0a8a0ee86",
              UT99AuthorizedGameData.patchMirrors.first?.host == "github.com" else {
            throw Failure("authorized-source contract changed")
        }
        print("UT99 game-data acquisition PASS files=\(count) official=\(official) patch=\(patchURL != nil)")
    }

    private struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
