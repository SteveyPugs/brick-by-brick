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
        app.buttons["add-wall"].tap()
        let saveWall = app.buttons["save-wall"]
        XCTAssertTrue(saveWall.waitForExistence(timeout: 5))
        XCTAssertFalse(saveWall.isEnabled)
        let wallName = app.textFields["wall-name"]
        wallName.tap()
        wallName.typeText("   ")
        XCTAssertFalse(saveWall.isEnabled)
        app.buttons["Cancel"].tap()
        app.buttons["add-wall"].tap()
        wallName.tap()
        wallName.typeText(String(repeating: "a", count: 81))
        XCTAssertFalse(saveWall.isEnabled)
        app.buttons["Cancel"].tap()
        app.buttons["add-wall"].tap()
        wallName.tap()
        wallName.typeText("  Read every evening  ")
        XCTAssertTrue(saveWall.isEnabled)
        saveWall.tap()
        XCTAssertTrue(app.staticTexts["Read every evening"].waitForExistence(timeout: 5))
        app.buttons["add-wall"].tap()
        wallName.tap()
        wallName.typeText("Visit the library")
        saveWall.tap()
        XCTAssertTrue(app.staticTexts["Visit the library"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["2 Walls"].exists)
        app.staticTexts[title].tap()
        XCTAssertTrue(app.staticTexts["Read every evening"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Visit the library"].exists)
        app.staticTexts["Read every evening"].tap()
        XCTAssertTrue(app.navigationBars["Your Wall"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Read every evening"].exists)
    }
}
