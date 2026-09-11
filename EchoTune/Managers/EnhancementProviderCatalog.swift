import Foundation

/// Small, local cache for provider model metadata. The app never needs this
/// request to start: bundled IDs are always the fallback and remain available
/// when a provider key is absent or the network is offline.
actor EnhancementProviderCatalog {
    static let shared = EnhancementProviderCatalog()

    struct Snapshot: Codable, Sendable {
        let fetchedAt: Date
        let modelIDs: [String]
        let groqETag: String?
        let googleETag: String?
    }

    private let storageKey = "enhancementProviderCatalog"
    private let maxAge: TimeInterval = 24 * 60 * 60
    private let bundledIDs = Set([
        "llama-3.3-70b-versatile",
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite"
    ])

    func modelIDs(groqAPIKey: String, geminiAPIKey: String) async -> Set<String> {
        let cached = loadSnapshot()
        if let cached, Date().timeIntervalSince(cached.fetchedAt) < maxAge {
            return Set(cached.modelIDs).union(bundledIDs)
        }

        var ids = bundledIDs
        var groqETag = cached?.groqETag
        var googleETag = cached?.googleETag
        var didRefresh = false

        if !groqAPIKey.isEmpty, let result = await fetchGroqModels(apiKey: groqAPIKey, etag: groqETag), !result.ids.isEmpty {
            ids.subtract(ids.filter { $0.hasPrefix("llama-") })
            ids.formUnion(result.ids)
            groqETag = result.etag ?? groqETag
            didRefresh = true
        }
        if !geminiAPIKey.isEmpty, let result = await fetchGoogleModels(apiKey: geminiAPIKey, etag: googleETag), !result.ids.isEmpty {
            ids.subtract(ids.filter { $0.hasPrefix("gemini-") })
            ids.formUnion(result.ids)
            googleETag = result.etag ?? googleETag
            didRefresh = true
        }

        if didRefresh {
            saveSnapshot(Snapshot(fetchedAt: Date(), modelIDs: ids.sorted(), groqETag: groqETag, googleETag: googleETag))
        } else if let cached {
            ids.formUnion(cached.modelIDs)
        }
        return ids
    }

    private struct FetchResult {
        let ids: Set<String>
        let etag: String?
    }

    private func fetchGroqModels(apiKey: String, etag: String?) async -> FetchResult? {
        guard let url = URL(string: "https://api.groq.com/openai/v1/models") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        return await fetch(request: request) { json in
            guard let rows = json["data"] as? [[String: Any]] else { return [] }
            return Set(rows.compactMap { $0["id"] as? String }.filter { $0 == "llama-3.3-70b-versatile" })
        }
    }

    private func fetchGoogleModels(apiKey: String, etag: String?) async -> FetchResult? {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models") else { return nil }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        return await fetch(request: request) { json in
            guard let rows = json["models"] as? [[String: Any]] else { return [] }
            return Set(rows.compactMap { row in
                guard let name = row["name"] as? String else { return nil }
                let id = name.replacingOccurrences(of: "models/", with: "")
                return ["gemini-2.5-flash", "gemini-2.5-flash-lite"].contains(id) ? id : nil
            })
        }
    }

    private func fetch(request: URLRequest, parse: ([String: Any]) -> Set<String>) async -> FetchResult? {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            let etag = http.value(forHTTPHeaderField: "ETag")
            if http.statusCode == 304 { return FetchResult(ids: [], etag: etag) }
            guard http.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return FetchResult(ids: parse(json), etag: etag)
        } catch {
            return nil
        }
    }

    private func loadSnapshot() -> Snapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    private func saveSnapshot(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
