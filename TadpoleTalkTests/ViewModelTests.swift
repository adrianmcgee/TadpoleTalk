import XCTest
import SwiftData
@testable import TadpoleTalk

@MainActor
final class ViewModelTests: XCTestCase {

    private let cal = Calendar.current

    func testStreakCountsConsecutiveDaysEndingToday() throws {
        let context = try TestSupport.makeContext()
        let child = TestSupport.makeChild(in: context)
        let today = cal.startOfDay(for: Date())
        for offset in 0..<3 {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            TestSupport.addSession(to: child, in: context, on: day, ratings: [.correct])
        }
        XCTAssertEqual(HomeViewModel().streak(child, now: today), 3)
    }

    func testStreakBreaksWithAGap() throws {
        let context = try TestSupport.makeContext()
        let child = TestSupport.makeChild(in: context)
        let today = cal.startOfDay(for: Date())
        TestSupport.addSession(to: child, in: context, on: today, ratings: [.correct])
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: today)!
        TestSupport.addSession(to: child, in: context, on: threeDaysAgo, ratings: [.correct])
        XCTAssertEqual(HomeViewModel().streak(child, now: today), 1)
    }

    func testSuccessesTodayOnlyCountsToday() throws {
        let context = try TestSupport.makeContext()
        let child = TestSupport.makeChild(in: context)
        let today = cal.startOfDay(for: Date())
        TestSupport.addSession(to: child, in: context, on: today, ratings: [.correct, .correct, .approx])
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        TestSupport.addSession(to: child, in: context, on: yesterday, ratings: [.correct])
        XCTAssertEqual(HomeViewModel().successesToday(child, now: today), 2)
    }

    func testProgressPerTargetAggregates() throws {
        let context = try TestSupport.makeContext()
        let child = TestSupport.makeChild(in: context)
        TestSupport.addSession(to: child, in: context, on: Date(), ratings: [.correct, .approx, .correct])
        let perTarget = ProgressViewModel().perTarget(child)
        XCTAssertEqual(perTarget.count, 1)
        XCTAssertEqual(perTarget.first?.word, "more")
        XCTAssertEqual(perTarget.first?.successes, 2)
        XCTAssertEqual(perTarget.first?.total, 3)
    }

    func testDailyBarsZeroFillToRequestedLength() throws {
        let context = try TestSupport.makeContext()
        let child = TestSupport.makeChild(in: context)
        TestSupport.addSession(to: child, in: context, on: Date(), ratings: [.correct])
        let bars = ProgressViewModel().dailyBars(child, days: 14)
        XCTAssertEqual(bars.count, 14)
        XCTAssertEqual(bars.last?.successes, 1)   // today is the last bar
        XCTAssertEqual(bars.first?.total, 0)      // two weeks ago is empty
    }

    func testExporterCSVHasHeaderAndRowPerTrial() throws {
        let context = try TestSupport.makeContext()
        let child = TestSupport.makeChild(in: context, name: "Mia")
        TestSupport.addSession(to: child, in: context, on: Date(), ratings: [.correct, .tryAgain])
        let csv = ReportExporter().makeCSV(for: child)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.first, "date,time,word,rating,prompting")
        XCTAssertEqual(lines.count, 3)  // header + 2 trials
        XCTAssertTrue(csv.contains("more,correct"))
    }

    func testOnboardingSeedsStarterTargets() throws {
        let context = try TestSupport.makeContext()
        let vm = OnboardingViewModel()
        vm.name = "Mia"
        vm.createChild(in: context)
        let children = try context.fetch(FetchDescriptor<Child>())
        XCTAssertEqual(children.count, 1)
        let targets = try context.fetch(FetchDescriptor<WordTarget>())
        XCTAssertFalse(targets.isEmpty, "starter targets should be seeded")
        XCTAssertTrue(targets.contains { $0.isActiveThisWeek }, "some targets active on day one")
    }
}
