import UIKit

/// A view controller that holds its content in one place on the glass
/// (`FixedToPhone.Controller`).
protocol GlassPinned: UIViewController {
    /// Where its content's frame sits on the glass: degrees clockwise from
    /// the screen's fixed coordinate space.
    var turnOnGlass: Double { get }
    /// Its window shares the screen (Split View, Slide Over): no place on the glass.
    var sharesScreen: Bool { get }
}

/// Which one way up the interface is to be, so that the swipe home is always
/// along the bottom edge of what is drawn on the glass, however the phone is
/// held and whatever the rotation lock says (user 11/27).
///
/// Every layout is fixed to the glass (`FixedToPhone`), each with its own
/// place there. The one in front says where the picture's bottom edge is; the
/// interface is given only the orientation whose bottom is that edge. A single
/// orientation is outside any rotation lock, so the system turns to it, as for
/// a landscape-only game; the content is held still on the glass while it does.
///
/// Orientation names and the glass: on a plain screen the interface's x axis
/// lies along the fixed space's +x in portrait, +y in landscapeRight, and so
/// on a quarter turn clockwise each (measured on the Duo's outer screen in the
/// simulator: landscapeRight, lie 90). A folding phone's inner screen may name
/// them from the phone's body instead, a quarter or a half turn off, so the
/// difference is measured on each screen (`learn`) and kept.
enum GlassSide {
    private final class Entry { weak var controller: GlassPinned?; init(_ c: GlassPinned) { controller = c } }
    private static var shown: [Entry] = []
    /// The screen the interface was last on.
    private static var lastScreen: CGSize?

    /// The pinned layouts on screen, the last in front.
    static var front: GlassPinned? {
        shown.removeAll { $0.controller == nil || $0.controller?.viewIfLoaded?.window == nil }
        return shown.last?.controller
    }

    static func appeared(_ c: GlassPinned) {
        let before = front.map(ObjectIdentifier.init)
        shown.removeAll { $0.controller === c }
        shown.append(Entry(c))
        if before != ObjectIdentifier(c) { changed("appeared \(c.turnOnGlass)") }
    }

    static func disappeared(_ c: GlassPinned) {
        // Read before anything is tidied away: by now its window may be gone.
        let top = shown.last?.controller
        let wasFront = top === c || top == nil
        shown.removeAll { $0.controller === c || $0.controller == nil }
        if wasFront { changed("gone \(c.turnOnGlass), front now \(front.map { "\($0.turnOnGlass)" } ?? "none")") }
    }

    private static func changed(_ why: String) {
        Diag.note("glass: \(why)")
        Posture.shared.askAgain()
    }

    // MARK: Which way up

    /// The kind of screen, by its size in points.
    enum Screen {
        /// An iPhone that doesn't fold (every one is under 450 points across).
        case plain
        /// An iPhone Duo's outer screen (466 across): the closed body.
        case outer
        /// An iPhone Duo's inner screen (669 across).
        case inner

        init(_ size: CGSize) {
            let short = min(size.width, size.height)
            self = short > 600 ? .inner : short > 450 ? .outer : .plain
        }
    }

    /// Where the bottom of what is shown should be, in degrees clockwise on the
    /// glass, or nil when any way up will do.
    static func wantedLie(onScreen size: CGSize) -> Double? {
        if let front {
            return front.sharesScreen ? nil : norm(front.turnOnGlass)
        }
        // Before any layout is up (the first question at launch): what each
        // screen opens on. The inner screen waits for the hinge, in black.
        switch Screen(size) {
        case .plain: return 0                                  // the upright body
        case .outer: return norm(FoldLayout.bodyTurnOnGlass)   // the closed body
        case .inner: return nil
        }
    }

    /// The ways up the interface may be on that screen just now.
    static func mask(onScreen screen: CGSize?) -> UIInterfaceOrientationMask {
        // Asked while the window is not on a screen (coming back from the
        // background, user 11/27: the swipe home was the narrow edge again):
        // the screen it was last on, not any way up.
        if let screen { lastScreen = screen }
        guard let size = screen ?? lastScreen, let lie = wantedLie(onScreen: size) else { return .all }
        let way = orientation(forLie: lie, onScreen: size)
        // No iPhone without a home button turns its interface upside down:
        // asking for only that would leave nothing to turn to.
        if way == .portraitUpsideDown { return .all }
        return mask(way)
    }

    static func mask(_ way: UIInterfaceOrientation) -> UIInterfaceOrientationMask {
        switch way {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .all
        }
    }

    /// The orientation whose interface lies at that turn on the glass.
    static func orientation(forLie lie: Double, onScreen size: CGSize) -> UIInterfaceOrientation {
        named(norm(lie - offset(onScreen: size)))
    }

    /// The open bag's place on the inner screen. Held like a book the right
    /// way up (gravity toward the phone's own bottom, `Posture.heldFlipped`
    /// false), its bottom is the inner screen's right-hand edge, upright:
    /// measured with gravity, upright hinge level reads x < 0 and upright like
    /// a book y < 0, so the phone's bottom is the fixed space's +x. That is the
    /// layout turned 270°. It does not turn with the hold (user 11/27): one
    /// side, the swipe home along its bottom. Should that be the one
    /// orientation the system won't give, the other side.
    static func bagTurn(onScreen size: CGSize) -> Double {
        orientation(forLie: 270, onScreen: size) == .portraitUpsideDown ? 90 : 270
    }

    // MARK: Names against the glass

    /// The orientation named for an interface lying at that turn on a plain screen.
    private static func named(_ lie: Double) -> UIInterfaceOrientation {
        switch Int(norm(lie)) {
        case 90: return .landscapeRight
        case 180: return .portraitUpsideDown
        case 270: return .landscapeLeft
        default: return .portrait
        }
    }

    private static func plainLie(_ way: UIInterfaceOrientation) -> Double? {
        switch way {
        case .portrait: return 0
        case .landscapeRight: return 90
        case .portraitUpsideDown: return 180
        case .landscapeLeft: return 270
        default: return nil
        }
    }

    private static func key(_ size: CGSize) -> String {
        "glassOffset.\(Int(min(size.width, size.height).rounded()))x\(Int(max(size.width, size.height).rounded()))"
    }

    /// How far this screen's names are turned from a plain screen's (0 until measured).
    static func offset(onScreen size: CGSize) -> Double {
        UserDefaults.standard.object(forKey: key(size)) == nil ? 0 : norm(UserDefaults.standard.double(forKey: key(size)))
    }

    private static var pending: (key: String, offset: Double, at: Double)?

    /// A layout settled on the glass: the interface lies at `lie` and the
    /// system names it `reported`, the one way up it was asked for. A new difference is taken once it has been
    /// seen twice a moment apart (a reading in the middle of a move between
    /// screens must not count), then the system is asked again.
    static func learn(lie: Double, reported: UIInterfaceOrientation, onScreen size: CGSize) {
        guard let plain = plainLie(reported) else { return }
        // Only once the system names the interface as it was asked to be: at
        // launch the window has turned while the name still says portrait
        // (seen in the simulator, a 678×466 window named portrait).
        guard let wanted = wantedLie(onScreen: size), orientation(forLie: wanted, onScreen: size) == reported else { return }
        let seen = norm(lie - plain), k = key(size)
        let known = UserDefaults.standard.object(forKey: k) != nil
        guard !known || offset(onScreen: size) != seen else { pending = nil; return }
        let now = ProcessInfo.processInfo.systemUptime
        // The first reading on a screen is taken at once: until then it was a guess.
        if known {
            guard let p = pending, p.key == k, p.offset == seen else { pending = (k, seen, now); return }
            guard now - p.at > 0.3 else { return }
        }
        pending = nil
        UserDefaults.standard.set(seen, forKey: k)
        Diag.note("glass: \(k) names are \(Int(seen))° off (\(reported.rawValue) lies at \(Int(lie)))")
        // Places that depend on the names (the open bag's side) are worked out again.
        Posture.shared.objectWillChange.send()
        if seen != 0 || known { Posture.shared.askAgain() }
    }

    /// How far, in degrees clockwise, a coordinate space's x axis is turned on the glass.
    static func lie(of space: UICoordinateSpace, on screen: UIScreen) -> Double {
        let origin = space.convert(CGPoint.zero, to: screen.fixedCoordinateSpace)
        let along = space.convert(CGPoint(x: 100, y: 0), to: screen.fixedCoordinateSpace)
        return norm(atan2(along.y - origin.y, along.x - origin.x) * 180 / .pi)
    }

    /// Where the system has the interface on the glass: its screen's
    /// interface-oriented space, which is what the swipe home follows. The
    /// window can disagree for a while (seen at launch in the simulator: a
    /// 678×466 window on a screen still portrait, the home bar portrait).
    static func systemLie(_ screen: UIScreen) -> Double {
        lie(of: screen.coordinateSpace, on: screen)
    }

    // MARK: Holding to it

    private static var retries = 0
    static func newOccasion() { retries = 0 }
    private static var retryTarget: Double?
    private static var checkPending = false

    /// After a layout settles: if the system's interface does not yet lie
    /// where it was asked to, asks again, a few times, a moment apart.
    static func check(_ window: UIWindow) {
        guard !checkPending, !CameraModel.isLockScreen else { return }
        checkPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak window] in
            checkPending = false
            guard let window, let scene = window.windowScene else { return }
            let size = scene.screen.bounds.size
            guard let wanted = wantedLie(onScreen: size) else { return }
            let way = orientation(forLie: wanted, onScreen: size)
            guard way != .portraitUpsideDown else { return }
            if retryTarget != wanted { retryTarget = wanted; retries = 0 }
            let lies = systemLie(scene.screen)
            guard lies != wanted else { retries = 0; return }
            guard retries < 4 else { return }
            retries += 1
            Diag.note("glass: system still \(scene.interfaceOrientation.rawValue) lying \(Int(lies)) (window \(Int(lie(of: window, on: scene.screen)))), want \(way.rawValue) at \(Int(wanted)): ask again (\(retries))")
            Posture.shared.askAgain(retry: true)
        }
    }

    static func norm(_ angle: Double) -> Double {
        let quarter = (angle / 90).rounded() * 90
        return (quarter.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: Record

    /// The last measured lie of the layout in front, for the record.
    static var frontLie: Double?
    private static var lastNote = ""

    /// Notes each question about the ways up when anything in it has changed.
    static func noteAsked(screen: CGSize?, mask: UIInterfaceOrientationMask, scene: UIWindowScene?) {
        #if DEBUG
        let s = screen.map { "\(Int($0.width))×\(Int($0.height))" } ?? "none"
        let line = "asked: screen \(s), mask \(describe(mask)), interface \(scene?.interfaceOrientation.rawValue ?? -1)"
            + ", device \(UIDevice.current.orientation.rawValue), front \(front.map { "\(Int($0.turnOnGlass))" } ?? "none")"
            + ", system lie \(scene.map { "\(Int(systemLie($0.screen)))" } ?? "?"), window lie \(frontLie.map { "\(Int($0))" } ?? "?"), offset \(screen.map { "\(Int(offset(onScreen: $0)))" } ?? "?")"
        guard line != lastNote else { return }
        lastNote = line
        Diag.note(line)
        #endif
    }

    static func describe(_ mask: UIInterfaceOrientationMask) -> String {
        switch mask {
        case .all: return "all"
        case .portrait: return "portrait"
        case .portraitUpsideDown: return "upsideDown"
        case .landscapeLeft: return "landscapeLeft"
        case .landscapeRight: return "landscapeRight"
        default: return "\(mask.rawValue)"
        }
    }
}
