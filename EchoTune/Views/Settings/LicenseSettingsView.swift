//
//  LicenseSettingsView.swift
//  EchoTune
//
//  Phase 1: License Settings Tab
//

import SwiftUI
#if APPSTORE
import StoreKit
#endif

struct LicenseSettingsView: View {
    @State private var licenseManager = LicenseManager.shared
    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    #if APPSTORE
    @State private var storeKit = StoreKitManager.shared
    @State private var showPurchaseSheet = false
    #endif

    var body: some View {
        Form {
            Section("License Status") {
                if licenseManager.isLicensed {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("EchoTune is Licensed")
                            .fontWeight(.semibold)
                        Spacer()
                        if let info = licenseManager.licenseInfo {
                            Text(info.tier.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let info = licenseManager.licenseInfo {
                        LicenseDetailRow(label: "License Key", value: maskLicenseKey(info.key))
                        LicenseDetailRow(label: "Tier", value: info.tier.rawValue)
                        LicenseDetailRow(label: "Activated On", value: formatDate(info.activatedOn))

                        if info.isLifetime {
                            LicenseDetailRow(label: "Updates", value: "Lifetime")
                        } else if let expiry = info.expiryDate {
                            LicenseDetailRow(label: "Expires", value: formatDate(expiry))
                        }
                    }

                    Button("Deactivate License") {
                        deactivateLicense()
                    }
                    .foregroundColor(.red)
                } else {
                    HStack {
                        Image(systemName: licenseManager.isTrialExpired ? "exclamationmark.triangle.fill" : "clock.fill")
                            .foregroundColor(licenseManager.isTrialExpired ? .orange : .blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(licenseManager.isTrialExpired ? "Trial Expired" : "Trial Active")
                                .fontWeight(.semibold)
                            if !licenseManager.isTrialExpired {
                                Text("\(licenseManager.trialDaysRemaining) days remaining")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Enter a license key to continue using EchoTune")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }
                }
            }

            if !licenseManager.isLicensed {
                #if !APPSTORE
                Section("Activate License") {
                    TextField("XXXXX-XXXXX-XXXXX-XXXXX", text: $licenseKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .textCase(.uppercase)
                        .disabled(isActivating)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if showSuccess {
                        Text("License activated successfully!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    HStack(spacing: 12) {
                        Button(action: activateLicense) {
                            if isActivating {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Activate")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(licenseKey.isEmpty || isActivating)

                        Button("Purchase") {
                            if let url = URL(string: "https://echotune.app/purchase") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                #else
                Section("Purchase") {
                    if storeKit.products.isEmpty {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Loading purchase options…")
                                .foregroundColor(.secondary)
                        }
                    } else if let product = storeKit.products.first {
                        Button {
                            showPurchaseSheet = true
                        } label: {
                            HStack {
                                Text("Purchase Pro")
                                Spacer()
                                Text(product.displayPrice)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(storeKit.isPurchasing)
                    } else {
                        Text("Purchase not available. Please contact support.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Retry Loading Products") {
                            Task { await storeKit.loadProducts() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                #endif
            }

            Section("License Tiers") {
                LicenseTierCard(tier: .individual)
                LicenseTierCard(tier: .pro)

                Button("Compare License Tiers") {
                    if let url = URL(string: "https://echotune.app/pricing") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .formStyle(.grouped)
        #if APPSTORE
        .sheet(isPresented: $showPurchaseSheet) {
            PurchaseSheet(storeKit: storeKit, isPresented: $showPurchaseSheet)
        }
        #endif
    }

    // MARK: - Actions

    private func activateLicense() {
        errorMessage = nil
        showSuccess = false
        isActivating = true

        licenseManager.activateLicense(licenseKey) { [self] result in
            isActivating = false

            switch result {
            case .success(let info):
                showSuccess = true
                licenseKey = ""
                debugLog("✓ License activated: \(info.tier.rawValue)")
                AppCoordinator.shared.updateLicenseState()

            case .failure(let error):
                errorMessage = error.localizedDescription
                debugLog("❌ License activation failed: \(error)")
            }
        }
    }

    private func deactivateLicense() {
        let alert = NSAlert()
        alert.messageText = "Deactivate License?"
        alert.informativeText = "This will deactivate your license on this device. You can activate it again later or use it on another device."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Deactivate")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            licenseManager.deactivateLicense { result in
                switch result {
                case .success:
                    debugLog("✓ License deactivated")
                    AppCoordinator.shared.updateLicenseState()

                case .failure(let error):
                    debugLog("❌ Deactivation failed: \(error)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func maskLicenseKey(_ key: String) -> String {
        licenseManager.maskLicenseKey(key)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - License Detail Row

struct LicenseDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}

// MARK: - License Tier Card

struct LicenseTierCard: View {
    let tier: LicenseTier

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tier.rawValue)
                    .font(.headline)

                Spacer()

                Text(tier.price)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }

            ForEach(tier.features, id: \.self) { feature in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(feature)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Purchase Sheet (App Store only)

#if APPSTORE
struct PurchaseSheet: View {
    @ObservedObject var storeKit: StoreKitManager
    @Binding var isPresented: Bool
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showSuccess = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)

                Text("Upgrade to Pro")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Unlock all features and support development")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            // Product info
            if let product = storeKit.products.first {
                VStack(spacing: 16) {
                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "infinity", color: .blue, text: "Unlimited transcriptions")
                        FeatureRow(icon: "keyboard", color: .blue, text: "Custom keyboard shortcuts")
                        FeatureRow(icon: "wand.and.stars", color: .blue, text: "Advanced AI features")
                        FeatureRow(icon: "arrow.up.circle", color: .blue, text: "Priority updates")
                        FeatureRow(icon: "heart", color: .pink, text: "Support indie development")
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)

                    // Price
                    VStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)

                        Text(product.displayPrice)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.blue)

                        Text("One-time purchase • Lifetime access")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Error message
                if let error = purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // Success message
                if showSuccess {
                    Text("Purchase successful! Enjoy EchoTune Pro!")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                // Purchase button
                Button(action: {
                    Task {
                        await purchaseProduct(product)
                    }
                }) {
                    if isPurchasing {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Processing…")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        Text("Purchase Pro")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPurchasing)
                .controlSize(.large)
            } else {
                Text("Product not available")
                    .foregroundColor(.secondary)
            }

            // Cancel button
            Button("Maybe Later") {
                isPresented = false
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()
        }
        .padding(32)
        .frame(width: 500, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil

        do {
            let success = try await storeKit.purchase(product)

            if success {
                showSuccess = true
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                isPresented = false
            } else {
                purchaseError = "Purchase was cancelled or is pending approval"
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }

        isPurchasing = false
    }
}
#endif
