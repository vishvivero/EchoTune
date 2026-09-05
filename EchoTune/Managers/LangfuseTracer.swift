//
//  LangfuseTracer.swift
//  EchoTune
//
//  Minimal, lib-free Langfuse tracer for the self-hosted Langfuse v4 instance.
//
//  Wire format: POST /api/public/generations with HTTP Basic auth
//  (username = public key, password = secret key) — the v3-compatible
//  contract Langfuse keeps available in `dual` migration mode.
//
//  Configuration is read from a local file that is NOT committed to the repo:
//    ~/.config/echotune/langfuse.env   (LANGFUSE_PUBLIC_KEY / LANGFUSE_SECRET_KEY / LANGFUSE_BASE_URL)
//  If unset or unreachable, tracing is a silent no-op — dictation never blocks.
//

import Foundation

struct LangfuseConfig {
    var baseURL: String
    var publicKey: String
    var secretKey: String
    var isConfigured: Bool {
        !publicKey.isEmpty && !secretKey.isEmpty
    }
}

final class LangfuseTracer {
    static let shared = LangfuseTracer()

    private let configPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/echotune/langfuse.env")

    /// Loaded lazily on first use so a missing config never blocks startup.
    private var _config: LangfuseConfig?
    private var configLock = NSLock()

    private var config: LangfuseConfig {
        configLock.lock()
        defer { configLock.unlock() }
        if let _config { return _config }
        let loaded = loadConfig()
        _config = loaded
        return loaded
    }

    // MARK: - Public

    /// Fire-and-forget: records an AI generation (enhance call) into Langfuse.
    /// Returns immediately; telemetry failures are swallowed.
    func recordGeneration(
        name: String,
        provider: String,
        model: String,
        input: String,
        output: String,
        latencySeconds: TimeInterval,
        status: String,
        metadata: [String: String] = [:]
    ) {
        let cfg = config
        guard cfg.isConfigured else { return }

        var meta = metadata
        meta["provider"] = provider
        meta["app"] = "echotune"

        let body: [String: Any] = [
            "name": name,
            "model": model,
            "input": input,
            "output": output,
            "metadata": meta,
            "statusMessage": status,
            "startTime": langfuseDate(Date().addingTimeInterval(-latencySeconds)),
            "endTime": langfuseDate(Date())
        ]
        let usage: [String: Int] = [
            "input": max(1, input.count / 4),
            "output": max(1, output.count / 4),
            "total": max(1, (input.count + output.count) / 4)
        ]

        postJSON(path: "generations", body: merge(body, usage))
    }

    // MARK: - Private transport

    private func postJSON(path: String, body: [String: Any]) {
        let cfg = config
        guard let url = URL(string: "\(cfg.baseURL)/api/public/\(path)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let credentials = "\(cfg.publicKey):\(cfg.secretKey)"
        if let data = credentials.data(using: .utf8) {
            request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        // Fire-and-forget on a utility queue — never touches the main thread.
        DispatchQueue.global(qos: .utility).async {
            let task = URLSession.shared.dataTask(with: request) { _, _, error in
                if let error {
                    debugLog("🔍 Langfuse trace skipped: \(error.localizedDescription)")
                }
            }
            task.resume()
        }
    }

    // MARK: - Config loading

    private func loadConfig() -> LangfuseConfig {
        var cfg = LangfuseConfig(baseURL: "http://localhost:3000", publicKey: "", secretKey: "")
        guard let content = try? String(contentsOf: configPath, encoding: .utf8) else {
            return cfg
        }
        for line in content.split(separator: "\n") {
            let entry = line.trimmingCharacters(in: .whitespaces)
            guard entry.contains("=") else { continue }
            let parts = entry.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "LANGFUSE_PUBLIC_KEY": cfg.publicKey = parts[1]
            case "LANGFUSE_SECRET_KEY": cfg.secretKey = parts[1]
            case "LANGFUSE_BASE_URL": cfg.baseURL = parts[1]
            default: break
            }
        }
        return cfg
    }

    private func langfuseDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func merge(_ a: [String: Any], _ b: [String: Any]) -> [String: Any] {
        var m = a
        for (k, v) in b { m[k] = v }
        return m
    }
}