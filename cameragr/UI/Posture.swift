import Combine
import CoreMotion
import SwiftUI
import UIKit

/// What a folding phone is doing: whether it is open, and which way up the
/// system currently has the interface. An ordinary phone always reads closed.
final class Posture: ObservableObject {
    static let shared = Posture()

    /// What the phone is being used as: closed (camera body), part way open
    /// (waist-level finder) or open flat (film library). Steadied by `FoldTracker`.
    @Published private(set) var mode: FoldMode = .closed
    /// On the inner screen before the hinge's first reading: what the phone
    /// is doing is not known yet, so nothing is drawn (no flash of the camera
    /// before the library). Over at the first reading, or after a moment.
    @Published private(set) var awaitingHinge = false
    /// This iPhone folds (an iPhone Duo): what the handbook tells depends on it.
    @Published private(set) var isFoldingPhone = false
    /// The hinge is open, part way or flat: the inner screen is in use.
    var isOpen: Bool { mode != .closed }
    /// Open flat, but the camera picked from the bag's page selector: the
    /// waist-level layout fills the inner screen (user 11/26). Ends with any
    /// change of the fold, so unfolding from closed or half opens the bag.
    @Published private(set) var flatCamera = false
    /// The film library (the bag) is what the screen shows.
    var showsLibrary: Bool { mode == .flat && !flatCamera }
    func setFlatCamera(_ on: Bool) {
        guard flatCamera != on, !on || mode == .flat else { return }
        flatCamera = on
    }
    private var tracker = FoldTracker(awaitingFirstReading: true)
    /// Debug: a mode given at launch, which hinge readings leave alone.
    private var forced = false
    /// The interface is on a folding phone's inner screen (see `FoldTracker.shown`).
    private var onInnerScreen = false

    /// The interface's size changed, or the hinge moved: tells the inner
    /// screen from the outer (`GlassSide.Screen`: the panels' fixed sizes and
    /// the hinge, never a range of window sizes; a scaled 469×669 window on the
    /// open phone was taken for the closed one, log diag-duo-1128-129).
    private var lastWindow: CGSize?
    func noteWindow(_ size: CGSize) {
        lastWindow = size
        // Asked of the screen the window is on, not of the window: sharing the
        // inner screen (Split View), the window is as narrow as the outer
        // screen (469 points), and was taken for it (user 11/24: the closed
        // body, upside down and cut, on half the open phone).
        let screen = host?.window?.windowScene?.screen.bounds.size ?? size
        let (kind, because) = GlassSide.Screen.identify(screen, hinge: lastReading)
        // A folding phone: its outer screen (466 points across) is already
        // wider than any other iPhone's (440 at most), and only it has a hinge.
        if kind != .plain, !isFoldingPhone { isFoldingPhone = true }
        let inner = kind == .inner
        guard inner != onInnerScreen else { return }
        let fromClosed = inner && mode == .closed && !tracker.awaitingFirstReading
        onInnerScreen = inner
        Diag.note("screen \(inner ? "inner" : "outer") \(screen.width)×\(screen.height), window \(size.width)×\(size.height), by \(because), hinge \(lastReading)")
        // The ways up the interface may be depend on the screen (AppDelegate).
        askAgain()
        if fromClosed, !forced { beginOpening() }
        if !inner, opening { opening = false }
        if inner, tracker.awaitingFirstReading, !forced {
            awaitingHinge = true
            layoutMoved = clock()
            // Never black for long, whatever fails to arrive.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in self?.reveal(force: true) }
        }
        noteShut()
        if !forced { settle() }
    }
    private var deadline: Timer?
    private let clock = { ProcessInfo.processInfo.systemUptime }
    @Published private(set) var orientation = UIInterfaceOrientation.landscapeRight

    private weak var host: UIView?
    private var timer: Timer?

    private init() {
        #if DEBUG
        // `-fold half|flat` (or `-open 1`, the same as half) pretends the phone
        // is open, for UI checks where no hinge exists.
        if UserDefaults.standard.bool(forKey: "open") { mode = .half }
        if let fold = UserDefaults.standard.string(forKey: "fold").flatMap(FoldMode.init(rawValue:)) { mode = fold }
        if mode == .flat, UserDefaults.standard.bool(forKey: "flatCamera") { flatCamera = true }   // `-fold flat -flatCamera 1`
        forced = mode != .closed   // the simulator's hinge reads closed: it must not undo this
        // Only a forced mode replaces the launch tracker (which takes the
        // first reading at once); a plain debug launch keeps it.
        if forced { tracker = FoldTracker(mode: mode) }
        #endif
    }

    /// Which way the open phone is held (user 11/24): with the hinge level,
    /// like a camera, it is a camera (the body and the finder, as part way
    /// open); with the hinge upright, like a book, it is the camera bag.
    /// Read from gravity, because the interface itself never turns. Measured
    /// on the iPhone Duo's inner screen: held like a book gravity lies along
    /// y (about -0.6…-0.8), turned a quarter it lies along x (about ±0.9).
    @Published private(set) var hingeLevel = false
    /// Held the other way up (turned a half turn from the way the layout is
    /// drawn): the open phone's content is turned over to stay upright.
    /// Measured: like a book, upright has gravity at y < 0; hinge level, at
    /// x < 0 (the first quarter turn from the book).
    @Published private(set) var heldFlipped = false
    /// The interface is on the inner screen.
    var isInner: Bool { onInnerScreen }
    /// Gravity has been read at least once (a launch can decide by it).
    private(set) var heldKnown = false
    private let motion = CMMotionManager()
    private var levelSince: Double?
    private var lastGravityNote = 0.0

    private func watchGravity() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let self, let g = m?.gravity else { return }
            let t = self.clock()
            // A quarter turn either way, held a moment; back the same way.
            let level = abs(g.x) > abs(g.y) + 0.25, book = abs(g.y) > abs(g.x) + 0.25
            let first = !self.heldKnown
            self.heldKnown = true
            if first, self.awaitingHinge {
                // Shown once the hold and the way up are both known (below).
                DispatchQueue.main.async { self.reveal() }
            }
            defer {
                // Which way up, along whichever axis gravity now lies (after the
                // hold is known, so a launch decides both at once: no turn on screen).
                let along = self.hingeLevel ? g.x : g.y
                if abs(along) > 0.5 {
                    let flipped = along > 0
                    if flipped != self.heldFlipped {
                        var quiet = Transaction(); quiet.disablesAnimations = true
                        withTransaction(quiet) { self.heldFlipped = flipped }
                        Diag.note("held \(flipped ? "the other way up" : "upright")")
                    }
                }
            }
            if (level && !self.hingeLevel) || (book && self.hingeLevel) {
                if first { self.hingeLevel = level; self.settle(); return }
                if let since = self.levelSince {
                    if t - since > 0.35 {
                        self.hingeLevel = level
                        self.levelSince = nil
                        Diag.note("held \(level ? "hinge level: camera" : "like a book: bag")")
                        self.settle()
                    }
                } else { self.levelSince = t }
            } else {
                self.levelSince = nil
                if first { self.settle() }
            }
        }
    }


    /// Starts reading the hinge through `view`, which has to be in the interface.
    func attach(to view: UIView) {
        watchGravity()
        guard host !== view else { return }
        host = view
        if let size = view.window?.bounds.size { noteWindow(size) }
        if #available(iOS 27.1, *) {
            view.addInteraction(UIHingeInteraction { [weak self] _, update in
                let reading: HingeReading
                switch update.hinge?.status {
                case .closed: reading = .closed
                case .partiallyOpen: reading = .partial
                case .fullyOpen: reading = .full
                default: reading = .unknown
                }
                // The probe for tuning the waits: every reading, with the
                // angle the system gives (not relied on, only recorded).
                Diag.note(String(format: "hinge %@ angle %.1f°", "\(reading)",
                                 (update.hinge?.angle ?? .nan) * 180 / .pi))
                self?.read(reading, angle: update.hinge.map { Double($0.angle) * 180 / .pi })
            })
        }
        // The interface's orientation has no change notice that also covers a
        // half turn (the window keeps its size), so it is simply looked at.
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.look() }
        look()
    }

    /// A picture is being taken: the mode holds (closing still acts).
    func holdForShot(_ hold: Bool) {
        tracker.holdForShot = hold
        if !hold { settle() }
    }

    /// The phone is shut all the way: the hinge reads closed at (nearly) no
    /// angle and the interface is on the outer screen. Measured: the status
    /// alone can say "closed" at 84°, and the outer screen takes over while
    /// the phone is still closing, before anyone can see it.
    @Published private(set) var isShut = false
    private var lastReading: HingeReading = .unknown
    private var lastAngle: Double?

    private func noteShut() {
        let closedOutside = !onInnerScreen && lastReading == .closed
        let shut = closedOutside && (lastAngle.map { $0 < 8 } ?? true)
        if shut != isShut {
            isShut = shut
            Diag.note("shut \(shut)")
        }
        // If readings ever stop short of 0° on the phone, this is where a
        // fallback goes, designed from the recorded readings (Diag), not guessed.
    }

    private func read(_ reading: HingeReading, angle: Double? = nil) {
        lastReading = reading
        GlassSide.hinge = reading
        if reading != .unknown, !isFoldingPhone { isFoldingPhone = true }
        // The hinge can settle which screen this is (GlassSide.Screen).
        if let lastWindow { noteWindow(lastWindow) }
        lastAngle = angle.flatMap { $0.isFinite ? $0 : nil }
        noteShut()
        if forced { return }
        tracker.read(reading, at: clock())
        if opening {
            if reading == .full { endOpening(at: .flat); return }
            if let a = lastAngle, abs(a - openingAngle) > 2 { openingAngle = a; hingeMoved = clock() }
            checkOpening()
            return
        }
        settle()
        reveal()
    }

    // MARK: Opening from closed

    /// Opened from the outer screen: the inner screen takes over at about 85°,
    /// with the hinge still swinging. Nothing is shown until it comes to rest:
    /// fully open is the bag at once; resting part way a moment is the camera.
    /// Measured (11/24): opened quickly, it reached 180° in 0.6 s, and the
    /// camera had flashed up for a second before the bag (user 11/24).
    private var opening = false
    private var openingAngle = 0.0
    private var hingeMoved = 0.0
    private static let rest = 0.3

    private func beginOpening() {
        opening = true
        openingAngle = lastAngle ?? 0
        hingeMoved = clock()
        layoutMoved = clock()
        awaitingHinge = true
        Diag.note("opening")
        checkOpening()
        // However the hinge reads, never black for long.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, self.opening else { return }
            self.endOpening(at: self.lastReading == .full ? .flat : .half)
        }
    }

    private func checkOpening() {
        guard opening else { return }
        let still = clock() - hingeMoved
        if still >= Self.rest {
            endOpening(at: lastReading == .full ? .flat : .half)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.rest - still + 0.02) { [weak self] in self?.checkOpening() }
        }
    }

    private func endOpening(at rested: FoldMode) {
        guard opening else { return }
        opening = false
        Diag.note("opened \(rested.rawValue)")
        tracker.jump(to: rested)
        var quiet = Transaction(); quiet.disablesAnimations = true
        withTransaction(quiet) { settle() }
        reveal()
    }

    /// Publishes the tracker's mode and waits for the next reading to take effect.
    /// The Lock Screen camera, open flat: the bag is wanted, which only the
    /// app has (user 11/24: it was stuck on the camera). The camera asks the
    /// app to open there, as its FILMS key does.
    @Published private(set) var lockScreenWantsBag = false

    private func settle() {
        if opening { return }
        var wantsBag = false
        defer { if wantsBag != lockScreenWantsBag { lockScreenWantsBag = wantsBag } }
        tracker.tick(at: clock())
        var shown = tracker.shown(onInnerScreen: onInnerScreen, showing: mode)
        if onInnerScreen, !forced {
            // Before the hinge's first reading: decide by how the phone is held
            // (no flash of the camera before the bag, user 11/24).
            if tracker.awaitingFirstReading, heldKnown { shown = hingeLevel ? .half : .flat }
            // Open flat but held like a camera: the camera.
            if shown == .flat, hingeLevel { shown = .half }
            // The Lock Screen camera only takes pictures, and carries none of
            // the bag's pictures (bare rolls on black, user 11/24): open flat,
            // it is the camera too.
            if shown == .flat, CameraModel.isLockScreen { shown = .half; wantsBag = true }
        }
        if shown != mode {
            Diag.note("fold \(mode.rawValue) → \(shown.rawValue)")
            mode = shown
            flatCamera = false
            askAgain()
        }
        deadline?.invalidate()
        if let next = tracker.nextDeadline {
            deadline = Timer.scheduledTimer(withTimeInterval: max(next - clock(), 0) + 0.01, repeats: false) { [weak self] _ in
                self?.settle()
            }
        }
    }

    /// How far, in degrees clockwise, the layout is turned within the
    /// interface: 0 when the two agree. Says which edge of the layout is the
    /// interface's bottom, where the swipe home starts.
    @Published private(set) var contentTurn: Double = 0

    func note(contentTurn turn: Double) {
        let whole = (turn.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        if whole != contentTurn { contentTurn = whole; layoutMoved = clock() }
    }

    /// When the layout last moved on the glass (the system turning the
    /// interface, or the content turned back): a launch stays black until it
    /// has been still a moment, so nothing is seen turning (user 11/24).
    private var layoutMoved = 0.0
    private static let still = 0.3

    /// Ends the black launch once the way the phone is held is known and the
    /// layout has stopped moving; tries again until then.
    private func reveal(force: Bool = false) {
        guard awaitingHinge else { return }
        if !force {
            guard heldKnown else { return }   // the first gravity reading calls again
            let quiet = clock() - layoutMoved
            if quiet < Self.still {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.still - quiet + 0.02) { [weak self] in self?.reveal() }
                return
            }
        }
        Diag.note("shown\(force ? " (late)" : "")")
        var quiet = Transaction(); quiet.disablesAnimations = true
        withTransaction(quiet) { awaitingHinge = false }
    }

    /// Reads the interface's orientation now.
    func look() {
        guard let now = host?.window?.windowScene?.interfaceOrientation, now != .unknown,
              now != orientation else { return }
        orientation = now
        layoutMoved = clock()
    }

    /// Has the system ask again which way up the interface may be (see
    /// AppDelegate): now, and once more shortly after, because a request made
    /// in the middle of the move between screens is dropped. Called on every
    /// change of screen, fold or layout in front, and each time the app comes
    /// back to the foreground (CameraScreen: scene active).
    func askAgain(retry: Bool = false) {
        // A fresh occasion gets its own few tries (GlassSide.check).
        if !retry { GlassSide.newOccasion() }
        for delay in [0, 0.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let window = self?.host?.window else { return }
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                if #available(iOS 26.0, *) { GlassSide.front?.setNeedsUpdateOfPrefersInterfaceOrientationLocked() }
                // And asked for outright, in case the system holds to the old
                // way up (the Lock Screen camera's ways up are its own: portrait).
                guard !CameraModel.isLockScreen, let scene = window.windowScene else { return }
                let mask = GlassSide.mask(onScreen: scene.screen.bounds.size)
                guard mask != .all else { return }
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                    Diag.note("glass: \(GlassSide.describe(mask)) refused: \(error.localizedDescription)")
                }
                // Then see that the system took it (it may not, mid-move).
                if delay > 0 { GlassSide.check(window) }
            }
        }
    }
}

/// An empty view at the root of the interface that reads the hinge for
/// `Posture`. At the root, because every mode needs the readings, including
/// the library, which has no viewfinder.
struct HingeReader: UIViewRepresentable {
    final class Probe: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { Posture.shared.attach(to: self) }
        }
    }
    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ uiView: Probe, context: Context) {}
}

/// Holds its content fixed to the phone while the interface turns under it.
///
/// Open, the layout belongs to the two halves of the screen, not to whichever
/// way the system has the interface. So the content is laid out once, upright
/// as the phone is held with its hinge level, and this view turns it against
/// the interface. During a turn it moves by exactly the opposite of the
/// system's own rotation, inside the system's animation, so that on the glass
/// nothing appears to move at all.
struct FixedToPhone<Content: View>: UIViewControllerRepresentable {
    /// The content's own frame is wider than tall (the closed body) rather
    /// than taller than wide (the open two halves).
    var wide = false
    /// In a window that shares the screen: kept to the closed body's shape
    /// (letterboxed) rather than filling the window. The open bag fills it.
    var keepsShapeShared = true
    /// Where the content's frame sits on the glass: degrees clockwise from
    /// the screen's fixed coordinate space.
    var turnOnGlass: Double
    @ViewBuilder var content: () -> Content

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller(host: UIHostingController(rootView: AnyView(content())))
        controller.wide = wide
        controller.keepsShapeShared = keepsShapeShared
        controller.turnOnGlass = turnOnGlass
        return controller
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.host.rootView = AnyView(content())
        // A new place on the glass (the open bag's side, once the inner
        // screen's names are measured): turned there, and the system asked again.
        if controller.turnOnGlass != turnOnGlass {
            controller.turnOnGlass = turnOnGlass
            controller.view.setNeedsLayout()
            if GlassSide.front === controller { Posture.shared.askAgain() }
        }
    }

    final class Controller: UIViewController, GlassPinned {
        let host: UIHostingController<AnyView>
        var wide = false
        var keepsShapeShared = true
        var turnOnGlass: Double = 0
        private var turning = false
        private var lastSettleNote = ""

        init(host: UIHostingController<AnyView>) {
            self.host = host
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        private var watch: AnyCancellable?

        override func viewDidLoad() {
            super.viewDidLoad()
            // The reported orientation can change with no change of layout.
            watch = Posture.shared.$orientation.sink { [weak self] _ in
                DispatchQueue.main.async { if self?.turning == false { self?.settle() } }
            }
            view.backgroundColor = .black
            host.view.backgroundColor = .clear
            host.safeAreaRegions = []
            addChild(host)
            view.addSubview(host.view)
            host.didMove(toParent: self)
        }

        /// Asks the system to hold the interface still while the phone turns.
        /// SwiftUI's root passes this question on to this controller. With the
        /// lock in force no turn reaches the layout at all; the counter-turn
        /// below remains for when the system declines (it only locks a scene
        /// that fills the screen and is not covered).
        /// Where one way up is asked for (GlassSide), the system holds to it
        /// anyway; the lock is asked only where any way up is allowed.
        /// Not on a folding phone's inner screen: there the interface is meant
        /// to turn with the phone (GlassSide.innerLie), and a lock there is
        /// what Apple answers by scaling the app.
        override var prefersInterfaceOrientationLocked: Bool {
            let size = view.window?.windowScene?.screen.bounds.size
            if let size, GlassSide.Screen(size) == .inner { return false }
            return GlassSide.mask(onScreen: size) == .all
        }

        override var prefersStatusBarHidden: Bool { true }
        override var prefersHomeIndicatorAutoHidden: Bool { true }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // Laid out again now the window is there: whether it shares the
            // screen (and so whether to turn at all) is known only now.
            view.setNeedsLayout()
            // In front now: the interface is to take this layout's bottom edge as its own.
            GlassSide.appeared(self)
            if #available(iOS 26.0, *) { setNeedsUpdateOfPrefersInterfaceOrientationLocked() }
            #if DEBUG
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                if #available(iOS 26.0, *) {
                    print("[lock] locked:",
                          self?.view.window?.windowScene?.effectiveGeometry.isInterfaceOrientationLocked ?? false)
                }
            }
            #endif
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            GlassSide.disappeared(self)
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            // The content's own frame: upright, hinge level, whatever the window's shape.
            // A window that shares its screen (Split View, Slide Over) is
            // no place on the glass: the content simply fills it, upright.
            let bounds = view.bounds
            let short = min(bounds.width, bounds.height), long = max(bounds.width, bounds.height)
            if sharesScreen {
                // Upright as the interface is. The closed body is a landscape
                // picture: fitted whole into the window (letterboxed), never
                // stretched to a half-screen's tall shape.
                if wide, keepsShapeShared {
                    let aspect: CGFloat = 678.0 / 466.0   // the outer screen, the body's own shape
                    let w = min(bounds.width, bounds.height * aspect)
                    host.view.bounds = CGRect(x: 0, y: 0, width: w, height: w / aspect)
                } else {
                    host.view.bounds = CGRect(origin: .zero, size: bounds.size)
                }
            } else {
                host.view.bounds = CGRect(x: 0, y: 0, width: wide ? long : short, height: wide ? short : long)
            }
            host.view.center = CGPoint(x: bounds.midX, y: bounds.midY)
            if !turning { settle() }
        }

        /// Turns the content to its place on the phone.
        ///
        /// Where that is, is asked of the screen itself: its fixed coordinate
        /// space never turns, whatever the interface does. The direction this
        /// view's x axis has in that space says exactly how the interface lies
        /// on the glass. The reported interface orientation cannot serve: on a
        /// folding phone's inner screen the same value was seen for layouts
        /// half a turn apart, and for an upright window it named a landscape.
        /// The window does not fill its screen: Split View or Slide Over.
        /// Asked of the window when there is one, else of this view's own size
        /// against the screen (at launch the window is not attached yet, and a
        /// half-screen window was taken for the whole screen and turned for it).
        var sharesScreen: Bool {
            let screen = view.window?.windowScene?.screen ?? view.window?.screen
                ?? (view.traitCollection.userInterfaceIdiom == .phone ? UIScreen.main : nil)
            guard let screen else { return false }
            let s = screen.bounds.size
            func differs(_ a: CGSize) -> Bool {
                a.width > 0 && (abs(min(a.width, a.height) - min(s.width, s.height)) > 2
                                || abs(max(a.width, a.height) - max(s.width, s.height)) > 2)
            }
            return differs(view.window?.bounds.size ?? .zero) || differs(view.bounds.size)
        }


        private func settle() {
            guard let screen = view.window?.screen else { return }
            if sharesScreen {
                // Upright as the interface is, fitted to the window.
                host.view.transform = .identity
                Posture.shared.note(contentTurn: 0)
                return
            }
            let origin = view.convert(CGPoint.zero, to: screen.fixedCoordinateSpace)
            let along = view.convert(CGPoint(x: 100, y: 0), to: screen.fixedCoordinateSpace)
            let lie = (atan2(along.y - origin.y, along.x - origin.x) * 180 / .pi / 90).rounded() * 90
            let turn = turnOnGlass - lie
            host.view.transform = CGAffineTransform(rotationAngle: turn * .pi / 180)
            Posture.shared.note(contentTurn: turn)
            if GlassSide.front === self, let window = view.window, let scene = window.windowScene {
                // The window's lie (this view may sit inside another pinned
                // layout, turned already), and the system's own.
                let windowLie = GlassSide.lie(of: window, on: screen)
                let system = GlassSide.systemLie(screen)
                GlassSide.frontLie = windowLie
                let note = "glass: system lies \(Int(system)), named \(scene.interfaceOrientation.rawValue), window lies \(Int(windowLie)) \(Int(window.bounds.width))×\(Int(window.bounds.height)), device \(UIDevice.current.orientation.rawValue), front on \(Int(turnOnGlass)) turned \(Int(GlassSide.norm(turn)))"
                if note != lastSettleNote { lastSettleNote = note; Diag.note(note) }
                // Interface and glass as the system names them: the screen's own difference.
                GlassSide.learn(lie: system, reported: scene.interfaceOrientation, onScreen: screen.bounds.size)
                GlassSide.check(window)
            }
            #if DEBUG
            if #available(iOS 26.0, *) {
                print("[fold] window", view.bounds.size, "lie", lie, "turn", turn,
                      "reported", view.window?.windowScene?.interfaceOrientation.rawValue ?? 0,
                      "device", UIDevice.current.orientation.rawValue, "locked",
                      view.window?.windowScene?.effectiveGeometry.isInterfaceOrientationLocked ?? false,
                      "fixed", screen.fixedCoordinateSpace.bounds.size)
            }
            #endif
        }

        override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)
            turning = true
            // The system's turn is not to be seen: the content is held on the
            // glass anyway, so it all jumps at once, still.
            GlassSide.freezeAnimations()
            coordinator.animate(alongsideTransition: { [weak self] context in
                guard let self, !self.sharesScreen else { return }
                // The interface turns by `targetTransform`; turn back by as much.
                let system = context.targetTransform
                let angle = atan2(system.b, system.a)
                self.host.view.transform = self.host.view.transform.rotated(by: -angle)
            }, completion: { [weak self] _ in
                GlassSide.thawAnimations()
                self?.turning = false
                self?.settle()
            })
        }
    }
}
