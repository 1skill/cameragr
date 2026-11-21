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
        return lang.hasPrefix("zh") ? "zh-Hans" : lang
    }

    static let all: [String: FilmNote] = {
        guard let url = Bundle.main.url(forResource: "film_notes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([String: Entry].self, from: data) else { return [:] }
        return entries.compactMapValues { entry in
            guard let text = entry.text[language] ?? entry.text["en"] else { return nil }
            return FilmNote(tagline: text.tagline, about: text.about, suits: text.suits, samples: entry.samples)
        }
    }()
}
