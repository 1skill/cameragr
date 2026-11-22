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
            case .off: String(localized: "Off")
            case .auto: String(localized: "Auto")
            case .on: String(localized: "On")
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

    @Published var film: Film?
    /// A roll chosen in the film library, loaded when the phone is next closed
    /// (or folded for the waist-level finder). Looking through the library
    /// alone never changes the loaded roll.
    @Published private(set) var readyToLoad: Film?
    /// The chosen roll on its way into the camera after the phone was closed:
    /// the chamber shows it going in (FilmChamber), then loads it.
    @Published var arrivingRoll: Film?
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
    /// The letter as it would go out, for the tray's preview.
    @Published private(set) var letterPreview: UIImage?
    @Published var message: String?

    /// A page over the body, opened from the strip beside the open chamber.
    enum Panel: Equatable { case detail(Film), settings }
    @Published var panel: Panel?
    /// The film store is open (pages opened from it go over it).
    @Published var isStoreOpen = false

    private let service = CameraService()
    /// Which way up the phone is held right now.
    var heldOrientation: CGImagePropertyOrientation { hold.orientation }
    private let hold = HoldSensor()
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
        /// When the shutter was pressed (for the timing record in debug builds).
        let pressed = ProcessInfo.processInfo.systemUptime
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

    init() {
        film = films.first
        #if DEBUG
        // Launch arguments for automated UI checks: -film <id>  -bay 1  -shoot 1  -url <link>
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: "film"), let match = films.first(where: { $0.id == id }) {
            film = match
        }
        isBayOpen = defaults.bool(forKey: "bay")
        // `-panel settings|store|<film id>`: open a page at launch.
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
            let all = films
            for (i, next) in all.enumerated() {
                let t = 4 + Double(i) * 7
                DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in
                    self?.load(next); Diag.note("perf film \(next.id)")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + t + 5) { [weak self] in self?.shoot() }
            }
            let burst = 4 + Double(all.count) * 7 + 2
            for k in 0..<5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + burst + Double(k) * 0.35) { [weak self] in
                    self?.shoot(fast: k > 0)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + burst + 10) { Diag.note("perf done") }
        }
                if defaults.bool(forKey: "resetStore") { Task { @MainActor in await FilmStore.shared.resetDebugState() } }
        if let link = defaults.string(forKey: "url").flatMap(URL.init(string:)) { open(link) }
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
        service.onShutter = { [weak self] in
            // Ready for the next exposure; this one is still being processed.
            Task { @MainActor in
                self?.isExposing = false
                Posture.shared.holdForShot(false)
            }
        }
        service.onPhoto = { [weak self] image, iso, lift in
            // Read the film on the main actor, then develop off it.
            Task { @MainActor in self?.develop(image, iso: iso, lift: lift) }
        }
    }

    func start() {
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
        String(localized: "Koco has no access to the camera. Allow it in Settings.")
    }

    func stop() {
        hold.stop()
        cameraReady = false
        service.stop()
    }

    /// Chooses a roll in the film library: it goes in when the phone is
    /// closed. Choosing the loaded roll, or the chosen one again, takes the choice back.
    func chooseInLibrary(_ choice: Film) {
        readyToLoad = (choice == film || choice == readyToLoad) ? nil : choice
        Haptic.tap()
    }

    /// The phone was folded or unfolded (see `Posture`).
    func foldChanged(to mode: FoldMode) {
        // Opened again while a roll was still going in: it is in.
        if mode != .closed { completeArrival() }
        // The chosen roll waits until the phone is shut all the way, where its
        // going in can be watched (`phoneShut`), or until a picture is taken
        // (`shoot` loads it first): passing through part-open while closing
        // must not load it unseen. At waist level the finder already shows it,
        // so what is seen is what the first picture gets.
        frames.set(film: mode == .half ? (readyToLoad ?? film) : film)
        if mode == .flat { isReviewing = false }
    }

    /// The phone is shut all the way (see `Posture.isShut`): a chosen roll
    /// goes in now, seen through the chamber door.
    func phoneShut() {
        guard let next = readyToLoad else { return }
        readyToLoad = nil
        guard next != film else { return }
        isStoreOpen = false
        panel = nil
        arrivingRoll = next
        isBayOpen = true
        // Should the chamber not be shown (e.g. the app left meanwhile),
        // the roll goes in all the same: this one, if it is still on its way.
        let arrival = UUID()
        arrivalID = arrival
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
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
        if next != film { load(next) }
        isBayOpen = false
    }

    func load(_ film: Film) {
        self.film = film
        frames.set(film: film)
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
        service.flip()
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
        // No more than a few pictures on their way at once.
        guard !isExposing, inFlight < 4 else { return }
        // Open flat the phone is the film library: the camera is resting and
        // a press of the volume or Camera Control button takes nothing.
        guard Posture.shared.mode != .flat else { return }
        // A shot during the loading animation, or before the chosen roll was
        // seen going in, is on the new roll.
        loadChosenRollNow()
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
                isStoreOpen = true
                panel = .detail(film)
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
        pendingShots.append(PendingShot(hold: Posture.shared.isOpen ? .up : hold.orientation,
                                        film: film, isTrial: isTrial, isSquare: isSquare))
        inFlight += 1
        Haptic.release()
        service.capture(flash: flash.mode, fast: fast)
    }

    // MARK: - Develop

    /// `lift`: stops to bring the picture up before the film, so it is as
    /// bright as the finder was (the dark finder exposes longer); the iPhone
    /// original kept alongside is the camera's own, unlifted.
    private func develop(_ image: CIImage?, iso: Float, lift: Double = 0) {
        isExposing = false
        Posture.shared.holdForShot(false)
        let shot = pendingShots.isEmpty ? PendingShot(hold: .up, film: film, isTrial: false, isSquare: isSquare)
                                        : pendingShots.removeFirst()
        let held = shot.hold
        guard let image else {
            finish(shot, saved: false)
            message = String(localized: "The picture couldn’t be taken. Please try again.")
            return
        }
        let film = shot.film
        let renderer = renderer
        let aspect = shot.isSquare ? 1 : Self.frameAspect
        let arrived = ProcessInfo.processInfo.systemUptime
        developQueue.async { [weak self] in
            // Crop in the finder's landscape frame first, then stand the picture up.
            let upright = Self.cropToFrame(image, aspect: aspect).oriented(held)
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
                    self?.message = String(localized: "The picture couldn’t be developed.")
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
                        if let identifier, let film { ShotLog.shared.add(asset: identifier, film: film.id) }
                        self.lastThumbnail = thumbnail
                        self.lastPair = pair
                        self.frameCount += 1
                    case .failure(PhotoSaver.SaveError.denied):
                        self.lastThumbnail = thumbnail
                        self.lastPair = pair   // what is reviewed is what is shared
                        self.message = String(localized: "Koco has no access to Photos, so the picture wasn’t saved. Allow it in Settings.")
                    case .failure:
                        self.message = String(localized: "The picture couldn’t be saved to Photos.")
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
                message = String(localized: "The video needs the iPhone picture, which wasn’t kept for this shot. Send the letter or the photo.")
                return
            }
            shareLastShot()
        case .letter:
            guard let letter = letterPreview ?? makeLetter() else { return }
            share(letter, named: "letter")
        case .photo:
            guard let photo = lastPair?.after else { return }
            share(photo, named: "photo")
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
        lastPair = (before: picture, after: picture, film: film?.name ?? "Koco", filmID: film?.id)
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
            message = String(localized: "The picture couldn’t be prepared to share.")
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
                message = String(localized: "The video couldn’t be made.")
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
