//
//  TrialCTAStep.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI

struct TrialCTAStep: View {
    let onComplete: () -> Void

    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var statusMessage = ""
    @State private var isSuccess = false
    @State private var showPurchaseSheet = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Get EchoTune Pro")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Unlock unlimited voice dictation, custom AI models, meeting summaries, and advanced automations.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 20)

            #if APPSTORE
            // App Store Build Flow
            VStack(spacing: 16) {
                OnboardingCardView {
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)

                        Text("EchoTune Pro In-App Purchase")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Unlock all features permanently with a one-time purchase via the App Store. No recurring subscriptions.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            showPurchaseSheet = true
                        }) {
                            Text("Unlock EchoTune Pro")
                                .frame(width: 220)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $showPurchaseSheet) {
                PurchaseView()
            }
            #else
            // Direct Sale Build Flow
            VStack(spacing: 16) {
                // Buy License Option
                OnboardingCardView {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Purchase EchoTune Pro")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Get a lifetime license key via secure checkout.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: openCheckoutBrowser) {
                            Text("Buy License")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }

                // Activate Key Option
                OnboardingCardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Already have a license key?")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)

                        HStack(spacing: 10) {
                            TextField("Paste your license key (ET-...)", text: $licenseKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13, design: .monospaced))
                                .disabled(isActivating || isSuccess)

                            Button(action: activateKey) {
                                if isActivating {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Activate")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isActivating || isSuccess)
                        }

                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isSuccess ? .green : .red)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            #endif

            Spacer()

            // Completion options
            VStack(spacing: 12) {
                Button(action: onComplete) {
                    Text("Start Free Trial")
                        .frame(width: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isActivating)

                Button(action: onComplete) {
                    Text("Skip for now")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isActivating)
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            statusMessage = ""
        }
    }

    private func openCheckoutBrowser() {
        statusMessage = "Opening browser..."
        isSuccess = true
        if let url = URL(string: "https://echotune.app/checkout") {
            if NSWorkspace.shared.open(url) {
                statusMessage = "Browser opened. Complete purchase, then return here to activate."
            } else {
                isSuccess = false
                statusMessage = "Failed to open browser. Please visit https://echotune.app."
            }
        }
    }

    private func activateKey() {
        let trimmedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }

        isActivating = true
        statusMessage = "Verifying license key..."

        LicenseManager.shared.activateLicense(trimmedKey) { result in
            DispatchQueue.main.async {
                isActivating = false
                switch result {
                case .success(let info):
                    isSuccess = true
                    statusMessage = "License activated successfully!"
                    AppCoordinator.shared.updateLicenseState()
                    // Brief delay then complete onboarding
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        onComplete()
                    }
                case .failure(let error):
                    isSuccess = false
                    statusMessage = "Activation failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
