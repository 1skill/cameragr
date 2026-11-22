import AppIntents
import SwiftUI
import WidgetKit

/// The link a roll opens: peli://film/<id>, handled by `CameraModel.open(_:)`.
private func link(to film: Film) -> URL {
    URL(string: "peli://film/\(film.id)") ?? URL(string: "peli://film")!
}

// MARK: - Shelf (medium, large)

struct FilmShelfWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "FilmShelf", intent: SelectShelfIntent.self, provider: ShelfProvider()) { entry in
            FilmShelfView(chosen: entry.films)
        }
        .configurationDisplayName("Film Shelf")
        .description("Tap a roll to start shooting with it.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

/// Which rolls stand on the shelf, in the order picked (up to six on the
/// medium shelf, sixteen on the large). None picked: the catalogue's own order.
struct SelectShelfIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Films"
    static var description = IntentDescription("Pick the rolls for this shelf, in the order they stand.")

    @Parameter(title: "Films", size: [.systemMedium: 6, .systemLarge: 16])
    var films: [FilmEntity]?
}

struct ShelfEntry: TimelineEntry {
    let date: Date
    /// Picked rolls, or nil for the default.
    let films: [Film]?
}

struct ShelfProvider: AppIntentTimelineProvider {
    private func entry(for configuration: SelectShelfIntent) -> ShelfEntry {
        let all = FilmLibrary.shared.films
        // Kept in the order picked; a roll no longer offered is skipped.
        let picked = (configuration.films ?? []).compactMap { pick in all.first { $0.id == pick.id } }
        return ShelfEntry(date: .now, films: picked.isEmpty ? nil : picked)
    }

    func placeholder(in context: Context) -> ShelfEntry { ShelfEntry(date: .now, films: nil) }

    func snapshot(for configuration: SelectShelfIntent, in context: Context) async -> ShelfEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: SelectShelfIntent, in context: Context) async -> Timeline<ShelfEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }
}

struct FilmShelfView: View {
    @Environment(\.widgetFamily) private var family
    /// The rolls picked for this shelf; nil shows the catalogue.
    var chosen: [Film]? = nil
    private var films: [Film] { chosen ?? FilmLibrary.shared.films }
    /// Set only by the in-app preview, which has no widget family.
    var previewLarge: Bool?

    var body: some View {
        let large = previewLarge ?? (family == .systemLarge)
        // Medium: one shelf of six. Large: every film in the catalogue has its
        // place: shelves of three while there are nine or fewer, of four
        // beyond (four shelves hold all sixteen).
        let perRow = large ? (films.count > 9 ? 4 : 3) : 6
        let shown = min(films.count, large ? perRow * perRow : 6)
        // A real shelf: its places stay put; rolls not picked leave gaps,
        // so every roll keeps its size whatever was chosen.
        let rowCount = large ? perRow : 1
        let rows: [[Film?]] = (0..<rowCount).map { r in
            (0..<perRow).map { c in
                let i = r * perRow + c
                return i < shown ? films[i] : nil
            }
        }
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Shelf(films: row, large: large)
            }
            BodyStripe()
        }
        .overlay(alignment: .topLeading) {
            if !large {
                Text("KOCO")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .kerning(4)
                    .foregroundStyle(Color(white: 0.55))
                    .padding(.leading, 18)
                    .padding(.top, 14)
            }
        }
        .containerBackground(for: .widget) { BodyBackground() }
    }
}

/// One row of rolls standing on a ledge.
private struct Shelf: View {
    let films: [Film?]
    let large: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(films.enumerated()), id: \.offset) { _, place in
                    if let film = place {
                    Link(destination: link(to: film)) {
                        VStack(spacing: large ? 6 : 4) {
                            Canister(film: film)
                                .aspectRatio(0.68, contentMode: .fit)
                                .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
                                .padding(.horizontal, large ? 16 : 6)
                            // The name may use the whole width of its place.
                            Text(film.name)
                                .font(.system(size: large ? 11 : 8, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color(white: 0.82))
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .padding(.horizontal, 2)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                    } else {
                        // An empty place on the shelf.
                        Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, large ? 14 : 12)
            .padding(.bottom, 6)
            // The ledge the rolls stand on.
            Rectangle().fill(Color.black.opacity(0.55)).frame(height: 2)
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
        }
    }
}

// MARK: - Single roll (small)

struct SingleFilmWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "SingleFilm", intent: SelectFilmIntent.self, provider: SingleFilmProvider()) { entry in
            SingleFilmView(film: entry.film)
        }
        .configurationDisplayName("One Roll")
        .description("Pick a favourite roll and tap to shoot with it.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct SelectFilmIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Film"

    @Parameter(title: "Film")
    var film: FilmEntity?
}

struct FilmEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Film"
    static var defaultQuery = FilmQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(_ film: Film) {
        id = film.id
        name = film.name
    }
}

struct FilmQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [FilmEntity] {
        // In the order asked for: a shelf keeps the order its rolls were picked in.
        let films = FilmLibrary.shared.films
        return identifiers.compactMap { id in films.first { $0.id == id } }.map(FilmEntity.init)
    }

    func suggestedEntities() async throws -> [FilmEntity] {
        FilmLibrary.shared.films.map(FilmEntity.init)
    }

    func defaultResult() async -> FilmEntity? {
        FilmLibrary.shared.films.first.map(FilmEntity.init)
    }
}

struct SingleFilmEntry: TimelineEntry {
    let date: Date
    let film: Film?
}

struct SingleFilmProvider: AppIntentTimelineProvider {
    private func entry(for configuration: SelectFilmIntent) -> SingleFilmEntry {
        let films = FilmLibrary.shared.films
        let film = films.first { $0.id == configuration.film?.id } ?? films.first
        return SingleFilmEntry(date: .now, film: film)
    }

    func placeholder(in context: Context) -> SingleFilmEntry {
        SingleFilmEntry(date: .now, film: FilmLibrary.shared.films.first)
    }

    func snapshot(for configuration: SelectFilmIntent, in context: Context) async -> SingleFilmEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: SelectFilmIntent, in context: Context) async -> Timeline<SingleFilmEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }
}

struct SingleFilmView: View {
    let film: Film?

    var body: some View {
        VStack(spacing: 0) {
            if let film {
                VStack(spacing: 6) {
                    Canister(film: film)
                        .aspectRatio(0.68, contentMode: .fit)
                        .shadow(color: .black.opacity(0.6), radius: 4, y: 3)
                    Text(film.name)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.top, 14)
                .padding(.bottom, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
            }
            BodyStripe()
        }
        .widgetURL(film.map(link(to:)))
        .containerBackground(for: .widget) { BodyBackground() }
    }
}

// MARK: - Shared look

/// The camera body's dark plastic.
struct BodyBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.19, green: 0.18, blue: 0.17), Color(red: 0.10, green: 0.10, blue: 0.09)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// The yellow and red stripe that runs along the bottom of the body.
private struct BodyStripe: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color(red: 0.96, green: 0.69, blue: 0.02)).frame(height: 5)
            Rectangle().fill(Color(red: 0.84, green: 0.09, blue: 0.13)).frame(height: 5)
            Color.clear.frame(height: 8)
        }
    }
}
