import Foundation

/// Stable accessibility identifiers for every interactive element the UI tests (and
/// future agent-driven changes) rely on. Keeping them in one place means a renamed
/// control breaks in exactly one spot, and tests read as a contract of app behaviour.
enum A11y {
    // Disclaimer / onboarding
    static let disclaimerAccept   = "disclaimer.accept"
    static let onboardingName     = "onboarding.name"
    static let onboardingAge      = "onboarding.age"
    static let onboardingContinue = "onboarding.continue"

    // Tab bar
    static let tabToday    = "tab.today"
    static let tabTargets  = "tab.targets"
    static let tabSounds   = "tab.sounds"
    static let tabSigns    = "tab.signs"
    static let tabProgress = "tab.progress"
    static let tabLearn    = "tab.learn"

    // Home
    static let startPractice = "home.startPractice"

    // Targets
    static let addTarget       = "targets.add"
    static let targetText      = "targetEditor.text"
    static let targetShape     = "targetEditor.shape"
    static let targetActive    = "targetEditor.activeThisWeek"
    static let targetSave      = "targetEditor.save"
    static let targetCarrier   = "targetEditor.carrierPhrase"
    static let targetRecordModel = "targetEditor.recordModel"
    static func targetRow(_ text: String) -> String { "target.row.\(text)" }

    // Practice
    static let practiceRatingCorrect  = "practice.rating.correct"
    static let practiceRatingApprox   = "practice.rating.approx"
    static let practiceRatingTryAgain = "practice.rating.tryAgain"
    static let practiceNext           = "practice.next"
    static let practiceDone           = "practice.done"
    static let practiceSummary        = "practice.summary"
    static let practiceHear           = "practice.hear"
    static let practiceHearSlow       = "practice.hearSlow"
    static let practicePhraseToggle   = "practice.phraseToggle"
    static let practiceReadinessStart = "practice.readiness.start"
    static let practiceReadinessLater = "practice.readiness.later"
    static let practiceIntervention   = "practice.intervention"
    static let practiceMoreSupport    = "practice.intervention.moreSupport"
    static let practiceModelAndRetry  = "practice.intervention.modelAndRetry"
    static let practiceMoveOn         = "practice.intervention.moveOn"
    static func practiceSupport(_ level: PracticeSupportLevel) -> String {
        "practice.support.\(level.rawValue)"
    }

    // Settings
    static let settingsRepGoal        = "settings.repGoal"
    static let settingsPracticeOrder  = "settings.practiceOrder"
    static let settingsAutoAdvance    = "settings.autoAdvance"
    static let settingsAutoPlayModel  = "settings.autoPlayModel"

    // Progress
    static let exportReport = "progress.export"
}
