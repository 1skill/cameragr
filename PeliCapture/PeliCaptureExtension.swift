import ExtensionKit
import LockedCameraCapture
import SwiftUI

/// The camera the system shows when Peli is opened from the Camera Control
/// button or the Lock Screen while the phone is still locked. It is the same
/// body as in the app; photos go straight into the photo library.
@main
struct PeliCaptureExtension: LockedCameraCaptureExtension {
    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            LockedCamera()
                .onAppear {
                    Diag.write(to: session.sessionContentURL.appendingPathComponent(Diag.fileName))
                    // On a locked phone the Peli album is out of reach. Shots are
                    // noted here and the app files them once it is opened.
                    PhotoSaver.unfiledLog = session.sessionContentURL.appendingPathComponent(PhotoSaver.unfiledLogName)
                    // Trial shots are noted there too, for the app to count.
                    FilmStore.lockScreenTrialLog = session.sessionContentURL
                        .appendingPathComponent(FilmStore.lockScreenTrialLogName)
                }
        }
    }
}

private struct LockedCamera: View {
    @StateObject private var model = CameraModel()

    var body: some View {
        CameraScreen(showsExitHint: true)
            .environmentObject(model)
            .preferredColorScheme(.dark)
            // Black from the very first frame, before the body is laid out.
            .background(Color.black.ignoresSafeArea())
            // Which films are bought: only the app knows; it left word for us.
            .task { await FilmStore.shared.adoptAppContext() }
    }
}
