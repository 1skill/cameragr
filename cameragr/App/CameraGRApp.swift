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
                let log = folder.appendingPathComponent(PhotoSaver.unfiledLogName)
                let filed = await withCheckedContinuation { done in
                    PhotoSaver.fileLater(from: log) { done.resume(returning: $0) }
                }
                if filed { try? await LockedCameraCaptureManager.shared.invalidateSessionContent(at: folder) }
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
                .task { await debugSnapshot() }
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
