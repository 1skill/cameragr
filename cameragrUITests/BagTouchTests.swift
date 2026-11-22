import XCTest

/// Real touches on the open bag (the flat inner screen): a page drawn over
/// another must never take the touches meant for the rolls under it.
final class BagTouchTests: XCTestCase {
    private func openBag() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-fold", "flat", "-look", "portra400", "-AppleLanguages", "(en)"]
        app.launch()
        return app
    }

    func testTappingARollPutsItOnTheCard() {
        let app = openBag()
        let roll = app.buttons["Golden 200"]
        XCTAssertTrue(roll.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Golden 200"].exists, "the card shows Porto 400 to begin with")
        roll.tap()
        XCTAssertTrue(app.staticTexts["Golden 200"].waitForExistence(timeout: 5), "the tapped roll's card")
    }

    func testRollsStillAnswerAfterTurningToTheKitAndBack() {
        let app = openBag()
        let kit = app.buttons["Kit"]
        XCTAssertTrue(kit.waitForExistence(timeout: 15))
        kit.tap()
        XCTAssertTrue(app.staticTexts["Koco handbook"].waitForExistence(timeout: 5))
        app.buttons["Films"].tap()
        let roll = app.buttons["Cine 500T"]
        XCTAssertTrue(roll.waitForExistence(timeout: 5))
        roll.tap()
        XCTAssertTrue(app.staticTexts["Cine 500T"].waitForExistence(timeout: 5))
    }
}
