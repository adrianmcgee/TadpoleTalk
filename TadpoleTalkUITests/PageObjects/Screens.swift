import XCTest

/// Page objects: each screen's controls and actions in one place, addressed by the stable
/// identifiers in `A11y`. UI tests read as user intent ("complete onboarding", "run a
/// practice") instead of a wall of `app.buttons[...]`, and a UI change updates one spot.

struct DisclaimerScreen {
    let app: XCUIApplication
    func accept() {
        let button = app.buttons["disclaimer.accept"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "disclaimer should show on first launch")
        button.tap()
    }
}

struct OnboardingScreen {
    let app: XCUIApplication
    func createChild(named name: String) {
        let field = app.textFields["onboarding.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "onboarding should show with no child")
        field.tap()
        field.typeText(name)
        app.buttons["onboarding.continue"].tap()
    }
}

struct TabBar {
    let app: XCUIApplication

    /// Works for both layouts: the iPhone tab bar addresses buttons by their visible
    /// title, the iPad sidebar by the accessibility identifier we set on each row.
    func go(title: String, sidebarID: String) {
        let tab = app.tabBars.buttons[title]
        if tab.waitForExistence(timeout: 5) { tab.tap(); return }
        let row = app.buttons[sidebarID]
        if row.waitForExistence(timeout: 3) { row.tap() }
    }
    func today() { go(title: "Today", sidebarID: "tab.today") }
    func targets() { go(title: "Targets", sidebarID: "tab.targets") }
    func progress() { go(title: "Progress", sidebarID: "tab.progress") }
    func learn() { go(title: "Learn", sidebarID: "tab.learn") }
}

struct TodayScreen {
    let app: XCUIApplication
    var startButton: XCUIElement { app.buttons["home.startPractice"] }
    func startPractice() {
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()
    }
}

struct PracticeScreen {
    let app: XCUIApplication
    func startWhenReady() {
        let start = app.buttons["practice.readiness.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "readiness check should appear before practice")
        start.tap()
    }
    func logCorrect() { app.buttons["practice.rating.correct"].firstMatch.tap() }
    func logApprox() { app.buttons["practice.rating.approx"].firstMatch.tap() }
    func addMoreSupport() { app.buttons["practice.intervention.moreSupport"].tap() }
    func next() {
        let next = app.buttons["practice.next"]
        if next.exists { next.tap() }
    }
    func finish() { app.buttons["practice.done"].tap() }
    var summary: XCUIElement { app.otherElements["practice.summary"] }
    func waitForSummary() -> Bool {
        app.staticTexts["Great practising!"].waitForExistence(timeout: 5)
    }
}

struct TargetsScreen {
    let app: XCUIApplication
    func add(word: String) {
        app.buttons["targets.add"].tap()
        let field = app.textFields["targetEditor.text"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(word)
        app.buttons["targetEditor.save"].tap()
    }
}
