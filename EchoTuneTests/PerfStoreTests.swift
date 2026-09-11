import XCTest
@testable import EchoTune

final class PerfStoreTests: XCTestCase {
    private func temporaryURL(_ name: String = UUID().uuidString) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("echotune-perf-\(name).json")
    }

    private func record(_ decodeMs: Double = 100) -> PerfStore.SessionRecord {
        PerfStore.SessionRecord(
            engine: "Whisper",
            modelID: "test-model",
            recordingDuration: 3,
            transcriptionSeconds: decodeMs / 1000,
            enhancementMs: 50,
            provider: "Ollama",
            p50TickMs: 20,
            p95TickMs: 40,
            vadMethod: "silero",
            vadDecisionCounts: ["speech": 2, "silence": 1],
            agreementDisposition: "streamed"
        )
    }

    func testRoundTripAndMetricFields() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = PerfStore(fileURL: url)
        store.record(record())

        let loaded = PerfStore(fileURL: url)
        XCTAssertEqual(loaded.records.count, 1)
        XCTAssertEqual(loaded.last?.modelID, "test-model")
        XCTAssertEqual(loaded.last?.p50TickMs, 20)
        XCTAssertEqual(loaded.last?.vadDecisionCounts["speech"], 2)
        XCTAssertEqual(loaded.last?.recordType, "performanceSession")
    }

    func testMedianAndP95IgnoreInvalidValues() {
        XCTAssertEqual(PerfStore.median([1, 3, 2, .nan]), 2)
        XCTAssertEqual(PerfStore.percentile([1, 2, 3, 4], 0.95), 4)
        XCTAssertNil(PerfStore.median([.nan, .infinity]))
    }

    func testRotationBacksUpBeforeCapping() {
        let url = temporaryURL()
        defer {
            try? FileManager.default.removeItem(at: url)
            for file in (try? FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)) ?? [] where file.lastPathComponent.contains("echotune-perf-") && file.pathExtension == "json" {
                try? FileManager.default.removeItem(at: file)
            }
        }
        let store = PerfStore(fileURL: url, maximumRecords: 2)
        store.record(record(1))
        store.record(record(2))
        store.record(record(3))
        XCTAssertEqual(store.records.count, 2)
        XCTAssertTrue(store.records.allSatisfy { $0.decodeMs >= 2 })
        let backups = ((try? FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)) ?? []).filter { $0.lastPathComponent.contains("backup-") }
        XCTAssertFalse(backups.isEmpty)
    }

    func testCorruptInputIsParkedAndStoreStartsEmpty() throws {
        let url = temporaryURL()
        defer {
            try? FileManager.default.removeItem(at: url)
            if let recoveryPath = UserDefaults.standard.string(forKey: "perfStoreLastRecoveryPath") {
                try? FileManager.default.removeItem(atPath: recoveryPath)
                UserDefaults.standard.removeObject(forKey: "perfStoreLastRecoveryPath")
            }
        }
        try Data("not json".utf8).write(to: url)
        let store = PerfStore(fileURL: url)
        XCTAssertTrue(store.records.isEmpty)
        XCTAssertNotNil(UserDefaults.standard.string(forKey: "perfStoreLastRecoveryPath"))
    }
}
