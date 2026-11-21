import AppIntents
import SwiftUI
import WidgetKit

/// A button for Control Center, the Lock Screen and the Action button that opens Peli.
struct PeliCaptureControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.oneskill.cameragr.capture") {
            ControlWidgetButton(action: PeliCaptureIntent()) {
                Label("Koco", systemImage: "camera.fill")
            }
        }
        .displayName("Koco Camera")
        .description("Open the Koco film camera.")
    }
}
