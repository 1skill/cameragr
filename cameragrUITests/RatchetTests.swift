import XCTest

/// The roll belt is a ratchet (user 11/24): a flick, slow or fast, ends on a
/// stop where every row in view is whole, the far end included.
final class RatchetTests: XCTestCase {
    func testTheBeltComesToRestOnWholeRows() {
        let app = XCUIApplication()
        app.launchArguments = ["-fold", "flat", "-look", "portra400", "-AppleLanguages", "(en)", "-dailyFree", "off"]
        app.launch()
        let porto = app.buttons["Porto 400"], c200 = app.buttons["C200"]
        XCTAssertTrue(porto.waitForExistence(timeout: 15))
        // The inner screen's bag lies sideways in the simulator: rows run along x.
        let x0 = porto.frame.minX, pitch = c200.frame.minX - porto.frame.minX
        let lead: CGFloat = 0
        for (dx, speed) in [(-60.0, XCUIGestureVelocity.slow), (-300.0, .fast)] {
            let start = app.buttons["Golden 200"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.02, thenDragTo: start.withOffset(CGVector(dx: dx, dy: 0)), withVelocity: speed, thenHoldForDuration: 0)
            sleep(3)
            let moved = x0 - porto.frame.minX
            let rest = moved == 0 ? 0 : (moved - lead).truncatingRemainder(dividingBy: pitch)
            XCTAssertLessThan(min(abs(rest), abs(pitch - rest)), 3, "came to rest \(moved) pt in: not on a stop")
        }
    }
}

/// Pages turn by hand from their outer edges (user 11/24).
final class EdgeTurnTests: XCTestCase {
    func testDraggingTheRightEdgeTurnsOnAndTheLeftEdgeTurnsBack() {
        let app = XCUIApplication()
        app.launchArguments = ["-fold", "flat", "-look", "portra400", "-AppleLanguages", "(en)", "-dailyFree", "off"]
        app.launch()
        XCTAssertTrue(app.buttons["Porto 400"].waitForExistence(timeout: 15))
        let w = app.windows.firstMatch
        // The flat bag lies sideways in the simulator: the right page's outer
        // edge is along the top of the screen, the left page's along the bottom.
        func drag(from y0: CGFloat, to y1: CGFloat) {
            let a = w.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 180, dy: y0))
            a.press(forDuration: 0.05, thenDragTo: a.withOffset(CGVector(dx: 0, dy: y1 - y0)), withVelocity: .default, thenHoldForDuration: 0)
        }
        // Films → community → settings (user 11/24: community second).
        drag(from: 22, to: 330)
        XCTAssertTrue(app.buttons["Post"].waitForExistence(timeout: 5), "the right edge turned on to the community")
        drag(from: 22, to: 330)
        XCTAssertTrue(app.staticTexts["Koco handbook"].waitForExistence(timeout: 5), "and on again to the settings")
        let bottom = w.frame.height
        drag(from: bottom - 25, to: bottom - 330)
        drag(from: bottom - 25, to: bottom - 330)
        XCTAssertTrue(app.buttons["Cine 500T"].waitForExistence(timeout: 5), "the left edge turned back to the films")
    }
}
