import Foundation

/// The few switches in Settings, read wherever they act.
enum Preferences {
    private static let defaults = UserDefaults.standard

    /// Also keep the iPhone original of every picture. Off by default.
    static var saveOriginal: Bool {
        get { defaults.bool(forKey: "saveOriginal") }
        set { defaults.set(newValue, forKey: "saveOriginal") }
    }

    /// The system shutter sound. On by default; where the law requires it
    /// (Japan, Korea…) the system plays it whatever this says.
    static var shutterSound: Bool {
        get { defaults.object(forKey: "shutterSound") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "shutterSound") }
    }
}

/// Addresses that only exist once the app is set up in App Store Connect
/// and the support channels are chosen. Rows that need one hide while it is nil.
enum AppLinks {
    /// The numeric App Store id, e.g. "6740000000".
    static let appStoreID: String? = nil
    static let supportEmail: String? = nil
    /// The account page on Xiaohongshu / Instagram, if any.
    static let social: URL? = nil

    static var appStore: URL? { appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)") } }
    static var writeReview: URL? { appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") } }
    /// Apple's standard licence agreement, used as the terms of use.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
