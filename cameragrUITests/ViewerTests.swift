import XCTest

/// The community's picture viewer (retro 10 P0-3): its ⋯ bubble is easy to
/// hit, a double tap goes full screen and there likes, a swipe goes on.
final class ViewerTests: XCTestCase {
    private func open(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-fold", "flat", "-look", "portra400", "-club", "1", "-clubView", "1",
                               "-AppleLanguages", "(en)", "-dailyFree", "off"] + extra
        app.launch()
        return app
    }

    func testBubbleItemsAreFullSizeToHit() {
        let app = open(["-clubMenu", "post"])
        let report = app.buttons["Report"]
        XCTAssertTrue(report.waitForExistence(timeout: 15))
        let f = report.frame
        XCTAssertGreaterThanOrEqual(min(f.width, f.height), 43, "44 points to hit (\(f))")
        XCTAssertTrue(report.isHittable)
    }

    func testDoubleTapGoesFullScreenThenLikes() {
        let app = open()
        let picture = app.descendants(matching: .any)["viewer-picture"]
        XCTAssertTrue(picture.waitForExistence(timeout: 15))
        sleep(1)
        picture.doubleTap()
        XCTAssertTrue(app.buttons["Exit Full Screen"].waitForExistence(timeout: 3), "full screen")
        XCTAssertTrue(app.staticTexts["215"].exists, "the card's double tap went full screen, it didn't like")
        let full = app.descendants(matching: .any)["viewer-picture"]
        full.doubleTap()
        XCTAssertTrue(app.staticTexts["216"].waitForExistence(timeout: 3), "liked: 216")
        sleep(1)
        full.doubleTap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["216"].exists, "a second double tap doesn't take the like back")
        XCTAssertTrue(app.buttons["Exit Full Screen"].exists, "nor leave full screen")
        app.buttons["Exit Full Screen"].tap()
        XCTAssertTrue(app.buttons["Full Screen"].waitForExistence(timeout: 3), "back to the card")
    }

    func testSwipeGoesToAnotherPicture() {
        let app = open()
        let author = app.staticTexts["viewer-author"]
        XCTAssertTrue(author.waitForExistence(timeout: 15))
        let first = author.label
        let picture = app.descendants(matching: .any)["viewer-picture"]
        // The bag is drawn turned on the simulator's upright screen: try each way.
        let mid = picture.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        for (dx, dy) in [(-0.4, 0.0), (0.0, -0.4), (0.0, 0.4), (0.4, 0.0)] {
            mid.press(forDuration: 0.05, thenDragTo: picture.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + dx, dy: 0.5 + dy)))
            sleep(1)
            if app.staticTexts["viewer-author"].label != first { return }
        }
        XCTFail("no swipe went to another picture")
    }

    /// Zoomed in, a drag moves about the picture; it doesn't turn to the next.
    func testZoomedDragDoesNotTurn() {
        let app = open()
        let author = app.staticTexts["viewer-author"]
        XCTAssertTrue(author.waitForExistence(timeout: 15))
        let first = author.label
        let picture = app.descendants(matching: .any)["viewer-picture"]
        picture.pinch(withScale: 2.5, velocity: 2)
        sleep(1)
        let mid = picture.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        for (dx, dy) in [(-0.4, 0.0), (0.0, -0.4), (0.0, 0.4), (0.4, 0.0)] {
            mid.press(forDuration: 0.05, thenDragTo: picture.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + dx, dy: 0.5 + dy)))
            sleep(1)
            XCTAssertEqual(app.staticTexts["viewer-author"].label, first, "zoomed: still the same picture")
        }
    }
}
