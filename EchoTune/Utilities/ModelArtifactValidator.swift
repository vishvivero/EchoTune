import Foundation
import WhisperKit

/// Validates WhisperKit model artifacts before they are exposed as installed or loaded.
/// Kept independent from UI and download orchestration so it can be regression-tested.
enum ModelArtifactValidator {
    static let minimumCompiledModelComponentSize: Int64 = 50 * 1024
    private static let requiredModels = ["MelSpectrogram", "AudioEncoder", "TextDecoder"]
    private static let requiredWhisperModels = ["MelSpectrogram", "AudioEncoder", "TextDecoder", "TextDecoderContextPrefill"]
    private static let requiredMetadata = ["config.json", "generation_config.json"]

    static func normalizedDirectory(at candidate: URL) -> URL? {
        if hasRequiredFiles(at: candidate) { return candidate }
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: candidate, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return nil }
        return contents.first { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true && hasRequiredFiles(at: url)
        }
    }

    static func hasRequiredFiles(at folder: URL) -> Bool {
        for modelName in requiredModels {
            let modelURL = ModelUtilities.detectModelURL(inFolder: folder, named: modelName)
            guard FileManager.default.fileExists(atPath: modelURL.path), directorySize(at: modelURL) >= minimumCompiledModelComponentSize else {
                return false
            }
        }
        return requiredMetadata.allSatisfy { FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path) }
    }

    /// Strict validation used at the staging boundary when tokenizer artifacts
    /// are present in the downloaded snapshot.
    static func hasRequiredWhisperModelFiles(at folder: URL) -> Bool {
        guard hasRequiredWhisperModelCoreFiles(at: folder) else { return false }
        let vocabularyCandidates = ["vocabulary.json", "tokenizer.json", "vocab.json"]
        return vocabularyCandidates.contains { nonEmptyFile(at: folder.appendingPathComponent($0)) }
    }

    /// WhisperKit 0.15.0 downloads tokenizer data into its sibling Hub cache,
    /// not always into the variant folder. This core gate therefore validates
    /// every model component and metadata before staging promotion while the
    /// strict method above additionally verifies an in-folder tokenizer file.
    static func hasRequiredWhisperModelCoreFiles(at folder: URL) -> Bool {
        for modelName in requiredWhisperModels {
            let modelURL = ModelUtilities.detectModelURL(inFolder: folder, named: modelName)
            guard FileManager.default.fileExists(atPath: modelURL.path), directorySize(at: modelURL) > 0 else {
                return false
            }
        }
        return requiredMetadata.allSatisfy { nonEmptyFile(at: folder.appendingPathComponent($0)) }
    }

    private static func nonEmptyFile(at url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true,
              let size = values.fileSize else { return false }
        return size > 0
    }

    private static func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return enumerator.reduce(into: Int64(0)) { total, item in
            guard let fileURL = item as? URL,
                  let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return }
            total += Int64(size)
        }
    }
}
