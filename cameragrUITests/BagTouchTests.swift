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

    /// Over the closed camera (any iPhone): the bag opens, its rolls answer,
    /// and its clasp closes it.
    func testTheBagOverTheCameraOpensAndClosesWithItsClasp() {
        let app = XCUIApplication()
        app.launchArguments = ["-openBag", "films", "-AppleLanguages", "(en)"]
        app.launch()
        let roll = app.buttons["Cine 500T"]
        XCTAssertTrue(roll.waitForExistence(timeout: 15))
        roll.tap()
        XCTAssertTrue(app.staticTexts["Cine 500T"].waitForExistence(timeout: 5))
        let clasp = app.buttons["Close the bag"]
        XCTAssertTrue(clasp.exists)
        // The simulator's Duo outer screen stands upright, which puts the clasp
        // along the bottom edge, where the home-indicator zone takes a tap at
        // its middle: tap its inner part.
        clasp.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        XCTAssertTrue(clasp.waitForNonExistence(timeout: 5), "the bag is closed")
    }
}
