import XCTest
import SwiftData
@testable import TadpoleTalk

/// Movement direction, prompting level, voicing swaps and the "try a new word" nudge —
/// the pieces that let a family follow a speech pathologist's CVC / CVCV plan at home.
@MainActor
final class TherapyFocusTests: XCTestCase {

    // MARK: - Movement

    func testMovementGuessFromSpelling() {
        for word in ["digger", "doggy", "tiger", "dark", "dog", "duck", "talk", "taco"] {
            XCTAssertEqual(MovementPattern.guess(for: word), .frontToBack, word)
        }
        for word in ["cat", "cut", "kit", "kid", "cot", "kite", "kitty", "goody"] {
            XCTAssertEqual(MovementPattern.guess(for: word), .backToFront, word)
        }
        for word in ["cup", "cake", "mama", "water", "bee", "city", "the"] {
            XCTAssertNil(MovementPattern.guess(for: word), word)
        }
    }

    func testStarterMovementsMatchTheGuess() {
        for starter in ContentStore().starterTargets {
            if let movement = starter.movement {
                XCTAssertEqual(MovementPattern.guess(for: starter.text), movement, starter.text)
            }
        }
    }

    func testMovementSetsIncludeHomePracticeWords() {
        let sets = ContentStore().movementSets
        func words(_ shape: SyllableShape, _ movement: MovementPattern) -> Set<String> {
            Set(sets.first { $0.shape == shape && $0.movement == movement }?.targets.map(\.text) ?? [])
        }
        XCTAssertTrue(["cat", "cut", "kit", "kid", "cot"].allSatisfy(words(.cvc, .backToFront).contains))
        XCTAssertTrue(["digger", "doggy"].allSatisfy(words(.cvcv, .frontToBack).contains))
        XCTAssertTrue(words(.cvc, .frontToBack).contains("dark"))
        XCTAssertEqual(sets.first?.shape, .cvc, "easiest shape first")
    }

    func testTargetMovementUsesOverrideThenGuess() {
        let target = WordTarget(text: "cat", shape: .cvc)
        XCTAssertEqual(target.movement, .backToFront, "guessed when not set")
        target.movementRaw = MovementPattern.storedNone
        XCTAssertNil(target.movement, "parent can say it doesn't apply")
        target.movementRaw = MovementPattern.frontToBack.rawValue
        XCTAssertEqual(target.movement, .frontToBack)
    }

    func testAddToThisWeekStarsExistingAndAddsMissing() throws {
        let context = try TestSupport.makeContext()
        let child = TestSupport.makeChild(in: context)
        let vm = TargetsViewModel()
        let cat = vm.add(text: "Cat", shape: .cvc, phonemeIDs: [], notes: "", activeThisWeek: false,
                         to: child, in: context)
        let starters = ContentStore().starterTargets.filter { ["cat", "cut", "kid"].contains($0.text) }

        XCTAssertEqual(vm.addToThisWeek(starters, to: child, in: context), 2)
        XCTAssertTrue(cat.isActiveThisWeek, "existing word is starred, not duplicated")
        XCTAssertEqual(child.targets.count, 3)
        XCTAssertTrue(child.targets.allSatisfy(\.isActiveThisWeek))

        XCTAssertEqual(vm.addToThisWeek(starters, to: child, in: context), 0, "adding again is a no-op")
        XCTAssertEqual(child.targets.count, 3)
    }

    // MARK: - Voicing swaps

    func testVoicingSwapExample() {
        XCTAssertEqual(VoicingSwap.example(for: "cat"), "gat")
        XCTAssertEqual(VoicingSwap.example(for: "digger"), "tigger")
        XCTAssertEqual(VoicingSwap.example(for: "kid"), "gid")
        XCTAssertNil(VoicingSwap.example(for: "mama"))
    }

    func testVoicingNoteOnlyWhenAccepted() throws {
        let context = try TestSupport.makeContext()
        let off = makeVM(context, targets: [WordTarget(text: "cat", shape: .cvc)])
        XCTAssertNil(off.voicingSwapExample)
        let on = makeVM(context, targets: [WordTarget(text: "cat", shape: .cvc)], acceptsVoicingSwaps: true)
        XCTAssertEqual(on.voicingSwapExample, "gat")
    }

    // MARK: - Prompting

    func testPromptFollowsSupportAndIsLogged() throws {
        let context = try TestSupport.makeContext()
        let vm = makeVM(context, targets: [WordTarget(text: "cat", shape: .cvc)])
        XCTAssertEqual(vm.promptLevel, .max, "starts with the most support")
        vm.log(.correct)
        vm.selectSupport(.immediate)
        XCTAssertEqual(vm.promptLevel, .mild)
        vm.log(.correct)
        vm.selectPrompt(.unprompted)
        vm.log(.correct)

        let trials = try context.fetch(FetchDescriptor<Trial>()).sorted { $0.timestamp < $1.timestamp }
        XCTAssertEqual(trials.map(\.prompt), [.max, .mild, .unprompted])
    }

    func testProgressShowsBestAndLatestPromptingAndMovement() throws {
        let context = try TestSupport.makeContext()
        let child = TestSupport.makeChild(in: context)
        let cat = WordTarget(text: "cat", shape: .cvc)
        cat.child = child
        context.insert(cat)
        let session = PracticeSession()
        session.child = child
        context.insert(session)
        let start = Date()
        let attempts: [(TrialRating, PromptLevel)] = [(.correct, .max), (.correct, .mild), (.tryAgain, .unprompted)]
        for (offset, attempt) in attempts.enumerated() {
            let trial = Trial(targetText: "cat", targetID: cat.id, rating: attempt.0, prompt: attempt.1,
                              timestamp: start.addingTimeInterval(Double(offset)))
            trial.session = session
            context.insert(trial)
            session.trials.append(trial)
        }
        session.refreshSummary()

        let vm = ProgressViewModel()
        let progress = try XCTUnwrap(vm.perTarget(child).first)
        XCTAssertEqual(progress.leastPromptForSuccess, .mild, "a miss without prompting isn't a best")
        XCTAssertEqual(progress.latestPrompt, .unprompted)
        XCTAssertEqual(progress.movement, .backToFront)

        let movement = try XCTUnwrap(vm.perMovement(child).first)
        XCTAssertEqual(movement.movement, .backToFront)
        XCTAssertEqual(movement.successes, 2)
        XCTAssertEqual(movement.total, 3)

        XCTAssertTrue(ReportExporter().makeCSV(for: child).contains("cat,correct,mild"))
    }

    // MARK: - Move on after repeated errors

    func testSuggestsNewWordAfterRepeatedMisses() throws {
        let context = try TestSupport.makeContext()
        let vm = makeVM(context, targets: [WordTarget(text: "cut", shape: .cvc),
                                           WordTarget(text: "cat", shape: .cvc)])
        vm.log(.tryAgain)
        vm.log(.tryAgain)
        XCTAssertTrue(vm.isShowingDifficultyIntervention)
        XCTAssertFalse(vm.suggestsNewWord, "first pause offers more help")

        vm.resumeWithMoreSupport()
        vm.log(.approx)
        vm.log(.tryAgain)
        XCTAssertTrue(vm.suggestsNewWord, "still missing after help: try a different word")

        vm.moveOnPositively()
        XCTAssertEqual(vm.currentTarget?.text, "cat")
        XCTAssertFalse(vm.suggestsNewWord)
    }

    func testSuccessResetsRepeatedMissCount() throws {
        let context = try TestSupport.makeContext()
        let vm = makeVM(context, targets: [WordTarget(text: "cut", shape: .cvc)])
        vm.log(.tryAgain)
        vm.log(.tryAgain)
        vm.resumeAfterModel()
        vm.log(.correct)
        XCTAssertEqual(vm.currentMissesSinceSuccess, 0)
        vm.log(.tryAgain)
        vm.log(.tryAgain)
        XCTAssertTrue(vm.isShowingDifficultyIntervention)
        XCTAssertFalse(vm.suggestsNewWord)
    }

    private func makeVM(_ context: ModelContext, targets: [WordTarget],
                        acceptsVoicingSwaps: Bool = false) -> PracticeSessionViewModel {
        let child = TestSupport.makeChild(in: context)
        for t in targets { t.child = child; context.insert(t) }
        return PracticeSessionViewModel(child: child, targets: targets, context: context,
                                        repGoal: 3, acceptsVoicingSwaps: acceptsVoicingSwaps)
    }
}
