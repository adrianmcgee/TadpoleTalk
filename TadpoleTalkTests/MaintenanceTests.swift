import XCTest
import SwiftData
import UserNotifications
@testable import TadpoleTalk

@MainActor
final class MaintenanceTests: XCTestCase {

    // MARK: - Reminders

    func testDailyReminderFiresOnceAtChosenTime() throws {
        let request = PracticeReminders.makeRequest(hour: 21, minute: 30)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 21)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
        XCTAssertEqual(request.identifier, PracticeReminders.requestID)
    }

    func testDisableAlsoClearsOldMultiReminderIDs() {
        XCTAssertEqual(PracticeReminders.legacyRequestIDs.count, 4)
        XCTAssertFalse(PracticeReminders.legacyRequestIDs.contains(PracticeReminders.requestID))
    }

    // MARK: - Renamed words keep their history

    func testRenamedWordKeepsItsHistoryTogether() throws {
        let context = try TestSupport.makeContext()
        let child = TestSupport.makeChild(in: context)
        let target = WordTarget(text: "bee", shape: .cv)
        target.child = child
        context.insert(target)

        let first = PracticeSessionViewModel(child: child, targets: [target], context: context)
        first.log(.correct)
        first.finish()
        target.text = "bees"
        let second = PracticeSessionViewModel(child: child, targets: [target], context: context)
        second.log(.approx)
        second.finish()

        let perTarget = ProgressViewModel().perTarget(child)
        XCTAssertEqual(perTarget.count, 1)
        XCTAssertEqual(perTarget.first?.word, "bees", "shows the word's current name")
        XCTAssertEqual(perTarget.first?.total, 2)
        XCTAssertEqual(perTarget.first?.successes, 1)
    }

    func testBackfillLinksOldTrialsToTheirWord() throws {
        let context = try TestSupport.makeContext()
        let child = TestSupport.makeChild(in: context)
        let target = WordTarget(text: "more", shape: .cv)
        target.child = child
        context.insert(target)
        // TestSupport logs trials for "more" without a target id, like pre-upgrade data.
        TestSupport.addSession(to: child, in: context, on: Date(), ratings: [.correct, .approx])

        LaunchMaintenance.backfillTrialTargetIDs(in: context)

        let trials = try context.fetch(FetchDescriptor<Trial>())
        XCTAssertEqual(trials.count, 2)
        XCTAssertTrue(trials.allSatisfy { $0.targetID == target.id })
    }

    func testBackfillLeavesUnmatchedTrialsAlone() throws {
        let context = try TestSupport.makeContext()
        let child = TestSupport.makeChild(in: context)
        TestSupport.addSession(to: child, in: context, on: Date(), ratings: [.correct])

        LaunchMaintenance.backfillTrialTargetIDs(in: context)

        let trials = try context.fetch(FetchDescriptor<Trial>())
        XCTAssertNil(trials.first?.targetID)
        XCTAssertEqual(ProgressViewModel().perTarget(child).first?.word, "more")
    }

    // MARK: - Recordings

    func testDeletingAWordDeletesItsRecording() throws {
        let context = try TestSupport.makeContext()
        let child = TestSupport.makeChild(in: context)
        let target = WordTarget(text: "go", shape: .cv)
        target.child = child
        context.insert(target)
        let store = AudioStore.shared
        let name = store.filename(for: target.id)
        try Data([0]).write(to: store.url(for: name))
        target.audioFilename = name

        TargetsViewModel().delete(target, in: context)

        XCTAssertFalse(store.exists(name))
    }

    func testOrphanSweepKeepsOnlyReferencedRecordings() throws {
        let store = AudioStore.shared
        let kept = store.filename(for: UUID())
        let orphan = store.filename(for: UUID())
        try Data([0]).write(to: store.url(for: kept))
        try Data([0]).write(to: store.url(for: orphan))
        defer { store.delete(kept) }

        store.removeOrphans(keeping: [kept])

        XCTAssertTrue(store.exists(kept))
        XCTAssertFalse(store.exists(orphan))
    }
}
