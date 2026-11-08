//
//  OnboardingView.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @ObservedObject private var store = OnboardingStateStore.shared
    @State private var hasPlayedIntroSound = false
    @State private var moveError: String?
    @State private var isMoving = false

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            AuroraBackgroundView()

            VStack(spacing: 0) {
                // Header & Progress indicators
                HStack {
                    if store.currentStep > 0 {
                        Button(action: goBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Back")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer()
                            .frame(width: 50)
                    }

                    Spacer()

                    StepIndicatorView(currentStep: store.currentStep, totalSteps: 5)

                    Spacer()

                    Spacer()
                        .frame(width: 50)
                }
                .padding(.horizontal, 30)
                .padding(.top, 24)

                if AppInstallLocation.isRunningFromDiskImage {
                    installLocationBanner
                        .padding(.horizontal, 30)
                        .padding(.top, 12)
                }

                // Current Step Content Container
                ZStack {
                    switch store.currentStep {
                    case 0:
                        WelcomeStep(onNext: goForward)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case 1:
                        PermissionsStep(onNext: goForward)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case 2:
                        LiveDemoStep(onNext: goForward)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case 3:
                        HotkeyStep(onNext: goForward)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case 4:
                        TrialCTAStep(onComplete: completeOnboarding)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    default:
                        WelcomeStep(onNext: goForward)
                            .transition(.identity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 700, height: 650)
        .onAppear {
            if !hasPlayedIntroSound {
                hasPlayedIntroSound = true
                OnboardingSound.play(.intro)
            }
            AppInstallLocation.logLaunchContext()
            ModelStarter.startDefaultModelDownloadIfNeeded()
        }
    }

    private var installLocationBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("EchoTune is running from the disk image")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Text(moveError ?? "Permissions can't stick to a mounted DMG. Move it to Applications to finish setup.")
                    .font(.system(size: 11))
                    .foregroundColor(moveError == nil ? .secondary : .red)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: moveToApplications) {
                if isMoving {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Move to Applications")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
            .disabled(isMoving)
            .accessibilityIdentifier("onboarding.installLocation.moveButton")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    private func moveToApplications() {
        isMoving = true
        moveError = nil
        if !AppInstallLocation.moveToApplicationsAndRelaunch() {
            isMoving = false
            moveError = "Couldn't copy to Applications. Drag EchoTune there yourself, then reopen it."
        }
    }

    private func goForward() {
        OnboardingSound.play(.pop)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            store.setCurrentStep(store.currentStep + 1)
        }
    }

    private func goBack() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            store.setCurrentStep(max(store.currentStep - 1, 0))
        }
    }

    private func completeOnboarding() {
        store.completeOnboarding()
        onComplete()
    }
}

/// 7.5.1: no model-selection step in onboarding anymore. The default
/// (Parakeet, multi-language) downloads in the background while the user
/// walks through onboarding, so it is ready by first real use.
enum ModelStarter {
    static func startDefaultModelDownloadIfNeeded() {
        let modelManager = ModelManager.shared
        let preferredID = AppSettings.shared.defaultTranscriptionModel

        let installCheck: () -> Void = {
            let alreadyCovered = modelManager.isDownloading
                || modelManager.installedModels.contains { $0.id == preferredID }
                || modelManager.currentModel?.id == preferredID
            guard !alreadyCovered else { return }

            guard let target = modelManager.availableModels.first(where: { $0.id == preferredID }),
                  target.category == .local, !target.isBuiltIn else { return }

            debugLog("📥 Onboarding: background-downloading default model \(preferredID)")
            modelManager.downloadModel(target) { result in
                if case .success(let downloaded) = result {
                    _ = modelManager.setCurrentModel(downloaded)
                }
            }
        }

        if modelManager.isReady {
            installCheck()
        } else {
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ModelManagerReady"),
                object: nil,
                queue: .main
            ) { _ in
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                installCheck()
            }
            // isReady may flip between the check above and observer registration;
            // re-check so the download is never missed.
            if modelManager.isReady {
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                installCheck()
            }
        }
    }
}
