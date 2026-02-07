//
//  AudioCleanupManager.swift
//  EchoTune
//
//  Audio file cleanup manager — handles retention period, auto-cleanup,
//  and manual cleanup of saved recording files.
//

import Foundation
import Combine

class AudioCleanupManager: ObservableObject {
    static let shared = AudioCleanupManager()

    @Published var lastCleanupDate: Date?
    @Published var isCleanupRunning = false

    private var cleanupTimer: Timer?
    private let cleanupCheckInterval: TimeInterval = 86400 // Check once per day

    private init() {
        // Load last cleanup date
        if let date = UserDefaults.standard.object(forKey: "lastAudioCleanupDate") as? Date {
            lastCleanupDate = date
        }
    }

    // MARK: - Automatic Cleanup

    /// Start the automatic cleanup process (call on app launch)
    func startAutomaticCleanup() {
        // Cancel any existing timer
        cleanupTimer?.invalidate()

        // Perform initial cleanup check
        performCleanupIfNeeded()

        // Schedule regular cleanup
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupCheckInterval, repeats: true) { [weak self] _ in
            self?.performCleanupIfNeeded()
        }

        print("🧹 Audio cleanup manager started")
    }

    /// Stop the automatic cleanup process
    func stopAutomaticCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }

    private func performCleanupIfNeeded() {
        guard AppSettings.shared.isAudioCleanupEnabled else {
            print("🧹 Auto-cleanup disabled, skipping")
            return
        }

        performCleanup()
    }

    // MARK: - Cleanup Logic

    /// Perform cleanup — deletes audio files older than the retention period
    func performCleanup() {
        let retentionDays = AppSettings.shared.audioRetentionDays
        let calendar = Calendar.current

        guard let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: Date()) else {
            return
        }

        isCleanupRunning = true

        let historyManager = TranscriptionHistoryManager.shared
        var deletedCount = 0

        for item in historyManager.transcriptions {
            // Only clean up items older than the retention period that have audio files
            guard item.date < cutoffDate,
                  let audioPath = item.audioFilePath,
                  FileManager.default.fileExists(atPath: audioPath) else {
                continue
            }

            do {
                try FileManager.default.removeItem(atPath: audioPath)
                historyManager.clearAudioPath(for: item.id)
                deletedCount += 1
                print("🧹 Cleaned up audio: \(audioPath)")
            } catch {
                print("❌ Failed to delete audio file: \(error)")
            }
        }

        lastCleanupDate = Date()
        UserDefaults.standard.set(lastCleanupDate, forKey: "lastAudioCleanupDate")
        isCleanupRunning = false

        if deletedCount > 0 {
            print("🧹 Cleaned up \(deletedCount) audio files (retention: \(retentionDays) days)")
        }
    }

    /// Run manual cleanup immediately (ignores the auto-cleanup toggle)
    func runManualCleanup() -> (deletedCount: Int, freedSpace: Int64) {
        let retentionDays = AppSettings.shared.audioRetentionDays
        let calendar = Calendar.current

        guard let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: Date()) else {
            return (0, 0)
        }

        isCleanupRunning = true

        let historyManager = TranscriptionHistoryManager.shared
        var deletedCount = 0
        var freedSpace: Int64 = 0

        for item in historyManager.transcriptions {
            guard item.date < cutoffDate,
                  let audioPath = item.audioFilePath,
                  FileManager.default.fileExists(atPath: audioPath) else {
                continue
            }

            // Get file size before deleting
            if let attrs = try? FileManager.default.attributesOfItem(atPath: audioPath),
               let size = attrs[.size] as? Int64 {
                freedSpace += size
            }

            do {
                try FileManager.default.removeItem(atPath: audioPath)
                historyManager.clearAudioPath(for: item.id)
                deletedCount += 1
            } catch {
                print("❌ Failed to delete audio file: \(error)")
            }
        }

        lastCleanupDate = Date()
        UserDefaults.standard.set(lastCleanupDate, forKey: "lastAudioCleanupDate")
        isCleanupRunning = false

        return (deletedCount, freedSpace)
    }

    /// Delete ALL audio files (full cleanup regardless of retention period)
    func deleteAllAudioFiles() -> (deletedCount: Int, freedSpace: Int64) {
        isCleanupRunning = true

        let historyManager = TranscriptionHistoryManager.shared
        var deletedCount = 0
        var freedSpace: Int64 = 0

        for item in historyManager.transcriptions {
            guard let audioPath = item.audioFilePath,
                  FileManager.default.fileExists(atPath: audioPath) else {
                continue
            }

            if let attrs = try? FileManager.default.attributesOfItem(atPath: audioPath),
               let size = attrs[.size] as? Int64 {
                freedSpace += size
            }

            do {
                try FileManager.default.removeItem(atPath: audioPath)
                historyManager.clearAudioPath(for: item.id)
                deletedCount += 1
            } catch {
                print("❌ Failed to delete audio file: \(error)")
            }
        }

        // Also clean up any orphaned files in the recordings directory
        let recordingsDir = TranscriptionHistoryManager.recordingsDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in files {
                if file.pathExtension == "caf" || file.pathExtension == "wav" {
                    // Check if this file is referenced by any transcription
                    let isReferenced = historyManager.transcriptions.contains { item in
                        item.audioFilePath == file.path
                    }

                    if !isReferenced {
                        if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
                           let size = attrs[.size] as? Int64 {
                            freedSpace += size
                        }
                        try? FileManager.default.removeItem(at: file)
                        deletedCount += 1
                        print("🧹 Removed orphaned audio file: \(file.lastPathComponent)")
                    }
                }
            }
        }

        isCleanupRunning = false
        return (deletedCount, freedSpace)
    }

    // MARK: - Info

    /// Get information about files eligible for cleanup
    func getCleanupInfo() -> (fileCount: Int, totalSize: Int64) {
        let retentionDays = AppSettings.shared.audioRetentionDays
        let calendar = Calendar.current

        guard let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: Date()) else {
            return (0, 0)
        }

        let historyManager = TranscriptionHistoryManager.shared
        var fileCount = 0
        var totalSize: Int64 = 0

        for item in historyManager.transcriptions {
            guard item.date < cutoffDate,
                  let audioPath = item.audioFilePath,
                  FileManager.default.fileExists(atPath: audioPath) else {
                continue
            }

            if let attrs = try? FileManager.default.attributesOfItem(atPath: audioPath),
               let size = attrs[.size] as? Int64 {
                totalSize += size
                fileCount += 1
            }
        }

        return (fileCount, totalSize)
    }

    /// Format file size in human-readable form
    func formatFileSize(_ size: Int64) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB, .useGB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: size)
    }
}
