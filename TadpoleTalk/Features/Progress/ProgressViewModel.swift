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
        /// The front/back movement the word practises, if it's still in the target bank.
        var movement: MovementPattern?
        /// Prompting on the most recent attempt that recorded it.
        var latestPrompt: PromptLevel?
        /// The least prompting any successful attempt has needed — the best so far.
        var leastPromptForSuccess: PromptLevel?
        var rate: Double { total == 0 ? 0 : Double(successes) / Double(total) }
    }

    /// Totals for every word practising one front/back movement.
    struct MovementProgress: Identifiable {
        var id: MovementPattern { movement }
        let movement: MovementPattern
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
        let current = Dictionary(child.targets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var map: [String: TargetProgress] = [:]
        let trials = child.sessions.flatMap(\.trials).sorted { $0.timestamp < $1.timestamp }
        for trial in trials {
            let key = trial.targetID?.uuidString ?? "text:\(trial.targetText)"
            let target = trial.targetID.flatMap { current[$0] }
            let prev = map[key] ?? TargetProgress(id: key, word: target?.text ?? trial.targetText,
                                                  successes: 0, total: 0, movement: target?.movement)
            var next = TargetProgress(id: key, word: prev.word,
                                      successes: prev.successes + (trial.rating.isSuccess ? 1 : 0),
                                      total: prev.total + 1, movement: prev.movement,
                                      latestPrompt: trial.prompt ?? prev.latestPrompt,
                                      leastPromptForSuccess: prev.leastPromptForSuccess)
            if trial.rating.isSuccess, let prompt = trial.prompt,
               prompt.order > (prev.leastPromptForSuccess?.order ?? -1) {
                next.leastPromptForSuccess = prompt
            }
            map[key] = next
        }
        return map.values.sorted { ($0.total, $1.word) > ($1.total, $0.word) }
    }

    /// Totals per front/back movement, across the words currently tagged with one.
    func perMovement(_ child: Child) -> [MovementProgress] {
        let words = perTarget(child)
        return MovementPattern.allCases.compactMap { movement in
            let matching = words.filter { $0.movement == movement }
            guard !matching.isEmpty else { return nil }
            return MovementProgress(movement: movement,
                                    successes: matching.reduce(0) { $0 + $1.successes },
                                    total: matching.reduce(0) { $0 + $1.total })
        }
    }

    func totalSessions(_ child: Child) -> Int { child.sessions.filter { $0.totalCount > 0 }.count }
    func totalSuccesses(_ child: Child) -> Int { child.sessions.reduce(0) { $0 + $1.successCount } }
    func totalTrials(_ child: Child) -> Int { child.sessions.reduce(0) { $0 + $1.totalCount } }

    /// A word counts as "coming along well" once it has a solid run of successful reps.
    func masteredCount(_ child: Child, threshold: Int = 8) -> Int {
        perTarget(child).filter { $0.successes >= threshold && $0.rate >= 0.8 }.count
    }
}
