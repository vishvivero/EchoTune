//
//  ErrorLogger.swift
//  EchoTune
//
//  Phase 5: Error Logging and Crash Reporting
//

import Foundation
import OSLog

// MARK: - Log Entry Model

struct LogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let context: [String: String]
    let stackTrace: String?

    enum LogLevel: String, Codable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"

        var emoji: String {
            switch self {
            case .debug: return "🐛"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🔥"
            }
        }
    }
}

// MARK: - System Info

struct SystemInfo: Codable {
    let appVersion: String
    let buildNumber: String
    let osVersion: String
    let deviceModel: String
    let architecture: String
    let memoryUsage: String
    let diskSpace: String

    static func current() -> SystemInfo {
        return SystemInfo(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: getDeviceModel(),
            architecture: getArchitecture(),
            memoryUsage: getMemoryUsage(),
            diskSpace: getDiskSpace()
        )
    }

    private static func getDeviceModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private static func getArchitecture() -> String {
        #if arch(arm64)
        return "Apple Silicon"
        #elseif arch(x86_64)
        return "Intel"
        #else
        return "Unknown"
        #endif
    }

    private static func getMemoryUsage() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            return String(format: "%.1f MB", usedMB)
        }

        return "Unknown"
    }

    private static func getDiskSpace() -> String {
        do {
            let fileURL = URL(fileURLWithPath: "/")
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                let gb = Double(capacity) / 1024.0 / 1024.0 / 1024.0
                return String(format: "%.1f GB available", gb)
            }
        } catch {
            return "Unknown"
        }
        return "Unknown"
    }
}

// MARK: - Error Logger

@Observable
class ErrorLogger {
    static let shared = ErrorLogger()

    private var logs: [LogEntry] = []
    private let maxLogEntries = 100
    private let logger = Logger(subsystem: "com.echotune.app", category: "ErrorLogger")

    private init() {
        loadLogs()
        print("✓ ErrorLogger initialized")
    }

    // MARK: - Logging Methods

    func logDebug(_ message: String, category: String = "General", context: [String: String] = [:]) {
        log(level: .debug, category: category, message: message, context: context)
        logger.debug("\(message)")
    }

    func logInfo(_ message: String, category: String = "General", context: [String: String] = [:]) {
        log(level: .info, category: category, message: message, context: context)
        logger.info("\(message)")
    }

    func logWarning(_ message: String, category: String = "General", context: [String: String] = [:]) {
        log(level: .warning, category: category, message: message, context: context)
        logger.warning("\(message)")
    }

    func logError(_ error: Error, category: String = "General", context: [String: String] = [:]) {
        var fullContext = context
        fullContext["errorDescription"] = error.localizedDescription

        log(
            level: .error,
            category: category,
            message: error.localizedDescription,
            context: fullContext,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n")
        )

        logger.error("\(error.localizedDescription)")

        // Record in analytics
        AnalyticsManager.shared.recordError(type: category, context: error.localizedDescription)
    }

    func logCritical(_ message: String, category: String = "General", context: [String: String] = [:]) {
        log(
            level: .critical,
            category: category,
            message: message,
            context: context,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n")
        )

        logger.critical("\(message)")

        // Record critical errors in analytics
        AnalyticsManager.shared.recordError(type: "Critical: \(category)", context: message)
    }

    private func log(
        level: LogEntry.LogLevel,
        category: String,
        message: String,
        context: [String: String] = [:],
        stackTrace: String? = nil
    ) {
        let entry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            context: context,
            stackTrace: stackTrace
        )

        logs.append(entry)

        // Keep only last N entries
        if logs.count > maxLogEntries {
            logs.removeFirst(logs.count - maxLogEntries)
        }

        saveLogs()

        // Print to console
        print("\(level.emoji) [\(category)] \(message)")
    }

    // MARK: - Log Retrieval

    func getLogs() -> [LogEntry] {
        return logs.reversed() // Most recent first
    }

    func getLogs(level: LogEntry.LogLevel) -> [LogEntry] {
        return logs.filter { $0.level == level }.reversed()
    }

    func getLogs(category: String) -> [LogEntry] {
        return logs.filter { $0.category == category }.reversed()
    }

    func getRecentLogs(count: Int = 10) -> [LogEntry] {
        return Array(logs.suffix(count).reversed())
    }

    // MARK: - Export

    func exportLogs() -> String {
        var output = "EchoTune Error Logs\n"
        output += "Generated: \(Date())\n"
        output += String(repeating: "=", count: 80) + "\n\n"

        // System info
        let sysInfo = SystemInfo.current()
        output += "System Information:\n"
        output += "  App Version: \(sysInfo.appVersion) (\(sysInfo.buildNumber))\n"
        output += "  OS Version: \(sysInfo.osVersion)\n"
        output += "  Device: \(sysInfo.deviceModel)\n"
        output += "  Architecture: \(sysInfo.architecture)\n"
        output += "  Memory Usage: \(sysInfo.memoryUsage)\n"
        output += "  Disk Space: \(sysInfo.diskSpace)\n"
        output += "\n" + String(repeating: "=", count: 80) + "\n\n"

        // Logs
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        for entry in logs.reversed() {
            output += "[\(dateFormatter.string(from: entry.timestamp))] "
            output += "\(entry.level.rawValue) "
            output += "[\(entry.category)] "
            output += "\(entry.message)\n"

            if !entry.context.isEmpty {
                output += "  Context:\n"
                for (key, value) in entry.context {
                    output += "    \(key): \(value)\n"
                }
            }

            if let stackTrace = entry.stackTrace {
                output += "  Stack Trace:\n"
                for line in stackTrace.split(separator: "\n") {
                    output += "    \(line)\n"
                }
            }

            output += "\n"
        }

        print("📋 Logs exported (\(output.count) characters)")
        return output
    }

    func exportLogsAsJSON() -> Data? {
        let exportData: [String: Any] = [
            "systemInfo": (try? JSONEncoder().encode(SystemInfo.current())) as Any,
            "logs": logs,
            "exportDate": Date().timeIntervalSince1970
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            print("📋 Logs exported as JSON (\(data.count) bytes)")
            return data
        } catch {
            print("❌ Failed to export logs as JSON: \(error)")
            return nil
        }
    }

    // MARK: - Management

    func clearLogs() {
        logs.removeAll()
        saveLogs()
        print("🗑️ All logs cleared")
    }

    func getLogCount() -> Int {
        return logs.count
    }

    func getErrorCount() -> Int {
        return logs.filter { $0.level == .error || $0.level == .critical }.count
    }

    // MARK: - Storage

    private func saveLogs() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(logs)

            if let dataString = String(data: data, encoding: .utf8) {
                UserDefaults.standard.set(dataString, forKey: "errorLogs")
            }
        } catch {
            logger.error("Failed to save logs: \(error.localizedDescription)")
        }
    }

    private func loadLogs() {
        guard let dataString = UserDefaults.standard.string(forKey: "errorLogs"),
              let data = dataString.data(using: .utf8) else {
            print("📋 No saved logs found")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            logs = try decoder.decode([LogEntry].self, from: data)
            print("✓ Logs loaded (\(logs.count) entries)")
        } catch {
            logger.error("Failed to load logs: \(error.localizedDescription)")
        }
    }

    // MARK: - Statistics

    func printLogStatistics() {
        print("\n📋 Log Statistics")
        print(String(repeating: "=", count: 60))

        let groupedByLevel = Dictionary(grouping: logs) { $0.level }
        let groupedByCategory = Dictionary(grouping: logs) { $0.category }

        print("\nBy Level:")
        for level in [LogEntry.LogLevel.debug, .info, .warning, .error, .critical] {
            let count = groupedByLevel[level]?.count ?? 0
            print("  \(level.emoji) \(level.rawValue): \(count)")
        }

        print("\nBy Category:")
        for (category, entries) in groupedByCategory.sorted(by: { $0.value.count > $1.value.count }) {
            print("  \(category): \(entries.count)")
        }

        print("\nTotal Entries: \(logs.count)")
        print(String(repeating: "=", count: 60))
    }
}

// MARK: - Crash Handler (Placeholder)

extension ErrorLogger {
    func setupCrashHandler() {
        // Register for uncaught exceptions
        NSSetUncaughtExceptionHandler { exception in
            ErrorLogger.shared.logCritical(
                "Uncaught exception: \(exception.name.rawValue)",
                category: "Crash",
                context: [
                    "reason": exception.reason ?? "Unknown",
                    "stackTrace": exception.callStackSymbols.joined(separator: "\n")
                ]
            )
        }

        print("✓ Crash handler registered")
    }
}
