//
//  ModelDownloadView.swift
//  EchoTune
//
//  Download recommended AI model
//

import SwiftUI

struct ModelDownloadView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var downloadComplete = false

    private let recommendedModel = AIModelInfo(
        name: "Whisper Base",
        size: "150 MB",
        description: "Balanced speed and accuracy",
        features: ["Fast transcription", "Works offline", "Good accuracy", "Low memory usage"]
    )

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 120, height: 120)

                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(iconColor)
            }
            .animation(.spring(response: 0.3), value: downloadComplete)

            VStack(spacing: 16) {
                Text(downloadComplete ? "Model Ready!" : "Download AI Model")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                Text(downloadComplete ?
                     "The AI model has been downloaded and is ready to use." :
                     "We recommend downloading the Whisper Base model for the best experience.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            if !downloadComplete {
                // Model info card
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(recommendedModel.name)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)

                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.yellow)

                                    Text("Recommended")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.yellow.opacity(0.1))
                                .cornerRadius(6)
                            }

                            Text(recommendedModel.description)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)

                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 12))

                                Text(recommendedModel.size)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "brain")
                            .font(.system(size: 40))
                            .foregroundColor(.blue.opacity(0.3))
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Features:")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        ForEach(recommendedModel.features, id: \.self) { feature in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)

                                Text(feature)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
                .frame(maxWidth: 500)
            }

            if isDownloading {
                // Download progress
                VStack(spacing: 16) {
                    ProgressView(value: downloadProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 400)
                        .tint(.blue)

                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)

                        Text("Downloading... \(Int(downloadProgress * 100))%")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            } else if downloadComplete {
                // Success message
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)

                    Text("Model downloaded successfully!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            }

            Spacer()

            // Action buttons
            if !isDownloading {
                VStack(spacing: 12) {
                    Button(action: downloadComplete ? continueToNext : startDownload) {
                        HStack(spacing: 12) {
                            if !downloadComplete {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 18))
                            }

                            Text(downloadComplete ? "Continue" : "Download Model")
                                .font(.system(size: 16, weight: .semibold))

                            if downloadComplete {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)

                    if !downloadComplete {
                        Button(action: continueToNext) {
                            Text("Skip for Now")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(40)
    }

    private var iconName: String {
        if downloadComplete {
            return "checkmark.circle.fill"
        } else if isDownloading {
            return "arrow.down.circle"
        } else {
            return "brain"
        }
    }

    private var iconColor: Color {
        downloadComplete ? .green : .blue
    }

    private var iconBackgroundColor: Color {
        downloadComplete ? .green.opacity(0.2) : .blue.opacity(0.2)
    }

    private func startDownload() {
        isDownloading = true
        downloadProgress = 0.0

        // Simulate download with Timer
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            downloadProgress += 0.02

            if downloadProgress >= 1.0 {
                timer.invalidate()
                isDownloading = false
                downloadComplete = true

                // Auto-continue after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    coordinator.modelDownloadProgress = 1.0
                }
            }
        }
    }

    private func continueToNext() {
        coordinator.nextStep()
    }
}

struct AIModelInfo {
    let name: String
    let size: String
    let description: String
    let features: [String]
}

#Preview {
    ModelDownloadView()
        .environment(OnboardingCoordinator.shared)
        .frame(width: 800, height: 600)
}
