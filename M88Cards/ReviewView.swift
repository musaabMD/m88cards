import SwiftUI

/// Every card you have answered, grouped by how it last went, with search.
struct ReviewView: View {
    @Environment(Store.self) private var store
    @State private var bucket: Bucket = .missed
    @State private var search = ""
    @State private var quiz: QuizScope?

    enum Bucket: String, CaseIterable, Identifiable {
        case missed = "Again", hard = "Hard", good = "Good", easy = "Easy"
        var id: String { rawValue }
        var rating: Rating {
            switch self { case .missed: .again; case .hard: .hard; case .good: .good; case .easy: .easy }
        }
    }

    private struct Row: Identifiable { let card: Card; let subject: Subject; let topic: Topic; var id: String { card.id } }

    private var rows: [Row] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        var out: [Row] = []
        for s in store.subjects { for t in s.topics { for c in t.cards {
            guard store.state(for: c).last == bucket.rating else { continue }
            if !q.isEmpty && !(c.q.lowercased().contains(q) || c.a.lowercased().contains(q) || t.name.lowercased().contains(q)) { continue }
            out.append(Row(card: c, subject: s, topic: t))
        } } }
        return out
    }

    private func count(_ b: Bucket) -> Int { store.states.values.filter { $0.last == b.rating }.count }

    var body: some View {
        List {
            Section {
                ForEach(rows) { r in
                    CardRow(card: r.card, status: store.state(for: r.card).status, caption: "\(r.subject.name) · \(r.topic.name)")
                }
            } header: {
                Picker("Rating", selection: $bucket) {
                    ForEach(Bucket.allCases) { Text("\($0.rawValue) \(count($0))").tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .padding(.bottom, 6)
            }
            if rows.isEmpty {
                ContentUnavailableView(search.isEmpty ? "No \(bucket.rawValue.lowercased()) cards yet" : "No matches", systemImage: "tray")
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search question or answer")
        .safeAreaInset(edge: .bottom) {
            if !rows.isEmpty {
                Button {
                    quiz = QuizScope(id: "review-\(bucket.rawValue)", name: "\(bucket.rawValue) cards", cards: rows.map(\.card))
                } label: {
                    Label("Quiz \(rows.count) cards", systemImage: "play.fill").font(.headline).frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 16).padding(.vertical, 6)
            }
        }
        .fullScreenCover(item: $quiz) { scope in QuizView(session: QuizSession(scope: scope)) }
    }
}
