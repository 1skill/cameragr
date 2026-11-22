import LockedCameraCapture
import SwiftUI

/// The app takes the interface any way up, so the system opens it as the Home
/// Screen already is and has no turn to make. The layouts ignore the
/// interface's orientation altogether: each is drawn in its one place on the
/// glass (FixedToPhone), and the system is asked to hold the interface still.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .all
    }
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

    var body: some Scene {
        WindowGroup {
            root
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
                .onOpenURL { model.open($0) }
                .task { await fileLockScreenShots() }
                #if DEBUG
                .task { await debugRender(model) }
                #endif
                #if DEBUG
                // The app's own record (hinge readings, fold changes), read off the phone with devicectl.
                .task { Diag.write(to: URL.documentsDirectory.appendingPathComponent("diag-app.txt")) }
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
    format.scale = 3
    let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
        window.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
    }
    try? image.pngData()?.write(to: URL.documentsDirectory.appendingPathComponent("render.png"))
    window.isHidden = true
}
#endif
