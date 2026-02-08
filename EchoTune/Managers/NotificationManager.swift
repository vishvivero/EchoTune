//
//  NotificationManager.swift
//  EchoTune
//
//  Phase 5: Native Notifications System
//

import Foundation
import UserNotifications
import AppKit

@Observable
class NotificationManager {
    static let shared = NotificationManager()

    // Settings
    var notificationsEnabled = true
    var soundEnabled = true

    private let center = UNUserNotificationCenter.current()

    private init() {
        requestAuthorization()
        debugLog("✓ NotificationManager initialized")
    }

    // MARK: - Authorization

    private func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                debugLog("✓ Notification permission granted")
            } else if let error = error {
                debugLog("❌ Notification permission error: \(error)")
            } else {
                debugLog("⚠️ Notification permission denied")
            }
        }
    }

    // MARK: - Transcription Notifications

    func showTranscriptionSuccess(text: String, wordCount: Int, duration: TimeInterval) {
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Transcription Complete"

        // Show preview of transcribed text (first 50 chars)
        let preview = text.count > 50 ? text.prefix(50) + "..." : text
        content.body = "\"\(preview)\"\n\(wordCount) words in \(String(format: "%.1f", duration))s"

        // Use the same setting as start/stop sounds for consistency
        content.sound = AppSettings.shared.playSoundOnStartStop ? .default : nil
        content.categoryIdentifier = "TRANSCRIPTION_SUCCESS"
        content.userInfo = ["transcribedText": text]

        // Show notification
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Show immediately
        )

        center.add(request) { error in
            if let error = error {
                debugLog("❌ Failed to show notification: \(error)")
            }
        }

        debugLog("📢 Notification: Transcription success (\(wordCount) words)")
    }

    func showTranscriptionError(error: String) {
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Transcription Failed"
        content.body = error
        // Use the same setting as start/stop sounds for consistency
        content.sound = (soundEnabled && AppSettings.shared.playSoundOnStartStop) ? .defaultCritical : nil
        content.categoryIdentifier = "TRANSCRIPTION_ERROR"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                debugLog("❌ Failed to show error notification: \(error)")
            }
        }

        debugLog("📢 Notification: Transcription error")
    }

    func showTranscriptionProcessing() {
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Processing..."
        content.body = "Transcribing your audio"
        content.sound = nil // Silent for processing
        content.categoryIdentifier = "TRANSCRIPTION_PROCESSING"

        let request = UNNotificationRequest(
            identifier: "processing", // Fixed ID so it can be replaced
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                debugLog("❌ Failed to show processing notification: \(error)")
            }
        }
    }

    func dismissProcessingNotification() {
        center.removeDeliveredNotifications(withIdentifiers: ["processing"])
    }

    // MARK: - License Notifications

    func showLicenseActivated(tier: String) {
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "License Activated"
        content.body = "EchoTune \(tier) is now active!"
        // Use the same setting as start/stop sounds for consistency
        content.sound = AppSettings.shared.playSoundOnStartStop ? .default : nil
        content.categoryIdentifier = "LICENSE_ACTIVATED"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                debugLog("❌ Failed to show license notification: \(error)")
            }
        }

        debugLog("📢 Notification: License activated (\(tier))")
    }

    func showLicenseDeactivated() {
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "License Deactivated"
        content.body = "Your license has been deactivated"
        content.sound = nil
        content.categoryIdentifier = "LICENSE_DEACTIVATED"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                debugLog("❌ Failed to show deactivation notification: \(error)")
            }
        }

        debugLog("📢 Notification: License deactivated")
    }

    // MARK: - Trial Notifications

    func showTrialReminder(daysLeft: Int) {
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Trial Ending Soon"

        if daysLeft == 1 {
            content.body = "Your trial ends tomorrow. Get a license to keep using EchoTune!"
        } else {
            content.body = "Your trial ends in \(daysLeft) days"
        }

        // Use the same setting as start/stop sounds for consistency
        content.sound = AppSettings.shared.playSoundOnStartStop ? .default : nil
        content.categoryIdentifier = "TRIAL_REMINDER"

        let request = UNNotificationRequest(
            identifier: "trial_reminder_\(daysLeft)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                debugLog("❌ Failed to show trial reminder: \(error)")
            }
        }

        debugLog("📢 Notification: Trial reminder (\(daysLeft) days left)")
    }

    func showTrialExpired() {
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Trial Expired"
        content.body = "Purchase a license to continue using EchoTune"
        // Use the same setting as start/stop sounds for consistency
        content.sound = AppSettings.shared.playSoundOnStartStop ? .default : nil
        content.categoryIdentifier = "TRIAL_EXPIRED"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                debugLog("❌ Failed to show trial expired notification: \(error)")
            }
        }

        debugLog("📢 Notification: Trial expired")
    }

    // MARK: - Update Notifications

    func showUpdateAvailable(version: String) {
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Update Available"
        content.body = "EchoTune \(version) is ready to install"
        content.sound = nil
        content.categoryIdentifier = "UPDATE_AVAILABLE"

        let request = UNNotificationRequest(
            identifier: "update_available",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                debugLog("❌ Failed to show update notification: \(error)")
            }
        }

        debugLog("📢 Notification: Update available (\(version))")
    }

    // MARK: - General Notifications

    func showNotification(title: String, body: String, sound: Bool = true) {
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // Use the same setting as start/stop sounds for consistency
        content.sound = (sound && AppSettings.shared.playSoundOnStartStop) ? .default : nil

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                debugLog("❌ Failed to show notification: \(error)")
            }
        }

        debugLog("📢 Notification: \(title)")
    }

    // MARK: - Settings

    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "notificationsEnabled")
        debugLog(enabled ? "✓ Notifications enabled" : "⏸️ Notifications disabled")
    }

    func setSoundEnabled(_ enabled: Bool) {
        soundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "notificationSoundEnabled")
        debugLog(enabled ? "✓ Notification sound enabled" : "🔇 Notification sound disabled")
    }

    func loadSettings() {
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        soundEnabled = UserDefaults.standard.bool(forKey: "notificationSoundEnabled")
    }

    // MARK: - Cleanup

    func clearAllNotifications() {
        center.removeAllDeliveredNotifications()
        debugLog("🗑️ All notifications cleared")
    }
}

// MARK: - Notification Categories

extension NotificationManager {
    func setupNotificationCategories() {
        // Copy to clipboard action for transcription success
        let copyAction = UNNotificationAction(
            identifier: "COPY_TEXT",
            title: "Copy to Clipboard",
            options: []
        )

        let transcriptionCategory = UNNotificationCategory(
            identifier: "TRANSCRIPTION_SUCCESS",
            actions: [copyAction],
            intentIdentifiers: [],
            options: []
        )

        // Purchase action for trial reminders
        let purchaseAction = UNNotificationAction(
            identifier: "PURCHASE_LICENSE",
            title: "Purchase",
            options: .foreground
        )

        let trialCategory = UNNotificationCategory(
            identifier: "TRIAL_REMINDER",
            actions: [purchaseAction],
            intentIdentifiers: [],
            options: []
        )

        let trialExpiredCategory = UNNotificationCategory(
            identifier: "TRIAL_EXPIRED",
            actions: [purchaseAction],
            intentIdentifiers: [],
            options: []
        )

        // Update action
        let updateAction = UNNotificationAction(
            identifier: "INSTALL_UPDATE",
            title: "Install",
            options: .foreground
        )

        let updateCategory = UNNotificationCategory(
            identifier: "UPDATE_AVAILABLE",
            actions: [updateAction],
            intentIdentifiers: [],
            options: []
        )

        // Register categories
        center.setNotificationCategories([
            transcriptionCategory,
            trialCategory,
            trialExpiredCategory,
            updateCategory
        ])

        debugLog("✓ Notification categories registered")
    }
}
