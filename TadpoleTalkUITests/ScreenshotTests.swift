import XCTest

/// Drives the app through the five App Store shots and saves each as a keep-always
/// attachment. Run on the iPhone 6.9" and iPad 13" simulators; the PNGs are pulled out
/// of the resulting .xcresult by the screenshot export script.
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Throwaway in-memory store so every run starts from a clean, seeded slate.
        app.launchArguments += ["-localStore"]
        app.launch()
    }

    func testCaptureStoreScreenshots() {
        DisclaimerScreen(app: app).accept()
        OnboardingScreen(app: app).createChild(named: "Mia")

        // 1. Today
        let today = TodayScreen(app: app)
        XCTAssertTrue(today.startButton.waitForExistence(timeout: 5))
        shot("01-Today")

        // 2. Practice — word, modelling controls, rating buttons
        today.startPractice()
        let practice = PracticeScreen(app: app)
        practice.startWhenReady()
        XCTAssertTrue(app.buttons["practice.rating.correct"].waitForExistence(timeout: 5))
        shot("02-Practice")

        // 3. Celebration summary
        for _ in 0..<3 {
            if app.buttons["practice.rating.correct"].waitForExistence(timeout: 5) {
                practice.logCorrect()
            }
            if app.buttons["practice.next"].exists { practice.next() }
        }
        if app.buttons["practice.done"].exists { practice.finish() }
        XCTAssertTrue(practice.waitForSummary(), "session should end on the celebration screen")
        shot("03-Summary")

        // Dismiss summary back to the app shell.
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }

        // 4. Sounds library
        TabBar(app: app).go(title: "Library", sidebarID: "tab.sounds")
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        shot("04-Library")

        // 5. Progress charts
        TabBar(app: app).progress()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        shot("05-Progress")
    }

    private func shot(_ name: String) {
        // Capture the device framebuffer rather than the app window: app.screenshot()
        // composites the app frame and rotates/black-pads on iPad.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
