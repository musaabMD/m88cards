import SwiftUI

struct TopicView: View {
    @Environment(Store.self) private var store
    let topic: Topic
    @State private var filter: Filter = .all
    @State private var quiz: QuizScope?

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", due = "Due", missed = "Again", hard = "Hard", new = "New"
        var id: String { rawValue }
    }

    private var cards: [Card] {
        topic.cards.filter { c in
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
                    if let d = topic.desc {
                        Text(d).font(.subheadline).foregroundStyle(.secondary).textCase(nil)
                    }
                    Text(summary).font(.footnote).foregroundStyle(.secondary).textCase(nil)
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
            Color.clear.frame(height: 60).listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            Button {
                let set = cards.isEmpty ? topic.cards : cards
                quiz = QuizScope(id: topic.id, name: topic.name, cards: set)
            } label: {
                Label("Quiz me", systemImage: "play.fill").font(.headline).padding(.horizontal, 6).padding(.vertical, 8)
            }
            .prominentGlassButton()
            .controlSize(.large)
            .padding(.trailing, 20).padding(.bottom, 16)
        }
        .toolbar {
            Menu {
                Button("Reset progress for this topic", role: .destructive) { store.resetProgress(for: topic.cards) }
            } label: { Image(systemName: "ellipsis") }
        }
        .fullScreenCover(item: $quiz) { scope in QuizView(session: QuizSession(scope: scope)) }
    }

    private var summary: String {
        let learned = topic.cards.filter { store.state(for: $0).status == .learned }.count
        let due = store.dueCards(in: topic.cards).count
        var parts = ["\(topic.cards.count) cards", "\(learned) learned"]
        if due > 0 { parts.append("\(due) due") }
        if let best = store.bestPercent(scopeID: topic.id) { parts.append("best \(best)%") }
        return parts.joined(separator: " · ")
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
