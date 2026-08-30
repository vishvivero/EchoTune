import Foundation
import WhisperKit

/// Validates WhisperKit model artifacts before they are exposed as installed or loaded.
/// Kept independent from UI and download orchestration so it can be regression-tested.
enum ModelArtifactValidator {
    static let minimumCompiledModelComponentSize: Int64 = 50 * 1024
    private static let requiredModels = ["MelSpectrogram", "AudioEncoder", "TextDecoder"]
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

    private static func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return enumerator.reduce(into: Int64(0)) { total, item in
            guard let fileURL = item as? URL,
                  let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return }
            total += Int64(size)
        }
    }
}
