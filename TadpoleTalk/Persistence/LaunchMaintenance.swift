import Foundation
import SwiftData

/// Small, idempotent housekeeping run once per launch: brings data and scheduled reminders
/// written by older versions up to date. Each step is cheap and safe to repeat.
enum LaunchMaintenance {
    @MainActor
    static func run(in context: ModelContext, defaults: UserDefaults = .standard) async {
        backfillTrialTargetIDs(in: context)
        removeOrphanedRecordings(in: context)
        await refreshReminders(defaults: defaults)
    }

    /// Link trials logged before `Trial.targetID` existed to their word, matched by text.
    /// Trials whose word has since been renamed or deleted keep their logged text.
    @MainActor
    static func backfillTrialTargetIDs(in context: ModelContext) {
        let descriptor = FetchDescriptor<Trial>(predicate: #Predicate { $0.targetID == nil })
        guard let trials = try? context.fetch(descriptor), !trials.isEmpty else { return }
        for trial in trials {
            let match = trial.session?.child?.targets.first { $0.text == trial.targetText }
            if let match { trial.targetID = match.id }
        }
        context.saveOrLog()
    }

    /// Delete recorded clips that no remaining word points at.
    @MainActor
    static func removeOrphanedRecordings(in context: ModelContext, store: AudioStore = .shared) {
        guard let targets = try? context.fetch(FetchDescriptor<WordTarget>()) else { return }
        store.removeOrphans(keeping: Set(targets.compactMap(\.audioFilename)))
    }

    /// Re-schedule the reminder if it's on, so anyone upgrading from the several-a-day
    /// version drops to the single daily nudge without visiting Settings.
    static func refreshReminders(defaults: UserDefaults) async {
        guard defaults.bool(forKey: "remindersEnabled") else { return }
        let minutes = defaults.object(forKey: "reminderMinutes") as? Int ?? 9 * 60
        await PracticeReminders().schedule(hour: minutes / 60, minute: minutes % 60)
    }
}
