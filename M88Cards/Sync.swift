import Foundation
import SwiftUI

/// Downloads every JSON deck in the `content/` folder of the GitHub repo into the app's imported-decks folder.
@Observable
final class GitHubSync {
    static let repo = "musaabMD/m88cards"
    static let folder = "content"

    var token: String {
        get { UserDefaults.standard.string(forKey: "githubToken") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "githubToken") }
    }
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
        if !token.isEmpty { r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        r.cachePolicy = .reloadIgnoringLocalCacheData
        return r
    }

    @MainActor
    func sync(into dir: URL) async -> Int {
        busy = true; message = nil
        defer { busy = false }
        do {
            let list = URL(string: "https://api.github.com/repos/\(Self.repo)/contents/\(Self.folder)")!
            let (data, resp) = try await URLSession.shared.data(for: request(list, raw: false))
            guard let http = resp as? HTTPURLResponse else { message = "No response"; return 0 }
            if http.statusCode == 404 { message = "Repo not found. It is private: add a GitHub token below, or make the repo public."; return 0 }
            if http.statusCode == 401 { message = "GitHub rejected the token."; return 0 }
            guard http.statusCode == 200 else { message = "GitHub returned \(http.statusCode)"; return 0 }
            let entries = try JSONDecoder().decode([Entry].self, from: data).filter { $0.type == "file" && $0.name.hasSuffix(".json") }
            var n = 0
            for e in entries {
                let fileURL = URL(string: "https://api.github.com/repos/\(Self.repo)/contents/\(e.path)")!
                let (body, r2) = try await URLSession.shared.data(for: request(fileURL, raw: true))
                guard (r2 as? HTTPURLResponse)?.statusCode == 200, !Store.decode(body).isEmpty else { continue }
                try body.write(to: dir.appendingPathComponent(e.name), options: .atomic)
                n += 1
            }
            lastSynced = Date()
            message = n == 0 ? "No decks found in \(Self.folder)/" : "Downloaded \(n) deck\(n == 1 ? "" : "s")"
            return n
        } catch {
            message = error.localizedDescription
            return 0
        }
    }
}

struct SyncView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var sync = GitHubSync()
    @State private var token = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        sync.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task {
                            let n = await sync.sync(into: store.importedDecksDir)
                            if n > 0 { store.loadDecks() }
                        }
                    } label: {
                        HStack {
                            Label("Download content from GitHub", systemImage: "arrow.down.circle")
                            Spacer()
                            if sync.busy { ProgressView() }
                        }
                    }
                    .disabled(sync.busy)
                    if let m = sync.message { Text(m).font(.footnote).foregroundStyle(.secondary) }
                } header: {
                    Text("\(GitHubSync.repo) · \(GitHubSync.folder)/")
                } footer: {
                    if let d = sync.lastSynced { Text("Last synced \(d.formatted(date: .abbreviated, time: .shortened))") }
                }
                Section {
                    SecureField("GitHub token (fine-grained, Contents: read)", text: $token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: { Text("Private repo") } footer: {
                    Text("Needed only while the repo is private. Create one at github.com → Settings → Developer settings → Fine-grained tokens, with read access to this repo's contents.")
                }
                Section {
                    Text("Downloaded decks are saved on this phone and replace the bundled deck with the same id. Progress is kept by card id.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Sync content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { token = sync.token }
        }
    }
}
