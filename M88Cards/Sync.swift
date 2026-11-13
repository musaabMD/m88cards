import Foundation
import SwiftUI

/// Downloads every JSON deck in the `content/` folder of the GitHub repo into the app's imported-decks folder.
@Observable
final class GitHubSync {
    static let repo = "musaabMD/m88cards"
    static let folder = "content"

    var lastSynced: Date? {
        get { UserDefaults.standard.object(forKey: "lastSynced") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastSynced") }
    }
    var busy = false
    var message: String?

    private struct Entry: Decodable { let name: String; let path: String; let type: String }

    private func request(_ url: URL, raw: Bool) -> URLRequest {
        var r = URLRequest(url: url)
        r.setValue(raw ? "application/vnd.github.raw+json" : "application/vnd.github+json", forHTTPHeaderField: "Accept")
        r.cachePolicy = .reloadIgnoringLocalCacheData
        return r
    }

    @MainActor
    /// Returns the number of decks now on the phone; -1 on failure.
    func sync(into dir: URL) async -> Int {
        busy = true; message = nil
        defer { busy = false }
        do {
            let list = URL(string: "https://api.github.com/repos/\(Self.repo)/contents/\(Self.folder)")!
            let (data, resp) = try await URLSession.shared.data(for: request(list, raw: false))
            guard let http = resp as? HTTPURLResponse else { message = "No response"; return -1 }
            if http.statusCode == 404 { message = "Repo or content/ folder not found."; return -1 }
            guard http.statusCode == 200 else { message = "GitHub returned \(http.statusCode)"; return -1 }
            let entries = try JSONDecoder().decode([Entry].self, from: data).filter { $0.type == "file" && $0.name.hasSuffix(".json") }
            // Mirror the folder: anything on the phone that is no longer on GitHub goes away.
            let keep = Set(entries.map(\.name))
            for f in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] where f.pathExtension == "json" && !keep.contains(f.lastPathComponent) {
                try? FileManager.default.removeItem(at: f)
            }
            var n = 0
            for e in entries {
                let fileURL = URL(string: "https://api.github.com/repos/\(Self.repo)/contents/\(e.path)")!
                let (body, r2) = try await URLSession.shared.data(for: request(fileURL, raw: true))
                guard (r2 as? HTTPURLResponse)?.statusCode == 200, !Store.decode(body).isEmpty else { continue }
                try body.write(to: dir.appendingPathComponent(e.name), options: .atomic)
                n += 1
            }
            lastSynced = Date()
            message = n == 0 ? "No decks in \(Self.folder)/ on GitHub" : "Synced \(n) deck\(n == 1 ? "" : "s")"
            return n
        } catch {
            message = error.localizedDescription
            return -1
        }
    }
}
