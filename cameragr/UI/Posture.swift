import Combine
import SwiftUI
import UIKit

/// What a folding phone is doing: whether it is open, and which way up the
/// system currently has the interface. An ordinary phone always reads closed.
final class Posture: ObservableObject {
    static let shared = Posture()

    /// The hinge is open, part way or flat: the inner screen is in use.
    @Published private(set) var isOpen = false
    @Published private(set) var orientation = UIInterfaceOrientation.landscapeRight

    private weak var host: UIView?
    private var timer: Timer?

    private init() {
        #if DEBUG
        // -open 1 pretends the phone is open, for UI checks where no hinge exists.
        if UserDefaults.standard.bool(forKey: "open") { isOpen = true }
        #endif
    }

    /// Starts reading the hinge through `view`, which has to be in the interface.
    func attach(to view: UIView) {
        guard host !== view else { return }
        host = view
        if #available(iOS 27.1, *) {
            view.addInteraction(UIHingeInteraction { [weak self] _, update in
                guard let status = update.hinge?.status else { return }
                self?.set(open: status == .partiallyOpen || status == .fullyOpen)
            })
        }
        // The interface's orientation has no change notice that also covers a
        // half turn (the window keeps its size), so it is simply looked at.
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.look() }
        look()
    }

    private func set(open: Bool) {
        guard open != isOpen else { return }
        isOpen = open
        askAgain()
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
            let bounds = view.bounds
            let short = min(bounds.width, bounds.height), long = max(bounds.width, bounds.height)
            host.view.bounds = CGRect(x: 0, y: 0, width: wide ? long : short, height: wide ? short : long)
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
        private func settle() {
            guard let screen = view.window?.screen else { return }
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
                guard let self else { return }
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
