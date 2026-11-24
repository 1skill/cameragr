import Combine
import Foundation

/// The language Koco's interface is shown in, chosen in the bag's kit
/// (user 11/24: in the app, not in iOS Settings). SwiftUI text follows it at
/// once through the environment's locale; strings made in code take it from
/// that language's own strings (`bundle`). It is also written where iOS keeps
/// an app's language, so what the system draws for the app (permission
/// prompts) follows from the next launch.
final class AppLanguage: ObservableObject {
    static let shared = AppLanguage()
    /// The languages Koco is translated into, in the order the key steps through.
    static let all = ["en", "zh-Hans", "zh-Hant", "ja", "ko"]

    /// The language in use: the one chosen, else the one iOS picked for the app.
    @Published private(set) var code: String

    private init() {
        code = UserDefaults.standard.string(forKey: Self.key)
            ?? Self.resolve(Bundle.main.preferredLocalizations.first ?? "en")
    }
    private static let key = "appLanguage"

    /// Our nearest translation for a language iOS names.
    static func resolve(_ lang: String) -> String {
        if lang.hasPrefix("zh-Hant") || lang == "zh-TW" || lang == "zh-HK" || lang == "zh-MO" { return "zh-Hant" }
        if lang.hasPrefix("zh") { return "zh-Hans" }
        let base = String(lang.prefix(2))
        return all.contains(lang) ? lang : (all.contains(base) ? base : "en")
    }

    var locale: Locale { Locale(identifier: code) }

    /// The language's own strings, for strings made in code.
    var bundle: Bundle {
        Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }

    /// A language's name in itself (English, 日本語…).
    static func name(_ code: String) -> String {
        let name = Locale(identifier: code).localizedString(forIdentifier: code) ?? code
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    /// Steps to the next language.
    func next() { choose(Self.all[((Self.all.firstIndex(of: code) ?? 0) + 1) % Self.all.count]) }

    func choose(_ new: String) {
        guard new != code else { return }
        UserDefaults.standard.set(new, forKey: Self.key)
        UserDefaults.standard.set([new], forKey: "AppleLanguages")
        code = new
    }
}

extension String {
    /// A string of Koco's in the interface's language (see `AppLanguage`).
    init(ui key: String.LocalizationValue) {
        self.init(localized: key, bundle: AppLanguage.shared.bundle, locale: AppLanguage.shared.locale)
    }
}
