import CoreMotion
import ImageIO

/// Which way up the phone is held, decided from gravity. Pure, so it can be tested.
enum HoldRule {
    /// Below this much gravity in the screen's plane the phone is lying (nearly)
    /// flat: the reading says nothing and the last one stands.
    static let flatBelow = 0.6
    /// How far past the halfway line (45°) the phone has to turn before the
    /// hold changes: the band between two holds is twice this wide (~30°), so
    /// a phone held near the diagonal doesn't flicker between them.
    static let hysteresis = 15.0

    /// The hold after a gravity reading (`x`, `y` in the device's own axes, in g),
    /// given the hold so far. `nil` when lying flat: keep the last one.
    static func next(_ current: CGImagePropertyOrientation, x: Double, y: Double) -> CGImagePropertyOrientation? {
        guard max(abs(x), abs(y)) > flatBelow else { return nil }
        let angle = atan2(y, x) * 180 / .pi
        func distance(to hold: CGImagePropertyOrientation) -> Double {
            let d = abs(angle - gravityAngle(hold)).truncatingRemainder(dividingBy: 360)
            return min(d, 360 - d)
        }
        // Stays while within 45° + the margin of its own direction.
        if distance(to: current) <= 45 + hysteresis, [.up, .down, .left, .right].contains(current) { return current }
        return [CGImagePropertyOrientation.right, .up, .down, .left].min { distance(to: $0) < distance(to: $1) }
    }

    /// Where gravity points (degrees, atan2(y, x) in the device's axes) for each hold.
    /// Gravity along -x is the landscape interface's own way up; along -y upright portrait.
    static func gravityAngle(_ hold: CGImagePropertyOrientation) -> Double {
        switch hold {
        case .up: 180      // (-1, 0)
        case .down: 0      // (1, 0)
        case .right: -90   // (0, -1): upright
        case .left: 90     // (0, 1): upside down
        default: -90
        }
    }

    /// How far (degrees clockwise on the screen) a label on the upright body
    /// turns so it reads upright for this hold.
    static func uprightTurn(_ hold: CGImagePropertyOrientation) -> Double {
        switch hold {
        case .up: 90       // top of the phone to the left: the viewer's up is the screen's right
        case .down: -90
        case .left: 180
        default: 0
        }
    }
}

/// Tells which way up the phone is being held, from gravity. The interface
/// doesn't turn with the phone (landscape on iPhone Duo, portrait on other
/// iPhones), so this is the only way to know how a shot was held.
/// (The system's own device orientation stops updating under rotation lock.)
final class HoldSensor {
    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    private let lock = NSLock()
    private var current: CGImagePropertyOrientation = .up
    /// Called (on a background queue) when the hold changes.
    var onChange: ((CGImagePropertyOrientation) -> Void)?

    init() {
        #if DEBUG
        // `-hold up|down|left|right`: a fixed hold for UI checks.
        if let forced = Self.forced { current = forced }
        #endif
    }

    #if DEBUG
    static let forced: CGImagePropertyOrientation? = {
        switch UserDefaults.standard.string(forKey: "hold") {
        case "up": .up
        case "down": .down
        case "left": .left
        case "right": .right
        default: nil
        }
    }()
    #endif

    /// How a frame in the interface's landscape orientation has to be turned
    /// so that what was up in the scene is up in the picture.
    var orientation: CGImagePropertyOrientation {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func start() {
        #if DEBUG
        if let forced = Self.forced { onChange?(forced); return }
        #endif
        guard motion.isAccelerometerAvailable, !motion.isAccelerometerActive else { return }
        motion.accelerometerUpdateInterval = 0.2
        var told = false   // the first clear reading is always told, even unchanged
        motion.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
            guard let self, let a = data?.acceleration else { return }
            self.lock.lock()
            let next = HoldRule.next(self.current, x: a.x, y: a.y)
            let changed = next != nil && (next != self.current || !told)
            if let next { self.current = next; told = true }
            self.lock.unlock()
            if changed, let next { self.onChange?(next) }
        }
    }

    func stop() {
        motion.stopAccelerometerUpdates()
    }
}
