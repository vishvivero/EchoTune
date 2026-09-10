//
//  CompiledModelManifest.swift
//  EchoTune
//
//  Phase 3: validate the pre-compiled CoreML models bundled in the app before
//  WhisperKit is told to use them. A stale or partially-deleted bundle must fall
//  back to normal CoreML compilation instead of producing broken inference.
//
//  The digest definition here must match compute_entry_digest in
//  Scripts/bundle_default_model.sh exactly.
//

import Foundation
import CryptoKit

struct CompiledModelManifest: Decodable {
    let schemaVersion: Int
    let modelId: String
    let files: [File]

    struct File: Decodable {
        let name: String
        let sha256: String
    }

    static let currentSchemaVersion = 1
}

struct CompiledModelBundleValidationError: Error, Equatable, CustomStringConvertible {
    let reason: String
    var description: String { reason }
}

enum CompiledModelBundleCheck {
    private static let hashChunkSize = 1 << 20
    private static let verifiedDefaultsKey = "compiledModelsVerifiedKey"

    static func validate(
        modelId: String,
        bundleResourceURL: URL?,
        fileManager: FileManager = .default
    ) -> Result<URL, CompiledModelBundleValidationError> {
        guard let bundleResourceURL else {
            return failure("no app resource URL")
        }
        let compiledDir = bundleResourceURL.appendingPathComponent("CompiledModels", isDirectory: true)
        guard fileManager.fileExists(atPath: compiledDir.path) else {
            return failure("no compiled models in bundle")
        }
        let manifestURL = compiledDir.appendingPathComponent("compiled-manifest.json")
        guard let manifestData = try? Data(contentsOf: manifestURL) else {
            return failure("manifest missing or unreadable")
        }
        guard let manifest = try? JSONDecoder().decode(CompiledModelManifest.self, from: manifestData) else {
            return failure("manifest malformed")
        }
        guard manifest.schemaVersion == CompiledModelManifest.currentSchemaVersion else {
            return failure("manifest schema v\(manifest.schemaVersion) unsupported")
        }
        guard manifest.modelId == modelId else {
            return failure("bundle compiled for \(manifest.modelId), loading \(modelId)")
        }

        let cacheKey = "\(manifest.modelId):\(sha256Hex(manifestData))"
        if UserDefaults.standard.string(forKey: verifiedDefaultsKey) == cacheKey {
            // The manifest bytes are unchanged, so skip expensive re-hashing,
            // but still reject a bundle entry deleted after the prior load.
            for file in manifest.files {
                let entryURL = compiledDir.appendingPathComponent(file.name)
                guard fileManager.fileExists(atPath: entryURL.path) else {
                    return failure("file \(file.name) missing")
                }
            }
            return .success(compiledDir)
        }

        let start = CFAbsoluteTimeGetCurrent()
        for file in manifest.files {
            let entryURL = compiledDir.appendingPathComponent(file.name)
            guard fileManager.fileExists(atPath: entryURL.path) else {
                return failure("file \(file.name) missing")
            }
            guard let digest = digestOfEntry(entryURL, fileManager: fileManager) else {
                return failure("file \(file.name) unreadable")
            }
            guard digest == file.sha256 else {
                return failure("file \(file.name) failed integrity check")
            }
        }
        let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        debugLog("🔐 Compiled models verified in \(ms) ms")
        UserDefaults.standard.set(cacheKey, forKey: verifiedDefaultsKey)
        return .success(compiledDir)
    }

    static func resetVerificationCache() {
        UserDefaults.standard.removeObject(forKey: verifiedDefaultsKey)
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func digestOfEntry(_ url: URL, fileManager: FileManager = .default) -> String? {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return nil }
        if !isDir.boolValue {
            return sha256HexOfFile(at: url)
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else { return nil }

        let prefix = url.path.hasSuffix("/") ? url.path : url.path + "/"
        var files: [(rel: String, url: URL)] = []
        for case let fileURL as URL in enumerator {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            let rel = fileURL.path.hasPrefix(prefix) ? String(fileURL.path.dropFirst(prefix.count)) : fileURL.lastPathComponent
            files.append((rel, fileURL))
        }
        files.sort { Array($0.rel.utf8).lexicographicallyPrecedes(Array($1.rel.utf8)) }

        var hasher = SHA256()
        for file in files {
            hasher.update(data: Data(file.rel.utf8))
            hasher.update(data: Data([0]))
            guard streamFile(at: file.url, into: &hasher) else { return nil }
            hasher.update(data: Data([0]))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func failure(_ reason: String) -> Result<URL, CompiledModelBundleValidationError> {
        .failure(CompiledModelBundleValidationError(reason: reason))
    }

    private static func sha256HexOfFile(at url: URL) -> String? {
        var hasher = SHA256()
        guard streamFile(at: url, into: &hasher) else { return nil }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func streamFile(at url: URL, into hasher: inout SHA256) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        while true {
            guard let chunk = try? handle.read(upToCount: hashChunkSize), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return true
    }
}