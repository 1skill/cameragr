import CoreMotion
import ImageIO

/// Tells which way up the phone is being held, from gravity. The interface is
/// locked to landscape, so this is the only way to know a shot was taken upright.
/// (The system's own device orientation stops updating under rotation lock.)
final class HoldSensor {
    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    private let lock = NSLock()
    private var current: CGImagePropertyOrientation = .up

    /// How a frame in the interface's landscape orientation has to be turned
    /// so that what was up in the scene is up in the picture.
    var orientation: CGImagePropertyOrientation {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func start() {
        guard motion.isAccelerometerAvailable, !motion.isAccelerometerActive else { return }
        motion.accelerometerUpdateInterval = 0.2
        motion.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
            guard let self, let a = data?.acceleration else { return }
            // Lying flat (or nearly) says nothing: keep the last clear reading.
            guard max(abs(a.x), abs(a.y)) > 0.6 else { return }
            let reading: CGImagePropertyOrientation
            if abs(a.x) > abs(a.y) {
                // Gravity along -x is the interface's own landscape; +x is the other one.
                reading = a.x < 0 ? .up : .down
            } else {
                // Gravity along -y is upright portrait: the frame's left edge is up.
                reading = a.y < 0 ? .right : .left
            }
            self.lock.lock(); self.current = reading; self.lock.unlock()
        }
    }

    func stop() {
        motion.stopAccelerometerUpdates()
    }
}
