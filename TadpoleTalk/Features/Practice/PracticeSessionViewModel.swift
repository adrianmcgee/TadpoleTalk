import SwiftUI
import SwiftData

/// Drives one practice session: which word we're on, logging each attempt, and the
/// running tally. The motor-learning rules (rep goals per word, blocked vs. random
/// ordering, celebrate the wins) live here so the view is just presentation and so the
/// logic is unit-testable.
@Observable
final class PracticeSessionViewModel {
    let targets: [WordTarget]
    let order: PracticeOrder
    /// Successful reps to aim for on each word before it's "done" for the session.
    let repGoal: Int
    /// Whether to move on by itself once a word hits its rep goal.
    let autoAdvance: Bool

    /// Index into `targets` of the word currently shown.
    private(set) var index: Int = 0
    /// Attempts logged on the current word this visit — surfaced for a parent.
    private(set) var repsForCurrent: Int = 0
    /// Pulses true briefly after a success so the view can celebrate.
    var celebrate: Bool = false
    private(set) var finished: Bool = false
    /// Current modelling support, chosen by the caregiver and never persisted.
    private(set) var supportLevel: PracticeSupportLevel = .together
    /// Consecutive attempts that have not yet reached "Got it" on this target.
    private(set) var consecutiveDifficultAttempts: Int = 0
    /// Pauses further ratings after repeated difficulty so practice can be made easier.
    private(set) var isShowingDifficultyIntervention: Bool = false

    /// Cumulative successful reps per word this session, keyed by the target's id — drives
    /// the rep-goal progress and when a word counts as done.
    private var successReps: [UUID: Int] = [:]

    private let child: Child
    private let session: PracticeSession
    private let context: ModelContext

    init(child: Child,
         targets: [WordTarget],
         context: ModelContext,
         order: PracticeOrder = .blocked,
         repGoal: Int = 5,
         autoAdvance: Bool = false) {
        self.child = child
        self.targets = targets
        self.context = context
        self.order = order
        self.repGoal = max(1, repGoal)
        self.autoAdvance = autoAdvance
        let session = PracticeSession()
        session.child = child
        context.insert(session)
        self.session = session
        if order == .random { self.index = targets.indices.randomElement() ?? 0 }
    }

    var currentTarget: WordTarget? { targets.indices.contains(index) ? targets[index] : nil }

    // MARK: - Rep-goal progress

    /// Successful reps logged on the current word so far this session.
    var currentSuccessReps: Int {
        guard let target = currentTarget else { return 0 }
        return successReps[target.id] ?? 0
    }

    /// True once the current word has reached its rep goal.
    var isCurrentComplete: Bool { currentSuccessReps >= repGoal }

    /// True once every word in the set has reached its rep goal.
    var allComplete: Bool {
        targets.allSatisfy { (successReps[$0.id] ?? 0) >= repGoal }
    }

    /// "2 / 5 good" — the rep-goal label for the current word.
    var goalText: String { "\(min(currentSuccessReps, repGoal)) / \(repGoal) good" }

    /// 0…1 progress toward the current word's rep goal, for a ring/bar.
    var goalProgress: Double {
        repGoal == 0 ? 0 : min(1, Double(currentSuccessReps) / Double(repGoal))
    }

    /// After a completing success, whether the session should move on by itself.
    var shouldAutoAdvance: Bool { autoAdvance && isCurrentComplete && !allComplete }

    // MARK: - Navigation state

    var isLastTarget: Bool { index >= targets.count - 1 }

    /// Show "Finish" instead of "Next word" when there's nowhere sensible left to go.
    var showFinish: Bool {
        switch order {
        case .blocked: return isLastTarget || allComplete
        case .random:  return allComplete
        }
    }

    var progressText: String {
        switch order {
        case .blocked:
            return "Word \(min(index + 1, targets.count)) of \(targets.count)"
        case .random:
            let done = targets.filter { (successReps[$0.id] ?? 0) >= repGoal }.count
            return "\(done) of \(targets.count) words done"
        }
    }

    var successCount: Int { session.successCount }
    var totalCount: Int { session.totalCount }

    /// Whether moving on can select a different target rather than ending the session.
    var canMoveToAnotherTarget: Bool {
        switch order {
        case .blocked:
            return index < targets.count - 1
        case .random:
            return targets.indices.contains {
                $0 != index && (successReps[targets[$0].id] ?? 0) < repGoal
            }
        }
    }

    /// The first linked sound for the current word, if any — used for the in-session diagram.
    func currentPhoneme(_ content: ContentStore = .shared) -> Phoneme? {
        guard let id = currentTarget?.phonemeIDs.first else { return nil }
        return content.phoneme(id: id)
    }

    /// Log one attempt at the current word. Successes count toward the rep goal and trigger
    /// the celebration. Trials stay keyed by the bare word so progress/export are unchanged.
    func log(_ rating: TrialRating) {
        guard let target = currentTarget, !isShowingDifficultyIntervention else { return }
        let trial = Trial(targetText: target.text, rating: rating)
        trial.session = session
        context.insert(trial)
        session.trials.append(trial)
        session.refreshSummary()
        repsForCurrent += 1
        if rating.isSuccess {
            successReps[target.id, default: 0] += 1
            celebrate = true
            resetDifficulty()
        } else {
            consecutiveDifficultAttempts += 1
            if consecutiveDifficultAttempts >= 2 {
                isShowingDifficultyIntervention = true
            }
        }
        context.saveOrLog()
    }

    /// Let the caregiver choose the support that matches advice from their clinician.
    func selectSupport(_ level: PracticeSupportLevel) {
        supportLevel = level
    }

    /// Resume after repeated difficulty with one additional step of modelling help.
    func resumeWithMoreSupport() {
        supportLevel = supportLevel.moreSupported
        resetDifficulty()
    }

    /// Resume at the current support level after hearing a slow model.
    func resumeAfterModel() {
        resetDifficulty()
    }

    /// End the difficult run on a positive note: choose another target where possible,
    /// otherwise finish the session.
    func moveOnPositively() {
        resetDifficulty()
        if canMoveToAnotherTarget {
            nextWord()
        } else {
            finish()
        }
    }

    /// Move to the next word, by the session's ordering rule. A no-op when the set is done.
    func nextWord() {
        resetDifficulty()
        switch order {
        case .blocked:
            guard index < targets.count - 1 else { return }
            index += 1
            repsForCurrent = 0
        case .random:
            selectNextRandom()
        }
    }

    /// Pick a random word that hasn't hit its goal yet, avoiding an immediate repeat when
    /// there's a choice. Stays put when everything is complete.
    private func selectNextRandom() {
        let incomplete = targets.indices.filter { (successReps[targets[$0].id] ?? 0) < repGoal }
        guard !incomplete.isEmpty else { return }
        let choices = incomplete.count > 1 ? incomplete.filter { $0 != index } : incomplete
        if let pick = choices.randomElement() {
            index = pick
            repsForCurrent = 0
        }
    }

    private func resetDifficulty() {
        consecutiveDifficultAttempts = 0
        isShowingDifficultyIntervention = false
    }

    /// End the session, stamping its finish time and persisting the final summary.
    func finish() {
        session.endedAt = Date()
        session.refreshSummary()
        context.saveOrLog()
        finished = true
    }

    /// One-line, genuine encouragement for the summary, scaled to what actually happened.
    var summaryMessage: String {
        switch successCount {
        case 0: return "Every go counts. Showing up is the hard part — well done."
        case 1...2: return "Lovely effort. A few good goes is exactly what helps."
        default: return "Brilliant practising! Those good reps are doing real work."
        }
    }
}
