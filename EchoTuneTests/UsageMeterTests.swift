import Foundation
import Testing
@testable import EchoTune

struct UsageMeterTests {
    private func temporaryURL() -> (URL, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("echotune-usage-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory, directory.appendingPathComponent("usage-meter.json"))
    }

    private func record(seconds: Double = 60, provider: String = "Deepgram", model: String = "nova-3") -> UsageRecord {
        UsageRecord(provider: provider, model: model, seconds: seconds, startedAt: Date(), disposition: "streamed")
    }

    @Test func knownDeepgramPriceIsEstimatedLocally() {
        let meter = UsageMeter(fileURL: temporaryURL().1)
        #expect(meter.estimatedCost(for: record()) == Decimal(string: "0.0077"))
    }

    @Test func unknownModelReturnsNilRatherThanZero() {
        let meter = UsageMeter(fileURL: temporaryURL().1)
        #expect(meter.estimatedCost(for: record(provider: "Unknown", model: "future") ) == nil)
    }

    @Test func rotationBacksUpBeforeCappingRecords() {
        let (directory, fileURL) = temporaryURL()
        let meter = UsageMeter(fileURL: fileURL, maximumRecords: 2)
        meter.record(record(seconds: 1))
        meter.record(record(seconds: 2))
        meter.record(record(seconds: 3))

        #expect(meter.recent.count == 2)
        #expect(meter.recent.map(\.seconds) == [2, 3])
        let backups = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.contains("backup-") } ?? []
        #expect(!backups.isEmpty)
        let reloaded = UsageMeter(fileURL: fileURL, maximumRecords: 2)
        #expect(reloaded.recent.count == 2)
    }

    @Test func corruptFileIsParkedAndDoesNotCrashLoad() throws {
        let (directory, fileURL) = temporaryURL()
        try Data("not-json".utf8).write(to: fileURL)
        let meter = UsageMeter(fileURL: fileURL)

        #expect(meter.recent.isEmpty)
        let parked = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.contains("corrupt-") } ?? []
        #expect(!parked.isEmpty)
    }
}
