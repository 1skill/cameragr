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
    private var tracker = FoldTracker(awaitingFirstReading: true)
    /// Debug: a mode given at launch, which hinge readings leave alone.
    private var forced = false
    /// The interface is on a folding phone's inner screen (see `FoldTracker.shown`).
    private var onInnerScreen = false

    /// The interface's size changed: tells the inner screen from the outer.
    /// The inner screen of an iPhone Duo is 669 points across its short side;
    /// the outer one and every other iPhone are under 500.
    func noteWindow(_ size: CGSize) {
        // A folding phone: its outer screen (466 points across) is already
        // wider than any other iPhone's (440 at most).
        if min(size.width, size.height) > 450, !isFoldingPhone { isFoldingPhone = true }
        let inner = min(size.width, size.height) > 600
        guard inner != onInnerScreen else { return }
        onInnerScreen = inner
        Diag.note("screen \(inner ? "inner" : "outer")")
        if inner, tracker.awaitingFirstReading, !forced {
            awaitingHinge = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.awaitingHinge = false }
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
        forced = mode != .closed   // the simulator's hinge reads closed: it must not undo this
        // Only a forced mode replaces the launch tracker (which takes the
        // first reading at once); a plain debug launch keeps it.
        if forced { tracker = FoldTracker(mode: mode) }
        #endif
    }

    #if DEBUG
    /// Probe (11/24): which way gravity points, to tell the inner screen held
    /// like a book (landscape) from held upright (portrait). Recorded only.
    private let motion = CMMotionManager()
    private var lastGravityNote = 0.0
    private func probeGravity() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.25
        motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let self, let g = m?.gravity else { return }
            let t = ProcessInfo.processInfo.systemUptime
            guard t - self.lastGravityNote > 1 else { return }
            self.lastGravityNote = t
            Diag.note(String(format: "gravity x %.2f y %.2f z %.2f inner %@ mode %@", g.x, g.y, g.z, "\(self.onInnerScreen)", self.mode.rawValue))
        }
    }
    #endif

    /// Starts reading the hinge through `view`, which has to be in the interface.
    func attach(to view: UIView) {
        #if DEBUG
        probeGravity()
        #endif
        guard host !== view else { return }
        host = view
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
        lastAngle = angle.flatMap { $0.isFinite ? $0 : nil }
        noteShut()
        if forced { return }
        tracker.read(reading, at: clock())
        if reading != .unknown, awaitingHinge { awaitingHinge = false }
        settle()
    }

    /// Publishes the tracker's mode and waits for the next reading to take effect.
    private func settle() {
        tracker.tick(at: clock())
        let shown = tracker.shown(onInnerScreen: onInnerScreen, showing: mode)
        if shown != mode {
            Diag.note("fold \(mode.rawValue) → \(shown.rawValue)")
            mode = shown
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
        if whole != contentTurn { contentTurn = whole }
    }

    /// Reads the interface's orientation now.
    func look() {
        guard let now = host?.window?.windowScene?.interfaceOrientation, now != .unknown,
              now != orientation else { return }
        orientation = now
    }

    /// Has the system ask again which way up the interface may be (see
    /// AppDelegate): now, and once more shortly after, because a request made
    /// in the middle of the move between screens is dropped.
    func askAgain() {
        for delay in [0, 0.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.host?.window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
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
    /// Where the content's frame sits on the glass: degrees clockwise from
    /// the screen's fixed coordinate space.
    var turnOnGlass: Double
    @ViewBuilder var content: () -> Content

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller(host: UIHostingController(rootView: AnyView(content())))
        controller.wide = wide
        controller.turnOnGlass = turnOnGlass
        return controller
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.host.rootView = AnyView(content())
    }

    final class Controller: UIViewController {
        let host: UIHostingController<AnyView>
        var wide = false
        var turnOnGlass: Double = 0
        private var turning = false

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
        override var prefersInterfaceOrientationLocked: Bool { true }

        override var prefersStatusBarHidden: Bool { true }
        override var prefersHomeIndicatorAutoHidden: Bool { true }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // Laid out again now the window is there: whether it shares the
            // screen (and so whether to turn at all) is known only now.
            view.setNeedsLayout()
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
                if wide {
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
        private var sharesScreen: Bool {
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
            coordinator.animate(alongsideTransition: { [weak self] context in
                guard let self, !self.sharesScreen else { return }
                // The interface turns by `targetTransform`; turn back by as much.
                let system = context.targetTransform
                let angle = atan2(system.b, system.a)
                self.host.view.transform = self.host.view.transform.rotated(by: -angle)
            }, completion: { [weak self] _ in
                self?.turning = false
                self?.settle()
            })
        }
    }
}
