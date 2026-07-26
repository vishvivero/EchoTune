//
//  AudioCleanupManager.swift
//  EchoTune
//
//  Prunes archived dictation audio once it ages past the user's retention
//  window, and clears stale temp files. Runs a daily background sweep while
//  the app is alive; transcript text is never touched, only audio files.
//

import Foundation
import Combine

class AudioCleanupManager: ObservableObject {
    static let shared = AudioCleanupManager()

    struct SweepResult {
        var removedFiles = 0
        var reclaimedBytes: Int64 = 0
    }

    @Published private(set) var lastSweepDate: Date?

    private var sweepTimer: DispatchSourceTimer?
    private let sweepInterval: TimeInterval = 24 * 60 * 60
    private let lastSweepKey = "lastAudioCleanupDate"

    private init() {
        lastSweepDate = UserDefaults.standard.object(forKey: lastSweepKey) as? Date
    }

    // MARK: - Scheduling

    /// Begins the daily retention sweep. Safe to call repeatedly; each call
    /// replaces any prior schedule. An initial sweep runs shortly after start.
    func startAutomaticCleanup() {
        sweepTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + 5, repeating: sweepInterval)
        timer.setEventHandler { [weak self] in
            self?.sweepExpiredAudio()
            self?.purgeStaleTempFiles()
        }
        timer.resume()
        sweepTimer = timer

        debugLog("🧹 Audio retention sweep scheduled (every 24h)")
    }

    // MARK: - Retention Sweep

    /// Deletes archived audio older than the retention window. Runs regardless
    /// of the archiving toggle so recordings written while it was on (or by
    /// older builds that archived unconditionally) still get pruned.
    private func sweepExpiredAudio() {
        let days = max(AppSettings.shared.audioRetentionDays, 1)
        let expiryThreshold = Date().addingTimeInterval(-Double(days) * 86400)

        var result = SweepResult()
        let history = TranscriptionHistoryManager.shared

        for item in history.transcriptions where item.date < expiryThreshold {
            guard let path = item.audioFilePath else { continue }
            result.reclaimedBytes += fileSize(atPath: path)
            if removeFile(atPath: path) {
                result.removedFiles += 1
                DispatchQueue.main.async {
                    history.clearAudioPath(for: item.id)
                }
            }
        }

        recordSweepCompleted()
        if result.removedFiles > 0 {
            debugLog("🧹 Retention sweep: removed \(result.removedFiles) audio file(s), reclaimed \(formatFileSize(result.reclaimedBytes))")
        }
    }

    /// Removes files older than a day from the app's temp directory.
    private func purgeStaleTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        let threshold = Date().addingTimeInterval(-86400)

        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for entry in entries {
            let created = (try? entry.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            if let created, created < threshold {
                try? FileManager.default.removeItem(at: entry)
            }
        }
    }

    // MARK: - Manual Actions

    /// Deletes every archived audio file — both those referenced by history
    /// entries and any orphans left behind in the recordings folder.
    func deleteAllAudioFiles() -> (deletedCount: Int, freedSpace: Int64) {
        var result = SweepResult()
        let history = TranscriptionHistoryManager.shared

        // Referenced audio first, clearing each history entry's pointer.
        for item in history.transcriptions {
            guard let path = item.audioFilePath else { continue }
            result.reclaimedBytes += fileSize(atPath: path)
            if removeFile(atPath: path) {
                result.removedFiles += 1
                DispatchQueue.main.async {
                    history.clearAudioPath(for: item.id)
                }
            }
        }

        // Then anything left in the recordings folder that no entry points at.
        let recordingsDir = TranscriptionHistoryManager.recordingsDirectory
        if let leftovers = try? FileManager.default.contentsOfDirectory(
            at: recordingsDir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for file in leftovers {
                result.reclaimedBytes += fileSize(atPath: file.path)
                if removeFile(atPath: file.path) {
                    result.removedFiles += 1
                }
            }
        }

        recordSweepCompleted()
        debugLog("🧹 Deleted all archived audio: \(result.removedFiles) file(s), \(formatFileSize(result.reclaimedBytes))")
        return (result.removedFiles, result.reclaimedBytes)
    }

    // MARK: - Formatting

    func formatFileSize(_ size: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    // MARK: - Private Helpers

    private func fileSize(atPath path: String) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.size] as? Int64) ?? 0
    }

    private func removeFile(atPath path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            debugLog("⚠️ Could not remove audio file at \(path): \(error.localizedDescription)")
            return false
        }
    }

    private func recordSweepCompleted() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: lastSweepKey)
        DispatchQueue.main.async { [weak self] in
            self?.lastSweepDate = now
        }
    }
}
