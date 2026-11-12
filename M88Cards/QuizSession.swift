import Foundation

/// What to quiz: a subject, a topic, everything due, or a retry of missed cards.
struct QuizScope: Identifiable, Hashable {
    var id: String
    var name: String
    var cards: [Card]
}

/// One run through a scope. Again cards come back later in the same session until answered Good or Easy.
@Observable
final class QuizSession {
    let scope: QuizScope
    private(set) var queue: [Card]
    private(set) var current: Card?
    var revealed = false
    private(set) var index = 0           // how many distinct cards have been answered at least once
    private(set) var firstRating: [String: Rating] = [:]
    let started = Date()
    private(set) var finished = false

    init(scope: QuizScope) {
        self.scope = scope
        self.queue = scope.cards.shuffled()
        self.current = queue.first
        if !queue.isEmpty { queue.removeFirst() }
    }

    var total: Int { scope.cards.count }
    var rightSoFar: Int { firstRating.values.filter { $0 != .again }.count }
    var againSoFar: Int { firstRating.values.filter { $0 == .again }.count }
    var progress: Double { total == 0 ? 1 : Double(firstRating.count) / Double(total) }

    func answer(_ rating: Rating, store: Store) {
        guard let card = current else { return }
        if firstRating[card.id] == nil { firstRating[card.id] = rating; index += 1 }
        store.rate(card, rating)
        if rating == .again || (rating == .hard && store.state(for: card).intervalDays < 1 && firstRating[card.id] == .again) {
            // put it back a few cards later
            let at = min(queue.count, 3)
            queue.insert(card, at: at)
        }
        revealed = false
        if queue.isEmpty { current = nil; finish(store: store) } else { current = queue.removeFirst() }
    }

    func finish(store: Store) {
        guard !finished else { return }
        finished = true
        var perTopic: [String: [Int]] = [:]
        for card in scope.cards {
            guard let r = firstRating[card.id], let (_, t) = store.topic(containing: card) else { continue }
            var v = perTopic[t.id] ?? [0, 0]
            v[1] += 1; if r != .again { v[0] += 1 }
            perTopic[t.id] = v
        }
        let rec = SessionRecord(scopeID: scope.id, scopeName: scope.name, date: Date(),
                                seconds: Int(Date().timeIntervalSince(started)),
                                total: firstRating.count, right: rightSoFar, again: againSoFar, perTopic: perTopic)
        if rec.total > 0 { store.sessions.append(rec) }
        store.save()
    }

    var missed: [Card] { scope.cards.filter { firstRating[$0.id] == .again } }
}
