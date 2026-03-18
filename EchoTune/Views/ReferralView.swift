//
//  ReferralView.swift
//  EchoTune
//
//  Referral Program View — Supabase-backed
//

import SwiftUI
import AppKit

struct ReferralView: View {
    @Environment(\.dismiss) var dismiss
    @State private var referralManager = ReferralManager.shared
    @State private var friendEmail: String = ""
    @State private var showCopiedAlert = false
    @State private var copiedText = "Link copied!"
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            Divider()

            // Progress bar to free year
            if referralManager.isRegistered {
                freeYearProgress
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
            }

            // Tabs
            Picker("", selection: $selectedTab) {
                Text("Share").tag(0)
                Text("Referrals (\(referralManager.totalReferrals))").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    if selectedTab == 0 {
                        shareContent
                    } else {
                        pastReferralsContent
                    }
                }
                .padding(24)
            }

            // Copied toast
            if showCopiedAlert {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(copiedText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .shadow(radius: 4)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 520, height: 640)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            if referralManager.isRegistered {
                await referralManager.refreshStats()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Refer Friends, Earn Free Months")
                    .font(.title2)
                    .fontWeight(.bold)

                if referralManager.isRegistered {
                    Text("Your code: **\(referralManager.referralCode)**")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Activate your license to get your referral code")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }

    // MARK: - Free Year Progress

    private var freeYearProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🎯 Free Year Progress")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(referralManager.totalReferrals)/12 referrals")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(NSColor.separatorColor))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            referralManager.hasFreeYear
                                ? AnyShapeStyle(Color.green)
                                : AnyShapeStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .frame(
                            width: geo.size.width * referralManager.progressToFreeYear,
                            height: 8
                        )
                        .animation(.easeInOut(duration: 0.5), value: referralManager.progressToFreeYear)
                }
            }
            .frame(height: 8)

            if referralManager.hasFreeYear {
                Text("🎉 You've earned a free year!")
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            } else if referralManager.bonusDaysEarned > 0 {
                Text("+\(referralManager.bonusDaysEarned) bonus days earned • \(referralManager.referralsToFreeYear) more for free year")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Share Content

    private var shareContent: some View {
        VStack(spacing: 24) {
            if !referralManager.isRegistered {
                notRegisteredView
            } else {
                // How it works
                howItWorks

                // Referral link
                referralLinkSection

                Divider()

                // Email invite
                emailInviteSection

                // Social share
                socialShareSection
            }
        }
    }

    private var notRegisteredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .padding(.top, 20)

            Text("Activate Your License First")
                .font(.headline)

            Text("You need an active EchoTune license to get your referral code. Activate your beta key in Settings → License.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How it works")
                .font(.headline)

            HowItWorksRow(icon: "paperplane.fill", text: "Share your unique link with friends")
            HowItWorksRow(icon: "person.badge.plus.fill", text: "They sign up and get 3 free months")
            HowItWorksRow(icon: "gift.fill", text: "You earn +1 month per referral (12 = free year!)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var referralLinkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Referral Checkout Link")
                .font(.headline)

            HStack(spacing: 8) {
                Text(referralManager.betaCheckoutWithReferral)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                Button(action: {
                    referralManager.copyCheckoutLink()
                    showCopied("Checkout link copied!")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            // Also show plain referral code
            HStack {
                Text("Code:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(referralManager.referralCode)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .textSelection(.enabled)

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(referralManager.referralCode, forType: .string)
                    showCopied("Code copied!")
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emailInviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite via Email")
                .font(.headline)

            HStack {
                TextField("friend@example.com", text: $friendEmail)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                Button(action: {
                    referralManager.shareViaEmail(to: friendEmail)
                    friendEmail = ""
                }) {
                    Text("Send")
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(friendEmail.isEmpty ? Color.gray.opacity(0.5) : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(friendEmail.isEmpty)
            }
        }
    }

    private var socialShareSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share on Social")
                .font(.headline)

            HStack(spacing: 12) {
                SocialShareButton(
                    platform: "X / Twitter",
                    icon: "xmark",
                    color: .black,
                    action: { referralManager.shareToX() }
                )

                SocialShareButton(
                    platform: "Copy Link",
                    icon: "link",
                    color: .blue,
                    action: {
                        referralManager.copyReferralLink()
                        showCopied("Referral link copied!")
                    }
                )
            }
        }
    }

    // MARK: - Past Referrals

    private var pastReferralsContent: some View {
        VStack(spacing: 16) {
            if referralManager.isLoading {
                ProgressView()
                    .padding(.top, 40)
            } else if referralManager.referrals.isEmpty {
                emptyReferrals
            } else {
                referralsList
            }
        }
    }

    private var emptyReferrals: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .padding(.top, 40)

            Text("No referrals yet")
                .font(.headline)

            Text("Share your link to start earning free months!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var referralsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(referralManager.referrals) { referral in
                HStack {
                    Text(referral.statusEmoji)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(referral.maskedEmail)
                            .font(.subheadline)
                        if let date = referral.createdDate {
                            Text(date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Text("+\(referral.bonus_days ?? 30) days")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Helpers

    private func showCopied(_ text: String) {
        copiedText = text
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopiedAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopiedAlert = false }
        }
    }
}

// MARK: - Subviews

struct HowItWorksRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
        }
    }
}

struct SocialShareButton: View {
    let platform: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(platform)
                    .fontWeight(.medium)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReferralView()
}
