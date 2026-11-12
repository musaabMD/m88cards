import SwiftUI

struct TopicView: View {
    @Environment(Store.self) private var store
    let topic: Topic
    @State private var filter: Filter = .all
    @State private var quiz: QuizScope?

    enum Filter: String, CaseIterable { case all = "All", due = "Due", hard = "Hard", missed = "Missed", new = "New" }

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
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                HStack(spacing: 8) {
                    ForEach(Filter.allCases, id: \.self) { f in
                        Button(f.rawValue) { filter = f }
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(filter == f ? Color.primary : Color(.secondarySystemBackground), in: Capsule())
                            .foregroundStyle(filter == f ? Color(.systemBackground) : .primary)
                    }
                }
                HStack {
                    Text("QUESTION").frame(maxWidth: .infinity, alignment: .leading)
                    Text("ANSWER").frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 14)

                ForEach(cards) { card in cardRow(card) }
                if cards.isEmpty {
                    Text("No cards match this filter.").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 40)
                }
                legend
                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottomTrailing) {
            Button {
                let set = cards.isEmpty ? topic.cards : cards
                quiz = QuizScope(id: topic.id, name: topic.name, cards: set)
            } label: {
                Label("Quiz me", systemImage: "play.fill")
                    .font(.headline)
                    .padding(.horizontal, 22).frame(height: 56)
                    .foregroundStyle(.white)
                    .background(Color.accentColor, in: Capsule())
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 10, y: 6)
            }
            .padding(.trailing, 20).padding(.bottom, 20)
        }
        .toolbar {
            Menu {
                Button("Reset progress for this topic", role: .destructive) { store.resetProgress(for: topic.cards) }
            } label: { Image(systemName: "ellipsis.circle") }
        }
        .fullScreenCover(item: $quiz) { scope in QuizView(session: QuizSession(scope: scope)) }
    }

    private var header: some View {
        let learned = topic.cards.filter { store.state(for: $0).status == .learned }.count
        let due = store.dueCards(in: topic.cards).count
        var parts = ["\(topic.cards.count) cards", "\(learned) learned"]
        if due > 0 { parts.append("\(due) due") }
        if let best = store.bestPercent(scopeID: topic.id) { parts.append("best \(best)%") }
        return VStack(alignment: .leading, spacing: 4) {
            if let d = topic.desc { Text(d).font(.subheadline).foregroundStyle(.secondary) }
            Text(parts.joined(separator: " · ")).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func cardRow(_ card: Card) -> some View {
        let status = store.state(for: card).status
        return HStack(alignment: .top, spacing: 10) {
            Text(card.q).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
            Text(card.a).font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10).overlay(alignment: .leading) { Rectangle().fill(Color(.separator)).frame(width: 1) }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14).fill(Self.color(status)).frame(width: 4)
        }
    }

    static func color(_ s: CardState.Status) -> Color {
        switch s {
        case .learned: .green
        case .hard: .orange
        case .missed: .red
        case .learning: .blue
        case .new: Color(.systemGray4)
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach([("learned", CardState.Status.learned), ("learning", .learning), ("hard", .hard), ("missed", .missed), ("new", .new)], id: \.0) { name, s in
                HStack(spacing: 5) { RoundedRectangle(cornerRadius: 2).fill(Self.color(s)).frame(width: 8, height: 8); Text(name) }
            }
        }
        .font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 14)
    }
}
