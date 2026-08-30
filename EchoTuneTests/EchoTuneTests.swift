//
//  EchoTuneTests.swift
//  EchoTuneTests
//
//  Created by Vishnu Raj on 25/10/2025.
//

import Foundation
import Testing
@testable import EchoTune

struct EchoTuneTests {

    @Test func example() async throws {
        #expect(true)
    }

    @Test func incompleteModelArtifactsAreRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("EchoTuneTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let config = root.appendingPathComponent("config.json")
        try Data("{}".utf8).write(to: config)
        #expect(ModelArtifactValidator.normalizedDirectory(at: root) == nil)
    }

    @Test func completeModelArtifactsAreAccepted() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("EchoTuneTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data("{}".utf8).write(to: root.appendingPathComponent("config.json"))
        try Data("{}".utf8).write(to: root.appendingPathComponent("generation_config.json"))
        for name in ["MelSpectrogram", "AudioEncoder", "TextDecoder"] {
            let model = root.appendingPathComponent("\(name).mlmodelc")
            try FileManager.default.createDirectory(at: model, withIntermediateDirectories: true)
            try Data(repeating: 0, count: Int(ModelArtifactValidator.minimumCompiledModelComponentSize)).write(to: model.appendingPathComponent("weights.bin"))
        }
        #expect(ModelArtifactValidator.normalizedDirectory(at: root) == root)
    }

}
