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

/// Which rolls stand in the widget's pockets, in the order picked (four on
/// the medium, nine on the large). None picked: the catalogue's own order.
/// A roll already picked is not offered again.
struct SelectShelfIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Films"
    static var description = IntentDescription("Pick the rolls for this widget, in the order they stand.")

    @Parameter(title: "Films", size: [.systemMedium: 4, .systemLarge: 9])
    var films: [ShelfFilm]?
}

/// A roll as the widget's picker offers it: the same film, but its list
/// leaves out the rolls already in the widget.
struct ShelfFilm: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Film"
    static var defaultQuery = ShelfFilmQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(_ film: Film) {
        id = film.id
        name = film.name
    }
}

struct ShelfFilmQuery: EntityQuery {
    @IntentParameterDependency<SelectShelfIntent>(\.$films) var shelf

    func entities(for identifiers: [String]) async throws -> [ShelfFilm] {
        // In the order asked for: the widget keeps the order its rolls were picked in.
        let films = FilmLibrary.shared.films
        return identifiers.compactMap { id in films.first { $0.id == id } }.map(ShelfFilm.init)
    }

    /// Every film not already picked for this widget.
    func suggestedEntities() async throws -> [ShelfFilm] {
        let taken = Set((shelf?.films ?? []).map(\.id))
        return FilmLibrary.shared.films.filter { !taken.contains($0.id) }.map(ShelfFilm.init)
    }
}

struct ShelfEntry: TimelineEntry {
    let date: Date
    /// Picked rolls, or nil for the default.
    let films: [Film]?
}

struct ShelfProvider: AppIntentTimelineProvider {
    private func entry(for configuration: SelectShelfIntent) -> ShelfEntry {
        let all = FilmLibrary.shared.films
        // Kept in the order picked; a roll no longer offered, or picked a
        // second time, is skipped.
        var seen = Set<String>()
        let picked = (configuration.films ?? []).compactMap { pick in
            seen.insert(pick.id).inserted ? all.first { $0.id == pick.id } : nil
        }
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
    /// The rolls picked for this widget; nil shows the catalogue.
    var chosen: [Film]? = nil
    private var films: [Film] { chosen ?? FilmLibrary.shared.films }
    /// Set only by the in-app preview, which has no widget family.
    var previewLarge: Bool?

    var body: some View {
        let art = (previewLarge ?? (family == .systemLarge)) ? WidgetArt.large : WidgetArt.medium
        // Each pocket keeps its place: rolls not picked leave it empty.
        let places: [Film?] = art.pockets.indices.map { $0 < films.count ? films[$0] : nil }
        WidgetPockets(art: art, places: places)
            .containerBackground(for: .widget) { WidgetArt.background(art) }
    }
}

/// The widgets' faces: the camera body's black plastic with its KOCO
/// nameplate and stripe, moulded pockets for the rolls and a label window
/// under each (GPT art, design/widgets; pockets measured on it, in points
/// of the size it was drawn for).
struct WidgetArt {
    let picture: UIImage
    let size: CGSize
    let pockets: [CGRect]
    let labels: [CGRect]

    static let small = WidgetArt(picture: UIImage(named: "widget_small.jpg") ?? UIImage(), size: CGSize(width: 170, height: 170),
                                 pockets: [CGRect(x: 45.3, y: 35.3, width: 78.3, height: 79.7)],
                                 labels: [CGRect(x: 16, y: 121, width: 138, height: 14.3)])
    static let medium = WidgetArt(picture: UIImage(named: "widget_medium.jpg") ?? UIImage(), size: CGSize(width: 364, height: 170),
                                  pockets: [24.3, 108.7, 192.7, 277.0].map { CGRect(x: $0, y: 40, width: 62.7, height: 80) },
                                  labels: [18.0, 102.7, 186.3, 270.7].map { CGRect(x: $0, y: 124.3, width: 75, height: 13) })
    static let large = WidgetArt(picture: UIImage(named: "widget_large.jpg") ?? UIImage(), size: CGSize(width: 364, height: 382),
                                 pockets: [CGFloat(38), 143.3, 247].flatMap { y in
                                     [CGFloat(36.7), 149, 261.3].map { CGRect(x: $0, y: y, width: 66, height: 72) } },
                                 labels: [CGFloat(124.7), 228.3, 325.7].flatMap { y in
                                     [CGFloat(18), 130, 242.3].map { CGRect(x: $0, y: y, width: 104, height: 12.5) } })

    static func background(_ art: WidgetArt) -> some View {
        Image(uiImage: art.picture).resizable()
    }
}

/// The rolls standing in their pockets, each named in the window under it.
private struct WidgetPockets: View {
    let art: WidgetArt
    let places: [Film?]

    var body: some View {
        GeometryReader { geo in
            let kx = geo.size.width / art.size.width, ky = geo.size.height / art.size.height
            ZStack(alignment: .topLeading) {
                ForEach(Array(places.enumerated()), id: \.offset) { i, place in
                    if let film = place {
                        let p = art.pockets[i], l = art.labels[i]
                        Link(destination: link(to: film)) {
                            ZStack(alignment: .topLeading) {
                                Canister(film: film)
                                    .shadow(color: .black.opacity(0.7), radius: 2, y: 1.5)
                                    .padding(.vertical, 4 * ky).padding(.horizontal, 4 * kx)
                                    .frame(width: p.width * kx, height: p.height * ky)
                                    .offset(x: p.minX * kx, y: p.minY * ky)
                                WidgetLabel(name: film.name, height: l.height * ky)
                                    .frame(width: l.width * kx, height: l.height * ky)
                                    .offset(x: l.minX * kx, y: l.minY * ky)
                            }
                        }
                        .accessibilityLabel(Text(film.name))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }
}

/// A roll's name, printed in a label window.
private struct WidgetLabel: View {
    let name: String
    let height: CGFloat

    var body: some View {
        Text(name)
            .font(.system(size: height * 0.68, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(white: 0.82))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 3)
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
        WidgetPockets(art: .small, places: [film])
            .widgetURL(film.map(link(to:)))
            .containerBackground(for: .widget) { WidgetArt.background(.small) }
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
