import XCTest
@testable import EchoTune

@MainActor
final class ParakeetBackendTests: XCTestCase {
    func testCatalogAssignsStableBackends() {
        let models = ModelManager.shared.availableModels
        XCTAssertEqual(models.first(where: { $0.id == "apple-speech" })?.backend, .appleSpeech)
        XCTAssertEqual(models.first(where: { $0.id == "distil-whisper_distil-large-v3_turbo_600MB" })?.backend, .whisper)
        XCTAssertEqual(models.first(where: { $0.id == "parakeet-tdt-0.6b-v2" })?.backend, .parakeet)
        XCTAssertEqual(models.first(where: { $0.id == "parakeet-tdt-0.6b-v3" })?.backend, .parakeet)
        XCTAssertEqual(models.first(where: { $0.id == "parakeet-unified-en-0.6b" })?.backend, .parakeet)
        XCTAssertEqual(models.first(where: { $0.id == "sensevoice-small" })?.backend, .senseVoice)
        XCTAssertEqual(models.first(where: { $0.id == "paraformer-large-zh" })?.backend, .paraformer)
        XCTAssertEqual(models.first(where: { $0.id == "parakeet-ja-0.6b" })?.backend, .parakeet)
        XCTAssertEqual(models.first(where: { $0.id == "parakeet-tdt-ctc-110m" })?.backend, .parakeet)
        XCTAssertEqual(models.first(where: { $0.id == "paraformer-large-zh" })?.fixedLanguage, "zh-CN")
        XCTAssertEqual(models.first(where: { $0.id == "parakeet-ja-0.6b" })?.fixedLanguage, "ja-JP")
        XCTAssertNil(models.first(where: { $0.id == "sensevoice-small" })?.fixedLanguage)
        XCTAssertEqual(models.first(where: { $0.id == "groq-whisper-large-v3-turbo" })?.backend, .groq)
        XCTAssertEqual(models.first(where: { $0.id == "deepgram-nova" })?.backend, .deepgram)
    }

    func testParakeetIDsMapToPinnedFluidAudioVersions() {
        XCTAssertEqual(ParakeetEngine.ModelVersion(rawValue: "parakeet-tdt-0.6b-v2"), .v2)
        XCTAssertEqual(ParakeetEngine.ModelVersion(rawValue: "parakeet-tdt-0.6b-v3"), .v3)
        XCTAssertEqual(ParakeetEngine.ModelVersion(rawValue: "parakeet-ja-0.6b"), .japanese)
        XCTAssertEqual(ParakeetEngine.ModelVersion(rawValue: "parakeet-tdt-ctc-110m"), .ctc110m)
        XCTAssertNil(ParakeetEngine.version(for: "parakeet-unified-en-0.6b"))
    }

    func testUnsupportedParakeetIDDoesNotPretendToBeWhisper() {
        XCTAssertNil(ParakeetEngine.version(for: "openai_whisper-base"))
    }

    func testPhase9RuntimeBenchmarkWhenRequested() async throws {
        let defaults = UserDefaults.standard
        let enabled = ProcessInfo.processInfo.environment["PHASE9_RUNTIME"] == "1"
            || defaults.bool(forKey: "phase9Runtime")
        guard enabled else {
            throw XCTSkip("Set PHASE9_RUNTIME=1 or phase9Runtime=true to run the opt-in model benchmark")
        }
        let fixturePath = ProcessInfo.processInfo.environment["PHASE9_FIXTURE"]
            ?? defaults.string(forKey: "phase9Fixture")
            ?? ""
        guard !fixturePath.isEmpty, FileManager.default.fileExists(atPath: fixturePath) else {
            throw XCTSkip("PHASE9_FIXTURE/phase9Fixture must point to a captured audio file")
        }
        let modelID = ProcessInfo.processInfo.environment["PHASE9_MODEL"]
            ?? defaults.string(forKey: "phase9Model")
            ?? "sensevoice-small"
        let model = ModelManager.shared.availableModels.first(where: { $0.id == modelID })
            ?? AIModel(id: modelID, name: modelID, size: 0, description: "benchmark", language: "auto", url: URL(string: "https://example.com")!, type: .balanced, category: .local, backend: modelID == "sensevoice-small" ? .senseVoice : (modelID == "paraformer-large-zh" ? .paraformer : .parakeet))
        let audio = try Data(contentsOf: URL(fileURLWithPath: fixturePath))
        let started = Date()
        switch model.backend {
        case .senseVoice:
            try await SenseVoiceEngine.shared.prepareModel(model)
        case .paraformer:
            try await ParaformerEngine.shared.prepareModel(model)
        default:
            try await ParakeetEngine.shared.prepareModel(model)
        }
        let loadedAt = Date()
        let result: WhisperTranscriptionResult
        switch model.backend {
        case .senseVoice:
            result = try await SenseVoiceEngine.shared.transcribe(audioData: audio)
        case .paraformer:
            result = try await ParaformerEngine.shared.transcribe(audioData: audio)
        default:
            result = try await ParakeetEngine.shared.transcribe(audioData: audio)
        }
        let decodedAt = Date()
        print("P9_RUNTIME model=\(modelID) loadSeconds=\(String(format: "%.3f", loadedAt.timeIntervalSince(started))) decodeSeconds=\(String(format: "%.3f", decodedAt.timeIntervalSince(loadedAt))) totalSeconds=\(String(format: "%.3f", decodedAt.timeIntervalSince(started))) text=\(result.outputText)")
        XCTAssertFalse(result.outputText.isEmpty)
    }
}
