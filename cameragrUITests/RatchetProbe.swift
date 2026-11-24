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
        let lead = pitch * 20 / 182
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
