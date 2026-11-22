import AppIntents
import SwiftUI
import WidgetKit

/// The link a roll opens: peli://film/<id>, handled by `CameraModel.open(_:)`.
func link(to film: Film) -> URL {
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
        ShelfEntry(date: .now, films: Self.picked((configuration.films ?? []).map(\.id), from: FilmLibrary.shared.films))
    }

    /// The rolls picked, in the order picked; a roll no longer offered, or
    /// picked a second time, is skipped. None: nil (the catalogue's order).
    static func picked(_ ids: [String], from all: [Film]) -> [Film]? {
        var seen = Set<String>()
        let picked = ids.compactMap { id in seen.insert(id).inserted ? all.first { $0.id == id } : nil }
        return picked.isEmpty ? nil : picked
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
    /// Each pocket keeps its place: rolls not picked leave it empty; more
    /// rolls than pockets, the first ones.
    static func places(_ films: [Film], pockets: Int) -> [Film?] {
        (0..<pockets).map { $0 < films.count ? films[$0] : nil }
    }

    @Environment(\.widgetFamily) private var family
    /// The rolls picked for this widget; nil shows the catalogue.
    var chosen: [Film]? = nil
    private var films: [Film] { chosen ?? FilmLibrary.shared.films }
    /// Set only by the in-app preview, which has no widget family.
    var previewLarge: Bool?

    var body: some View {
        let art = (previewLarge ?? (family == .systemLarge)) ? WidgetArt.large : WidgetArt.medium
        let places = Self.places(films, pockets: art.pockets.count)
        WidgetPockets(art: art, places: places)
            .containerBackground(for: .widget) { WidgetArt.background(art) }
    }
}

/// The widgets' faces, all three alike (GPT art, design/widgets/
/// medium_plain_v1.png): the camera body's black plastic, the KOCO nameplate
/// and the yellow and red stripe, cut from that one picture and set at the
/// same places on every size; the rolls stand on the plastic, their names
/// printed under them like the body's key names. No pockets.
struct WidgetArt {
    let size: CGSize
    let columns: Int
    let rows: Int

    static let small = WidgetArt(size: CGSize(width: 170, height: 170), columns: 1, rows: 1)
    static let medium = WidgetArt(size: CGSize(width: 364, height: 170), columns: 4, rows: 1)
    static let large = WidgetArt(size: CGSize(width: 364, height: 382), columns: 3, rows: 3)

    static let texture = UIImage(named: "widget_texture.jpg") ?? UIImage()
    static let plate = UIImage(named: "widget_plate") ?? UIImage()
    static let stripe = UIImage(named: "widget_stripe") ?? UIImage()
    /// Measured on the picture, in points of the medium widget.
    static let plateRect = CGRect(x: 13.3, y: 10.9, width: 59.2, height: 20.1)
    static let stripeFromBottom: CGFloat = 22.5, stripeHeight: CGFloat = 10.9

    /// Where the rolls stand: between the nameplate and the stripe.
    private var area: CGRect {
        CGRect(x: 12, y: 38, width: size.width - 24, height: size.height - 38 - Self.stripeFromBottom - 6)
    }
    private func cell(_ i: Int) -> CGRect {
        let w = area.width / CGFloat(columns), h = area.height / CGFloat(rows)
        return CGRect(x: area.minX + CGFloat(i % columns) * w, y: area.minY + CGFloat(i / columns) * h, width: w, height: h)
    }
    /// Each place: where its roll stands, and where its name is printed.
    var pockets: [CGRect] {
        (0..<columns * rows).map { i in
            let c = cell(i)
            return CGRect(x: c.minX + 4, y: c.minY + 2, width: c.width - 8, height: c.height - 18)
        }
    }
    var labels: [CGRect] {
        (0..<columns * rows).map { i in
            let c = cell(i)
            return CGRect(x: c.minX + 2, y: c.maxY - 15, width: c.width - 4, height: 13)
        }
    }

    /// The face, for any widget size: plastic everywhere, then the plate and
    /// the stripe at their measured places.
    static func background(_ art: WidgetArt) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Image(uiImage: texture).resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height).clipped()
                Image(uiImage: stripe).resizable()
                    .frame(width: geo.size.width, height: stripeHeight)
                    .offset(y: geo.size.height - stripeFromBottom)
                Image(uiImage: plate).resizable()
                    .frame(width: plateRect.width, height: plateRect.height)
                    .offset(x: plateRect.minX, y: plateRect.minY)
            }
        }
    }
}

/// The rolls standing on the plastic, each named under it.
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
                                    .shadow(color: .black.opacity(0.75), radius: 3, y: 2)
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

/// A roll's name, printed on the plastic like the body's key names.
private struct WidgetLabel: View {
    let name: String
    let height: CGFloat

    var body: some View {
        Text(name.uppercased())
            .font(.system(size: height * 0.72, weight: .semibold, design: .rounded))
            .kerning(0.6)
            .foregroundStyle(Color(white: 0.78))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 2)
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
