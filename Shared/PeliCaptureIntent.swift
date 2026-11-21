import AppIntents

/// Lets the system open Peli as a camera: from the Camera Control button, the
/// Lock Screen and Control Center. Has to be in the app, the widget extension
/// and the capture extension alike.
struct PeliCaptureIntent: CameraCaptureIntent {
    static let title: LocalizedStringResource = "Shoot with Koco"
    static let description = IntentDescription("Open the Koco film camera.")

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}
