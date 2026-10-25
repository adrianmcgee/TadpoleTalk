import SwiftUI
import SwiftData

/// Aggregates practice history into the small number of figures a parent (and their SLP)
/// actually want: how often we practised, how it's trending, and which words are coming
/// along. All derived, all testable, no storage of its own.
@Observable
final class ProgressViewModel {

    struct DayBar: Identifiable {
        var id: Date { date }
        let date: Date
        let successes: Int
        let total: Int
    }

    struct TargetProgress: Identifiable {
        let id: String
        let word: String
        let successes: Int
        let total: Int
        var rate: Double { total == 0 ? 0 : Double(successes) / Double(total) }
    }

    /// Practice counts per day for the last `days` days, oldest first (zero-filled).
    func dailyBars(_ child: Child, days: Int = 14,
                   now: Date = Date(), calendar: Calendar = .current) -> [DayBar] {
        let today = calendar.startOfDay(for: now)
        var totals: [Date: (s: Int, t: Int)] = [:]
        for session in child.sessions {
            let day = calendar.startOfDay(for: session.startedAt)
            let prev = totals[day] ?? (0, 0)
            totals[day] = (prev.s + session.successCount, prev.t + session.totalCount)
        }
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let v = totals[day] ?? (0, 0)
            return DayBar(date: day, successes: v.s, total: v.t)
        }
    }

    /// Per-word totals across every session, best-practised first. Grouped by the target's
    /// id so a renamed word keeps its history and shows its current name; trials with no id
    /// (or whose word was deleted) fall back to the text that was logged.
    func perTarget(_ child: Child) -> [TargetProgress] {
        let currentNames = Dictionary(child.targets.map { ($0.id, $0.text) }, uniquingKeysWith: { first, _ in first })
        var map: [String: (word: String, s: Int, t: Int)] = [:]
        for session in child.sessions {
            for trial in session.trials {
                let key = trial.targetID?.uuidString ?? "text:\(trial.targetText)"
                let word = trial.targetID.flatMap { currentNames[$0] } ?? trial.targetText
                let prev = map[key] ?? (word, 0, 0)
                map[key] = (word, prev.s + (trial.rating.isSuccess ? 1 : 0), prev.t + 1)
            }
        }
        return map
            .map { TargetProgress(id: $0.key, word: $0.value.word, successes: $0.value.s, total: $0.value.t) }
            .sorted { ($0.total, $1.word) > ($1.total, $0.word) }
    }

    func totalSessions(_ child: Child) -> Int { child.sessions.filter { $0.totalCount > 0 }.count }
    func totalSuccesses(_ child: Child) -> Int { child.sessions.reduce(0) { $0 + $1.successCount } }
    func totalTrials(_ child: Child) -> Int { child.sessions.reduce(0) { $0 + $1.totalCount } }

    /// A word counts as "coming along well" once it has a solid run of successful reps.
    func masteredCount(_ child: Child, threshold: Int = 8) -> Int {
        perTarget(child).filter { $0.successes >= threshold && $0.rate >= 0.8 }.count
    }
}
