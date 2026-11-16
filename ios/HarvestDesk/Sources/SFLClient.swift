import Foundation

/// Sunflower Land community API (about one call every 5 s) and the GitHub readings.
struct SFLClient {
    var key: String
    var base = URL(string: "https://api.sunflower-land.com")!

    enum Failure: LocalizedError {
        case http(Int), badKey
        var errorDescription: String? {
            switch self {
            case .badKey: return "Clé API refusée. Vérifie-la dans Réglages."
            case .http(let c): return "Sunflower Land a répondu \(c). Réessaie dans un instant."
            }
        }
    }

    private func get(_ path: String) async throws -> Data {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.timeoutInterval = 30
        for attempt in 0..<3 {
            let (data, res) = try await URLSession.shared.data(for: req)
            let code = (res as? HTTPURLResponse)?.statusCode ?? 0
            if code == 429 && attempt < 2 { try await Task.sleep(for: .seconds(10)); continue }
            if code == 401 || code == 403 { throw Failure.badKey }
            guard (200..<300).contains(code) else { throw Failure.http(code) }
            return data
        }
        throw Failure.http(429)
    }

    /// The farm as JSON text ({ farm, id, … }).
    func farm(_ id: String) async throws -> String {
        String(decoding: try await get("community/farms/\(id)"), as: UTF8.self)
    }

    func marketplace() async throws -> String {
        var c = URLComponents(url: base.appendingPathComponent("community/data"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "type", value: "marketplaceActivity")]
        var req = URLRequest(url: c.url!)
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        let (data, res) = try await URLSession.shared.data(for: req)
        let code = (res as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw Failure.http(code) }
        return String(decoding: data, as: UTF8.self)
    }

    /// A file of the procs-data branch (reads.jsonl, snapshots.json). nil when missing.
    static func readings(_ base: String, file: String) async -> String? {
        guard let url = URL(string: "\(base)/\(file)?t=\(Int(Date().timeIntervalSince1970))") else { return nil }
        guard let (data, res) = try? await URLSession.shared.data(from: url),
              (res as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
