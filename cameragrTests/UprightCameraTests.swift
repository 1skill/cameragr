import Testing
import ImageIO
import CoreGraphics
@testable import cameragr

/// The upright body on iPhones that don't fold: which way up the phone is
/// held, and the body filling each screen.
struct UprightCameraTests {
    /// Gravity at `degrees` (atan2(y, x) in the device's axes), 1 g.
    private func g(_ degrees: Double) -> (Double, Double) {
        (cos(degrees * .pi / 180), sin(degrees * .pi / 180))
    }

    @Test func clearHoldsAreRead() {
        let (ux, uy) = g(-90)
        #expect(HoldRule.next(.up, x: ux, y: uy) == .right)        // upright
        let (lx, ly) = g(180)
        #expect(HoldRule.next(.right, x: lx, y: ly) == .up)        // top to the left
        let (rx, ry) = g(0)
        #expect(HoldRule.next(.right, x: rx, y: ry) == .down)      // top to the right
        let (dx, dy) = g(90)
        #expect(HoldRule.next(.right, x: dx, y: dy) == .left)      // upside down
    }

    @Test func holdKeepsThroughTheDiagonal() {
        // Upright is -90°. Turning toward the left landscape (180°): the
        // diagonal (-135°) and 15° past it keep upright; further changes.
        for angle in [-120.0, -135, -149] {
            let (x, y) = g(angle)
            #expect(HoldRule.next(.right, x: x, y: y) == .right, "at \(angle)°")
        }
        let (x, y) = g(-152)
        #expect(HoldRule.next(.right, x: x, y: y) == .up)
        // And back: landscape keeps until 15° past the diagonal the other way.
        let (bx, by) = g(-122)
        #expect(HoldRule.next(.up, x: bx, y: by) == .up)
        let (cx, cy) = g(-118)
        #expect(HoldRule.next(.up, x: cx, y: cy) == .right)
    }

    @Test func lyingFlatKeepsTheLastHold() {
        #expect(HoldRule.next(.up, x: 0.1, y: -0.2) == nil)
        #expect(HoldRule.next(.right, x: 0.4, y: 0.4) == nil)
    }

    @Test func labelsTurnToReadUpright() {
        #expect(HoldRule.uprightTurn(.right) == 0)
        #expect(HoldRule.uprightTurn(.up) == 90)
        #expect(HoldRule.uprightTurn(.down) == -90)
        #expect(HoldRule.uprightTurn(.left) == 180)
    }

    /// iPhone SE, 17 Pro, 17 Pro Max (points).
    static let screens = [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874),
                          CGSize(width: 440, height: 956)]

    @Test(arguments: screens) func bodyFillsTheScreen(size: CGSize) {
        let layout = UprightLayout(size: size)
        // The plate's bands run on without gaps or overlaps, from the top
        // band down past the body's end: no black bar inside the body.
        for (a, b) in zip(layout.bands, layout.bands.dropFirst()) {
            #expect(abs(a.frame.maxY - b.frame.minY) < 0.5)
            #expect(a.frame.height >= 0)
        }
        #expect(layout.bands.allSatisfy { $0.frame.width == size.width })
        #expect(layout.bands.last!.frame.maxY >= layout.bodyEnd)
        #expect(layout.bands.first!.frame.minY <= 59)
        // The window is big and not stretched out of shape.
        #expect(layout.glass.width > size.width * 0.8)
        #expect(layout.glass.height >= layout.glass.width * 0.85 - 0.5)
        #expect(layout.glass.height <= layout.glass.width * 1.15 + 0.5)
    }

    @Test(arguments: screens) func controlsFitAndCanBeHit(size: CGSize) {
        let layout = UprightLayout(size: size)
        let parts = [layout.nameplate, layout.lcd, layout.ev, layout.door, layout.shutter] + layout.keys
        // Everything below the window and above the body's end, on the body.
        for part in parts {
            #expect(part.minY >= layout.glass.maxY)
            #expect(part.maxY <= layout.bodyEnd)
            #expect(part.minX >= 0 && part.maxX <= size.width)
        }
        // Rows don't overlap.
        #expect(layout.nameplate.maxY <= layout.lcd.minY)
        #expect(layout.lcd.maxY <= layout.keys[0].minY)
        #expect(layout.keys[0].maxY <= layout.door.minY)
        #expect(!layout.door.intersects(layout.shutter))
        // Touch targets: at least 44 points.
        for key in layout.keys { #expect(key.height >= 39.6 && key.width >= 44) }
        #expect(layout.shutter.width >= 88)
        #expect(layout.door.height >= 110)
    }

    @Test func finderMarksThePicturesFrame() {
        let sensor = CGSize(width: 300, height: 400)
        let wide = UprightFinderFrame.frame(in: sensor, square: false)
        #expect(abs(wide.width - 400.0 * 2 / 3) < 0.01 && wide.height == 400)
        #expect(UprightFinderFrame.frame(in: sensor, square: true) == CGSize(width: 300, height: 300))
    }
}
