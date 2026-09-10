import Foundation
import Testing
@testable import EchoTune

struct DownloadResumeTests {
    @Test func completeWhisperStagingFolderPassesStrictValidation() throws {
        let root = try makeFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        addRequiredFiles(to: root)
        #expect(ModelArtifactValidator.hasRequiredWhisperModelFiles(at: root))
    }

    @Test func eachRequiredWhisperArtifactIsDetectedWhenMissing() throws {
        let names = [
            "MelSpectrogram.mlmodelc",
            "AudioEncoder.mlmodelc",
            "TextDecoder.mlmodelc",
            "TextDecoderContextPrefill.mlmodelc",
            "vocabulary.json"
        ]
        for missing in names {
            let root = try makeFolder()
            addRequiredFiles(to: root)
            try removeArtifact(named: missing, from: root)
            #expect(!ModelArtifactValidator.hasRequiredWhisperModelFiles(at: root), "missing \(missing) must fail")
            try? FileManager.default.removeItem(at: root)
        }
    }

    @Test func truncatedModelComponentIsRejected() throws {
        let root = try makeFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        addRequiredFiles(to: root)
        try Data().write(to: root.appendingPathComponent("AudioEncoder.mlmodelc/weights.bin"))
        #expect(!ModelArtifactValidator.hasRequiredWhisperModelFiles(at: root))
    }

    private func makeFolder() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("DownloadResume-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func addRequiredFiles(to root: URL) {
        let models = ["MelSpectrogram", "AudioEncoder", "TextDecoder", "TextDecoderContextPrefill"]
        for name in models {
            let dir = root.appendingPathComponent("\(name).mlmodelc")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? Data("model-payload".utf8).write(to: dir.appendingPathComponent("weights.bin"))
        }
        try? Data("{}".utf8).write(to: root.appendingPathComponent("config.json"))
        try? Data("{}".utf8).write(to: root.appendingPathComponent("generation_config.json"))
        try? Data("vocabulary".utf8).write(to: root.appendingPathComponent("vocabulary.json"))
    }

    private func removeArtifact(named name: String, from root: URL) throws {
        try FileManager.default.removeItem(at: root.appendingPathComponent(name))
    }
}
