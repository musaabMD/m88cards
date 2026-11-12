import Foundation
import Observation

/// Loads decks (bundled + imported), keeps per-card progress and session history on disk.
@Observable
final class Store {
    private(set) var subjects: [Subject] = []
    var states: [String: CardState] = [:]
    var sessions: [SessionRecord] = []
    var importError: String?

    private let fm = FileManager.default
    private var progressURL: URL {
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("progress.json")
    }
    private var importedDecksDir: URL {
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Decks")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init() {
        loadProgress()
        loadDecks()
    }

    // MARK: Decks

    func loadDecks() {
        var found: [Subject] = []
        let bundled = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Decks") ?? []
        let imported = (try? fm.contentsOfDirectory(at: importedDecksDir, includingPropertiesForKeys: nil)) ?? []
        for url in bundled + imported where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url) {
                found.append(contentsOf: Store.decode(data))
            }
        }
        // Imported decks with the same id replace bundled ones.
        var byID: [String: Subject] = [:]
        var order: [String] = []
        for s in found { if byID[s.id] == nil { order.append(s.id) }; byID[s.id] = s }
        subjects = order.compactMap { byID[$0] }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func decode(_ data: Data) -> [Subject] {
        let dec = JSONDecoder()
        if let one = try? dec.decode(Subject.self, from: data) { return [one] }
        if let many = try? dec.decode([Subject].self, from: data) { return many }
        return []
    }

    /// Import a JSON (Subject or [Subject]) or CSV/TSV file: question, answer, [topic], [subject].
    func importDeck(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { importError = "Could not read \(url.lastPathComponent)"; return }
        var subjectsToSave: [Subject]
        if url.pathExtension.lowercased() == "json" {
            subjectsToSave = Store.decode(data)
            if subjectsToSave.isEmpty { importError = "JSON is not a subject: needs id, name, topics[{id,name,cards[{id,q,a}]}]"; return }
        } else {
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else { importError = "File is not UTF-8 text"; return }
            subjectsToSave = Store.parseTable(text, fallbackName: url.deletingPathExtension().lastPathComponent)
            if subjectsToSave.isEmpty { importError = "No rows found. Use columns: question, answer, topic (optional), subject (optional)"; return }
        }
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        for s in subjectsToSave {
            if let out = try? enc.encode(s) {
                try? out.write(to: importedDecksDir.appendingPathComponent("\(s.id).json"))
            }
        }
        loadDecks()
    }

    static func parseTable(_ text: String, fallbackName: String) -> [Subject] {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return [] }
        let sep: Character = lines[0].contains("\t") ? "\t" : ","
        func split(_ line: String) -> [String] {
            var out: [String] = [], cur = "", inQ = false
            for ch in line {
                if ch == "\"" { inQ.toggle() }
                else if ch == sep && !inQ { out.append(cur); cur = "" }
                else { cur.append(ch) }
            }
            out.append(cur)
            return out.map { $0.trimmingCharacters(in: .whitespaces) }
        }
        var rows = lines.map(split)
        var qi = 0, ai = 1, ti: Int? = nil, si: Int? = nil
        let head = rows[0].map { $0.lowercased() }
        if head.contains(where: { $0.hasPrefix("q") || $0 == "front" }) {
            qi = head.firstIndex { $0.hasPrefix("q") || $0 == "front" } ?? 0
            ai = head.firstIndex { $0.hasPrefix("a") || $0 == "back" } ?? 1
            ti = head.firstIndex { $0.hasPrefix("topic") || $0.hasPrefix("sub") }
            si = head.firstIndex { $0 == "subject" }
            rows.removeFirst()
        }
        func slug(_ s: String) -> String {
            s.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined().trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
        var subjects: [String: Subject] = [:], order: [String] = []
        for (n, r) in rows.enumerated() where r.count > max(qi, ai) {
            let q = r[qi], a = r[ai]
            if q.isEmpty || a.isEmpty { continue }
            let sName = si.flatMap { $0 < r.count && !r[$0].isEmpty ? r[$0] : nil } ?? fallbackName
            let tName = ti.flatMap { $0 < r.count && !r[$0].isEmpty ? r[$0] : nil } ?? "General"
            let sid = slug(sName), tid = sid + "/" + slug(tName)
            if subjects[sid] == nil { subjects[sid] = Subject(id: sid, name: sName, blurb: nil, color: nil, topics: []); order.append(sid) }
            var subj = subjects[sid]!
            if let k = subj.topics.firstIndex(where: { $0.id == tid }) {
                subj.topics[k].cards.append(Card(id: "\(tid)/\(n)", q: q, a: a, note: nil))
            } else {
                subj.topics.append(Topic(id: tid, name: tName, desc: nil, cards: [Card(id: "\(tid)/\(n)", q: q, a: a, note: nil)]))
            }
            subjects[sid] = subj
        }
        return order.compactMap { subjects[$0] }
    }

    // MARK: Progress

    private struct Progress: Codable { var states: [String: CardState]; var sessions: [SessionRecord] }

    private func loadProgress() {
        guard let data = try? Data(contentsOf: progressURL),
              let p = try? JSONDecoder().decode(Progress.self, from: data) else { return }
        states = p.states
        sessions = p.sessions
    }

    func save() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(Progress(states: states, sessions: sessions)) {
            try? data.write(to: progressURL, options: .atomic)
        }
    }

    func state(for card: Card) -> CardState { states[card.id] ?? CardState() }

    func rate(_ card: Card, _ rating: Rating) {
        states[card.id] = Scheduler.apply(rating, to: state(for: card))
    }

    func resetProgress(for cards: [Card]) {
        for c in cards { states[c.id] = nil }
        save()
    }

    // MARK: Queries used by the screens

    var allCards: [Card] { subjects.flatMap(\.allCards) }
    func dueCards(in cards: [Card]) -> [Card] { cards.filter { state(for: $0).isDue } }
    var dueCount: Int { dueCards(in: allCards).count }
    func missedCards(in cards: [Card]) -> [Card] { cards.filter { state(for: $0).status == .missed } }

    /// Accuracy across cards that have been seen: share whose last rating was not Again.
    func percent(for cards: [Card]) -> Int? {
        let seen = cards.compactMap { states[$0.id] }.filter { !$0.isNew }
        guard !seen.isEmpty else { return nil }
        let right = seen.filter { $0.last != .again }.count
        return Int((Double(right) / Double(seen.count) * 100).rounded())
    }
    func reps(for cards: [Card]) -> Int { cards.reduce(0) { $0 + state(for: $1).reps } }

    func topic(containing card: Card) -> (Subject, Topic)? {
        for s in subjects { for t in s.topics where t.cards.contains(where: { $0.id == card.id }) { return (s, t) } }
        return nil
    }

    func lastSession(scopeID: String) -> SessionRecord? {
        sessions.filter { $0.scopeID == scopeID }.sorted { $0.date > $1.date }.first
    }
    func bestPercent(scopeID: String) -> Int? {
        sessions.filter { $0.scopeID == scopeID }.map(\.percent).max()
    }
}
