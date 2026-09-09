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

    // MARK: - CorrectionLearner diff engine

    @Test func singleWordSubstitutionIsDetected() {
        let learner = CorrectionLearner.shared
        let pair = learner.diffSingleWordSubstitution(
            old: "I work on the teem project",
            new: "I work on the team project"
        )
        #expect(pair?.spoken.lowercased() == "teem")
        #expect(pair?.written.lowercased() == "team")
    }

    @Test func multiWordChangesAreRejected() {
        let learner = CorrectionLearner.shared
        #expect(learner.diffSingleWordSubstitution(old: "the cat sat", new: "the dog ran away quickly") == nil)
        #expect(learner.diffSingleWordSubstitution(old: "one two three", new: "one three") == nil)
    }

    @Test func identicalTextYieldsNoCandidate() {
        let learner = CorrectionLearner.shared
        #expect(learner.diffSingleWordSubstitution(old: "hello world", new: "hello world") == nil)
        #expect(learner.diffSingleWordSubstitution(old: "", new: "hello") == nil)
    }

    @Test func caseOnlySwapIsRejectedByLearner() {
        // Diff finds the swap, but recordCorrection ignores case-only changes.
        let before = CorrectionLearner.shared.suggestions.count
        CorrectionLearner.shared.recordCorrection(from: "I like Team work", to: "I like team work")
        #expect(CorrectionLearner.shared.suggestions.count == before)
    }

    @Test func punctuationOnlyChangeIsRejected() {
        let before = CorrectionLearner.shared.suggestions.count
        CorrectionLearner.shared.recordCorrection(from: "Hello world", to: "Hello world!")
        #expect(CorrectionLearner.shared.suggestions.count == before)
    }

}
