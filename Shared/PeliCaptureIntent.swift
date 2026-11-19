import AppIntents

/// Lets the system open Peli as a camera: from the Camera Control button, the
/// Lock Screen and Control Center. Has to be in the app, the widget extension
/// and the capture extension alike.
struct PeliCaptureIntent: CameraCaptureIntent {
    static let title: LocalizedStringResource = "用 Koco 拍照"
    static let description = IntentDescription("打开 Koco 胶片相机。")

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}
