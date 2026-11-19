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
        StaticConfiguration(kind: "FilmShelf", provider: ShelfProvider()) { _ in
            FilmShelfView()
        }
        .configurationDisplayName("胶卷架")
        .description("点一卷胶卷，直接用它开拍。")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct ShelfEntry: TimelineEntry {
    let date: Date
}

struct ShelfProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShelfEntry { ShelfEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (ShelfEntry) -> Void) {
        completion(ShelfEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ShelfEntry>) -> Void) {
        completion(Timeline(entries: [ShelfEntry(date: .now)], policy: .never))
    }
}

struct FilmShelfView: View {
    @Environment(\.widgetFamily) private var family
    private let films = FilmLibrary.shared.films
    /// Set only by the in-app preview, which has no widget family.
    var previewLarge: Bool?

    var body: some View {
        let large = previewLarge ?? (family == .systemLarge)
        let perRow = large ? 3 : 6
        let rows = stride(from: 0, to: min(films.count, 6), by: perRow).map {
            Array(films[$0..<min($0 + perRow, films.count)])
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
    let films: [Film]
    let large: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(films) { film in
                    Link(destination: link(to: film)) {
                        VStack(spacing: large ? 6 : 4) {
                            Canister(film: film)
                                .aspectRatio(0.68, contentMode: .fit)
                                .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
                            Text(film.name)
                                .font(.system(size: large ? 11 : 8, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color(white: 0.82))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .padding(.horizontal, large ? 16 : 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
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
        .configurationDisplayName("一卷胶卷")
        .description("选一卷常用的胶卷，点一下直接开拍。")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct SelectFilmIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "选择胶卷"

    @Parameter(title: "胶卷")
    var film: FilmEntity?
}

struct FilmEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "胶卷"
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
        FilmLibrary.shared.films.filter { identifiers.contains($0.id) }.map(FilmEntity.init)
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
