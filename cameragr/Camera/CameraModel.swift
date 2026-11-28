import Combine
import AVFoundation
import CoreImage
import SwiftUI
import UIKit

/// App state: the loaded film, camera controls, and the capture → develop → save flow.
@MainActor
final class CameraModel: ObservableObject {
    enum Flash: String, CaseIterable {
        case off, auto, on

        /// Spoken and shown name.
        var title: String {
            switch self {
            case .off: String(ui: "Off")
            case .auto: String(ui: "Auto")
            case .on: String(ui: "On")
            }
        }

        var mode: AVCaptureDevice.FlashMode {
            switch self {
            case .off: return .off
            case .auto: return .auto
            case .on: return .on
            }
        }

        var next: Flash {
            let all = Flash.allCases
            return all[(all.firstIndex(of: self)! + 1) % all.count]
        }
    }

    /// Frame aspect of the loaded film (135 film is 3:2).
    nonisolated static let frameAspect: CGFloat = 3.0 / 2.0

    let films: [Film] = FilmLibrary.shared.films
    let frames = FrameStore()

    @Published var film: Film? {
        // Another roll in, by any way: the old one's "used up" note goes.
        didSet { if film != oldValue { usedUp = nil } }
    }
    /// A roll chosen in the film library, loaded when the phone is next closed
    /// (or folded for the waist-level finder). Looking through the library
    /// alone never changes the loaded roll.
    @Published private(set) var readyToLoad: Film?
    /// The roll last looked at in the bag (on its card), not loaded yet.
    var lookedAt: Film?
    /// What goes in when the bag is put away (phone shut, turned upright to
    /// shoot, clasp done up): the roll chosen with its tag, else the one
    /// looked at last, if it can take a picture now.
    private var rollToLoad: Film? {
        if let readyToLoad { return readyToLoad }
        guard let looked = lookedAt, looked != film else { return nil }
        let store = FilmStore.shared
        return store.isUnlocked(looked) || store.trialsLeft(looked) > 0 ? looked : nil
    }
    /// The chosen roll on its way into the camera after the phone was closed:
    /// the chamber shows it going in (FilmChamber), then loads it.
    @Published var arrivingRoll: Film?
    /// The door is open on an empty chamber, the old roll already out: the
    /// arriving roll only has to go in.
    @Published var bayWaiting = false
    /// Which arrival the fallback timer belongs to.
    private var arrivalID: UUID?
    /// The roll the next picture is taken on.
    var nextShotFilm: Film? { arrivingRoll ?? film }
    @Published var isBayOpen = false
    @Published var flash: Flash = .off
    @Published var showsGrid = true
    @Published var exposureBias: Double = 0
    @Published var zoom: CGFloat = 1
    @Published var isFrontCamera = false
    /// Square pictures instead of 3:2.
    @Published var isSquare = false
    @Published var lastThumbnail: UIImage?
    /// The last picture as the iPhone saw it and as the film made it (small,
    /// upright), for the comparison video shared from the review.
    /// `before` may be missing: then only the video can't be made.
    private(set) var lastPair: (before: UIImage?, after: UIImage, film: String, filmID: String?)? {
        // The tray, if open, shows the picture that is now the last one.
        didSet { makeLetterPreview() }
    }
    /// The comparison video is being made.
    @Published private(set) var isMakingShare = false
    /// A made video waiting for the share sheet (the screen presents it).
    @Published var shareVideo: SharedFile?
    @Published var frameCount = 0
    /// True from the shutter press until the camera hands over the exposure:
    /// the finder blinks dark and a second press is ignored. Developing and
    /// saving happen afterwards in the background and don't hold up the next shot.
    @Published var isExposing = false
    /// Counts shutter releases: the finder's shutter closes once for each.
    @Published var releases = 0
    /// The finder shows the last picture instead of the scene.
    @Published var isReviewing = false {
        // The share tray belongs to the review: gone with it.
        didSet { if !isReviewing { isShareTrayOpen = false } }
    }
    /// Reviewing, SHARE opened the share tray in the finder: a slide picks
    /// what goes out (a video, a letter, the photo), SHARE again sends it.
    @Published var isShareTrayOpen = false
    @Published var shareKind: ShareKind = ShareKind(rawValue: UserDefaults.standard.object(forKey: "shareKind") as? Int ?? 1) ?? .letter {
        didSet { UserDefaults.standard.set(shareKind.rawValue, forKey: "shareKind"); makeLetterPreview() }
    }
    /// Which line the letter's tag says (see `ShareLetter.lines`).
    @Published var letterLine = UserDefaults.standard.integer(forKey: "letterLine") {
        didSet { UserDefaults.standard.set(letterLine, forKey: "letterLine"); makeLetterPreview() }
    }
    /// The last picture's place in Photos, to share it whole.
    private var lastAsset: String?
    /// The letter as it would go out, for the tray's preview.
    @Published private(set) var letterPreview: UIImage?
    @Published var message: String?
    /// The used-up roll, bought from the finder: the purchase sheet, then on shooting.
    func buyUsedUp() {
        guard let film = usedUp else { return }
        let store = FilmStore.shared
        let ids = [FilmStore.productID(film), FilmStore.allFilmsID]
        guard store.purchasing == nil, !ids.contains(where: store.awaitingApproval.contains) else { return }
        guard store.price(film) != nil else { Task { await store.loadProductsIfMissing(force: true) }; return }
        Task { @MainActor in
            if await store.buy(film) { if usedUp == film { usedUp = nil }; Haptic.stop() }
        }
    }

    /// The used-up roll: choose another in the bag.
    func changeRollFromUsedUp() {
        usedUp = nil
        showBag()
    }

    /// The loaded roll's free shots ran out at a press of the shutter: the
    /// LCD shows END and the finder says what to do until another roll goes
    /// in, the bag opens, or the shutter is pressed again.
    @Published var usedUp: Film?

    /// A page over the body, opened from the strip beside the open chamber.
    enum Panel: Equatable { case detail(Film), settings }
    @Published var panel: Panel?
    /// The film store is open (pages opened from it go over it).
    @Published var isStoreOpen = false
    /// The camera bag opened over the closed camera (FILMS, SETUP), on any
    /// iPhone: its films, its kit and its book. Closing its clasp loads the
    /// roll chosen in it, as closing the phone does on iPhone Duo.
    struct BagOpening: Equatable { var spread: Spread; var look: Film? }
    @Published var bag: BagOpening? {
        // The bag opening drops any press kept for the shutter: none goes off after.
        didSet { if bag != nil { pressQueued = 0; shutterWaiting = 0 } }
    }
    /// The Lock Screen camera, which can't buy or keep the book: it keeps the old pages.
    static let isLockScreen = Bundle.main.bundleURL.pathExtension == "appex"

    /// In the Lock Screen camera: asks to unlock and open the app at the bag
    /// (set by the extension). Cancelled, the camera stays as it was.
    static var openAppAtBag: ((Spread, Film?) -> Void)?

    /// The bag, wherever the camera is: in the app it opens here; in the Lock
    /// Screen camera the phone is unlocked first and the app opens it.
    func showBag(_ spread: Spread = .films, look: Film? = nil, posture: Posture = .shared) {
        // Camera shown on the open inner screen: the bag is the full screen again.
        if posture.flatCamera {
            libraryStart = BagOpening(spread: spread, look: look)
            pressQueued = 0; shutterWaiting = 0   // no kept press goes off after the bag
            posture.setFlatCamera(false)
            return
        }
        // Open flat but held like a camera (the same screen as above, shown as
        // the camera by the hold): the full-screen bag too, not a bag drawn in
        // the half layout.
        // Never in the Lock Screen camera: there the app has to be unlocked
        // and opened at the bag (below), not a bag pinned in the extension.
        if !Self.isLockScreen, posture.pinBag() {
            libraryStart = BagOpening(spread: spread, look: look)
            pressQueued = 0; shutterWaiting = 0
            return
        }
        if Self.isLockScreen {
            if let open = Self.openAppAtBag { open(spread, look) }
            else if spread == .kit { panel = .settings } else { isStoreOpen = true; if let look { panel = .detail(look) } }
        } else {
            openBag(spread, look: look)
        }
    }

    /// The app opened from the Lock Screen camera's FILMS or SETUP.
    func openBag(fromLockScreen info: [AnyHashable: Any]?) {
        let spread = (info?["bag"] as? Int).flatMap(Spread.init(rawValue:)) ?? .films
        let look = (info?["look"] as? String).flatMap { id in films.first { $0.id == id } }
        openBag(spread, look: look)
    }

    func openBag(_ spread: Spread = .films, look: Film? = nil) {
        usedUp = nil
        // Going for another roll means going back to shooting: the finder
        // shows the scene again, not the last picture (user 11/24).
        isReviewing = false
        bag = BagOpening(spread: spread, look: look)
        Haptic.tap()
    }

    /// The pages the library (open flat) shows first when the camera on the
    /// inner screen hands the screen back to it. Cleared on any fold change.
    @Published var libraryStart: BagOpening?

    /// The bag's Camera entry over the closed camera: the bag goes away and
    /// nothing is loaded (unlike `closeBag`).
    func leaveBag() {
        bag = nil
        Haptic.stop()
    }

    /// The Camera entry on the open inner screen: the half-fold camera layout.
    func enterFlatCamera() {
        libraryStart = nil
        isReviewing = false
        // As at waist level: the finder shows the chosen roll, so the first picture matches it.
        frames.set(film: readyToLoad ?? film)
        lookToken &+= 1
        lookPending = false
        // Pinned bag (open flat, held like a camera): the hold shows the camera again.
        if Posture.shared.bagPinned { Posture.shared.unpinBag() } else { Posture.shared.setFlatCamera(true) }
        start()
    }

    /// The bag's clasp done up: back to the camera, loading the roll chosen in it.
    func closeBag() {
        bag = nil
        Haptic.stop()
        phoneShut()
    }

    private let service = CameraService()
    /// Which way up the phone is held right now.
    var heldOrientation: CGImagePropertyOrientation { hold.orientation }
    private let hold = HoldSensor()
    /// How far the upright body's labels turn to read upright as the phone is
    /// held (degrees clockwise; see `HoldRule.uprightTurn`). Lying flat keeps the last.
    @Published private(set) var labelTurn: Double = 0
    /// One exposure on its way from the shutter to Photos.
    private struct PendingShot {
        /// How the phone was held at the press.
        let hold: CGImagePropertyOrientation
        /// The film loaded at the press: switching films while the picture is
        /// still being processed must not change it.
        let film: Film?
        /// Whether the shot used one of the film's free trial shots.
        let isTrial: Bool
        let isSquare: Bool
        /// How a front camera picture is flipped to act as a mirror, decided
        /// with the hold at the press (nil: the back camera, not flipped).
        var mirror: CGImagePropertyOrientation? = nil
        /// When the shutter was pressed (for the timing record in debug builds).
        let pressed = ProcessInfo.processInfo.systemUptime
        /// The clock time of the press: the day a picture belongs to (the
        /// photo book) is the day it was taken, not the day it was saved.
        let takenAt = Date()
        /// Asks the system for time to finish if the app is left meanwhile.
        let keepAlive = KeepAlive()
    }
    /// Exposures waiting for the camera, oldest first.
    private var pendingShots: [PendingShot] = []
    /// Pictures between the shutter and Photos (taking, developing, saving).
    /// Capped, so a long burst cannot pile up full-size pictures in memory.
    private var inFlight = 0
    /// The camera started; false when access was refused or before it is up.
    private var cameraReady = false
    private let renderer = FilmRenderer.shared
    private let developQueue = DispatchQueue(label: "cameragr.develop", qos: .userInitiated)

    private var purchaseWatch: AnyCancellable?

    init() {
        // A purchase that failed anywhere (bag, card, finder): the notice says so.
        purchaseWatch = FilmStore.shared.$purchaseProblem
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                self?.message = note
                FilmStore.shared.purchaseProblem = nil
            }
        film = films.first
        #if DEBUG
        // Launch arguments for automated UI checks: -film <id>  -bay 1  -shoot 1  -url <link>
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: "film"), let match = films.first(where: { $0.id == id }) {
            film = match
        }
        isBayOpen = defaults.bool(forKey: "bay")
        // `-panel settings|store|<film id>`: open a page at launch.
        // `-openBag films|kit|book`: the camera bag open over the camera.
        if let b = defaults.string(forKey: "openBag") {
            bag = BagOpening(spread: ["kit": .kit, "club": .club][b] ?? .films, look: nil)
        }
        if let p = defaults.string(forKey: "panel") {
            if p == "store" { isStoreOpen = true }
            panel = p == "settings" ? .settings : films.first(where: { $0.id == p }).map { .detail($0) }
        }
        // `-closeOn <film id>`: as if the phone was just closed on that roll,
        // chosen in the library, to watch it go in.
        if let id = defaults.string(forKey: "closeOn"), let next = films.first(where: { $0.id == id }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.readyToLoad = next
                self?.foldChanged(to: .closed)
                self?.phoneShut()
            }
        }
                // `-perfRun 1`: every film in turn, five seconds of finder and one
        // picture each, then a burst of five; timings go to Diag.
        if defaults.bool(forKey: "perfRun") {
            // Only rolls that can be shot here (owned, free today, or trial shots
            // left): a locked roll's shutter is refused and nothing is timed.
            let store = FilmStore.shared
            let all = films.filter { store.isUnlocked($0) || store.trialsLeft($0) > 0 }
            FilmLibrary.cubeTimed = { name, seconds, main in
                Diag.note(String(format: "perf cube %@ %.1f ms%@", name, seconds * 1000, main ? " (main)" : ""))
            }
            for (i, next) in all.enumerated() {
                let t = 4 + Double(i) * 7
                DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in
                    self?.load(next); Diag.note("perf film \(next.id)")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + t + 5) { [weak self] in self?.shoot() }
            }
            let burst = 4 + Double(all.count) * 7 + 2
            // The burst on a roll that's owned (or free today), loaded first.
            if let owned = all.first(where: { store.isUnlocked($0) }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + burst - 1.5) { [weak self] in
                    self?.load(owned); Diag.note("perf burst on \(owned.id)")
                }
            }
            for k in 0..<5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + burst + Double(k) * 0.35) { [weak self] in
                    self?.shoot(fast: k > 0)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + burst + 10) { Diag.note("perf done") }
        }
                if defaults.bool(forKey: "resetStore") { Task { @MainActor in await FilmStore.shared.resetDebugState() } }
        if let link = defaults.string(forKey: "url").flatMap(URL.init(string:)) { open(link) }
        // `-usedUp 1`: as if the shutter was pressed with the roll's free shots used up.
        if defaults.bool(forKey: "usedUp") { usedUp = film }
        if defaults.bool(forKey: "shoot") {
            // `-shootAfter <s>` moves the shot later, past a slow simulator launch.
            let wait = defaults.double(forKey: "shootAfter") > 0 ? defaults.double(forKey: "shootAfter") : 1.5
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in self?.shoot() }
        }
        #endif
        frames.set(film: film)
        service.filmTitles = films.map(\.name)
        if let film, let index = films.firstIndex(of: film) { service.select(film: index) }
        service.onControl = { [weak self] change in
            Task { @MainActor in self?.apply(change) }
        }
        let frames = frames
        service.onFrame = { frames.set(image: $0, iso: $1) }
        hold.onChange = { [weak self] hold in
            Task { @MainActor in
                self?.labelTurn = HoldRule.uprightTurn(hold)
                self?.updateFrontMirror()
            }
        }
        service.onShutter = { [weak self] in
            // Ready for the next exposure; this one is still being processed.
            Task { @MainActor in
                self?.isExposing = false
                Posture.shared.holdForShot(false)
                self?.takeQueuedPress()
            }
        }
        service.onPhoto = { [weak self] image, iso, lift in
            // Read the film on the main actor, then develop off it.
            Task { @MainActor in self?.develop(image, iso: iso, lift: lift) }
        }
    }

    func start() {
        service.rest(false)
        hold.start()
        let asked = ProcessInfo.processInfo.systemUptime
        service.start { [weak self] granted in
            // For the fold probe: how long the camera takes to come back.
            Diag.note(String(format: "camera ready %@ in %.2fs", granted ? "yes" : "no",
                             ProcessInfo.processInfo.systemUptime - asked))
            self?.cameraReady = granted
            if !granted { self?.message = Self.noCameraMessage }
        }
    }

    private static var noCameraMessage: String {
        String(ui: "Koco has no access to the camera. Allow it in Settings.")
    }

    func stop() {
        hold.stop()
        cameraReady = false
        service.stop()
    }

    /// The bag is up: the camera rests, running but offering and showing
    /// nothing (see `CameraService.rest`). `start` brings it back.
    func rest() {
        Diag.note("camera rests (bag)")
        hold.stop()
        service.rest(true)
        service.start { _ in }
    }

    /// Chooses a roll in the film library: it goes in when the phone is
    /// closed. Choosing the loaded roll, or the chosen one again, takes the choice back.
    func chooseInLibrary(_ choice: Film) {
        // Chosen stays chosen (user 11/24: no undo); the roll already in the
        // camera means keeping it.
        readyToLoad = choice == film ? nil : choice
        Haptic.tap()
    }

    /// The phone was folded or unfolded (see `Posture`).
    func foldChanged(to mode: FoldMode) {
        // Open flat is the library: no press kept for the shutter goes off later.
        if mode == .flat { pressQueued = 0; shutterWaiting = 0 }
        // Opened again while a roll was still going in: it is in.
        if mode != .closed {
            completeArrival()
            if bayWaiting {
                bayWaiting = false
                var quiet = Transaction(); quiet.disablesAnimations = true
                withTransaction(quiet) { isBayOpen = false }
            }
        }
        // Closed on a chosen roll: the old one was taken out while open (the
        // bag is where rolls are changed), so the body comes up with its door
        // already open and the chamber empty, waiting for the new one (user 11/24).
        if mode == .closed, bag == nil, let next = rollToLoad, next != film {
            bayWaiting = true
            var quiet = Transaction(); quiet.disablesAnimations = true
            withTransaction(quiet) { isBayOpen = true }
            // Should the phone not be shut all the way, the roll goes in all the same.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                if self?.bayWaiting == true, self?.arrivingRoll == nil { self?.phoneShut() }
            }
        }
        // The chosen roll waits until the phone is shut all the way, where its
        // going in can be watched (`phoneShut`), or until a picture is taken
        // (`shoot` loads it first): passing through part-open while closing
        // must not load it unseen. At waist level the finder already shows it,
        // so what is seen is what the first picture gets.
        frames.set(film: mode == .half ? (readyToLoad ?? film) : film)
        // Set here at once: a roll still being read must not paint over it later.
        lookToken &+= 1
        lookPending = false
        if mode == .flat { isReviewing = false }
    }

    /// The roll just put in by turning the open phone upright, shown for a moment.
    @Published private(set) var loadedNotice: Film?

    /// The open phone turned from the bag (held like a book) to the camera
    /// (hinge level): the chosen roll goes in at once, and says so (user 11/24).
    func turnedToCamera() {
        guard let next = rollToLoad else { return }
        readyToLoad = nil
        lookedAt = nil
        Diag.note("turned upright: load \(next.id)")
        if next != film { load(next) }
        Haptic.stop()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { loadedNotice = next }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard self?.loadedNotice == next else { return }
            withAnimation(.easeOut(duration: 0.3)) { self?.loadedNotice = nil }
        }
    }

    /// The phone is shut all the way (see `Posture.isShut`): a chosen roll
    /// goes in now, seen through the chamber door.
    func phoneShut() {
        guard let next = rollToLoad else { return }
        readyToLoad = nil
        lookedAt = nil
        Diag.note("shut: load \(next.id)")
        guard next != film else { return }
        isStoreOpen = false
        panel = nil
        arrivingRoll = next
        isBayOpen = true
        // Should the chamber not be shown (e.g. the app left meanwhile),
        // the roll goes in all the same: this one, if it is still on its way.
        let arrival = UUID()
        arrivalID = arrival
        var wait = 4.0
        #if DEBUG
        if UserDefaults.standard.double(forKey: "chamberSlow") > 0 { wait *= UserDefaults.standard.double(forKey: "chamberSlow") }   // with the drawn-out chamber
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
            guard self?.arrivalID == arrival else { return }
            self?.completeArrival()
        }
    }

    /// Before a picture: a roll chosen in the library goes in at once, so the
    /// picture is on it (e.g. shooting at waist level before ever closing).
    private func loadChosenRollNow() {
        completeArrival()
        if let next = readyToLoad {
            readyToLoad = nil
            if next != film { load(next) }
        }
    }

    /// Loads the arriving roll at once, if one is still on its way.
    func completeArrival() {
        guard let next = arrivingRoll else { return }
        arrivingRoll = nil
        arrivalID = nil
        bayWaiting = false
        if next != film { load(next) }
        isBayOpen = false
    }

    /// A press made while the last picture was still exposing (0: none, 1: fast, 2: normal).
    private var pressQueued = 0
    /// The shutter is ready again: a press kept meanwhile is taken now.
    private func takeQueuedPress() {
        guard pressQueued > 0, !isExposing else { return }
        let fast = pressQueued == 1
        pressQueued = 0
        noteShot("queued press taken")
        shoot(fast: fast)
    }
    private func noteShot(_ what: String) {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "perfRun") { Diag.note("perf press \(what)") }
        #endif
    }

    /// The new roll's look is being read; the finder still shows the last one.
    private var lookPending = false
    /// A shutter press made while it was (0: none, 1: fast, 2: normal).
    private var shutterWaiting = 0
    /// Bumped by every roll change: only the latest one's reading clears the wait.
    private var lookToken = 0

    func load(_ film: Film) {
        usedUp = nil
        isReviewing = false   // a new roll in: back to the scene
        self.film = film
        // The finder keeps the last roll's look for the moment it takes to read
        // the new one's cubes off the main thread, then switches (11/25).
        let frames = frames
        lookPending = true
        lookToken &+= 1
        let token = lookToken
        Task.detached(priority: .userInitiated) {
            FilmLibrary.shared.prewarm(film)
            await MainActor.run { [weak self] in
                guard let self, self.lookToken == token, self.film == film else { return }
                frames.set(film: film)
                self.lookPending = false
                // A press made meanwhile is taken now, on the new roll.
                if self.shutterWaiting > 0 { let fast = self.shutterWaiting == 1; self.shutterWaiting = 0; self.shoot(fast: fast) }
            }
        }
        frameCount = 0
        if let index = films.firstIndex(of: film) { service.select(film: index) }
        Haptic.stop()
    }

    /// A setting changed with the phone's Camera Control button: the camera
    /// already has it, so only the body's own readouts need to follow.
    private func apply(_ change: CameraService.ControlChange) {
        switch change {
        case .film(let index):
            guard films.indices.contains(index), films[index] != film else { return }
            film = films[index]
            frames.set(film: film)
            // Set at once here: any roll still being read is overtaken.
            lookToken &+= 1
            lookPending = false
            if shutterWaiting > 0 { let fast = shutterWaiting == 1; shutterWaiting = 0; shoot(fast: fast) }
        case .flash(let index):
            guard Flash.allCases.indices.contains(index) else { return }
            flash = Flash.allCases[index]
        case .zoom(let factor):
            zoom = factor
        case .exposure(let bias):
            exposureBias = min(max(Double(bias), -2), 2)
        }
    }

    /// Handles peli://film/<id>, the link a widget's roll opens.
    func open(_ url: URL) {
        guard url.scheme == "peli", url.host == "film",
              let match = films.first(where: { $0.id == url.lastPathComponent }) else { return }
        isBayOpen = false
        bag = nil   // a roll tapped on a widget: back to the camera with it
        // That roll, not one chosen earlier and still waiting to go in.
        readyToLoad = nil
        arrivingRoll = nil
        arrivalID = nil
        if match != film { load(match) }
    }

    /// Shows the last picture in the finder, or goes back to the scene.
    func toggleReview() {
        guard lastThumbnail != nil else { return }
        isReviewing.toggle()
        Haptic.tap()
    }

    func toggleGrid() {
        showsGrid.toggle()
        Haptic.click()
    }

    func toggleBay() {
        isBayOpen.toggle()
        if isBayOpen { isReviewing = false }   // changing the roll: back to the scene
        Haptic.tap()
    }

    func cycleFlash() {
        flash = flash.next
        Haptic.tap()
        service.select(flash: Flash.allCases.firstIndex(of: flash) ?? 0)
    }

    func flipCamera() {
        zoom = 1
        isFrontCamera.toggle()
        Haptic.tap()
        updateFrontMirror()
        service.flip(correctingMount: usesUprightBody)
    }

    /// The upright body is the camera (an iPhone that doesn't fold). Known
    /// only once the first window size is seen, so asked each time.
    private var usesUprightBody: Bool { !Posture.shared.isFoldingPhone && !CameraScreen.forcesLandscapeBody }

    private func updateFrontMirror() {
        let mirror = Self.frontMirror(hold: hold.orientation, uprightBody: usesUprightBody)
        service.frontMirror.withLock { $0 = mirror }
    }

    /// Switches between the plain view and a 2× crop.
    func toggleLens() {
        // 0.5× needs an ultra-wide lens: zooming can only crop, never widen.
        let steps: [CGFloat] = service.hasUltraWide ? [0.5, 1, 2, 3] : [1, 2, 3]
        zoom = steps.first { $0 > zoom + 0.01 } ?? steps[0]
        service.setZoom(zoom)
        Haptic.tap()
    }

    func toggleFormat() {
        isSquare.toggle()
        Haptic.tap()
    }

    func setExposureBias(_ ev: Double) {
        let clamped = min(max(ev, -2), 2)
        // One click per third of a stop, a firmer one at zero and at the ends.
        if abs(clamped - exposureBias) > 0.01 {
            if abs(clamped) < 0.01 || abs(clamped) > 1.99 { Haptic.stop() } else { Haptic.click() }
        }
        exposureBias = clamped
        service.setExposureBias(Float(clamped))
    }

    /// Releases the shutter. `fast` is for the pictures of a burst after the
    /// first: the camera spends less on each so that they follow closely.
    func shoot(fast: Bool = false) {
        // Open flat the phone is the film library: the camera is resting and
        // a press of the volume or Camera Control button takes nothing. The bag
        // open over the camera is the same: its clasp loads the roll, not a
        // button. Asked first, so no press is kept to go off later (retro 14).
        guard !Posture.shared.showsLibrary else { return }
        guard bag == nil else { return }
        // A roll going in: the finder still shows the last one's look, so the
        // press waits the few milliseconds until both are the new roll's (what
        // is seen is what is taken).
        if lookPending { shutterWaiting = fast ? 1 : 2; return }
        // Still exposing the last one: this press is kept (one at most) and taken
        // the moment the shutter is ready again, never dropped unsaid (retro 14).
        if isExposing {
            // One kept; any more while it waits are refused, said with a buzz.
            if pressQueued > 0 { Haptic.stop(); noteShot("refused (one already waiting)"); return }
            pressQueued = fast ? 1 : 2; noteShot("queued"); return
        }
        // No more than a few pictures on their way at once: said with a buzz.
        guard inFlight < 4 else { Haptic.stop(); noteShot("refused (busy)"); return }
        // A shot during the loading animation, or before the chosen roll was
        // seen going in, is on the new roll.
        loadChosenRollNow()
        // Loading it just now started reading its look: the press waits for it.
        if lookPending { shutterWaiting = fast ? 1 : 2; return }
        // No camera (access refused): say so again, and spend nothing.
        guard cameraReady else {
            Haptic.stop()
            message = Self.noCameraMessage
            return
        }
        // A paid film not bought yet: a few free shots, then its page.
        var isTrial = false
        if let film, !FilmStore.shared.isUnlocked(film) {
            guard FilmStore.shared.useTrial(film) else {
                Haptic.stop()
                // The LCD shows END and the finder offers the two ways on:
                // buy this roll there and then, or choose another (user, 11/23).
                // The shutter itself never leaves the camera.
                usedUp = film
                return
            }
            isTrial = true
        }
        isExposing = true
        Posture.shared.holdForShot(true)
        isReviewing = false
        releases += 1
        // Folded open, the finder lies flat under the eye and gravity says
        // nothing about it: the picture is kept exactly as the finder shows it.
        let held: CGImagePropertyOrientation = Posture.shared.isOpen ? .up : hold.orientation
        pendingShots.append(PendingShot(hold: held, film: film, isTrial: isTrial, isSquare: isSquare,
                                        mirror: isFrontCamera ? Self.frontMirror(hold: held, uprightBody: usesUprightBody) : nil))
        inFlight += 1
        Haptic.release()
        service.capture(flash: flash.mode, fast: fast)
    }

    // MARK: - Develop

    /// `lift`: stops to bring the picture up before the film, so it is as
    /// bright as the finder was (the dark finder exposes longer); the iPhone
    /// original kept alongside is the camera's own, unlifted.
    private func develop(_ image: CIImage?, iso: Float, lift: Double = 0) {
        let shot = pendingShots.isEmpty ? PendingShot(hold: .up, film: film, isTrial: false, isSquare: isSquare,
                                                      mirror: isFrontCamera ? .upMirrored : nil)
                                        : pendingShots.removeFirst()
        // An older picture arriving while a newer one is still exposing leaves
        // that exposure (and the press waiting on it) alone (retro 14 review).
        if pendingShots.isEmpty {
            isExposing = false
            Posture.shared.holdForShot(false)
        }
        defer { if pendingShots.isEmpty { takeQueuedPress() } }
        let held = shot.hold
        guard let image else {
            finish(shot, saved: false)
            message = String(ui: "The picture couldn’t be taken. Please try again.")
            return
        }
        let film = shot.film
        let renderer = renderer
        let aspect = shot.isSquare ? 1 : Self.frameAspect
        let arrived = ProcessInfo.processInfo.systemUptime
        developQueue.async { [weak self] in
            // Flipped like the finder (front camera), cropped in the finder's
            // landscape frame, then stood up.
            let seen = shot.mirror.map { image.oriented($0) } ?? image
            let upright = Self.cropToFrame(seen, aspect: aspect).oriented(held)
            let cropped = upright.transformed(by: CGAffineTransform(translationX: -upright.extent.minX,
                                                                    y: -upright.extent.minY))
            let exposed = lift > 0 ? cropped.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: lift]) : cropped
            let developed = renderer.filtered(exposed, film: film, iso: iso)
            let data = renderer.context.heifRepresentation(of: developed,
                                                           format: .RGBA8,
                                                           colorSpace: renderer.sRGB,
                                                           options: [:])
            let developedAt = ProcessInfo.processInfo.systemUptime
            // The finder is fixed to the glass: turned back to how the frame
            // lay in it when taken, so a shot held upright is reviewed upright.
            let thumbnail = Self.thumbnail(of: developed.oriented(Self.undo(held)), context: renderer.context)
            let before = Self.small(cropped, context: renderer.context)
            let pair = Self.small(developed, context: renderer.context).map {
                (before: before, after: $0, film: film?.name ?? "Koco", filmID: film?.id)
            }

            guard let data else {
                Task { @MainActor in
                    self?.finish(shot, saved: false)
                    self?.message = String(ui: "The picture couldn’t be developed.")
                }
                return
            }
            #if DEBUG
            // `-perfRun`: timed, not saved — nothing lands in the user's Photos,
            // and a trial shot used is given back.
            if UserDefaults.standard.bool(forKey: "perfRun") {
                Diag.note(String(format: "perf shot %@ capture %.2fs develop %.2fs (not saved)",
                                 film?.id ?? "-", arrived - shot.pressed, developedAt - arrived))
                Task { @MainActor in self?.finish(shot, saved: false) }
                return
            }
            #endif
            // Settings: keep the iPhone original too, cropped the same way, saved first.
            if Preferences.saveOriginal,
               let original = renderer.context.heifRepresentation(of: cropped, format: .RGBA8,
                                                                  colorSpace: renderer.sRGB, options: [:]) {
                PhotoSaver.save(original) { _ in }
            }
            PhotoSaver.save(data) { result in
                let savedAt = ProcessInfo.processInfo.systemUptime
                Diag.note(String(format: "perf shot %@ capture %.2fs develop %.2fs save %.2fs total %.2fs",
                                 film?.id ?? "-", arrived - shot.pressed, developedAt - arrived,
                                 savedAt - developedAt, savedAt - shot.pressed))
                Task { @MainActor in
                    guard let self else { return }
                    if case .success = result { self.finish(shot, saved: true) } else { self.finish(shot, saved: false) }
                    switch result {
                    case .success(let identifier):
                        // Remembered with its film, for the film library.
                        if let identifier, let film { ShotLog.shared.add(asset: identifier, film: film.id, date: shot.takenAt) }
                        self.lastAsset = identifier
                        self.lastThumbnail = thumbnail
                        self.lastPair = pair
                        self.frameCount += 1
                    case .failure(PhotoSaver.SaveError.denied):
                        self.lastThumbnail = thumbnail
                        self.lastPair = pair   // what is reviewed is what is shared
                        self.lastAsset = nil   // not in Photos: never share the one before
                        self.message = String(ui: "Koco has no access to Photos, so the picture wasn’t saved. Allow it in Settings.")
                    case .failure:
                        self.message = String(ui: "The picture couldn’t be saved to Photos.")
                    }
                }
            }
        }
    }

    /// The end of a shot, whichever way it went. A trial shot that never
    /// reached Photos is not counted.
    private func finish(_ shot: PendingShot, saved: Bool) {
        inFlight = max(inFlight - 1, 0)
        if !saved, shot.isTrial, let film = shot.film { FilmStore.shared.returnTrial(film) }
        shot.keepAlive.end()
    }

    /// Centre-crops to the film's frame aspect and moves the origin to zero.
    nonisolated static func cropToFrame(_ image: CIImage, aspect: CGFloat) -> CIImage {
        let extent = image.extent
        var width = extent.width
        var height = width / aspect
        if height > extent.height {
            height = extent.height
            width = height * aspect
        }
        let rect = CGRect(x: extent.midX - width / 2, y: extent.midY - height / 2, width: width, height: height).integral
        return image.cropped(to: rect).transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
    }

    /// How the front camera's picture (in the back sensor's landscape frame)
    /// is flipped to act as a mirror: across the line that is upright as the
    /// phone is held, as the system camera does. Held sideways that is the
    /// frame's own up; held upright, a quarter on (the upright body's finder
    /// shows the frame turned a quarter, so a left-right flip there is an
    /// up-down flip of the frame). iPhone Duo keeps the flip it was checked with.
    nonisolated static func frontMirror(hold: CGImagePropertyOrientation, uprightBody: Bool) -> CGImagePropertyOrientation {
        guard uprightBody else { return .upMirrored }
        switch hold {
        case .right, .left: return .downMirrored
        default: return .upMirrored
        }
    }

    /// The turn that takes an upright picture back to the finder's frame.
    nonisolated private static func undo(_ turn: CGImagePropertyOrientation) -> CGImagePropertyOrientation {
        switch turn {
        case .right: return .left
        case .left: return .right
        default: return turn   // .up stays; .down undoes itself
        }
    }

    /// Upright and at most 1350 px on its long side: enough for the video.
    nonisolated private static func small(_ image: CIImage, context: CIContext) -> UIImage? {
        let scale = min(1, 1350 / max(image.extent.width, image.extent.height, 1))
        let small = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(small, from: small.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// The SHARE key, reviewing: the first press opens the share tray, the
    /// next sends what the tray is set to.
    func pressShare() {
        guard lastPair != nil, !isMakingShare else { return }
        if !isShareTrayOpen {
            isShareTrayOpen = true
            makeLetterPreview()
            Haptic.tap()
            return
        }
        switch shareKind {
        case .video:
            guard lastPair?.before != nil else {
                message = String(ui: "The video needs the iPhone picture, which wasn’t kept for this shot. Send the letter or the photo.")
                return
            }
            shareLastShot()
        case .letter:
            guard let letter = letterPreview ?? makeLetter() else { return }
            share(letter, named: "letter")
        case .photo:
            // The picture as saved, full size, read back from Photos; the
            // review's small copy only if Photos can't give it.
            guard let photo = lastPair?.after else { return }
            guard let asset = lastAsset else { share(photo, named: "photo"); return }
            isMakingShare = true
            Task {
                defer { isMakingShare = false }
                if let (data, ext) = await PhotoFetch.original(asset) {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("Koco-photo-\(UUID().uuidString.prefix(6)).\(ext)")
                    if (try? data.write(to: url)) != nil { Haptic.tap(); shareVideo = SharedFile(url: url); return }
                }
                share(photo, named: "photo")
            }
        }
    }

    #if DEBUG
    /// `-demoShare letter|video|photo`: as if a picture of the `-feed` sample
    /// had just been taken on `-look`'s roll, reviewed with the tray open.
    func demoShare() {
        guard let kind = UserDefaults.standard.string(forKey: "demoShare"),
              let name = UserDefaults.standard.string(forKey: "feed"),
              let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
              let picture = UIImage(contentsOfFile: url.path) else { return }
        let film = films.first { $0.id == (UserDefaults.standard.string(forKey: "look") ?? "") } ?? self.film
        let developed = film.flatMap { f in CIImage(image: picture).flatMap { FilmRendering.pair($0, film: f, iso: 200) } }
        lastPair = (before: picture, after: developed?.after ?? picture, film: film?.name ?? "Koco", filmID: film?.id)
        lastThumbnail = picture
        isReviewing = true
        shareKind = ["video": .video, "photo": .photo][kind] ?? .letter
        isShareTrayOpen = true
        makeLetterPreview()
        try? letterPreview?.jpegData(compressionQuality: 0.9)?.write(to: URL.documentsDirectory.appendingPathComponent("letter.jpg"))
    }
    #endif

    func closeShareTray() {
        isShareTrayOpen = false
        Haptic.click()
    }

    /// Turns the letter's tag over to its other line.
    func flipLetterLine() {
        letterLine = (letterLine + 1) % ShareLetter.lines.count
        Haptic.click()
    }

    private func makeLetter() -> UIImage? {
        guard let pair = lastPair else { return nil }
        return ShareLetter.make(photo: pair.after, filmID: pair.filmID, filmName: pair.film, line: letterLine)
    }

    private func makeLetterPreview() {
        letterPreview = isShareTrayOpen ? makeLetter() : nil
    }

    /// Writes a picture to a temporary file and offers it to share.
    private func share(_ image: UIImage, named name: String) {
        Haptic.tap()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Koco-\(name)-\(UUID().uuidString.prefix(6)).jpg")
        guard let data = image.jpegData(compressionQuality: 0.92), (try? data.write(to: url)) != nil else {
            message = String(ui: "The picture couldn’t be prepared to share.")
            return
        }
        shareVideo = SharedFile(url: url)
    }

    /// Makes the comparison video of the last picture (iPhone, then film)
    /// and offers it to share.
    func shareLastShot() {
        guard let pair = lastPair, let before = pair.before, !isMakingShare else { return }
        isMakingShare = true
        Haptic.tap()
        Task {
            defer { isMakingShare = false }
            do {
                let url = try await ComparisonVideo.make(before: before, after: pair.after, filmName: pair.film)
                shareVideo = SharedFile(url: url)
            } catch {
                message = String(ui: "The video couldn’t be made.")
            }
        }
    }

    nonisolated private static func thumbnail(of image: CIImage, context: CIContext) -> UIImage? {
        let scale = 1440 / max(image.extent.width, 1)   // sharp when reviewed in the finder
        let small = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(small, from: small.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// What the fingers feel: every key, dial and window answers a touch.
@MainActor
enum Haptic {
    /// Settings: 触感反馈. On unless switched off.
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "haptics") }
    }
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let selection = UISelectionFeedbackGenerator()

    /// A key going down, a window tapped.
    static func tap() { if enabled { light.impactOccurred() } }
    /// One step of a dial.
    static func click() { if enabled { selection.selectionChanged() } }
    /// A ratchet's tooth: firmer than a click (the roll belt, user 11/24).
    static func detent() { if enabled { detentEngine.impactOccurred(intensity: 0.9) } }
    private static let detentEngine = UIImpactFeedbackGenerator(style: .rigid)
    /// A dial reaching a detent or its end; a part seating.
    static func stop() { if enabled { rigid.impactOccurred() } }
    /// The shutter going off.
    static func release() { if enabled { heavy.impactOccurred(intensity: 1) } }
}

/// Keeps the app running in the background, within what the system allows,
/// from the shutter until the picture is in Photos, so leaving the app right
/// after a shot does not lose it. Works in the Lock Screen camera too (no
/// UIApplication there). If the system's time runs out first, the work goes
/// on only as long as the system lets the app run.
final class KeepAlive: @unchecked Sendable {
    private let done = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var ended = false

    init() {
        ProcessInfo.processInfo.performExpiringActivity(withReason: "Saving a picture") { [done] expired in
            if expired {
                #if DEBUG
                print("[camera] background time ran out before the picture was saved")
                #endif
                done.signal()   // let the waiting call return; the system suspends the app
            } else {
                done.wait()
            }
        }
    }

    func end() {
        lock.lock(); defer { lock.unlock() }
        guard !ended else { return }
        ended = true
        done.signal()
    }
}


/// A file handed to the share sheet.
struct SharedFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}
