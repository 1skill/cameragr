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

    init(mode: FoldMode = .closed) { self.mode = mode }

    /// A new reading at time `t`. Returns true if the mode changed.
    @discardableResult
    mutating func read(_ reading: HingeReading, at t: TimeInterval) -> Bool {
        let target: FoldMode
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

    /// Lets time pass. Returns true if the mode changed.
    @discardableResult
    mutating func tick(at t: TimeInterval) -> Bool {
        guard let candidate, !holdForShot, t - since >= wait(to: candidate) else { return false }
        mode = candidate
        self.candidate = nil
        return true
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
