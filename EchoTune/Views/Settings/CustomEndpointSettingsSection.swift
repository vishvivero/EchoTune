//
//  CustomEndpointSettingsSection.swift
//  EchoTune
//
//  ET-766 · connect LM Studio / Ollama (HTTP) / vLLM / faster-whisper-server /
//  OpenRouter or any other OpenAI-compatible server.
//

import SwiftUI

struct CustomEndpointSettingsSection: View {
    @EnvironmentObject var settings: AppSettings

    @State private var testStatus: TestStatus = .idle

    private enum TestStatus: Equatable {
        case idle
        case running
        case ok(String)
        case failed(String)
    }

    private var normalizedURL: URL? {
        CustomOpenAICompatibleService.normalizedBaseURL(settings.customEndpointBaseURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Use a custom OpenAI-compatible endpoint", isOn: $settings.customEndpointEnabled)
                .font(.headline)

            Text("LM Studio, Ollama (HTTP), vLLM, faster-whisper-server, OpenRouter and anything else that speaks the OpenAI wire format.")
                .font(.caption)
                .foregroundColor(.secondary)

            if settings.customEndpointEnabled {
                Divider()

                // Presets
                HStack(spacing: 8) {
                    Text("Preset")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(CustomOpenAICompatibleService.Preset.all) { preset in
                        Button(preset.name) {
                            settings.customEndpointBaseURL = preset.baseURL
                            testStatus = .idle
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(preset.note)
                    }
                    Spacer()
                }

                // Base URL
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Base URL", text: $settings.customEndpointBaseURL)
                        .textFieldStyle(.roundedBorder)
                    if let normalizedURL {
                        Text("Requests go to \(normalizedURL.absoluteString)/chat/completions")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Label("That is not a usable URL.", systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }

                // Models
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speech-to-text model")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("whisper-1", text: $settings.customEndpointSTTModel)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chat model")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("local-model", text: $settings.customEndpointChatModel)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                // Key (only for remote endpoints)
                if CustomOpenAICompatibleService.requiresAPIKey(settings.customEndpointBaseURL) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("sk-…", text: $settings.customEndpointAPIKey)
                            .textFieldStyle(.roundedBorder)
                        if settings.customEndpointAPIKey.isEmpty {
                            Label("This endpoint is not local, so a key is required.", systemImage: "key")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    Label("Local endpoint — no API key needed.", systemImage: "lock.shield")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Connection test
                HStack(spacing: 10) {
                    Button(testStatus == .running ? "Testing…" : "Test Connection") {
                        testConnection()
                    }
                    .buttonStyle(.bordered)
                    .disabled(testStatus == .running || normalizedURL == nil)

                    switch testStatus {
                    case .idle:
                        EmptyView()
                    case .running:
                        ProgressView().controlSize(.small)
                    case .ok(let message):
                        Label(message, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    case .failed(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(3)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    /// Pings `/chat/completions` with a trivial prompt. A 200 means the server is
    /// reachable and the model name is understood; anything else is reported
    /// verbatim so the user can fix it without reading logs.
    private func testConnection() {
        guard let url = CustomOpenAICompatibleService.endpointURL(
            base: settings.customEndpointBaseURL,
            kind: .chat
        ) else { return }

        guard let built = CustomOpenAICompatibleService.chatRequest(
            messages: [("user", "ping")],
            model: settings.customEndpointChatModel,
            apiKey: settings.customEndpointAPIKey
        ) else { return }

        testStatus = .running

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = built.body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        CustomOpenAICompatibleService.applyAuthorization(settings.customEndpointAPIKey, to: &request)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    testStatus = .failed(error.localizedDescription)
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    testStatus = .failed("No HTTP response")
                    return
                }
                guard (200..<300).contains(http.statusCode) else {
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    testStatus = .failed("HTTP \(http.statusCode) \(body.prefix(120))")
                    return
                }
                if let text = data.flatMap({ CustomOpenAICompatibleService.chatText(from: $0) }) {
                    testStatus = .ok("Connected — replied “\(text.prefix(40))”")
                } else {
                    testStatus = .ok("Connected (HTTP \(http.statusCode))")
                }
            }
        }.resume()
    }
}
