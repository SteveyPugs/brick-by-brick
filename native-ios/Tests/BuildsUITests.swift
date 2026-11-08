import XCTest

final class BuildsUITests: XCTestCase {
    @MainActor
    func testCreateValidateCancelAndRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["add-build"].waitForExistence(timeout: 10))
        app.buttons["add-build"].tap()
        let save = app.buttons["save-build"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)
        let name = app.descendants(matching: .any).matching(identifier: "build-name").firstMatch
        name.tap()
        name.typeText("   ")
        XCTAssertFalse(save.isEnabled)
        app.buttons["Cancel"].tap()
        XCTAssertFalse(save.exists)

        app.buttons["add-build"].tap()
        let title = "Build a reading habit"
        name.tap()
        name.typeText(title)
        let why = app.descendants(matching: .any).matching(identifier: "build-motivation").firstMatch
        why.tap()
        why.typeText("Make time to learn something new.")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Make time to learn something new."].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Saved Builds after relaunch"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.staticTexts[title].tap()
        XCTAssertTrue(app.navigationBars["Your Build"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[title].exists)
    }
}
