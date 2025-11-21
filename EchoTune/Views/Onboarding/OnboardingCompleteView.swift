//
//  OnboardingCompleteView.swift
//  EchoTune
//
//  Final onboarding screen celebrating completion
//

import SwiftUI

struct OnboardingCompleteView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var showContent = false
    @State private var confettiOpacity: Double = 0

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Success animation
            ZStack {
                // Confetti effect
                ForEach(0..<20) { index in
                    ConfettiShape()
                        .fill(confettiColors[index % confettiColors.count])
                        .frame(width: 10, height: 10)
                        .offset(
                            x: CGFloat.random(in: -150...150),
                            y: CGFloat.random(in: -150...150)
                        )
                        .rotationEffect(.degrees(Double.random(in: 0...360)))
                        .opacity(confettiOpacity)
                }

                // Success icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .shadow(color: .green.opacity(0.3), radius: 20)

                    Image(systemName: "checkmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                .scaleEffect(showContent ? 1.0 : 0.5)
                .opacity(showContent ? 1.0 : 0.0)
            }

            VStack(spacing: 20) {
                Text("All Set!")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 20)

                Text("EchoTune is ready to transform your voice into text")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 20)
            }

            // Quick tips
            VStack(alignment: .leading, spacing: 16) {
                QuickTipRow(
                    icon: "command.circle.fill",
                    title: "Press fn to start recording",
                    subtitle: "Works anywhere on your Mac"
                )

                QuickTipRow(
                    icon: "waveform.circle.fill",
                    title: "Speak naturally",
                    subtitle: "AI will transcribe your voice accurately"
                )

                QuickTipRow(
                    icon: "text.insert",
                    title: "Text appears instantly",
                    subtitle: "No copy-pasting needed"
                )
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 500)
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)

            Spacer()

            // Start button
            Button(action: {
                // Close onboarding and show main app
                coordinator.completeOnboarding()
            }) {
                HStack(spacing: 12) {
                    Text("Start Using EchoTune")
                        .font(.system(size: 18, weight: .semibold))

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: .blue.opacity(0.4), radius: 15, y: 8)
            }
            .buttonStyle(.plain)
            .opacity(showContent ? 1.0 : 0.0)
            .scaleEffect(showContent ? 1.0 : 0.9)

            Spacer()
                .frame(height: 40)
        }
        .padding(40)
        .onAppear {
            // Animate entrance
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showContent = true
            }

            // Confetti animation
            withAnimation(.easeIn(duration: 0.3)) {
                confettiOpacity = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 2.0)) {
                    confettiOpacity = 0.0
                }
            }
        }
    }

    private let confettiColors: [Color] = [
        .blue, .green, .yellow, .orange, .red, .purple, .pink
    ]
}

struct QuickTipRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct ConfettiShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Simple confetti shapes (circles, squares, triangles)
        let shapeType = Int.random(in: 0...2)

        switch shapeType {
        case 0: // Circle
            path.addEllipse(in: rect)
        case 1: // Square
            path.addRect(rect)
        case 2: // Triangle
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        default:
            path.addEllipse(in: rect)
        }

        return path
    }
}

#Preview {
    OnboardingCompleteView()
        .environment(OnboardingCoordinator.shared)
        .frame(width: 800, height: 600)
}
