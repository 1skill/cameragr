import SwiftUI

@main
struct CameraGRApp: App {
    @StateObject private var model = CameraModel()

    var body: some Scene {
        WindowGroup {
            CameraScreen()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
        }
    }
}
