import Foundation
import AppKit

@available(macOS 13.0, *)
final class MeetingAutoDetectionCoordinator {
    static let shared = MeetingAutoDetectionCoordinator()

    private let workspaceCenter = NSWorkspace.shared.notificationCenter
    private var observers: [NSObjectProtocol] = []
    private var pollTimer: Timer?
    private var lastPromptedAtByKey: [String: Date] = [:]
    private let promptCooldown: TimeInterval = 5 * 60

    private init() {
        startObserving()
        debugLog("✅ MeetingAutoDetectionCoordinator initialised")
    }

    deinit {
        observers.forEach { workspaceCenter.removeObserver($0) }
        pollTimer?.invalidate()
    }

    func startDetectedMeeting(from userInfo: [AnyHashable: Any]) {
        let appName = (userInfo["appName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceHint = (userInfo["sourceHint"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        let detectedApp = (appName?.isEmpty == false) ? appName : MeetingManager.detectMeetingApp()
        let titleBase = detectedApp ?? "Meeting"
        let title = sourceHint?.isEmpty == false ? "\(titleBase) — \(sourceHint!)" : "\(titleBase) Meeting"

        MeetingManager.shared.startMeeting(
            title: title,
            template: AppSettings.shared.meetingDefaultTemplate,
            detectedApp: detectedApp
        )
    }

    private func startObserving() {
        let activateObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleEvaluation(delay: 1.0)
        }

        let launchObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleEvaluation(delay: 2.0)
        }

        observers = [activateObserver, launchObserver]

        pollTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.evaluatePotentialMeeting(reason: "poll")
        }
    }

    private func scheduleEvaluation(delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.evaluatePotentialMeeting(reason: "activation")
        }
    }

    private func evaluatePotentialMeeting(reason: String) {
        let settings = AppSettings.shared

        guard settings.meetingModeEnabled, settings.meetingAutoDetect else { return }
        guard OnboardingStateStore.shared.hasCompletedOnboarding else { return }

        if MeetingManager.shared.isRecording {
            if MeetingManager.shared.shouldAutoStopDetectedMeeting() {
                debugLog("🛑 Auto-stopping meeting recording [\(reason)]")
                MeetingManager.shared.stopMeeting(autoSummarise: true)
                NotificationManager.shared.showNotification(
                    title: "Recording stopped",
                    body: "EchoTune stopped the meeting recording because the call appears to have ended.",
                    sound: true
                )
            }
            return
        }

        guard let context = MeetingManager.detectMeetingContext() else { return }

        let key = context.cooldownKey
        let now = Date()
        if let lastPromptedAt = lastPromptedAtByKey[key], now.timeIntervalSince(lastPromptedAt) < promptCooldown {
            return
        }
        lastPromptedAtByKey[key] = now

        if settings.meetingAutoStartDetectedApps {
            debugLog("🎙️ Auto-starting meeting recording for \(context.appName) [\(reason)]")
            MeetingManager.shared.startMeeting(
                title: context.defaultMeetingTitle,
                template: settings.meetingDefaultTemplate,
                detectedApp: context.appName
            )
            NotificationManager.shared.showNotification(
                title: "Recording started",
                body: "EchoTune started recording \(context.appName).",
                sound: true
            )
            return
        }

        debugLog("👀 Potential meeting detected in \(context.appName) [\(reason)]")
        NotificationManager.shared.showMeetingDetectedPrompt(
            appName: context.appName,
            sourceHint: context.sourceHint,
            includesSystemAudio: SystemAudioCapture.hasPermission()
        )
    }
}
