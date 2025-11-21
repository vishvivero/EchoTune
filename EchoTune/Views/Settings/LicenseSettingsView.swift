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
    @Environment(\.dismiss) var dismiss
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
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("License")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Manage your EchoTune license")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                licenseContent
                    .padding(24)
            }
        }
        .frame(width: 600, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
        #if APPSTORE
        .sheet(isPresented: $showPurchaseSheet) {
            PurchaseSheet(storeKit: storeKit, isPresented: $showPurchaseSheet)
        }
        #endif
    }

    private var licenseContent: some View {
        VStack(spacing: 24) {
            if licenseManager.isLicensed {
                // Licensed State
                licensedSection
            } else {
                // Unlicensed State
                unlicensedSection
            }

            // License Tiers Info
            licenseTiersSection
        }
    }

    // MARK: - Licensed Section

    private var licensedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("License Status")
                .font(.headline)

            VStack(spacing: 16) {
                // Success badge
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundColor(.green)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("EchoTune is Licensed")
                            .font(.headline)

                        if let info = licenseManager.licenseInfo {
                            Text("\(info.tier.rawValue) License")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)

                // License details
                if let info = licenseManager.licenseInfo {
                    VStack(spacing: 8) {
                        LicenseDetailRow(label: "License Key", value: maskLicenseKey(info.key))
                        LicenseDetailRow(label: "Tier", value: info.tier.rawValue)
                        LicenseDetailRow(label: "Activated On", value: formatDate(info.activatedOn))

                        if info.isLifetime {
                            LicenseDetailRow(label: "Updates", value: "Lifetime")
                        } else if let expiry = info.expiryDate {
                            LicenseDetailRow(label: "Expires", value: formatDate(expiry))
                        }
                    }
                }

                // Deactivate button
                Button("Deactivate License") {
                    deactivateLicense()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)

                Text("Deactivating will allow you to use this license on another device")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Unlicensed Section

    private var unlicensedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activate License")
                .font(.headline)

            VStack(spacing: 16) {
                // Trial status
                if !licenseManager.isTrialExpired {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Trial Active")
                                .font(.headline)
                            Text("\(licenseManager.trialDaysRemaining) days remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    // Trial expired
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Trial Expired")
                                .font(.headline)
                            Text("Enter a license key to continue using EchoTune")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                #if !APPSTORE
                // License key input (Direct sale builds only)
                VStack(alignment: .leading, spacing: 8) {
                    Text("License Key")
                        .font(.headline)

                    TextField("XXXXX-XXXXX-XXXXX-XXXXX", text: $licenseKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .textCase(.uppercase)
                        .disabled(isActivating)

                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(error)
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }

                    if showSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("License activated successfully!")
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                    }
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button(action: activateLicense) {
                        if isActivating {
                            ProgressView()
                                .controlSize(.small)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Activate License")
                                .frame(maxWidth: .infinity)
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
                #else
                // App Store build - Show IAP purchase button only
                VStack(spacing: 12) {
                    if storeKit.products.isEmpty {
                        // Products not loaded yet
                        VStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading purchase options...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else if let product = storeKit.products.first {
                        // Show product with pricing
                        VStack(spacing: 12) {
                            Text("Purchase EchoTune Pro to continue using all features")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button(action: {
                                showPurchaseSheet = true
                            }) {
                                HStack {
                                    Text("Purchase Pro")
                                    Text("•")
                                    Text(product.displayPrice)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(storeKit.isPurchasing)
                        }
                    } else {
                        // Products failed to load or not configured
                        VStack(spacing: 12) {
                            Text("⚠️ Purchase not available")
                                .font(.headline)
                                .foregroundColor(.orange)

                            Text("In-App Purchase is not configured yet. Please contact support.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Retry Loading Products") {
                                Task {
                                    await storeKit.loadProducts()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                #endif
            }
        }
    }

    // MARK: - License Tiers Section

    private var licenseTiersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("License Tiers")
                .font(.headline)

            VStack(spacing: 12) {
                LicenseTierCard(tier: .individual)
                LicenseTierCard(tier: .pro)
            }

            Button("Compare License Tiers →") {
                if let url = URL(string: "https://echotune.app/pricing") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
            .font(.caption)
        }
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
                print("✓ License activated: \(info.tier.rawValue)")

                // Update app state
                AppCoordinator.shared.updateLicenseState()

            case .failure(let error):
                errorMessage = error.localizedDescription
                print("❌ License activation failed: \(error)")
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
                    print("✓ License deactivated")
                    // Update app state
                    AppCoordinator.shared.updateLicenseState()

                case .failure(let error):
                    print("❌ Deactivation failed: \(error)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func isValidLicenseFormat(_ key: String) -> Bool {
        let pattern = "^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$"
        return key.range(of: pattern, options: .regularExpression) != nil
    }

    private func maskLicenseKey(_ key: String) -> String {
        return licenseManager.maskLicenseKey(key)
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
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
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
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                // Success message
                if showSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Purchase successful! Enjoy EchoTune Pro!")
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
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
                            Text("Processing...")
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
                // Wait a moment to show success message
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
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
