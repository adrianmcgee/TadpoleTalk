import XCTest
import SwiftData
@testable import TadpoleTalk

@MainActor
final class PracticeSessionViewModelTests: XCTestCase {

    private func makeVM(_ context: ModelContext,
                        targets: [WordTarget],
                        order: PracticeOrder = .blocked,
                        repGoal: Int = 3,
                        autoAdvance: Bool = false) -> PracticeSessionViewModel {
        let child = TestSupport.makeChild(in: context)
        for t in targets { t.child = child; context.insert(t) }
        return PracticeSessionViewModel(child: child, targets: targets, context: context,
                                        order: order, repGoal: repGoal, autoAdvance: autoAdvance)
    }

    // MARK: - phraseText

    func testPhraseTextReplacesPlaceholder() {
        let t = WordTarget(text: "milk", shape: .cvc, carrierPhrase: "I want ___")
        XCTAssertEqual(t.phraseText, "I want milk")
    }

    func testPhraseTextAppendsWhenNoPlaceholder() {
        let t = WordTarget(text: "ball", shape: .cvc, carrierPhrase: "more")
        XCTAssertEqual(t.phraseText, "more ball")
    }

    func testPhraseTextFallsBackToWord() {
        XCTAssertEqual(WordTarget(text: "go", shape: .cv).phraseText, "go")
        XCTAssertEqual(WordTarget(text: "go", shape: .cv, carrierPhrase: "   ").phraseText, "go")
    }

    // MARK: - Blocked rep goals

    func testBlockedAdvancesOnlyAtGoal() throws {
        let context = try TestSupport.makeContext()
        let vm = makeVM(context,
                        targets: [WordTarget(text: "bee", shape: .cv),
                                  WordTarget(text: "go", shape: .cv)],
                        order: .blocked, repGoal: 3)
        vm.log(.correct)
        vm.log(.correct)
        XCTAssertFalse(vm.isCurrentComplete)
        XCTAssertEqual(vm.index, 0)
        vm.log(.correct)
        XCTAssertTrue(vm.isCurrentComplete)
        XCTAssertEqual(vm.index, 0, "no auto-advance when the flag is off")
        vm.nextWord()
        XCTAssertEqual(vm.index, 1)
        XCTAssertFalse(vm.isCurrentComplete, "fresh word starts at zero reps")
    }

    func testApproxAndTryAgainDoNotCountTowardGoal() throws {
        let context = try TestSupport.makeContext()
        let vm = makeVM(context, targets: [WordTarget(text: "bee", shape: .cv)], repGoal: 2)
        vm.log(.approx)
        vm.log(.tryAgain)
        XCTAssertEqual(vm.currentSuccessReps, 0)
        XCTAssertFalse(vm.isCurrentComplete)
    }

    func testShouldAutoAdvanceOnlyWhenEnabledAndIncomplete() throws {
        let context = try TestSupport.makeContext()
        let vm = makeVM(context,
                        targets: [WordTarget(text: "bee", shape: .cv),
                                  WordTarget(text: "go", shape: .cv)],
                        order: .blocked, repGoal: 1, autoAdvance: true)
        XCTAssertFalse(vm.shouldAutoAdvance)
        vm.log(.correct)
        XCTAssertTrue(vm.shouldAutoAdvance, "first word done, another remains")
    }

    func testAllCompleteAndShowFinish() throws {
        let context = try TestSupport.makeContext()
        let vm = makeVM(context,
                        targets: [WordTarget(text: "bee", shape: .cv),
                                  WordTarget(text: "go", shape: .cv)],
                        order: .blocked, repGoal: 1)
        vm.log(.correct)        // bee done
        vm.nextWord()
        vm.log(.correct)        // go done
        XCTAssertTrue(vm.allComplete)
        XCTAssertTrue(vm.showFinish)
    }

    // MARK: - Random order

    func testRandomNeverRepicksCompletedWord() throws {
        let context = try TestSupport.makeContext()
        let targets = [WordTarget(text: "bee", shape: .cv),
                       WordTarget(text: "go", shape: .cv),
                       WordTarget(text: "me", shape: .cv)]
        let vm = makeVM(context, targets: targets, order: .random, repGoal: 1)

        var visited: Set<String> = []
        for _ in 0..<3 {
            guard let word = vm.currentTarget?.text else { return XCTFail("no current word") }
            XCTAssertFalse(visited.contains(word), "should not return to a completed word")
            visited.insert(word)
            vm.log(.correct)     // completes the current word (goal = 1)
            vm.nextWord()
        }
        XCTAssertEqual(visited.count, 3, "every word is visited once")
        XCTAssertTrue(vm.allComplete)
        XCTAssertTrue(vm.showFinish)
    }

    // MARK: - Logging keeps trials keyed by word

    func testLoggingKeysTrialByWordText() throws {
        let context = try TestSupport.makeContext()
        let vm = makeVM(context,
                        targets: [WordTarget(text: "bee", shape: .cv, carrierPhrase: "more ___")],
                        repGoal: 5)
        vm.log(.correct)
        vm.log(.approx)
        XCTAssertEqual(vm.totalCount, 2)
        XCTAssertEqual(vm.successCount, 1)
        let trials = try context.fetch(FetchDescriptor<Trial>())
        XCTAssertEqual(Set(trials.map(\.targetText)), ["bee"],
                       "trials log the bare word, not the carrier phrase")
    }

    // MARK: - Positive-practice guardrail

    func testTwoDifficultAttemptsTriggerIntervention() throws {
        let context = try TestSupport.makeContext()
        let vm = makeVM(context, targets: [WordTarget(text: "bee", shape: .cv)])

        vm.log(.approx)
        XCTAssertEqual(vm.consecutiveDifficultAttempts, 1)
        XCTAssertFalse(vm.isShowingDifficultyIntervention)

        vm.log(.tryAgain)
        XCTAssertEqual(vm.consecutiveDifficultAttempts, 2)
        XCTAssertTrue(vm.isShowingDifficultyIntervention)

        vm.log(.correct)
        XCTAssertEqual(vm.totalCount, 2, "ratings stay locked until the caregiver chooses")
    }

    func testSuccessAndTargetChangeResetDifficulty() throws {
        let context = try TestSupport.makeContext()
        let vm = makeVM(
            context,
            targets: [WordTarget(text: "bee", shape: .cv),
                      WordTarget(text: "go", shape: .cv)]
        )

        vm.log(.approx)
        vm.log(.correct)
        XCTAssertEqual(vm.consecutiveDifficultAttempts, 0)
        XCTAssertFalse(vm.isShowingDifficultyIntervention)

        vm.log(.approx)
        vm.nextWord()
        XCTAssertEqual(vm.consecutiveDifficultAttempts, 0)
        XCTAssertFalse(vm.isShowingDifficultyIntervention)
    }

    func testInterventionCanIncreaseSupportOrResumeAfterModel() throws {
        let context = try TestSupport.makeContext()
        let vm = makeVM(context, targets: [WordTarget(text: "bee", shape: .cv)])
        vm.selectSupport(.delayed)
        vm.log(.approx)
        vm.log(.tryAgain)

        vm.resumeWithMoreSupport()
        XCTAssertEqual(vm.supportLevel, .immediate)
        XCTAssertFalse(vm.isShowingDifficultyIntervention)

        vm.selectSupport(.together)
        vm.log(.approx)
        vm.log(.approx)
        vm.resumeWithMoreSupport()
        XCTAssertEqual(vm.supportLevel, .together, "maximum support is a stable boundary")

        vm.log(.tryAgain)
        vm.log(.tryAgain)
        vm.resumeAfterModel()
        XCTAssertEqual(vm.supportLevel, .together)
        XCTAssertEqual(vm.consecutiveDifficultAttempts, 0)
        XCTAssertFalse(vm.isShowingDifficultyIntervention)
    }

    func testMoveOnPositivelyAdvancesOrFinishes() throws {
        let context = try TestSupport.makeContext()
        let vm = makeVM(
            context,
            targets: [WordTarget(text: "bee", shape: .cv),
                      WordTarget(text: "go", shape: .cv)]
        )
        vm.log(.approx)
        vm.log(.tryAgain)
        vm.moveOnPositively()
        XCTAssertEqual(vm.currentTarget?.text, "go")
        XCTAssertFalse(vm.finished)

        vm.log(.approx)
        vm.log(.tryAgain)
        vm.moveOnPositively()
        XCTAssertTrue(vm.finished)
        XCTAssertEqual(vm.totalCount, 4, "all attempts remain in the normal trial history")
    }
}
