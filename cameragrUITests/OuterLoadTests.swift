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

extension OuterLoadTests {
    /// Looking at the last picture, then changing the roll: the finder goes
    /// back to the scene (user 11/24: it stayed on the picture).
    func testChangingTheRollLeavesTheLastPicture() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-dailyFree", "off"]
        app.launch()
        let shutter = app.buttons["Shutter"]
        if shutter.waitForExistence(timeout: 15) { shutter.tap(); sleep(3) }
        let last = app.buttons["Show the last picture"]
        XCTAssertTrue(last.waitForExistence(timeout: 10))
        if last.isEnabled { last.tap(); sleep(1) }
        XCTAssertTrue(app.staticTexts["PLAY"].exists, "looking at the last picture")
        app.buttons["Films"].tap()
        let roll = app.buttons["Cine 500T"]
        XCTAssertTrue(roll.waitForExistence(timeout: 10))
        roll.tap()
        let tag = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'try it' OR label CONTAINS[c] 'load this roll'")).firstMatch
        XCTAssertTrue(tag.waitForExistence(timeout: 5))
        tag.tap()
        XCTAssertTrue(app.staticTexts["500T"].waitForExistence(timeout: 8), "the new roll on the display")
        XCTAssertFalse(app.staticTexts["PLAY"].exists, "back to the scene, not the last picture")
    }
}

extension OuterLoadTests {
    /// A roll chosen, then another chosen while the first is still going in:
    /// the camera ends with the last one chosen.
    func testChoosingAgainWhileTheRollGoesIn() {
        let app = XCUIApplication()
        app.launchArguments = ["-openBag", "films", "-chamberSlow", "4", "-AppleLanguages", "(en)", "-dailyFree", "off"]
        app.launch()
        func choose(_ name: String) {
            let roll = app.buttons[name]
            XCTAssertTrue(roll.waitForExistence(timeout: 15), name)
            roll.tap()
            let tag = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'try it' OR label CONTAINS[c] 'load this roll'")).firstMatch
            XCTAssertTrue(tag.waitForExistence(timeout: 5), "\(name)'s tag")
            tag.tap()
        }
        choose("Cine 500T")
        let films = app.buttons["Films"]
        XCTAssertTrue(films.waitForExistence(timeout: 5))
        // Still changing (drawn out four times): Cine 500T isn't in yet.
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label == 'Change film' AND value == 'Cine 500T'")).firstMatch.exists,
                       "the first roll is still on its way in")
        films.tap()   // straight back, while the chamber still changes the roll
        choose("Golden 200")
        let loaded = app.buttons.matching(NSPredicate(format: "label == 'Change film' AND value == 'Golden 200'")).firstMatch
        let ok = loaded.waitForExistence(timeout: 20)
        if !ok { print("FINAL " + app.buttons.matching(identifier: "Change film").debugDescription) }
        XCTAssertTrue(ok, "the last roll chosen is the one in the camera")
    }
}
