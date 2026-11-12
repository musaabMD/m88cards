import Foundation
import SwiftUI

// MARK: - Deck content (what a deck JSON file holds)

struct Subject: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var blurb: String?
    var color: String?          // hex, e.g. "#2563EB"
    var topics: [Topic]

    var tint: Color { Color(hex: color) ?? .blue }
    var cardCount: Int { topics.reduce(0) { $0 + $1.cards.count } }
    var allCards: [Card] { topics.flatMap(\.cards) }
}

struct Topic: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var desc: String?
    var cards: [Card]
}

struct Card: Codable, Identifiable, Hashable {
    var id: String
    var q: String
    var a: String
    var note: String?
}

// MARK: - Progress (what the app remembers about each card)

enum Rating: Int, Codable, CaseIterable {
    case again = 0, hard = 1, good = 2, easy = 3

    var label: String {
        switch self {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }
    var tint: Color {
        switch self {
        case .again: .red
        case .hard: .orange
        case .good: .green
        case .easy: .blue
        }
    }
}

struct CardState: Codable {
    var ease: Double = 2.5
    var intervalDays: Double = 0
    var due: Date? = nil
    var reps: Int = 0
    var lapses: Int = 0
    var last: Rating? = nil
    var lastReviewed: Date? = nil

    var isNew: Bool { reps == 0 }
    var isDue: Bool { due.map { $0 <= Date() } ?? false }

    enum Status { case new, learned, hard, missed, learning }
    var status: Status {
        guard let last else { return .new }
        switch last {
        case .again: return .missed
        case .hard: return .hard
        case .good, .easy: return intervalDays >= 1 ? .learned : .learning
        }
    }
}

struct SessionRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var scopeID: String          // subject id, topic id, "due" or "missed"
    var scopeName: String
    var date: Date
    var seconds: Int
    var total: Int
    var right: Int               // first answer was Hard/Good/Easy
    var again: Int               // first answer was Again
    var perTopic: [String: [Int]] // topic id -> [right, total]

    var percent: Int { total == 0 ? 0 : Int((Double(right) / Double(total) * 100).rounded()) }
}

// MARK: - Spaced repetition (SM-2 style)

enum Scheduler {
    /// Returns the new state and a short preview like "1 min" or "4 days".
    static func apply(_ rating: Rating, to state: CardState, now: Date = Date()) -> CardState {
        var s = state
        let minute = 60.0, day = 86_400.0
        switch rating {
        case .again:
            s.ease = max(1.3, s.ease - 0.2)
            s.intervalDays = 0
            s.due = now.addingTimeInterval(minute)
            s.lapses += s.reps > 0 ? 1 : 0
        case .hard:
            s.ease = max(1.3, s.ease - 0.15)
            if s.intervalDays < 1 {
                s.intervalDays = 0
                s.due = now.addingTimeInterval(10 * minute)
            } else {
                s.intervalDays = max(1, s.intervalDays * 1.2)
                s.due = now.addingTimeInterval(s.intervalDays * day)
            }
        case .good:
            s.intervalDays = s.intervalDays < 1 ? 1 : (s.intervalDays * s.ease).rounded()
            s.due = now.addingTimeInterval(s.intervalDays * day)
        case .easy:
            s.ease += 0.15
            s.intervalDays = s.intervalDays < 1 ? 4 : (s.intervalDays * s.ease * 1.3).rounded()
            s.due = now.addingTimeInterval(s.intervalDays * day)
        }
        s.reps += 1
        s.last = rating
        s.lastReviewed = now
        return s
    }

    static func preview(_ rating: Rating, for state: CardState) -> String {
        let next = apply(rating, to: state)
        guard let due = next.due else { return "" }
        let secs = due.timeIntervalSinceNow
        if secs < 3600 { return "\(max(1, Int((secs / 60).rounded()))) min" }
        let days = Int((secs / 86_400).rounded())
        if days < 1 { return "today" }
        if days == 1 { return "1 day" }
        if days < 30 { return "\(days) days" }
        let months = Int((Double(days) / 30).rounded())
        return months == 1 ? "1 month" : "\(months) months"
    }
}

// MARK: - Helpers

extension Color {
    init?(hex: String?) {
        guard var h = hex?.trimmingCharacters(in: .whitespaces) else { return nil }
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
