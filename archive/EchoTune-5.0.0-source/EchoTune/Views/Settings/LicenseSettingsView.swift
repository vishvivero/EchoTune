//
//  LicenseSettingsView.swift
//  EchoTune
//
//  Created by Antigravity on 13/06/2026.
//

import SwiftUI

struct LicenseSettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var licenseKey: String = ""
    @State private var isActivating: Bool = false
    @State private var activationError: String? = nil
    @State private var showSuccessAlert = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header Card
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: coordinator.appState.isLicensed ? "checkmark.seal.fill" : "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(coordinator.appState.isLicensed ? .green : .blue)
                }
                .padding(.top, 20)
                
                Text(coordinator.appState.isLicensed ? "EchoTune Pro Active" : "Unlock EchoTune Pro")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(coordinator.appState.isLicensed 
                     ? "You have full access to local Whisper & high-speed Groq transcription."
                     : "Activate a lifetime license to remove trial limits and unlock pro features.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Divider()
            
            // License Details / Activation Panel
            VStack(alignment: .leading, spacing: 16) {
                if coordinator.appState.isLicensed {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("License Status:")
                                .fontWeight(.medium)
                            Spacer()
                            Text("Active")
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                        
                        if let info = coordinator.licenseManager.licenseInfo {
                            HStack {
                                Text("License Key:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(String(info.key.prefix(12)) + "...")
                                    .foregroundColor(.secondary)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            HStack {
                                Text("Tier:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(info.tier.rawValue.capitalized)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let expires = info.expiryDate {
                                HStack {
                                    Text("Expiry Date:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(expires, style: .date)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.2), lineWidth: 1))
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("License Key")
                            .font(.headline)
                        
                        TextField("Enter your Polar license key (e.g. ET-XXXXXX)", text: $licenseKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .disabled(isActivating)
                        
                        if let error = activationError {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            .padding(.top, 4)
                        }
                        
                        Button(action: activateKey) {
                            if isActivating {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.horizontal, 10)
                            } else {
                                Text("Activate License")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isActivating)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // Trial Status / Purchase Link
                    VStack(spacing: 12) {
                        Text("Don't have a license key yet?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            _ = coordinator.licenseManager.openPurchaseURL()
                        }) {
                            HStack {
                                Image(systemName: "cart.fill")
                                Text("Purchase License from Polar.sh")
                            }
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        Text("Trial days remaining: \(coordinator.licenseManager.trialDaysRemaining) days")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Close Button
            Button("Done") {
                coordinator.showLicenseSheet = false
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 24)
        }
        .frame(width: 480, height: 520)
        .alert("License Activated!", isPresented: $showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Thank you for purchasing EchoTune Pro! All premium features are now unlocked.")
        }
    }
    
    private func activateKey() {
        isActivating = true
        activationError = nil
        
        coordinator.licenseManager.activateLicense(licenseKey) { result in
            DispatchQueue.main.async {
                isActivating = false
                switch result {
                case .success(let info):
                    coordinator.appState.isLicensed = true
                    coordinator.appState.licenseInfo = info
                    showSuccessAlert = true
                case .failure(let error):
                    activationError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - License Subscription Button
struct LicenseSubscriptionButton: View {
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
        Button(action: {
            coordinator.showLicenseSheet = true
        }) {
            HStack(spacing: 8) {
                if coordinator.appState.isLicensed {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("EchoTune Pro Active")
                        .fontWeight(.medium)
                } else {
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                    Text("Unlock EchoTune Pro")
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer()
                    Text("\(coordinator.licenseManager.trialDaysRemaining)d left")
                        .font(.caption2)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(coordinator.appState.isLicensed ? Color.green.opacity(0.06) : Color.orange.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(coordinator.appState.isLicensed ? Color.green.opacity(0.15) : Color.orange.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
