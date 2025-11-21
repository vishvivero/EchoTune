//
//  PurchaseView.swift
//  EchoTune
//
//  In-App Purchase UI for App Store build
//

import SwiftUI
import StoreKit

struct PurchaseView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            headerSection

            Divider()

            ScrollView {
                VStack(spacing: 32) {
                    // Hero section
                    heroSection

                    // Features
                    featuresSection

                    // Purchase button
                    if let product = storeManager.proProduct {
                        purchaseSection(product: product)
                    } else {
                        ProgressView("Loading...")
                            .padding()
                    }

                    // Restore purchases
                    restoreSection

                    // Terms
                    termsSection
                }
                .padding(32)
            }
        }
        .frame(width: 600, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Upgrade to Pro")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Unlock unlimited transcriptions")
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
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
                .shadow(color: .yellow.opacity(0.3), radius: 10)

            Text("EchoTune Pro")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Transform your workflow with unlimited AI-powered voice transcription")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's Included")
                .font(.headline)

            VStack(spacing: 12) {
                FeatureRow(icon: "infinity", color: .blue, text: "Unlimited transcriptions")
                FeatureRow(icon: "sparkles", color: .purple, text: "All AI models (Whisper, Groq, Deepgram)")
                FeatureRow(icon: "lock.shield", color: .green, text: "100% private local processing")
                FeatureRow(icon: "keyboard", color: .orange, text: "Global keyboard shortcuts (⌘⇧D)")
                FeatureRow(icon: "arrow.down.circle", color: .blue, text: "Automatic text insertion")
                FeatureRow(icon: "chart.bar", color: .cyan, text: "Detailed statistics and analytics")
                FeatureRow(icon: "clock.arrow.circlepath", color: .indigo, text: "Complete session history")
                FeatureRow(icon: "arrow.clockwise", color: .green, text: "Lifetime updates (v1.x)")
            }
        }
    }

    // MARK: - Purchase

    private func purchaseSection(product: Product) -> some View {
        VStack(spacing: 16) {
            Button(action: {
                Task {
                    do {
                        let success = try await storeManager.purchase(product)
                        if success {
                            // Show success briefly before dismissing
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            dismiss()
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }) {
                HStack(spacing: 12) {
                    if storeManager.isPurchasing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }

                    VStack(spacing: 4) {
                        Text("Upgrade to Pro")
                            .font(.headline)
                        Text(product.displayPrice)
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(storeManager.isPurchasing)

            Text("One-time purchase • No subscription • Single device")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Restore

    private var restoreSection: some View {
        VStack(spacing: 12) {
            Text("Already purchased?")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: {
                Task {
                    await storeManager.restorePurchases()

                    // Check if restored successfully
                    if storeManager.isProUnlocked {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        dismiss()
                    }
                }
            }) {
                Text("Restore Purchases")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Terms

    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("Payment will be charged to your Apple Account. Purchases are non-refundable except as required by law.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: "https://echotune.app/privacy")!)
                Text("•").foregroundColor(.secondary)
                Link("Terms of Use", destination: URL(string: "https://echotune.app/terms")!)
            }
            .font(.caption2)
            .foregroundColor(.blue)
        }
        .padding(.top)
    }
}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
                .font(.body)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    PurchaseView()
}
