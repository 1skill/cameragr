import LockedCameraCapture
import SwiftUI

/// The app takes the interface any way up (except on a folding phone's outer
/// screen, below), so the system opens it as the Home Screen already is and
/// has no turn to make. The layouts ignore the
/// interface's orientation altogether: each is drawn in its one place on the
/// glass (FixedToPhone), and the system is asked to hold the interface still.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        CameraService.mixAudio()
        return true
    }

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.orientations(onScreen: window?.windowScene?.screen.bounds.size)
    }

    /// Which ways up the interface may be, by the screen the window is on.
    ///
    /// The outer screen of an iPhone Duo (466 points across; every other
    /// iPhone is under 450, its inner screen over 600) shows the closed body,
    /// which is fixed to the glass on its side. The interface takes the one
    /// landscape that body is drawn in, so the swipe home is along the body's
    /// bottom edge, whatever the rotation lock says (user 11/27). A single
    /// landscape is outside any portrait lock, so the system turns to it, as
    /// for a landscape-only game. Everywhere else, any way up, as before.
    static func orientations(onScreen screen: CGSize?) -> UIInterfaceOrientationMask {
        guard let screen else { return .all }
        let short = min(screen.width, screen.height)
        if short > 450, short < 600 { return outerBody }
        return .all
    }

    /// The landscape whose frame is the closed body's place on the outer screen
    /// (`FoldLayout.bodyTurnOnGlass`, 90° clockwise from the screen's upright
    /// fixed space): the interface's x axis along the fixed space's y axis.
    static let outerBody: UIInterfaceOrientationMask = .landscapeRight
}

@main
struct CameraGRApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = CameraModel()

    @ViewBuilder private var root: some View {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "widgets") { WidgetGallery() } else { CameraScreen() }
        #else
        CameraScreen()
        #endif
    }

    /// Pictures taken with the Lock Screen camera while the phone was locked
    /// couldn't go into the Peli album at the time; put them there now.
    private func fileLockScreenShots() async {
        for await update in LockedCameraCaptureManager.shared.sessionContentUpdates {
            let folders: [URL]
            switch update {
            case .initial(let urls): folders = urls
            case .added(let url): folders = [url]
            default: folders = []
            }
            for folder in folders {
                #if DEBUG
                if let record = try? String(contentsOf: folder.appendingPathComponent(Diag.fileName), encoding: .utf8) {
                    // Kept in the app's own folder: the session's is discarded below.
                    let history = URL.documentsDirectory.appendingPathComponent("diag-history.txt")
                    let earlier = (try? String(contentsOf: history, encoding: .utf8)) ?? ""
                    let entry = "=== \(Date()) \(folder.lastPathComponent)\n\(record)\n"
                    try? String((earlier + entry).suffix(20000)).write(to: history, atomically: true, encoding: .utf8)
                }
                #endif
                // Trial shots taken on the Lock Screen count here too.
                let shotsKept = await MainActor.run {
                    FilmStore.shared.addLockScreenTrials(from: folder)
                    return ShotLog.shared.addLockScreenShots(from: folder)
                }
                let log = folder.appendingPathComponent(PhotoSaver.unfiledLogName)
                let filed = await withCheckedContinuation { done in
                    PhotoSaver.fileLater(from: log) { done.resume(returning: $0) }
                }
                // The session goes only once its pictures are filed and noted with their films.
                if filed && shotsKept { try? await LockedCameraCaptureManager.shared.invalidateSessionContent(at: folder) }
            }
        }
    }

    @ObservedObject private var language = AppLanguage.shared

    var body: some Scene {
        WindowGroup {
            root
                // The language chosen in the kit, at once for every text.
                .environment(\.locale, language.locale)
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
                .onOpenURL { model.open($0) }
                // From the Lock Screen camera: FILMS or SETUP unlocked the
                // phone to open the bag at those pages.
                .onContinueUserActivity(NSUserActivityTypeLockedCameraCapture) { activity in
                    model.openBag(fromLockScreen: activity.userInfo)
                }
                .task { await fileLockScreenShots() }
                #if DEBUG
                .task { await debugRender(model) }
                #endif
                #if DEBUG
                // The app's own record (hinge readings, fold changes), read off the phone with devicectl.
                .task {
                    Diag.write(to: URL.documentsDirectory.appendingPathComponent("diag-app.txt"))
                    #if DEBUG
                    if UserDefaults.standard.bool(forKey: "logHits") { HitLog.start() }
                    #endif
                }
                #endif
                #if DEBUG
                .task { await debugSnapshot() }
                .task { await debugComparisonVideo() }
                .task { await debugExportSamples() }
                #endif
        }
    }
}

#if DEBUG
/// `-snap <seconds>`: after that long, draw the window into Documents/snap.png,
/// for layout checks where the simulator's own screenshot is unavailable.
@MainActor
private func debugSnapshot() async {
    let wait = UserDefaults.standard.double(forKey: "snap")
    guard wait > 0 else { return }
    try? await Task.sleep(for: .seconds(wait))
    guard let window = UIApplication.shared.connectedScenes
        .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
    let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("snap.png")
    try? image.pngData()?.write(to: url)
}
#endif

#if DEBUG
/// `-exportSamples 1`: writes every film's samples, original and through
/// the film, to Documents/samples/ (for App Store screenshots).
private func debugExportSamples() async {
    // `-exportOne <sample>`: that one bundled picture through every film.
    if let one = UserDefaults.standard.string(forKey: "exportOne"),
       let url = Bundle.main.url(forResource: one, withExtension: "jpg"), let image = CIImage(contentsOf: url) {
        let folder = URL.documentsDirectory.appendingPathComponent("one")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for film in FilmLibrary.shared.films {
            let pair = await Task.detached { FilmRendering.pair(image, film: film, iso: 200) }.value
            try? pair?.after.jpegData(compressionQuality: 0.92)?.write(to: folder.appendingPathComponent("\(film.id).jpg"))
        }
        try? Data("done".utf8).write(to: folder.appendingPathComponent("done.txt"))
        return
    }
    guard UserDefaults.standard.bool(forKey: "exportSamples") else { return }
    let folder = URL.documentsDirectory.appendingPathComponent("samples")
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for film in FilmLibrary.shared.films {
        for sample in FilmNotes.all[film.id]?.samples ?? [] {
            guard let url = Bundle.main.url(forResource: sample.file, withExtension: "jpg"),
                  let image = CIImage(contentsOf: url) else { continue }
            let pair = await Task.detached { FilmRendering.pair(image, film: film, iso: sample.iso) }.value
            guard let pair else { continue }
            try? pair.after.jpegData(compressionQuality: 0.92)?.write(to: folder.appendingPathComponent("\(film.id)__\(sample.file).jpg"))
            try? pair.before.jpegData(compressionQuality: 0.92)?.write(to: folder.appendingPathComponent("orig__\(sample.file).jpg"))
        }
    }
    try? Data("done".utf8).write(to: folder.appendingPathComponent("done.txt"))
}

/// `-video <film id>`: writes the share video of that film's first sample
/// to Documents/compare.mp4, to check the video without the share flow.
private func debugComparisonVideo() async {
    guard let id = UserDefaults.standard.string(forKey: "video"),
          let film = FilmLibrary.shared.films.first(where: { $0.id == id }),
          let sample = FilmNotes.all[id]?.samples.first,
          let url = Bundle.main.url(forResource: sample.file, withExtension: "jpg"),
          let image = CIImage(contentsOf: url),
          let pair = FilmRendering.pair(image, film: film, iso: sample.iso),
          let video = try? await ComparisonVideo.make(before: pair.before, after: pair.after, filmName: film.name)
    else { return }
    let target = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("compare.mp4")
    try? FileManager.default.removeItem(at: target)
    try? FileManager.default.moveItem(at: video, to: target)
}
#endif

#if DEBUG
/// `-render inner|outer|finder`: draws that screen at the Duo's real size and
/// resolution (inner 951×669 pt, outer 678×466 pt, a half-fold half 669×475 pt, @3x) in a window
/// of its own, into Documents/render.png — for App Store screenshots and
/// checks the simulator's one screen can't show.
@MainActor
private func debugRender(_ model: CameraModel) async {
    guard let what = UserDefaults.standard.string(forKey: "render"),
          let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
    try? await Task.sleep(for: .seconds(2))
    let size: CGSize
    let view: AnyView
    switch what {
    case "outer":
        // The closed phone's outer screen: the camera body. It lays itself
        // out for the phone held upright here, so the window is upright and
        // the picture comes out on its side (turn it a quarter after).
        size = CGSize(width: 466, height: 678)
        model.demoShare()
        view = AnyView(CameraScreen().environmentObject(model))
    case "finder":
        size = CGSize(width: 669, height: 475)
        view = AnyView(WaistFinder().environmentObject(model))
    default:
        size = CGSize(width: 951, height: 669)
        view = AnyView(RollLibrary().environmentObject(model))
    }
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(origin: CGPoint(x: 4000, y: 0), size: size)
    window.rootViewController = UIHostingController(rootView: view.ignoresSafeArea().preferredColorScheme(.dark))
    window.isHidden = false
    try? await Task.sleep(for: .seconds(UserDefaults.standard.double(forKey: "renderWait") > 0
                                        ? UserDefaults.standard.double(forKey: "renderWait") : 4))
    let format = UIGraphicsImageRendererFormat()
    // `-renderScale N` for large App Store crops (default @3x, the phone's own).
    let scale = UserDefaults.standard.double(forKey: "renderScale")
    format.scale = scale > 0 ? scale : 3
    let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
        window.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
    }
    try? image.pngData()?.write(to: URL.documentsDirectory.appendingPathComponent("render.png"))
    window.isHidden = true
}
#endif

#if DEBUG
import ObjectiveC
/// `-logHits 1`: notes in the diag file which view each touch lands on, and
/// its chain of superviews (for finding what takes a touch meant for another).
enum HitLog {
    static func start() {
        let original = #selector(UIWindow.hitTest(_:with:)), swapped = #selector(UIWindow.koco_hitTest(_:with:))
        guard let m = class_getInstanceMethod(UIWindow.self, original),
              let n = class_getInstanceMethod(UIWindow.self, swapped) else { return }
        // hitTest is UIView's: give UIWindow its own first, so only windows change.
        if class_addMethod(UIWindow.self, original, method_getImplementation(n), method_getTypeEncoding(n)) {
            class_replaceMethod(UIWindow.self, swapped, method_getImplementation(m), method_getTypeEncoding(m))
        } else {
            method_exchangeImplementations(m, n)
        }
    }
}
extension UIWindow {
    @objc func koco_hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = koco_hitTest(point, with: event)   // the original, swapped
        if event?.type == .touches {
            var chain: [String] = []
            var v = view
            while let x = v, chain.count < 8 { chain.append(String(describing: type(of: x)) + "\(x.frame.integral)"); v = x.superview }
            Diag.note("hit \(point) -> " + chain.joined(separator: " < "))
        }
        return view
    }
}
#endif
