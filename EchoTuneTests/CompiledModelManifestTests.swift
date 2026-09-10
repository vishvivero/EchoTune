import Foundation
import Testing
@testable import EchoTune

@Suite(.serialized)
struct CompiledModelManifestTests {
    @Test func validManifestIsAccepted() throws {
        let root = try makeBundle(files: ["AudioEncoder.mlmodelc": ["weights.bin": Data("encoder".utf8)]])
        defer { try? FileManager.default.removeItem(at: root) }

        let result = CompiledModelBundleCheck.validate(modelId: "model-a", bundleResourceURL: root)
        guard case .success(let url) = result else {
            Issue.record("valid manifest was rejected: \(result)")
            return
        }
        #expect(url.lastPathComponent == "CompiledModels")
    }

    @Test func missingManifestIsRejected() throws {
        let root = try makeBundle(files: [:])
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.removeItem(at: root.appendingPathComponent("CompiledModels/compiled-manifest.json"))

        let result = CompiledModelBundleCheck.validate(modelId: "model-a", bundleResourceURL: root)
        #expect(failureReason(result) == "manifest missing or unreadable")
    }

    @Test func malformedManifestIsRejected() throws {
        let root = try makeBundle(files: [:])
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("not json".utf8).write(to: root.appendingPathComponent("CompiledModels/compiled-manifest.json"))

        let result = CompiledModelBundleCheck.validate(modelId: "model-a", bundleResourceURL: root)
        #expect(failureReason(result) == "manifest malformed")
    }

    @Test func schemaMismatchIsRejected() throws {
        let root = try makeBundle(files: [:], schemaVersion: 99)
        defer { try? FileManager.default.removeItem(at: root) }
        let result = CompiledModelBundleCheck.validate(modelId: "model-a", bundleResourceURL: root)
        #expect(failureReason(result) == "manifest schema v99 unsupported")
    }

    @Test func modelMismatchIsRejected() throws {
        let root = try makeBundle(files: [:], modelId: "model-b")
        defer { try? FileManager.default.removeItem(at: root) }
        let result = CompiledModelBundleCheck.validate(modelId: "model-a", bundleResourceURL: root)
        #expect(failureReason(result) == "bundle compiled for model-b, loading model-a")
    }

    @Test func missingEntryIsRejected() throws {
        let root = try makeBundle(files: ["AudioEncoder.mlmodelc": ["weights.bin": Data("encoder".utf8)]])
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.removeItem(at: root.appendingPathComponent("CompiledModels/AudioEncoder.mlmodelc"))
        let result = CompiledModelBundleCheck.validate(modelId: "model-a", bundleResourceURL: root)
        #expect(failureReason(result) == "file AudioEncoder.mlmodelc missing")
    }

    @Test func changedEntryFailsIntegrityCheck() throws {
        let root = try makeBundle(files: ["AudioEncoder.mlmodelc": ["weights.bin": Data("encoder".utf8)]])
        defer { try? FileManager.default.removeItem(at: root) }
        CompiledModelBundleCheck.resetVerificationCache()
        try Data("truncated".utf8).write(to: root.appendingPathComponent("CompiledModels/AudioEncoder.mlmodelc/weights.bin"))
        let result = CompiledModelBundleCheck.validate(modelId: "model-a", bundleResourceURL: root)
        #expect(failureReason(result) == "file AudioEncoder.mlmodelc failed integrity check")
    }

    @Test func successfulVerdictIsCachedByManifestBytes() throws {
        let root = try makeBundle(files: ["AudioEncoder.mlmodelc": ["weights.bin": Data("encoder".utf8)]])
        defer { try? FileManager.default.removeItem(at: root) }
        CompiledModelBundleCheck.resetVerificationCache()
        let first = CompiledModelBundleCheck.validate(modelId: "model-a", bundleResourceURL: root)
        guard case .success = first else {
            Issue.record("initial validation failed: \(first)")
            return
        }
        try Data("changed-after-verification".utf8).write(to: root.appendingPathComponent("CompiledModels/AudioEncoder.mlmodelc/weights.bin"))
        let second = CompiledModelBundleCheck.validate(modelId: "model-a", bundleResourceURL: root)
        guard case .success = second else {
            Issue.record("cached validation did not return success: \(second)")
            return
        }
        CompiledModelBundleCheck.resetVerificationCache()
    }

    @Test func cachedVerdictStillRejectsDeletedEntry() throws {
        let root = try makeBundle(files: ["AudioEncoder.mlmodelc": ["weights.bin": Data("encoder".utf8)]])
        defer { try? FileManager.default.removeItem(at: root) }
        CompiledModelBundleCheck.resetVerificationCache()
        let first = CompiledModelBundleCheck.validate(modelId: "model-a", bundleResourceURL: root)
        guard case .success = first else {
            Issue.record("initial validation failed: \(first)")
            return
        }
        try FileManager.default.removeItem(at: root.appendingPathComponent("CompiledModels/AudioEncoder.mlmodelc"))
        let second = CompiledModelBundleCheck.validate(modelId: "model-a", bundleResourceURL: root)
        #expect(failureReason(second) == "file AudioEncoder.mlmodelc missing")
        CompiledModelBundleCheck.resetVerificationCache()
    }

    private func makeBundle(
        files: [String: [String: Data]],
        modelId: String = "model-a",
        schemaVersion: Int = 1
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CompiledManifest-\(UUID().uuidString)")
        let compiled = root.appendingPathComponent("CompiledModels", isDirectory: true)
        try FileManager.default.createDirectory(at: compiled, withIntermediateDirectories: true)
        var entries: [[String: String]] = []
        for (name, children) in files {
            let entry = compiled.appendingPathComponent(name)
            if name.hasSuffix(".mlmodelc") {
                try FileManager.default.createDirectory(at: entry, withIntermediateDirectories: true)
                for (child, data) in children {
                    let childURL = entry.appendingPathComponent(child)
                    try FileManager.default.createDirectory(at: childURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: childURL)
                }
            } else {
                try FileManager.default.createDirectory(at: entry.deletingLastPathComponent(), withIntermediateDirectories: true)
                try children.values.first?.write(to: entry)
            }
            entries.append(["name": name, "sha256": CompiledModelBundleCheck.digestOfEntry(entry) ?? ""])
        }
        let manifest: [String: Any] = ["schemaVersion": schemaVersion, "modelId": modelId, "files": entries]
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: compiled.appendingPathComponent("compiled-manifest.json"))
        return root
    }

    private func failureReason(_ result: Result<URL, CompiledModelBundleValidationError>) -> String? {
        guard case .failure(let error) = result else { return nil }
        return error.reason
    }
}
