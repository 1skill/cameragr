import XCTest

/// Real touches on the open bag (the flat inner screen): a page drawn over
/// another must never take the touches meant for the rolls under it.
final class BagTouchTests: XCTestCase {
    /// The page window shows one name: a tap at its right end turns on, its left end back.
    static func turn(_ app: XCUIApplication, _ steps: Int) {
        let dial = app.descendants(matching: .any)["page-dial"]
        XCTAssertTrue(dial.waitForExistence(timeout: 15), "the page window")
        // The bag is drawn turned on an upright screen: the window's long side may run up and down.
        let tall = dial.frame.height > dial.frame.width
        for _ in 0..<abs(steps) {
            let end: CGFloat = steps > 0 ? 0.9 : 0.1
            dial.coordinate(withNormalizedOffset: tall ? CGVector(dx: 0.5, dy: 1 - end) : CGVector(dx: end, dy: 0.5)).tap()
            sleep(1)
        }
    }

    private func openBag() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-fold", "flat", "-look", "portra400", "-AppleLanguages", "(en)", "-dailyFree", "off"]
        app.launch()
        return app
    }

    func testTappingARollPutsItOnTheCard() {
        let app = openBag()
        let roll = app.buttons["Golden 200"]
        XCTAssertTrue(roll.waitForExistence(timeout: 15))
        // The name may be elsewhere too (the community page's film rooms): the card adds one more.
        let named = app.staticTexts.matching(identifier: "Golden 200")
        let before = named.count
        roll.tap()
        let more = NSPredicate { _, _ in named.count > before }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: more, object: nil)], timeout: 5), .completed,
                       "the tapped roll's card")
    }

    func testRollsStillAnswerAfterTurningToTheKitAndBack() {
        let app = openBag()
        Self.turn(app, 2)   // films → community → settings
        XCTAssertTrue(app.buttons["Restore purchases"].waitForExistence(timeout: 5))
        Self.turn(app, -2)
        let roll = app.buttons["Cine 500T"]
        XCTAssertTrue(roll.waitForExistence(timeout: 5))
        roll.tap()
        XCTAssertTrue(app.staticTexts["Cine 500T"].waitForExistence(timeout: 5))
    }

    /// The kit's left page, set a little smaller above the page selector:
    /// its buttons still answer where they are drawn.
    func testTheKitButtonsAnswerAboveThePageSelector() {
        let app = openBag()
        Self.turn(app, 2)
        let restore = app.buttons["Restore purchases"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        XCTAssertTrue(restore.isHittable)
        restore.tap()
        XCTAssertTrue(app.staticTexts["Restoring…"].waitForExistence(timeout: 3)
                      || app.buttons["Restoring…"].exists
                      || app.staticTexts["The App Store could not be reached. Try again later."].waitForExistence(timeout: 10)
                      || app.staticTexts["No other purchases on this Apple ID."].exists,
                      "the tap reached the restore button")
        Self.turn(app, -2)
        XCTAssertTrue(app.buttons["Cine 500T"].waitForExistence(timeout: 5))
    }

    /// Over the closed camera (any iPhone): the bag opens, its rolls answer,
    /// and its clasp closes it.
    func testTheBagOverTheCameraOpensAndClosesWithItsClasp() {
        let app = XCUIApplication()
        app.launchArguments = ["-openBag", "films", "-AppleLanguages", "(en)", "-dailyFree", "off"]
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

    /// The first row (Porto 400, Golden 200) answers like the others, on the
    /// small bag over the camera and on the open inner screen.
    func testTheFirstRowAnswersOnBothScreens() {
        for args in [["-openBag", "films"], ["-fold", "flat", "-look", "cine500t"]] {
            let app = XCUIApplication()
            app.launchArguments = args + ["-AppleLanguages", "(en)", "-dailyFree", "off"]
            app.launch()
            for name in ["Golden 200", "Porto 400"] {
                let roll = app.buttons[name]
                guard roll.waitForExistence(timeout: 15) else { XCTFail("\(name) missing \(args)"); continue }
                roll.tap()
                XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), "\(name) on the card \(args)")
            }
            app.terminate()
        }
    }

    /// Free shots used up: the finder's "choose another roll" opens the bag.
    func testUsedUpRollOffersAnotherRoll() {
        let app = XCUIApplication()
        app.launchArguments = ["-film", "portra400", "-usedUp", "1", "-AppleLanguages", "(en)", "-dailyFree", "off"]
        app.launch()
        let other = app.buttons["Choose another roll"]
        XCTAssertTrue(other.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Buy it'")).firstMatch.exists)
        other.tap()
        XCTAssertTrue(app.buttons["Golden 200"].waitForExistence(timeout: 5), "the bag is open")
    }
}
