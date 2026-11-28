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
        #expect(layout.bands.first!.frame.minY <= 0.5)   // no black bar on top
        #expect(layout.bands.last!.frame.maxY >= size.height - 0.5)   // nor at the bottom
        // The window is big and not stretched out of shape.
        #expect(layout.glass.width > size.width * 0.8)
        #expect(layout.glass.height >= layout.glass.width * 0.85 - 0.5)
        #expect(layout.glass.height <= layout.glass.width * 1.15 + 0.5)
    }

    @Test(arguments: screens) func controlsFitAndCanBeHit(size: CGSize) {
        let layout = UprightLayout(size: size)
        let parts = [layout.nameplate, layout.lastFrame, layout.lcd, layout.ev, layout.door, layout.shutter, layout.ribs] + layout.keys
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
        // The chamber is exactly what the door covers (user 11/28); the shutter
        // and its ribs stay on the body beside it. Each of the chamber's three
        // keys (a third of its height, 44 wide) is a 44-point target, and the
        // roll keeps some room beside them.
        #expect(layout.chamber == layout.door)
        #expect(!layout.chamber.intersects(layout.shutter) && !layout.chamber.intersects(layout.ribs))
        #expect(layout.ribs.minY >= layout.shutter.maxY)
        #expect(layout.chamber.height / 3 >= 44 - 0.01)
        #expect(layout.chamber.width - 44 >= 60)
        // The last picture is big enough to see (user 11/28: it was 46 × 30).
        #expect(layout.lastFrame.width >= 60 && layout.lastFrame.height >= 45)
        // The body runs to the top; a ring round the island where there is one.
        #expect((layout.islandRing != nil) == UprightLayout.hasIsland(size))
        if let ring = layout.islandRing { #expect(ring.maxY < layout.glass.minY) }
    }

    @Test func finderMarksThePicturesFrame() {
        let sensor = CGSize(width: 300, height: 400)
        let wide = UprightFinderFrame.frame(in: sensor, square: false)
        #expect(abs(wide.width - 400.0 * 2 / 3) < 0.01 && wide.height == 400)
        #expect(UprightFinderFrame.frame(in: sensor, square: true) == CGSize(width: 300, height: 300))
    }
    /// The front sensor's mounting, from two rotation angles: a quarter turn in 0..<360.
    @Test func frontMountTurnIsAQuarterTurn() {
        #expect(CameraService.mountTurn(front: 90, back: 90) == 0)
        #expect(CameraService.mountTurn(front: 0, back: 90) == 270)
        #expect(CameraService.mountTurn(front: 180, back: 90) == 90)
        #expect(CameraService.mountTurn(front: 270, back: 0) == 270)
        #expect(CameraService.mountTurn(front: 89.6, back: 0) == 90)
    }

    /// Held upright, the upright body's selfie flips across the frame's other
    /// axis (its finder shows the frame turned a quarter); sideways, as before.
    /// iPhone Duo always keeps the flip it was checked with.
    @Test func frontMirrorFollowsTheHold() {
        #expect(CameraModel.frontMirror(hold: .right, uprightBody: true) == .downMirrored)
        #expect(CameraModel.frontMirror(hold: .left, uprightBody: true) == .downMirrored)
        #expect(CameraModel.frontMirror(hold: .up, uprightBody: true) == .upMirrored)
        #expect(CameraModel.frontMirror(hold: .down, uprightBody: true) == .upMirrored)
        for hold in [CGImagePropertyOrientation.right, .left, .up, .down] {
            #expect(CameraModel.frontMirror(hold: hold, uprightBody: false) == .upMirrored)
        }
    }

    /// Shut, the door's window shows the roll lying across behind it (user
    /// 11/27: only half showed): its whole body from end to end, the window
    /// on its middle, on every upright phone, dark and light body.
    @MainActor @Test func doorWindowShowsTheWholeRoll() {
        for size in [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)] {
            let layout = UprightLayout(size: size)
            for light in [false, true] {
                let window = UprightCameraBody.doorWindow(layout, light: light).rect
                let roll = FilmChamber.compactRoll(in: layout.chamber.size, window: UprightCameraBody.rollWindow(layout, light: light))
                    .offsetBy(dx: layout.chamber.minX, dy: layout.chamber.minY)
                // The roll's body: its cradle less the end caps.
                let body = roll.insetBy(dx: roll.width * (1 - FilmChamber.rollBody) / 2, dy: 0)
                #expect(body.minX >= window.minX - 1 && body.maxX <= window.maxX + 1,
                        "\(size) light \(light): body \(body.minX)...\(body.maxX), window \(window.minX)...\(window.maxX)")
                #expect(body.width >= window.width * 0.8, "\(size) light \(light): the roll fills the window")
                #expect(roll.minY <= window.minY + 1 && roll.maxY >= window.maxY - 1, "\(size) light \(light): the window is on the roll")
            }
        }
    }

    /// Only phones with a Dynamic Island get the ring; notched ones and the SE don't.
    @Test func islandRingOnlyRoundAnIsland() {
        let island = [(393.0, 852.0), (402, 874), (420, 912), (430, 932), (440, 956)]
        let none = [(375.0, 667.0), (375, 812), (414, 896), (390, 844), (428, 926)]
        for (w, h) in island { #expect(UprightLayout(size: CGSize(width: w, height: h)).islandRing != nil, "\(w)×\(h)") }
        for (w, h) in none { #expect(UprightLayout(size: CGSize(width: w, height: h)).islandRing == nil, "\(w)×\(h)") }
    }
}
