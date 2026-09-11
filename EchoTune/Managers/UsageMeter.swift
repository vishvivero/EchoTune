import Foundation

/// Local accounting only. These records are never transmitted.
struct UsageRecord: Codable, Equatable, Sendable {
    let provider: String
    let model: String
    let seconds: Double
    let startedAt: Date
    let disposition: String
}

/// Persists cloud-stream usage locally so billable audio remains auditable.
final class UsageMeter {
    static let shared = UsageMeter()

    private static let defaultMaximumRecords = 500
    private let fileURL: URL
    private let maximumRecords: Int
    private let lock = NSLock()
    private var records: [UsageRecord]

    init(fileURL: URL? = nil, maximumRecords: Int = UsageMeter.defaultMaximumRecords) {
        let defaultURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("EchoTune", isDirectory: true)
            .appendingPathComponent("usage-meter.json")
        self.fileURL = fileURL ?? defaultURL
        self.maximumRecords = max(1, maximumRecords)
        self.records = []
        load()
    }

    var recent: [UsageRecord] {
        lock.lock()
        defer { lock.unlock() }
        return records
    }

    func record(_ record: UsageRecord) {
        lock.lock()
        defer { lock.unlock() }
        var next = records
        next.append(record)
        if next.count > maximumRecords {
            backupExistingFile()
            next = Array(next.suffix(maximumRecords))
        }
        records = next
        persist(next)
    }

    /// Local estimate only. Prices are estimates from the provider pricing
    /// pages and must be rechecked before making any customer-facing billing
    /// claim. Unknown models intentionally return nil.
    func estimatedCost(for record: UsageRecord) -> Decimal? {
        let provider = record.provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let model = record.model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pricePerMinute: Decimal?
        switch (provider, model) {
        case ("deepgram", "nova-3"), ("deepgram", "nova-3-general"):
            pricePerMinute = Decimal(string: "0.0077")
        case ("deepgram", "nova-2"):
            pricePerMinute = Decimal(string: "0.0043")
        case ("groq", "whisper-large-v3-turbo"):
            pricePerMinute = Decimal(string: "0.0006666667") // $0.04/hour estimate
        default:
            pricePerMinute = nil
        }
        guard let pricePerMinute else { return nil }
        let minutes = Decimal(string: String(format: "%.6f", max(0, record.seconds) / 60)) ?? 0
        return minutes * pricePerMinute
    }

    private func load() {
        lock.lock()
        defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            records = Array(try Self.decoder.decode([UsageRecord].self, from: data).suffix(maximumRecords))
        } catch {
            let parkedURL = fileURL.deletingPathExtension()
                .appendingPathExtension("corrupt-\(Self.timestamp()).json")
            try? FileManager.default.moveItem(at: fileURL, to: parkedURL)
            records = []
        }
    }

    private func persist(_ values: [UsageRecord]) {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(values).write(to: fileURL, options: .atomic)
        } catch {
            debugLog("⚠️ Usage meter persistence failed: \(error.localizedDescription)")
        }
    }

    private func backupExistingFile() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let backupURL = fileURL.deletingPathExtension()
            .appendingPathExtension("backup-\(Self.timestamp()).json")
        try? FileManager.default.copyItem(at: fileURL, to: backupURL)
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
