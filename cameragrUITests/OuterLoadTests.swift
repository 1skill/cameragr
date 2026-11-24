import XCTest

/// The bag over the closed camera (outer screen, any iPhone): a roll chosen
/// with its tag goes straight into the camera (user 11/24: it didn't, and
/// the clasp was a step too many).
final class OuterLoadTests: XCTestCase {
    func testChosenRollGoesStraightIn() {
        let app = XCUIApplication()
        app.launchArguments = ["-openBag", "films", "-AppleLanguages", "(en)", "-dailyFree", "off"]
        app.launch()
        let roll = app.buttons["Cine 500T"]
        XCTAssertTrue(roll.waitForExistence(timeout: 15))
        roll.tap()
        XCTAssertTrue(app.staticTexts["Cine 500T"].waitForExistence(timeout: 5))
        let tag = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'try it' OR label CONTAINS[c] 'load this roll'")).firstMatch
        XCTAssertTrue(tag.waitForExistence(timeout: 5), "the tag")
        tag.tap()
        // The bag closes by itself, the chamber changes the roll.
        XCTAssertTrue(app.buttons["Films"].waitForExistence(timeout: 5), "back at the camera")
        let loaded = app.buttons.matching(NSPredicate(format: "label == 'Change film' AND value == 'Cine 500T'")).firstMatch
        XCTAssertTrue(loaded.waitForExistence(timeout: 8), "the camera has the new roll")
        XCTAssertTrue(app.staticTexts["500T"].exists, "its name on the display")
    }
}
