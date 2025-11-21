//
//  PerformanceMonitor.swift
//  EchoTune
//
//  Phase 1: Performance Optimization - Metrics & Profiling
//  Tracks pipeline performance for optimization
//

import Foundation

class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    // MARK: - Metrics Structure

    struct TranscriptionMetrics {
        var recordingStartTime: Date?
        var recordingEndTime: Date?
        var recordingDuration: TimeInterval = 0

        var audioConversionStartTime: Date?
        var audioConversionEndTime: Date?
        var audioConversionTime: TimeInterval = 0

        var transcriptionStartTime: Date?
        var transcriptionEndTime: Date?
        var transcriptionProcessingTime: TimeInterval = 0

        var textInsertionStartTime: Date?
        var textInsertionEndTime: Date?
        var textInsertionTime: TimeInterval = 0

        var totalLatency: TimeInterval = 0
        var audioDataSize: Int = 0
        var bufferCount: Int = 0
        var wordCount: Int = 0

        var engineUsed: String = ""
        var modelUsed: String = ""

        // Calculated metrics
        var realTimeFactor: Double {
            guard recordingDuration > 0 else { return 0 }
            return transcriptionProcessingTime / recordingDuration
        }

        var averageBufferProcessingTime: TimeInterval {
            guard bufferCount > 0 else { return 0 }
            return audioConversionTime / Double(bufferCount)
        }
    }

    // MARK: - Current Session Metrics

    private(set) var currentMetrics = TranscriptionMetrics()
    private(set) var sessionMetrics: [TranscriptionMetrics] = []

    // MARK: - Settings

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "PerformanceMonitorEnabled")
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "PerformanceMonitorEnabled")
        print("📊 Performance Monitor: \(enabled ? "Enabled" : "Disabled")")
    }

    private init() {
        // Default to disabled in production, enabled in debug
        #if DEBUG
        if !UserDefaults.standard.bool(forKey: "PerformanceMonitorConfigured") {
            UserDefaults.standard.set(true, forKey: "PerformanceMonitorEnabled")
            UserDefaults.standard.set(true, forKey: "PerformanceMonitorConfigured")
        }
        #endif
    }

    // MARK: - Recording Phase

    func startRecording() {
        guard isEnabled else { return }

        currentMetrics = TranscriptionMetrics()
        currentMetrics.recordingStartTime = Date()

        print("📊 [Performance] Recording started")
    }

    func endRecording(duration: TimeInterval, bufferCount: Int = 0) {
        guard isEnabled else { return }

        currentMetrics.recordingEndTime = Date()
        currentMetrics.recordingDuration = duration
        currentMetrics.bufferCount = bufferCount

        if let startTime = currentMetrics.recordingStartTime {
            let actualDuration = Date().timeIntervalSince(startTime)
            print("📊 [Performance] Recording ended: \(String(format: "%.2f", actualDuration))s (\(bufferCount) buffers)")
        }
    }

    // MARK: - Audio Conversion Phase

    func startAudioConversion(dataSize: Int = 0) {
        guard isEnabled else { return }

        currentMetrics.audioConversionStartTime = Date()
        currentMetrics.audioDataSize = dataSize

        print("📊 [Performance] Audio conversion started (\(dataSize) bytes)")
    }

    func endAudioConversion() {
        guard isEnabled else { return }

        currentMetrics.audioConversionEndTime = Date()

        if let startTime = currentMetrics.audioConversionStartTime {
            currentMetrics.audioConversionTime = Date().timeIntervalSince(startTime)
            print("📊 [Performance] Audio conversion completed: \(String(format: "%.3f", currentMetrics.audioConversionTime))s")
        }
    }

    // MARK: - Transcription Phase

    func startTranscription(engine: String, model: String) {
        guard isEnabled else { return }

        currentMetrics.transcriptionStartTime = Date()
        currentMetrics.engineUsed = engine
        currentMetrics.modelUsed = model

        print("📊 [Performance] Transcription started (\(engine) - \(model))")
    }

    func endTranscription(wordCount: Int = 0) {
        guard isEnabled else { return }

        currentMetrics.transcriptionEndTime = Date()
        currentMetrics.wordCount = wordCount

        if let startTime = currentMetrics.transcriptionStartTime {
            currentMetrics.transcriptionProcessingTime = Date().timeIntervalSince(startTime)
            print("📊 [Performance] Transcription completed: \(String(format: "%.3f", currentMetrics.transcriptionProcessingTime))s (\(wordCount) words)")
        }
    }

    // MARK: - Text Insertion Phase

    func startTextInsertion() {
        guard isEnabled else { return }

        currentMetrics.textInsertionStartTime = Date()
        print("📊 [Performance] Text insertion started")
    }

    func endTextInsertion() {
        guard isEnabled else { return }

        currentMetrics.textInsertionEndTime = Date()

        if let startTime = currentMetrics.textInsertionStartTime {
            currentMetrics.textInsertionTime = Date().timeIntervalSince(startTime)
            print("📊 [Performance] Text insertion completed: \(String(format: "%.3f", currentMetrics.textInsertionTime))s")
        }
    }

    // MARK: - Session Completion

    func completeSession() {
        guard isEnabled else { return }

        // Calculate total latency
        if let startTime = currentMetrics.recordingStartTime {
            currentMetrics.totalLatency = Date().timeIntervalSince(startTime)
        }

        // Add to session history
        sessionMetrics.append(currentMetrics)

        // Keep only last 50 sessions
        if sessionMetrics.count > 50 {
            sessionMetrics.removeFirst(sessionMetrics.count - 50)
        }

        // Log comprehensive metrics
        logDetailedMetrics()
    }

    // MARK: - Logging & Reporting

    private func logDetailedMetrics() {
        let m = currentMetrics

        print("📊 ═══════════════════════════════════════════════════════")
        print("📊 PERFORMANCE METRICS - \(m.engineUsed) (\(m.modelUsed))")
        print("📊 ═══════════════════════════════════════════════════════")
        print("📊 Recording Duration:    \(String(format: "%6.2f", m.recordingDuration))s")
        print("📊 Audio Conversion:      \(String(format: "%6.3f", m.audioConversionTime))s")
        print("📊 Transcription:         \(String(format: "%6.3f", m.transcriptionProcessingTime))s")
        print("📊 Text Insertion:        \(String(format: "%6.3f", m.textInsertionTime))s")
        print("📊 ───────────────────────────────────────────────────────")
        print("📊 Total Latency:         \(String(format: "%6.3f", m.totalLatency))s")
        print("📊 ═══════════════════════════════════════════════════════")
        print("📊 Real-Time Factor:      \(String(format: "%6.2f", m.realTimeFactor))x")
        print("📊 Words Generated:       \(m.wordCount) words")
        print("📊 Audio Data Size:       \(formatBytes(m.audioDataSize))")
        print("📊 Buffers Processed:     \(m.bufferCount)")
        if m.bufferCount > 0 {
            print("📊 Avg Buffer Time:       \(String(format: "%6.3f", m.averageBufferProcessingTime * 1000))ms")
        }
        print("📊 ═══════════════════════════════════════════════════════")

        // Performance assessment
        let rtf = m.realTimeFactor
        let assessment: String
        if rtf < 0.3 {
            assessment = "🚀 EXCELLENT (< 0.3x)"
        } else if rtf < 0.5 {
            assessment = "✅ GOOD (< 0.5x)"
        } else if rtf < 1.0 {
            assessment = "⚠️ ACCEPTABLE (< 1.0x)"
        } else {
            assessment = "❌ SLOW (> 1.0x) - Needs optimization"
        }

        print("📊 Performance:           \(assessment)")
        print("📊 ═══════════════════════════════════════════════════════")
    }

    func getSessionSummary() -> String {
        guard !sessionMetrics.isEmpty else {
            return "No sessions recorded yet"
        }

        let avgLatency = sessionMetrics.map { $0.totalLatency }.reduce(0, +) / Double(sessionMetrics.count)
        let avgRTF = sessionMetrics.map { $0.realTimeFactor }.reduce(0, +) / Double(sessionMetrics.count)
        let totalWords = sessionMetrics.map { $0.wordCount }.reduce(0, +)

        var summary = "Performance Summary (\(sessionMetrics.count) sessions):\n"
        summary += "  Average Latency: \(String(format: "%.2f", avgLatency))s\n"
        summary += "  Average RTF: \(String(format: "%.2f", avgRTF))x\n"
        summary += "  Total Words: \(totalWords)\n"

        return summary
    }

    func exportMetrics() -> String {
        var csv = "Session,Engine,Model,Recording(s),Conversion(s),Transcription(s),Insertion(s),Total(s),RTF,Words,Buffers\n"

        for (index, m) in sessionMetrics.enumerated() {
            csv += "\(index + 1),"
            csv += "\(m.engineUsed),"
            csv += "\(m.modelUsed),"
            csv += "\(String(format: "%.2f", m.recordingDuration)),"
            csv += "\(String(format: "%.3f", m.audioConversionTime)),"
            csv += "\(String(format: "%.3f", m.transcriptionProcessingTime)),"
            csv += "\(String(format: "%.3f", m.textInsertionTime)),"
            csv += "\(String(format: "%.3f", m.totalLatency)),"
            csv += "\(String(format: "%.2f", m.realTimeFactor)),"
            csv += "\(m.wordCount),"
            csv += "\(m.bufferCount)\n"
        }

        return csv
    }

    func resetMetrics() {
        sessionMetrics.removeAll()
        currentMetrics = TranscriptionMetrics()
        print("📊 [Performance] Metrics reset")
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0

        if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else {
            return String(format: "%.2f KB", kb)
        }
    }
}

// MARK: - Convenience Extensions

extension PerformanceMonitor {
    func measure<T>(_ name: String, block: () throws -> T) rethrows -> T {
        guard isEnabled else {
            return try block()
        }

        let startTime = Date()
        let result = try block()
        let duration = Date().timeIntervalSince(startTime)

        print("📊 [Performance] \(name): \(String(format: "%.3f", duration))s")

        return result
    }

    func measureAsync<T>(_ name: String, block: () async throws -> T) async rethrows -> T {
        guard isEnabled else {
            return try await block()
        }

        let startTime = Date()
        let result = try await block()
        let duration = Date().timeIntervalSince(startTime)

        print("📊 [Performance] \(name): \(String(format: "%.3f", duration))s")

        return result
    }
}
