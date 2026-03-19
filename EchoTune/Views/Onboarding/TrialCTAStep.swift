//
//  TrialCTAStep.swift
//  EchoTune
//
//  Onboarding Step 6: Trial CTA / Get Started
//

import SwiftUI

struct TrialCTAStep: View {
    let onFinish: () -> Void
    let onBack: () -> Void

    @State private var appeared = false
    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var activationError: String?
    @State private var showLicenseField = false
    @State private var purchaseStatusMessage: String?
    @State private var purchaseStatusIsError = false
    @State private var showPurchaseSheet = false

    private let licenseManager = LicenseManager.shared

    var body: some View {
        VStack(spacing: 0) {
            BackButton(action: onBack)

            Spacer()

            // Checkmark / crown icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.echoPrimary.opacity(0.15), Color.echoAccent.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(appeared ? 1.0 : 0.5)

                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.echoPrimary, Color.echoAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(appeared ? 1.0 : 0.5)
            }

            Spacer().frame(height: 24)

            Text("You're all set!")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.echoTextPrimary)
                .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 8)

            Text("Start your 7-day free trial with full access.\nNo credit card required.")
                .font(.system(size: 15))
                .foregroundColor(.echoTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 28)

            // What you get
            VStack(spacing: 8) {
                TrialFeatureRow(icon: "infinity", text: "Unlimited transcriptions")
                TrialFeatureRow(icon: "sparkles", text: "All AI models & enhancements")
                TrialFeatureRow(icon: "keyboard", text: "Global shortcut \u{2014} works in any app")
                TrialFeatureRow(icon: "brain.head.profile", text: "Context-aware & Power Modes")
            }
            .padding(.horizontal, 80)
            .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 28)

            // CTA Buttons
            VStack(spacing: 12) {
                // Primary: Start Free Trial
                Button(action: onFinish) {
                    Text(primaryButtonTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 260, height: 46)
                        .background(
                            LinearGradient(
                                colors: [Color.echoPrimary, Color.echoAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.echoPrimary.opacity(0.35), radius: 16, y: 6)
                }
                .buttonStyle(.plain)

                #if APPSTORE
                Button(action: {
                    showPurchaseSheet = true
                    purchaseStatusMessage = nil
                }) {
                    Text(storeButtonTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.echoPrimary)
                }
                .buttonStyle(.plain)
                #else
                HStack(spacing: 16) {
                    Button(action: openPurchaseFlow) {
                        Text("Get License")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.echoPrimary)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        activationError = nil
                        withAnimation(.easeOut(duration: 0.25)) {
                            showLicenseField.toggle()
                        }
                    }) {
                        Text(showLicenseField ? "Hide License Field" : "I have a license key")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.echoPrimary)
                    }
                    .buttonStyle(.plain)
                }

                if showLicenseField {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            TextField("XXXXX-XXXXX-XXXXX-XXXXX", text: $licenseKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 220)

                            Button(action: activateLicense) {
                                if isActivating {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.echoPrimary)
                                } else {
                                    Text("Activate")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.echoPrimary)
                            .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isActivating)
                        }

                        if let error = activationError {
                            Text(error)
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                #endif

                if let purchaseStatusMessage {
                    Text(purchaseStatusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(purchaseStatusIsError ? .red : .echoPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
            }
            .opacity(appeared ? 1 : 0)

            Spacer()

            Text(trialFooterText)
                .font(.system(size: 11))
                .foregroundColor(.echoTextTertiary)
                .padding(.bottom, 48)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PurchaseCompleted"))) { _ in
            purchaseStatusIsError = false
            purchaseStatusMessage = "Pro unlocked on this Mac. Finish setup when you're ready."
        }
        .sheet(isPresented: $showPurchaseSheet) {
            PurchaseView()
        }
    }

    private func activateLicense() {
        isActivating = true
        activationError = nil
        purchaseStatusMessage = nil

        licenseManager.activateLicense(licenseKey.uppercased()) { result in
            isActivating = false
            switch result {
            case .success:
                onFinish()
            case .failure(let error):
                activationError = error.localizedDescription
            }
        }
    }

    private func openPurchaseFlow() {
        activationError = nil
        let opened = licenseManager.openPurchaseURL()
        purchaseStatusIsError = !opened
        purchaseStatusMessage = opened
            ? "Purchase page opened in your browser. After checkout, come back here and paste your license key."
            : "EchoTune could not open the purchase page. Visit \(Constants.purchaseURL) manually to buy a license."
    }

    private var primaryButtonTitle: String {
        licenseManager.isPro ? "Finish Setup" : "Start Free Trial"
    }

    private var storeButtonTitle: String {
        licenseManager.isPro ? "Pro unlocked" : "Upgrade to Pro"
    }

    private var trialFooterText: String {
        #if APPSTORE
        return "7-day free trial \u{2022} Then a one-time App Store purchase"
        #else
        return "7-day free trial \u{2022} Then a one-time EchoTune license"
        #endif
    }
}

// MARK: - Trial Feature Row

struct TrialFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.echoPrimary)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.echoTextSecondary)

            Spacer()
        }
    }
}
