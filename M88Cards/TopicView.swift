import SwiftUI

struct TopicView: View {
    @Environment(Store.self) private var store
    let topic: Topic
    @State private var filter: Filter = .all
    @State private var quiz: QuizScope?
    @State private var search = ""

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", due = "Due", missed = "Again", hard = "Hard", new = "New"
        var id: String { rawValue }
    }

    private var cards: [Card] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return topic.cards.filter { c in
            if !q.isEmpty && !(c.q.lowercased().contains(q) || c.a.lowercased().contains(q)) { return false }
            let s = store.state(for: c)
            switch filter {
            case .all: return true
            case .due: return s.isDue
            case .hard: return s.status == .hard
            case .missed: return s.status == .missed
            case .new: return s.isNew
            }
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(cards) { card in CardRow(card: card, status: store.state(for: card).status) }
            } header: {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text("Question").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Answer").frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.caption2.weight(.semibold)).foregroundStyle(.tertiary).textCase(.uppercase)
                    .padding(.leading, 16).padding(.top, 4)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
            }
            if cards.isEmpty {
                Text("No cards here yet.").foregroundStyle(.secondary).frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search this topic")
        .safeAreaInset(edge: .bottom) {
            Button {
                let set = cards.isEmpty ? topic.cards : cards
                quiz = QuizScope(id: topic.id, name: topic.name, cards: set)
            } label: {
                Label("Quiz me", systemImage: "play.fill").font(.headline).frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 16).padding(.vertical, 6)
        }
        .toolbar {
            Menu {
                Button("Reset progress for this topic", role: .destructive) { store.resetProgress(for: topic.cards) }
            } label: { Image(systemName: "ellipsis") }
        }
        .fullScreenCover(item: $quiz) { scope in QuizView(session: QuizSession(scope: scope)) }
    }
}

/// Two-column question | answer row with a small status dot.
struct CardRow: View {
    let card: Card
    let status: CardState.Status
    var caption: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(status.color).frame(width: 7, height: 7).padding(.top, 7)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    Text(card.q).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
                    Text(card.a).font(.subheadline).foregroundStyle(.secondary).lineLimit(6).frame(maxWidth: .infinity, alignment: .leading)
                }
                if let caption { Text(caption).font(.caption2).foregroundStyle(.tertiary) }
            }
        }
        .padding(.vertical, 4)
    }
}
