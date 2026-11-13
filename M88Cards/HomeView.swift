import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(Store.self) private var store
    @State private var expanded: Set<String> = []
    @State private var search = ""
    @State private var quiz: QuizScope?
    @State private var showImporter = false
    @State private var showStats = false
    @State private var showSync = false

    private var filtered: [Subject] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return store.subjects }
        return store.subjects.compactMap { s in
            if s.name.lowercased().contains(q) { return s }
            let topics = s.topics.compactMap { t -> Topic? in
                if t.name.lowercased().contains(q) { return t }
                let cards = t.cards.filter { $0.q.lowercased().contains(q) || $0.a.lowercased().contains(q) }
                return cards.isEmpty ? nil : Topic(id: t.id, name: t.name, desc: t.desc, cards: cards)
            }
            return topics.isEmpty ? nil : Subject(id: s.id, name: s.name, blurb: s.blurb, color: s.color, topics: topics)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.subjects.isEmpty {
                    ContentUnavailableView("No decks yet", systemImage: "rectangle.on.rectangle.angled",
                                           description: Text("Import a JSON, CSV or TSV file from the + button."))
                }
                ForEach(filtered) { subject in
                    Section {
                        subjectRow(subject)
                        if expanded.contains(subject.id) || !search.isEmpty {
                            ForEach(subject.topics) { topic in
                                NavigationLink(value: topic) { topicRow(topic) }
                            }
                        }
                    }
                }
            }
            .listSectionSpacing(10)
            .navigationTitle("Cards")
            .navigationDestination(for: Topic.self) { topic in TopicView(topic: topic) }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search \(store.allCards.count) cards")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { ReviewView() } label: { Image(systemName: "tray.full") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showSync = true } label: { Label("Sync content from GitHub", systemImage: "arrow.down.circle") }
                        Button { showImporter = true } label: { Label("Import file…", systemImage: "square.and.arrow.down") }
                        Button { showStats = true } label: { Label("Stats", systemImage: "chart.bar") }
                    } label: { Image(systemName: "ellipsis") }
                }
            }
            .safeAreaInset(edge: .bottom) { dueBar }
            .fullScreenCover(item: $quiz) { scope in QuizView(session: QuizSession(scope: scope)) }
            .alert("Import failed", isPresented: Binding(get: { store.importError != nil }, set: { if !$0 { store.importError = nil } })) {
                Button("OK") {}
            } message: { Text(store.importError ?? "") }
            .sheet(isPresented: $showStats) { StatsView() }
            .sheet(isPresented: $showSync) { SyncView() }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .commaSeparatedText, .tabSeparatedText, .plainText], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result { urls.forEach(store.importDeck(from:)) }
            }
        }
    }

    // MARK: Rows

    private func subjectRow(_ subject: Subject) -> some View {
        let due = store.dueCards(in: subject.allCards).count
        let open = expanded.contains(subject.id)
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(subject.tint).frame(width: 6, height: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(subject.name).font(.headline)
                HStack(spacing: 4) {
                    Text("\(subject.topics.count) subtopics · \(subject.cardCount) cards" + (due > 0 ? " · \(due) due" : ""))
                    Image(systemName: open ? "chevron.down" : "chevron.right").font(.caption2.bold())
                }
                .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button {
                quiz = QuizScope(id: subject.id, name: subject.name, cards: subject.allCards)
            } label: {
                Image(systemName: "play.fill").font(.caption).foregroundStyle(.white)
                    .frame(width: 32, height: 32).background(subject.tint, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quiz \(subject.name)")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy) { if open { expanded.remove(subject.id) } else { expanded.insert(subject.id) } }
        }
    }

    private func topicRow(_ topic: Topic) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(topic.name).font(.subheadline.weight(.medium))
                Text("\(topic.cards.count) cards").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let pct = store.percent(for: topic.cards) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(pct)%").font(.callout.weight(.semibold)).foregroundStyle(pct >= 80 ? .green : pct >= 50 ? .blue : .orange)
                    Text("\(store.reps(for: topic.cards)) reps").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("new").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 18)
    }

    @ViewBuilder private var dueBar: some View {
        let due = store.dueCards(in: store.allCards)
        if !due.isEmpty {
            Button { quiz = QuizScope(id: "due", name: "Due today", cards: due) } label: {
                Label("Review \(due.count) due cards", systemImage: "play.fill").font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 16).padding(.vertical, 6)
        }
    }
}

struct StatsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Overall") {
                    let seen = store.states.values.filter { !$0.isNew }.count
                    LabeledContent("Cards seen", value: "\(seen) of \(store.allCards.count)")
                    LabeledContent("Learned", value: "\(store.states.values.filter { $0.status == .learned }.count)")
                    LabeledContent("Due now", value: "\(store.dueCount)")
                    LabeledContent("Sessions", value: "\(store.sessions.count)")
                }
                Section("Recent sessions") {
                    ForEach(store.sessions.sorted { $0.date > $1.date }.prefix(30)) { s in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.scopeName).font(.subheadline)
                                Text(s.date, format: .dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(s.percent)%").font(.headline).foregroundStyle(s.percent >= 80 ? .green : .orange)
                            Text("\(s.right)/\(s.total)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Stats")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
