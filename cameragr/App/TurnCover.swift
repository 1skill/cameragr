import SwiftUI
import UIKit

/// A black cover, the launch screen's colour, held over the app while the
/// system turns the interface right after a launch or a return to the front,
/// so that turn is never seen (user 11/28: "both phones turn once when they
/// open"). Only when the system is really turning: it is up only while the
/// interface is in a way up the app did not ask for, and only in the moments
/// after a launch or a return; turns asked for later (a page in landscape, a
/// fold) are never covered. The inner screen asks for no way up, so it is
/// never covered there.
///
/// Why it is needed (diag-fn-1128-135, trials 11/28 in PROGRESS): with
/// UIRequiresFullScreen off the system opens the app in a way up taken from
/// Info.plist alone, before the app is asked; one list cannot suit both the
/// Duo's outer screen (landscape) and a plain iPhone (portrait).
final class TurnCover: ObservableObject {
    static let shared = TurnCover()

    /// Up from the start: a launch is a moment to watch until the first answer.
    @Published private(set) var shown = true
    @Published private(set) var fading = false

    private var watchUntil = ProcessInfo.processInfo.systemUptime + TurnCover.launchWatch
    private var shownSince: Double?
    private var matchedSince: Double?
    private var timer: Timer?
    /// Which cover is up: a fade started for an earlier one must not lift a newer one.
    private var round = 0

    /// How long after a launch or a return a turn the app did not ask for is covered.
    static let launchWatch = 3.0
    static let returnWatch = 1.5
    /// How long the asked way up must hold before the cover lifts.
    static let settle = 0.45
    /// The longest the cover stays, whatever the system does.
    static let longest = 2.4

    private init() {
        NotificationCenter.default.addObserver(forName: UIScene.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.watch(for: TurnCover.returnWatch)
        }
        // Never left up: should no answer come, off once the launch watch is over.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.launchWatch) { [weak self] in
            guard let self, self.shown, !self.fading else { return }
            self.lift(quietly: false)
        }
    }

    private var now: Double { ProcessInfo.processInfo.systemUptime }

    /// Whether `interface` is a way up the app is waiting to be turned out of.
    static func turnPending(mask: UIInterfaceOrientationMask, interface: UIInterfaceOrientation) -> Bool {
        guard interface != .unknown else { return false }
        return !mask.contains(GlassSide.mask(interface))
    }

    private func watch(for seconds: Double) {
        guard !CameraModel.isLockScreen else { return }
        watchUntil = now + seconds
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            look(at: scene)
        }
    }

    /// The system asked which ways up (AppDelegate): cover or uncover.
    func asked(mask: UIInterfaceOrientationMask, scene: UIWindowScene?) {
        guard let scene else { return }
        decide(pending: Self.turnPending(mask: mask, interface: scene.interfaceOrientation))
    }

    private func look(at scene: UIWindowScene) {
        let mask = GlassSide.mask(onScreen: scene.screen.bounds.size)
        decide(pending: Self.turnPending(mask: mask, interface: scene.interfaceOrientation))
    }

    private func decide(pending: Bool) {
        let watching = now < watchUntil
        let tooLong = shownSince.map { now - $0 > Self.longest } ?? false
        if pending && watching && !tooLong {
            matchedSince = nil
            if !shown || fading {
                round += 1
                fading = false
                shown = true
            }
            if shownSince == nil { shownSince = now; Diag.note("cover: on (the system is turning)") }
            startLooking()
        } else if shown && !fading {
            // Never needed (the first answer found no turn): off at once.
            if shownSince == nil { lift(quietly: true); return }
            // The system names the new way up before its turn has finished
            // on the screen (蜂鸟 136: lifted 0.55 s in, the turn still seen):
            // the way up must hold a while first.
            if tooLong { lift(quietly: false); return }
            if matchedSince == nil { matchedSince = now }
            if now - matchedSince! >= Self.settle { lift(quietly: false) } else { startLooking() }
        }
    }

    /// Off: at once when it was never needed (the first answer found no
    /// turn), with a short fade after a turn.
    private func lift(quietly: Bool) {
        timer?.invalidate(); timer = nil
        matchedSince = nil
        if quietly {
            shown = false
            return
        }
        Diag.note(String(format: "cover: off after %.2fs", now - (shownSince ?? now)))
        shownSince = nil
        // A moment for the turned interface to be drawn, then fade.
        fading = true
        let this = round
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, self.fading, self.round == this else { return }
            withAnimation(.easeOut(duration: 0.22)) { self.shown = false }
            self.fading = false
        }
    }

    /// While up, looks at the system's way up every frame or so: the turn
    /// can end without another question.
    private func startLooking() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
            self.look(at: scene)
        }
    }
}

/// The cover itself, over everything in the window.
struct TurnCoverView: View {
    @ObservedObject private var cover = TurnCover.shared

    var body: some View {
        if cover.shown {
            Color.black
                .ignoresSafeArea()
                .allowsHitTesting(true)
                .transition(.opacity)
        }
    }
}
