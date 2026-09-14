import Foundation

/// Local append-only session telemetry. It deliberately contains no network,
/// analytics, or remote I/O code; the dashboard reads this store directly.
///
/// Explicitly `nonisolated`: the project builds with the MainActor default
/// actor isolation, but this type is a lock-guarded value store that is safe
/// from any thread. Leaving it MainActor-isolated made deallocation on older
/// runtimes (macOS 14/15) go through the back-deployed isolated-deinit path,
/// which crashed with heap corruption when an instance was released off the
/// main actor (observed in CI on macOS 15).
nonisolated final class PerfStore {
    static let shared = PerfStore()

    struct SessionRecord: Codable, Equatable, Identifiable, Sendable {
        let id: UUID
        let recordedAt: Date
        let schemaVersion: Int
        let recordType: String

        // Existing runtime benchmark schema fields (kept compatible with the
        // validator; telemetry-specific fields extend the same record).
        let fixtureDurationSeconds: Double
        let modelID: String
        let modelPath: String
        let loadSeconds: Double
        let transcriptionSeconds: Double
        let peakRssKiB: Double
        let cpuPercent: Double
        let transcript: String
        let success: Bool

        // Phase 10 optional session metrics.
        let engine: String
        let firstTickMs: Double?
        let p50TickMs: Double?
        let p95TickMs: Double?
        let decodeMs: Double
        let vadMethod: String
        let vadDecisionCounts: [String: Int]
        let agreementDisposition: String?
        let cloudSeconds: Double
        let enhancementMs: Double?
        let provider: String?

        init(
            id: UUID = UUID(),
            recordedAt: Date = Date(),
            engine: String,
            modelID: String,
            recordingDuration: Double,
            transcriptionSeconds: Double,
            enhancementMs: Double?,
            provider: String?,
            firstTickMs: Double? = nil,
            p50TickMs: Double? = nil,
            p95TickMs: Double? = nil,
            vadMethod: String = "unknown",
            vadDecisionCounts: [String: Int] = [:],
            agreementDisposition: String? = nil,
            cloudSeconds: Double = 0,
            success: Bool = true
        ) {
            self.id = id
            self.recordedAt = recordedAt
            self.schemaVersion = 1
            self.recordType = "performanceSession"
            self.fixtureDurationSeconds = Self.nonNegative(recordingDuration)
            self.modelID = modelID
            self.modelPath = ""
            self.loadSeconds = 0
            self.transcriptionSeconds = Self.nonNegative(transcriptionSeconds)
            self.peakRssKiB = 0
            self.cpuPercent = 0
            self.transcript = ""
            self.success = success
            self.engine = engine
            self.firstTickMs = Self.optionalNonNegative(firstTickMs)
            self.p50TickMs = Self.optionalNonNegative(p50TickMs)
            self.p95TickMs = Self.optionalNonNegative(p95TickMs)
            self.decodeMs = Self.nonNegative(transcriptionSeconds * 1000)
            self.vadMethod = vadMethod
            self.vadDecisionCounts = vadDecisionCounts
            self.agreementDisposition = agreementDisposition
            self.cloudSeconds = Self.nonNegative(cloudSeconds)
            self.enhancementMs = Self.optionalNonNegative(enhancementMs)
            self.provider = provider
        }

        init(from metrics: PerformanceMonitor.TranscriptionMetrics) {
            self.init(
                engine: metrics.engineUsed,
                modelID: metrics.modelUsed,
                recordingDuration: metrics.recordingDuration,
                transcriptionSeconds: metrics.transcriptionProcessingTime,
                enhancementMs: metrics.enhancementProcessingTime > 0 ? metrics.enhancementProcessingTime * 1000 : nil,
                provider: metrics.enhancementEngine.isEmpty ? nil : metrics.enhancementEngine,
                firstTickMs: PerfStore.median(metrics.liveTickLatencies.prefix(1).map { $0 * 1000 }),
                p50TickMs: PerfStore.median(metrics.liveTickLatencies.map { $0 * 1000 }),
                p95TickMs: PerfStore.percentile(metrics.liveTickLatencies.map { $0 * 1000 }, 0.95),
                vadMethod: "unknown"
            )
        }

        private static func nonNegative(_ value: Double) -> Double {
            value.isFinite ? max(0, value) : 0
        }

        private static func optionalNonNegative(_ value: Double?) -> Double? {
            guard let value, value.isFinite else { return nil }
            return max(0, value)
        }
    }

    struct Aggregate: Equatable, Sendable {
        let count: Int
        let medianDecodeMs: Double
        let p95DecodeMs: Double
        let medianEnhancementMs: Double?
        let p95EnhancementMs: Double?
    }

    private static let defaultMaximumRecords = 1_000
    private let fileURL: URL
    private let maximumRecords: Int
    private let lock = NSLock()
    private var storedRecords: [SessionRecord]

    init(fileURL: URL? = nil, maximumRecords: Int = PerfStore.defaultMaximumRecords) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.maximumRecords = max(1, maximumRecords)
        self.storedRecords = []
        load()
    }

    var records: [SessionRecord] {
        lock.lock()
        defer { lock.unlock() }
        return storedRecords
    }

    var last: SessionRecord? { records.last }

    func record(_ record: SessionRecord) {
        lock.lock()
        defer { lock.unlock() }
        var next = storedRecords + [record]
        if next.count > maximumRecords {
            backupExistingFile()
            next = Array(next.suffix(maximumRecords))
        }
        storedRecords = next
        persist(next)
    }

    func aggregate(since date: Date) -> Aggregate {
        let values = records.filter { $0.recordedAt >= date }
        let decode = values.map(\.decodeMs)
        let enhancements = values.compactMap(\.enhancementMs)
        return Aggregate(
            count: values.count,
            medianDecodeMs: Self.median(decode) ?? 0,
            p95DecodeMs: Self.percentile(decode, 0.95) ?? 0,
            medianEnhancementMs: Self.median(enhancements),
            p95EnhancementMs: Self.percentile(enhancements, 0.95)
        )
    }

    static func median(_ values: [Double]) -> Double? {
        let sorted = values.filter { $0.isFinite }.sorted()
        guard !sorted.isEmpty else { return nil }
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) { return (sorted[middle - 1] + sorted[middle]) / 2 }
        return sorted[middle]
    }

    static func percentile(_ values: [Double], _ fraction: Double) -> Double? {
        let sorted = values.filter { $0.isFinite }.sorted()
        guard !sorted.isEmpty else { return nil }
        let bounded = min(1, max(0, fraction))
        let index = Int(ceil(bounded * Double(sorted.count)) - 1)
        return sorted[max(0, min(sorted.count - 1, index))]
    }

    private func load() {
        lock.lock()
        defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            storedRecords = try Self.decoder.decode([SessionRecord].self, from: data).suffix(maximumRecords).map { $0 }
        } catch {
            let recoveryURL = fileURL.deletingPathExtension()
                .appendingPathExtension("corrupt-\(Self.timestamp()).json")
            try? FileManager.default.moveItem(at: fileURL, to: recoveryURL)
            UserDefaults.standard.set(recoveryURL.path, forKey: "perfStoreLastRecoveryPath")
            storedRecords = []
        }
    }

    private func persist(_ values: [SessionRecord]) {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(values).write(to: fileURL, options: .atomic)
        } catch {
            debugLog("⚠️ PerfStore persistence failed: \(error.localizedDescription)")
        }
    }

    private func backupExistingFile() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let backupURL = fileURL.deletingPathExtension()
            .appendingPathExtension("backup-\(Self.timestamp()).json")
        try? FileManager.default.copyItem(at: fileURL, to: backupURL)
    }

    private static func defaultFileURL() -> URL {
        if let resultDirectory = ProcessInfo.processInfo.environment["ECHOTUNE_RESULTS_DIR"], !resultDirectory.isEmpty {
            return URL(fileURLWithPath: resultDirectory, isDirectory: true).appendingPathComponent("performance-sessions.json")
        }
        guard let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Extremely pathological: keep telemetry in a writable scratch
            // location rather than crash because telemetry must never be fatal.
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("EchoTune", isDirectory: true)
                .appendingPathComponent("performance-sessions.json")
        }
        return supportDirectory
            .appendingPathComponent("EchoTune", isDirectory: true)
            .appendingPathComponent("performance-sessions.json")
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static func timestamp() -> String {
        "\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(8))"
    }
}
