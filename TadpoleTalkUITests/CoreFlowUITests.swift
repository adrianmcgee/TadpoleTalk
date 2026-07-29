import XCTest

/// End-to-end coverage of the journeys that matter: first-run setup, adding a word, and
/// running a full practice session to its celebration. Launches with `-localStore` so the
/// app uses a throwaway in-memory store and every run starts from a clean slate.
final class CoreFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-localStore"]
        app.launch()
    }

    /// Disclaimer → onboarding → land in the app, then run a practice to the summary.
    func testFirstRunThroughToPracticeSummary() {
        DisclaimerScreen(app: app).accept()
        OnboardingScreen(app: app).createChild(named: "Mia")

        attachScreenshot(name: "Today")

        let today = TodayScreen(app: app)
        today.startPractice()

        // Onboarding seeds three active CV words; log each and advance.
        let practice = PracticeScreen(app: app)
        practice.startWhenReady()
        for _ in 0..<3 {
            XCTAssertTrue(app.buttons["practice.rating.correct"].waitForExistence(timeout: 5))
            practice.logCorrect()
            if app.buttons["practice.next"].exists {
                practice.next()
            }
        }
        if app.buttons["practice.done"].exists { practice.finish() }

        XCTAssertTrue(practice.waitForSummary(), "session should end on the celebration screen")
        attachScreenshot(name: "Summary")
    }

    /// Repeated difficulty pauses ratings until the caregiver chooses a positive response.
    func testPracticeDifficultyGuardrail() {
        DisclaimerScreen(app: app).accept()
        OnboardingScreen(app: app).createChild(named: "Mia")

        TodayScreen(app: app).startPractice()
        let practice = PracticeScreen(app: app)
        practice.startWhenReady()
        XCTAssertTrue(app.buttons["practice.rating.approx"].waitForExistence(timeout: 5))

        practice.logApprox()
        practice.logApprox()

        XCTAssertTrue(app.otherElements["practice.intervention"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["practice.rating.correct"].exists)
        practice.addMoreSupport()
        XCTAssertTrue(app.buttons["practice.rating.correct"].waitForExistence(timeout: 5))
    }

    /// Deferring practice returns home without recording practice history.
    func testTryPracticeLaterLeavesHistoryEmpty() {
        DisclaimerScreen(app: app).accept()
        OnboardingScreen(app: app).createChild(named: "Mia")

        TodayScreen(app: app).startPractice()
        let later = app.buttons["practice.readiness.later"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()
        XCTAssertTrue(TodayScreen(app: app).startButton.waitForExistence(timeout: 5))

        TabBar(app: app).progress()
        XCTAssertTrue(app.staticTexts["Your practice will show up here once you've had a few goes."]
            .waitForExistence(timeout: 5))
    }

    /// Add a brand-new word from the Targets tab.
    func testAddTargetWord() {
        DisclaimerScreen(app: app).accept()
        OnboardingScreen(app: app).createChild(named: "Sam")

        TabBar(app: app).targets()
        TargetsScreen(app: app).add(word: "zoo")

        XCTAssertTrue(app.staticTexts["zoo"].waitForExistence(timeout: 5),
                      "the new word should appear in the target bank")
    }

    /// The reference library and learn sections should open without a child-data dependency.
    func testNavigateLearn() {
        DisclaimerScreen(app: app).accept()
        OnboardingScreen(app: app).createChild(named: "Sam")

        TabBar(app: app).learn()
        XCTAssertTrue(app.staticTexts["What is apraxia of speech?"].waitForExistence(timeout: 5))
    }

    private func attachScreenshot(name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
