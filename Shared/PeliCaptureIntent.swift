import AppIntents

/// Lets the system open Peli as a camera: from the Camera Control button, the
/// Lock Screen and Control Center. Has to be in the app, the widget extension
/// and the capture extension alike.
struct PeliCaptureIntent: CameraCaptureIntent {
    typealias AppContext = CaptureContext
    static let title: LocalizedStringResource = "Shoot with Koco"
    static let description = IntentDescription("Open the Koco film camera.")

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}

/// What the Lock Screen camera needs to know from the app, which it cannot
/// read directly: the films this Apple ID owns and the trial shots used.
/// The app hands it over through the capture intent's app context.
struct CaptureContext: Codable {
    var owned: [String]
    var trialsUsed: [String: Int]
}
