import XCTest
@testable import EchoTune

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
}
