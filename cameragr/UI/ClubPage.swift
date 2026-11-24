import SwiftUI
import UIKit

/// The community's pair of pages in the bag (user 11/24: the community is in
/// v1, in place of the Book). Right: a long clear three-pocket sleeve threaded
/// on brass rings, one picture per pocket with a kraft slip under it (author ·
/// film · hearts); it slides and rests on whole rows. Left: the theme.
/// Art is GPT's (design/community/parts): the spread with its rail and rings,
/// one tileable sleeve row, the rings as their own layer.
enum ClubArt {
    static let spread = UIImage(named: "club_spread.jpg") ?? UIImage()
    static let row = UIImage(named: "sleeve_row.jpg") ?? UIImage()
    static let rings = UIImage(named: "club_rings") ?? UIImage()
    static let slip = UIImage(named: "kraft_slip") ?? UIImage()

    /// Bag pixels: where the sleeve runs (its punched margin under the rings),
    /// and the rings' layer.
    static let sleeveX: CGFloat = 826
    static let sleeveWidth: CGFloat = 616
    static var rowHeight: CGFloat { sleeveWidth * row.size.height / max(row.size.width, 1) }
    static let ringsRect = CGRect(x: 770, y: 30, width: 180, height: 970)
    /// The three pockets of a row, as fractions of the row (measured on sleeve_row).
    static let pockets: [CGRect] = [
        CGRect(x: 0.0591, y: 0.0255, width: 0.3105, height: 0.9430),
        CGRect(x: 0.3732, y: 0.0255, width: 0.3123, height: 0.9430),
        CGRect(x: 0.6877, y: 0.0255, width: 0.3091, height: 0.9430),
    ]
}

/// The community as the bag shows it: themes and the posts of the open one.
@MainActor
final class ClubModel: ObservableObject {
    static let shared = ClubModel()
    let client: CommunityClient
    @Published private(set) var themes: [Community.Theme] = []
    @Published private(set) var theme: Community.Theme?
    @Published private(set) var posts: [Community.Post] = []

    init(client: CommunityClient? = nil) {
        if let client { self.client = client } else {
            // Until the Worker is deployed (CommunityConfig.apiBase): the
            // in-memory community, with the app's sample pictures as others' posts.
            let mock = MockCommunityClient()
            self.client = mock
            Task {
                await mock.seed(MockCommunityClient.samplePosts(theme: "daily-sample"))
                await mock.seed(Array(MockCommunityClient.samplePosts(theme: "weekly-sample").suffix(5)))
            }
        }
    }

    func load() async {
        do {
            themes = try await client.themes(at: Date())
        } catch {
            Diag.note("club themes failed: \(error)")
            themes = []
        }
        // The one chosen before if it is still there, else the first open one.
        let keep = theme.flatMap { t in themes.first { $0.id == t.id } }
        await choose(keep ?? themes.first { $0.isOpen(at: Date()) } ?? themes.first)
    }

    /// Shows a theme's posts; never another theme's (cleared first, and on failure).
    func choose(_ new: Community.Theme?) async {
        theme = new
        posts = []
        guard let new else { return }
        do {
            let list = try await client.posts(theme: new.id, cursor: nil).posts
            if theme?.id == new.id { posts = list }   // still the one chosen
        } catch {
            Diag.note("club posts failed: \(error)")
        }
    }
}

/// A post's picture: bundled (the mock's samples) or from the server.
struct PostPicture: View {
    let url: URL
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() } else { Color.black.opacity(0.3) }
        }
        .task(id: url) {
            // Never the previous picture under a new one, nor a late answer over it.
            image = nil
            let asked = url
            let loaded: UIImage?
            if asked.isFileURL { loaded = UIImage(contentsOfFile: asked.path) }
            else if let (data, _) = try? await URLSession.shared.data(from: asked) { loaded = UIImage(data: data) }
            else { loaded = nil }
            if !Task.isCancelled, asked == url { image = loaded }
        }
    }
}

/// The right page: the sleeve of pictures.
struct ClubSleevePage: View {
    @ObservedObject private var club = ClubModel.shared
    let s: CGFloat
    @State private var rowSeen = 0

    var body: some View {
        let page = RollLibrary.lidPage
        let rowH = ClubArt.rowHeight * s, w = ClubArt.sleeveWidth * s
        let rows = max(Int((CGFloat(club.posts.count) / 3).rounded(.up)), Int(page.height / ClubArt.rowHeight) + 1)
        ZStack(alignment: .topLeading) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { r in
                        row(r, width: w, height: rowH)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .onScrollGeometryChange(for: Int.self) { Int(($0.contentOffset.y / rowH).rounded(.down)) } action: { _, row in
                if row != rowSeen { rowSeen = row; Haptic.detent() }
            }
            // Only within the page's board: cut at its outer edge, rounded like it.
            .frame(width: min(w, (page.maxX - ClubArt.sleeveX) * s), height: page.height * s, alignment: .leading)
            .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: RollLibrary.boardRadius * s,
                                              topTrailingRadius: RollLibrary.boardRadius * s))
            .offset(x: ClubArt.sleeveX * s, y: page.minY * s)
            // The rings over the sleeve.
            Image(uiImage: ClubArt.rings).resizable()
                .frame(width: ClubArt.ringsRect.width * s, height: ClubArt.ringsRect.height * s)
                .offset(x: ClubArt.ringsRect.minX * s, y: ClubArt.ringsRect.minY * s)
                .allowsHitTesting(false)
        }
        .task { await club.load() }
    }

    private func row(_ r: Int, width w: CGFloat, height h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: ClubArt.row).resizable().frame(width: w, height: h)
            ForEach(0..<3, id: \.self) { c in
                let i = r * 3 + c
                let p = ClubArt.pockets[c]
                let box = CGRect(x: p.minX * w, y: p.minY * h, width: p.width * w, height: p.height * h).insetBy(dx: 2 * s, dy: 2 * s)
                if i < club.posts.count {
                    pocket(club.posts[i], size: box.size)
                        .offset(x: box.minX, y: box.minY)
                }
            }
        }
        .frame(width: w, height: h)
    }

    /// A picture in its pocket, the plastic's sheen over it, and its slip.
    private func pocket(_ post: Community.Post, size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            PostPicture(url: post.thumbURL)
                .frame(width: size.width, height: size.height)
                .clipped()
            // The sleeve's own sheen, laid back over the picture.
            Image(uiImage: ClubArt.row).resizable()
                .frame(width: size.width, height: size.height)
                .blendMode(.screen).opacity(0.18)
                .allowsHitTesting(false)
            HStack(spacing: 4 * s) {
                Text(verbatim: post.author.name).lineLimit(1)
                Text(verbatim: "·")
                Text(verbatim: FilmNames.short(post.filmId)).lineLimit(1)
                Spacer(minLength: 2 * s)
                Image(systemName: post.likedByMe ? "heart.fill" : "heart").foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
                Text(verbatim: "\(post.likeCount)")
            }
            .font(.custom("Marker Felt", size: 11 * s))
            .foregroundStyle(KitArt.ink)
            .padding(.horizontal, 6 * s).padding(.vertical, 2 * s)
            .background(Image(uiImage: ClubArt.slip).resizable())
            .padding(.horizontal, 6 * s).padding(.bottom, 5 * s)
        }
        // The pocket's own size: the slip's spacer would otherwise widen it
        // to the whole row and push the picture a pocket over.
        .frame(width: size.width, height: size.height)
        .accessibilityElement(children: .combine)
    }
}

/// The left page: the open themes, each on a kraft slip; the chosen one
/// large with its prompt, the others small beneath it to switch to (GPT art
/// for the theme tags and the rest of the page comes with posting, C3c).
struct ClubThemePage: View {
    @ObservedObject private var club = ClubModel.shared
    @ObservedObject private var language = AppLanguage.shared
    let s: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 18 * s) {
            if let theme = club.theme {
                VStack(alignment: .leading, spacing: 8 * s) {
                    kindName(theme.kind).font(.custom("American Typewriter", size: 20 * s)).opacity(0.7)
                    Text(verbatim: Community.Theme.text(theme.title, language: language.code))
                        .font(.custom("American Typewriter", size: 38 * s).weight(.semibold))
                    Text(verbatim: Community.Theme.text(theme.prompt, language: language.code))
                        .font(.custom("American Typewriter", size: 22 * s))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(KitArt.ink)
                .padding(28 * s)
                .frame(width: 560 * s, alignment: .leading)
                .background(Image(uiImage: ClubArt.slip).resizable())
                .accessibilityElement(children: .combine)
            }
            ForEach(club.themes.filter { $0.id != club.theme?.id }) { other in
                Button {
                    Haptic.click()
                    Task { await club.choose(other) }
                } label: {
                    HStack(spacing: 10 * s) {
                        kindName(other.kind).font(.custom("American Typewriter", size: 17 * s)).opacity(0.7)
                        Text(verbatim: Community.Theme.text(other.title, language: language.code))
                            .font(.custom("American Typewriter", size: 24 * s).weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 16 * s, weight: .semibold)).opacity(0.6)
                    }
                    .foregroundStyle(KitArt.ink)
                    .padding(.horizontal, 24 * s).padding(.vertical, 14 * s)
                    .frame(width: 480 * s, alignment: .leading)
                    .background(Image(uiImage: ClubArt.slip).resizable())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .offset(x: 84 * s, y: 90 * s)
    }

    private func kindName(_ kind: Community.Theme.Kind) -> Text {
        switch kind {
        case .daily: Text("Today’s theme")
        case .weekly: Text("This week’s theme")
        case .festival: Text("Festival theme")
        }
    }
}

/// Short film names for the slips (the rolls' own words).
enum FilmNames {
    static func short(_ id: String) -> String {
        FilmLibrary.shared.films.first { $0.id == id }?.name ?? id
    }
}
