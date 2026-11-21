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
    @Published var frameCount = 0
    /// True from the shutter press until the camera hands over the exposure:
    /// the finder blinks dark and a second press is ignored. Developing and
    /// saving happen afterwards in the background and don't hold up the next shot.
    @Published var isExposing = false
    /// Counts shutter releases: the finder's shutter closes once for each.
    @Published var releases = 0
    /// The finder shows the last picture instead of the scene.
    @Published var isReviewing = false
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
            }
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
        service.onPhoto = { [weak self] image, iso in
            // Read the film on the main actor, then develop off it.
            Task { @MainActor in self?.develop(image, iso: iso) }
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
        switch mode {
        case .closed:
            // Closed on a chosen roll: it goes in, seen through the chamber door.
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
        case .half:
            // Folded for the waist-level finder: the chosen roll goes straight in.
            if let next = readyToLoad {
                readyToLoad = nil
                if next != film { load(next) }
                Haptic.stop()
            }
        case .flat:
            isReviewing = false
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
        // A shot during the loading animation is on the new roll.
        completeArrival()
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

    private func develop(_ image: CIImage?, iso: Float) {
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
        developQueue.async { [weak self] in
            // Crop in the finder's landscape frame first, then stand the picture up.
            let upright = Self.cropToFrame(image, aspect: aspect).oriented(held)
            let cropped = upright.transformed(by: CGAffineTransform(translationX: -upright.extent.minX,
                                                                    y: -upright.extent.minY))
            let developed = renderer.filtered(cropped, film: film, iso: iso)
            let data = renderer.context.heifRepresentation(of: developed,
                                                           format: .RGBA8,
                                                           colorSpace: renderer.sRGB,
                                                           options: [:])
            // The finder is fixed to the glass: turned back to how the frame
            // lay in it when taken, so a shot held upright is reviewed upright.
            let thumbnail = Self.thumbnail(of: developed.oriented(Self.undo(held)), context: renderer.context)

            guard let data else {
                Task { @MainActor in
                    self?.finish(shot, saved: false)
                    self?.message = String(localized: "The picture couldn’t be developed.")
                }
                return
            }
            // Settings: keep the iPhone original too, cropped the same way, saved first.
            if Preferences.saveOriginal,
               let original = renderer.context.heifRepresentation(of: cropped, format: .RGBA8,
                                                                  colorSpace: renderer.sRGB, options: [:]) {
                PhotoSaver.save(original) { _ in }
            }
            PhotoSaver.save(data) { result in
                Task { @MainActor in
                    guard let self else { return }
                    if case .success = result { self.finish(shot, saved: true) } else { self.finish(shot, saved: false) }
                    switch result {
                    case .success(let identifier):
                        // Remembered with its film, for the film library.
                        if let identifier, let film { ShotLog.shared.add(asset: identifier, film: film.id) }
                        self.lastThumbnail = thumbnail
                        self.frameCount += 1
                    case .failure(PhotoSaver.SaveError.denied):
                        self.lastThumbnail = thumbnail
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
