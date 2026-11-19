import AppIntents
import SwiftUI
import WidgetKit

/// A button for Control Center, the Lock Screen and the Action button that opens Peli.
struct PeliCaptureControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.oneskill.cameragr.capture") {
            ControlWidgetButton(action: PeliCaptureIntent()) {
                Label("Peli", systemImage: "camera.fill")
            }
        }
        .displayName("Peli 相机")
        .description("打开 Peli 胶片相机。")
    }
}
