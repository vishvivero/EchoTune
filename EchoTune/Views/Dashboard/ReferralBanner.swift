//
//  ReferralBanner.swift
//  EchoTune
//

import SwiftUI

// MARK: - Referral Banner

struct ReferralBanner: View {
    @Binding var showReferralSheet: Bool
    @EnvironmentObject var appCoordinator: AppCoordinator

    private var isProUser: Bool {
        appCoordinator.licenseManager.isLicensed
    }

    private var bannerTitle: String {
        isProUser ? "Share EchoTune, earn rewards" : "Give a month, get a month"
    }

    private var bannerSubtitle: String {
        isProUser ? "Earn $5 for every friend who subscribes!" : "Invite friends and you both get a free month!"
    }

    private var bannerIcon: String {
        isProUser ? "dollarsign.circle.fill" : "gift.fill"
    }

    var body: some View {
        Button(action: {
            showReferralSheet = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: bannerIcon)
                    .font(.title3)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bannerTitle)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(bannerSubtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Share Now")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: isProUser ? [
                        Color(red: 0.2, green: 0.7, blue: 0.4),
                        Color(red: 0.15, green: 0.6, blue: 0.35)
                    ] : [
                        Color(red: 0.4, green: 0.6, blue: 1.0),
                        Color(red: 0.3, green: 0.5, blue: 0.9)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: (isProUser ? Color.green : Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - License/Subscription Button

struct LicenseSubscriptionButton: View {
    @EnvironmentObject var appCoordinator: AppCoordinator

    private var isPro: Bool {
        appCoordinator.licenseManager.isPro
    }

    private var buttonTitle: String {
        if isPro {
            return "Pro Version"
        } else if !appCoordinator.licenseManager.isTrialExpired {
            #if APPSTORE
            return "Upgrade to Pro"
            #else
            return "Purchase Now"
            #endif
        } else {
            #if APPSTORE
            return "Upgrade to Pro"
            #else
            return "Purchase Now"
            #endif
        }
    }

    private var buttonIcon: String {
        if isPro {
            return "crown.fill"
        } else {
            return "cart.fill"
        }
    }

    private var buttonColor: Color {
        if isPro {
            return .purple
        } else if !appCoordinator.licenseManager.isTrialExpired {
            return .blue
        } else {
            return .orange
        }
    }

    var body: some View {
        Button(action: {
            guard !isPro else { return }
            appCoordinator.presentPurchaseFlow()
        }) {
            HStack(spacing: 8) {
                Image(systemName: buttonIcon)
                    .foregroundColor(buttonColor)

                Text(buttonTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                if !appCoordinator.licenseManager.isLicensed && !appCoordinator.licenseManager.isTrialExpired {
                    Text("\(appCoordinator.licenseManager.trialDaysRemaining)d")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(buttonColor.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
