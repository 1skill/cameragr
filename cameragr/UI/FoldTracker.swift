import Foundation

/// What the folding phone is being used as.
enum FoldMode: String, Equatable, Sendable {
    /// Closed: the outer screen, the camera body.
    case closed
    /// Part way open: a waist-level finder, looked down into.
    case half
    /// Open flat: the film library, to look through the rolls and choose one.
    case flat
}

/// One reading of the hinge, as the system reports it (status only: the
/// angle's precision and rate are not promised, so nothing depends on it).
enum HingeReading: Equatable, Sendable {
    case closed, partial, full
    /// Unknown, or no hinge reported (the view left a screen that has one).
    case unknown
}

/// Turns hinge readings into a steady mode.
///
/// Closing acts at once. Anything else must hold for a while first, so that
/// passing through a state (opening a closed phone flat goes through
/// "partially open") or a small wobble of the hinge changes nothing. The
/// waist-level finder is sticky: it takes the longest steady "fully open" to
/// leave it for the library, and nothing but closing changes the mode while a
/// picture is being taken.
///
/// Pure logic, with times passed in, so every rule can be tested without a
/// hinge. `Posture` feeds it and calls `tick` at `nextDeadline`.
struct FoldTracker: Equatable {
    private(set) var mode: FoldMode
    /// A picture is being taken: hold the mode (closing still acts).
    var holdForShot = false

    /// Seconds a reading must hold before the mode follows it.
    struct Dwell: Equatable {
        var closedToHalf = 0.6
        var closedToFlat = 0.4
        var halfToFlat = 1.0
        var flatToHalf = 0.8
    }
    var dwell = Dwell()

    private var candidate: FoldMode?
    private var since: TimeInterval = 0
    /// No reading yet since launch. The first one is taken at once: the waits
    /// smooth out a hinge on the move, and at launch it is simply where it is.
    private(set) var awaitingFirstReading: Bool

    /// `awaitingFirstReading`: a tracker made at launch, whose first reading
    /// is the phone's state as it is, taken without waiting.
    init(mode: FoldMode = .closed, awaitingFirstReading: Bool = false) {
        self.mode = mode
        self.awaitingFirstReading = awaitingFirstReading
    }

    /// A new reading at time `t`. Returns true if the mode changed.
    @discardableResult
    mutating func read(_ reading: HingeReading, at t: TimeInterval) -> Bool {
        let target: FoldMode
        if awaitingFirstReading, reading != .unknown {
            awaitingFirstReading = false
            let first: FoldMode = reading == .closed ? .closed : (reading == .partial ? .half : .flat)
            candidate = nil
            guard first != mode else { return false }
            mode = first
            return true
        }
        switch reading {
        case .unknown: return false
        case .closed:
            candidate = nil
            guard mode != .closed else { return false }
            mode = .closed
            return true
        case .partial: target = .half
        case .full: target = .flat
        }
        if target == mode {
            candidate = nil
        } else if candidate != target {
            candidate = target
            since = t
        }
        return tick(at: t)
    }

    /// Takes `mode` at once, with no wait: the hinge has come to rest
    /// after opening from closed, and where it rests is plain.
    mutating func jump(to mode: FoldMode) {
        self.mode = mode
        candidate = nil
        awaitingFirstReading = false
    }

    /// Lets time pass. Returns true if the mode changed.
    @discardableResult
    mutating func tick(at t: TimeInterval) -> Bool {
        guard let candidate, !holdForShot, t - since >= wait(to: candidate) else { return false }
        mode = candidate
        self.candidate = nil
        return true
    }

    /// The mode to show, given which screen the interface is on.
    ///
    /// Measured on an iPhone Duo: the hinge's status can still read "closed"
    /// at 84° open, and the interface moves to the inner screen before the
    /// status changes. The screen, though, is never wrong: the inner one is
    /// only in use when the phone is open, the outer one only when closed. So
    /// the screen decides closed or open, and the hinge only half or flat.
    /// Closing from flat, the hinge reads "closed" (at about 83°) a moment
    /// before the outer screen takes over: the library stays until then
    /// rather than flicking to the waist-level finder. `showing` is the mode
    /// on screen now.
    func shown(onInnerScreen: Bool, showing: FoldMode = .closed) -> FoldMode {
        guard onInnerScreen else { return .closed }
        guard mode == .closed else { return mode }
        return showing == .flat ? .flat : .half
    }

    /// When a reading now waiting would take effect, if one is waiting.
    var nextDeadline: TimeInterval? {
        candidate.map { since + wait(to: $0) }
    }

    private func wait(to target: FoldMode) -> TimeInterval {
        switch (mode, target) {
        case (.closed, .half): dwell.closedToHalf
        case (.closed, .flat): dwell.closedToFlat
        case (.half, .flat): dwell.halfToFlat
        case (.flat, .half): dwell.flatToHalf
        default: 0
        }
    }
}
