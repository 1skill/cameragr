import Foundation

/// What the film detail page says about a stock, and its sample pictures
/// (`film_notes.json`). Samples are iPhone-style originals in
/// `Resources/Samples`; the app renders the film's version itself.
/// The text is kept per language; English is the fallback.
struct FilmNote {
    struct Sample: Decodable, Hashable {
        /// File name in Resources/Samples, without the extension (.jpg).
        let file: String
        /// The ISO the scene would have been shot at (for looks with sensor noise).
        let iso: Float
        /// Where the comparison divider starts, 0...1 across: on the subject.
        let split: Double
    }
    let tagline: String
    let about: String
    let suits: [String]
    let samples: [Sample]
}

enum FilmNotes {
    private struct Text: Decodable { let tagline: String; let about: String; let suits: [String] }
    private struct Entry: Decodable { let samples: [FilmNote.Sample]; let text: [String: Text] }

    /// The app's language as the system resolved it against our localizations.
    static var language: String {
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        // Traditional Chinese (Taiwan, Hong Kong) has its own text; any other Chinese is Simplified.
        if lang.hasPrefix("zh-Hant") || lang == "zh-TW" || lang == "zh-HK" || lang == "zh-MO" { return "zh-Hant" }
        if lang.hasPrefix("zh") { return "zh-Hans" }
        return lang
    }

    private static let entries: [String: Entry] = {
        guard let url = Bundle.main.url(forResource: "film_notes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([String: Entry].self, from: data) else { return [:] }
        return entries
    }()

    /// A film's notes in exactly that language, without falling back (for checks).
    static func text(for film: String, language: String) -> String? {
        entries[film]?.text[language].map { $0.tagline + " " + $0.about }
    }

    static let all: [String: FilmNote] = {
        entries.compactMapValues { entry in
            guard let text = entry.text[language] ?? entry.text["en"] else { return nil }
            return FilmNote(tagline: text.tagline, about: text.about, suits: text.suits, samples: entry.samples)
        }
    }()
}
