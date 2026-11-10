import XCTest

final class GuidedGoalsUITests: XCTestCase {
    @MainActor
    func testGoalDiscoverySurvivesRelaunchAndWallsRemainAccessible() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["add-build"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Guided Goals"].tap()
        app.buttons["Start a guided goal"].tap()
        let title = "Guided UI test \(UUID().uuidString.prefix(6))"
        let field = app.descendants(matching: .any).matching(identifier: "guided-goal-title").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(title)
        app.buttons["Start the conversation"].tap()
        XCTAssertTrue(app.staticTexts["LET’S FIND YOUR DIRECTION"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["What would success look like for you, and what should I know about your starting point? You can answer in your own words."].exists)
        app.terminate(); app.launch()
        app.tabBars.buttons["Guided Goals"].tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        app.staticTexts[title].tap()
        XCTAssertTrue(app.staticTexts["LET’S FIND YOUR DIRECTION"].waitForExistence(timeout: 5))
        app.tabBars.buttons["My Walls"].tap()
        XCTAssertTrue(app.buttons["add-build"].waitForExistence(timeout: 5))
    }
}
