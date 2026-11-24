import Photos
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

    /// Bag pixels (community_v4, as agreed): the rail and rings on the left
    /// page near the spine; the sleeve threaded on them runs across the spine
    /// to the right page's edge, most of the bag (user 11/24).
    static let sleeveX: CGFloat = 470
    static let sleeveRight: CGFloat = 1430
    static var sleeveWidth: CGFloat { sleeveRight - sleeveX }
    static var rowHeight: CGFloat { sleeveWidth * row.size.height / max(row.size.width, 1) }
    static let ringsRect = CGRect(x: 380, y: 30, width: 190, height: 970)
    /// The left page's narrow column left of the rail, for the themes.
    static let navWidth: CGFloat = 330
    static let navX: CGFloat = 50
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
    /// The picture drawn out of its pocket to look at.
    @Published var viewing: Community.Post?
    /// The folder of one's own Koco pictures is open, to post one.
    @Published var posting = false
    @Published private(set) var sending = false
    /// A line to show for a moment (reported, blocked…); each new one restarts its time.
    @Published var note: Text? { didSet { if note != nil { noteID += 1 } } }
    @Published private(set) var noteID = 0

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
        // Until Sign in with Apple (C4), the in-memory community signs in by itself.
        if client is MockCommunityClient { _ = try? await client.signIn(appleIdentityToken: "mock", name: nil) }
        do {
            themes = try await client.themes(at: Date())
        } catch {
            Diag.note("club themes failed: \(error)")
            themes = []
        }
        // The one chosen before if it is still there, else the first open one.
        let keep = theme.flatMap { t in themes.first { $0.id == t.id } }
        await choose(keep ?? themes.first { $0.isOpen(at: Date()) } ?? themes.first)
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "clubView") { viewing = posts.first }   // `-clubView 1`, for checks
        if UserDefaults.standard.bool(forKey: "clubPost") { posting = true }   // `-clubPost 1`, for checks
        #endif
    }

    func toggleLike(_ post: Community.Post) async {
        guard let r = try? await client.setLike(!post.likedByMe, post: post.id) else { return }
        update(post.id) { $0.likeCount = r.likeCount; $0.likedByMe = r.liked }
    }

    func report(_ post: Community.Post, reason: Community.ReportReason) async {
        do {
            try await client.report(post: post.id, reason: reason, note: nil)
            note = Text("Reported. Thank you — it will be looked at within a day.")
        } catch { note = Text("The report didn't go through. Try again.") }
    }

    /// Blocks the author: none of their pictures show again.
    func block(_ post: Community.Post) async {
        do {
            try await client.setBlocked(true, user: post.author.id)
            posts.removeAll { $0.author.id == post.author.id }
            viewing = nil
            note = Text("You won’t see \(post.author.name)’s pictures.")
        } catch { note = Text("That didn't go through. Try again.") }
    }

    /// Posts one of one's own Koco pictures to the open theme: read from
    /// Photos, made small and stripped of its metadata, sent. True if it went in.
    func post(_ shot: ShotLog.Shot, caption: String) async -> Bool {
        guard let theme, !sending else { return false }
        sending = true
        defer { sending = false }
        guard let data = await Self.imageData(asset: shot.asset), let ready = CommunityPhoto.prepare(data) else {
            note = Text("That picture can't be read from Photos.")
            return false
        }
        let line = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let p = try await client.post(theme: theme.id, photo: ready.photo, thumb: ready.thumb, film: shot.film,
                                          caption: line.isEmpty ? nil : line, takenAt: shot.date)
            posts.insert(p, at: 0)
            note = Text("Posted — it’s in the sleeve.")
            return true
        } catch Community.Failure.words {
            note = Text("Those words can’t be posted. Try other ones.")
        } catch Community.Failure.themeClosed {
            note = Text("This theme has closed.")
        } catch {
            note = Text("Couldn’t post. Check the connection and try again.")
        }
        return false
    }

    /// A picture's data from Photos (from iCloud if need be).
    private static func imageData(asset id: String) async -> Data? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        return await withCheckedContinuation { done in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                done.resume(returning: data)
            }
        }
    }

    private func update(_ id: String, _ change: (inout Community.Post) -> Void) {
        if let i = posts.firstIndex(where: { $0.id == id }) { change(&posts[i]) }
        if var v = viewing, v.id == id { change(&v); viewing = v }
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
    /// Filling its frame (a pocket) or fitting whole (looked at).
    var fill = true
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image {
                if fill { Image(uiImage: image).resizable().scaledToFill() } else { Image(uiImage: image).resizable().scaledToFit() }
            } else { Color.black.opacity(0.3) }
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
        let page = RollLibrary.lidPage   // the boards' height; the sleeve spans both pages
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
            // Within the boards' height, cut at the right page's outer edge, rounded like it.
            .frame(width: w, height: page.height * s, alignment: .leading)
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
            .font(.custom("Marker Felt", size: 15 * s))
            .foregroundStyle(KitArt.ink)
            .padding(.horizontal, 8 * s).padding(.vertical, 3 * s)
            .background(Image(uiImage: ClubArt.slip).resizable())
            .padding(.horizontal, 6 * s).padding(.bottom, 5 * s)
        }
        // The pocket's own size: the slip's spacer would otherwise widen it
        // to the whole row and push the picture a pocket over.
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptic.click()
            withAnimation(.easeOut(duration: 0.25)) { club.viewing = post }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
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
                        .font(.custom("American Typewriter", size: 32 * s).weight(.semibold))
                    Text(verbatim: Community.Theme.text(theme.prompt, language: language.code))
                        .font(.custom("American Typewriter", size: 19 * s))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(KitArt.ink)
                .padding(20 * s)
                .frame(width: ClubArt.navWidth * s, alignment: .leading)
                .background(Image(uiImage: ClubArt.slip).resizable())
                .accessibilityElement(children: .combine)
            }
            if let theme = club.theme, theme.isOpen(at: Date()) {
                Button {
                    Haptic.click()
                    withAnimation(.easeOut(duration: 0.25)) { club.posting = true }
                } label: {
                    Label("Post one", systemImage: "plus")
                        .font(.custom("American Typewriter", size: 24 * s).weight(.semibold))
                        .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
                        .padding(.horizontal, 26 * s).padding(.vertical, 12 * s)
                        .background(Image(uiImage: ClubArt.slip).resizable())
                }
                .buttonStyle(.plain)
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
                    .padding(.horizontal, 18 * s).padding(.vertical, 12 * s)
                    .frame(width: ClubArt.navWidth * s, alignment: .leading)
                    .background(Image(uiImage: ClubArt.slip).resizable())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .offset(x: ClubArt.navX * s, y: 80 * s)
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

/// A post drawn out of its pocket (community_detail_v2: the picture large,
/// a kraft card under it): who, which film, which theme, when, their line;
/// the heart; report and block. Tap outside or Close to put it back.
struct ClubPostViewer: View {
    @ObservedObject private var club = ClubModel.shared
    @ObservedObject private var language = AppLanguage.shared
    let post: Community.Post
    @State private var reporting = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Color.black.opacity(0.88).ignoresSafeArea()
                    .onTapGesture { close() }
                VStack(spacing: 14) {
                    ZoomablePicture { PostPicture(url: post.photoURL, fill: false) }
                        .frame(maxWidth: w * 0.9, maxHeight: h * 0.62)
                    card.frame(maxWidth: min(w * 0.9, 560))
                }
                .padding(.top, 20)
                if reporting { reasons(width: min(w * 0.8, 420)) }
            }
            .overlay(alignment: .topTrailing) {
                Button("Close") { close() }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(.black.opacity(0.5)))
                    .padding(16)
            }
        }
    }

    private var card: some View {
        let theme = club.themes.first { $0.id == post.themeId }
        let shown = club.viewing ?? post
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: post.author.name).font(.custom("American Typewriter", size: 22).weight(.semibold))
                Text(verbatim: "· " + FilmNames.short(post.filmId)).font(.custom("American Typewriter", size: 17)).opacity(0.75)
                Spacer(minLength: 8)
                Button {
                    Haptic.click()
                    Task { await club.toggleLike(shown) }
                } label: {
                    Label("\(shown.likeCount)", systemImage: shown.likedByMe ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Like"))
            }
            if let caption = post.caption, !caption.isEmpty {
                Text(verbatim: caption).font(.custom("American Typewriter", size: 18))
            }
            HStack {
                if let theme { Text(verbatim: Community.Theme.text(theme.title, language: language.code)) }
                Text(post.createdAt, format: .dateTime.month().day())
                Spacer(minLength: 8)
                Button { withAnimation(.easeOut(duration: 0.2)) { reporting = true } } label: {
                    Image(systemName: "ellipsis").font(.system(size: 18, weight: .bold)).padding(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Report or block"))
            }
            .font(.custom("American Typewriter", size: 15))
            .opacity(0.8)
        }
        .foregroundStyle(KitArt.ink)
        .padding(.horizontal, 22).padding(.vertical, 16)
        .background(Image(uiImage: ClubArt.slip).resizable())
    }

    /// Why it is reported, on kraft slips; and blocking its author.
    private func reasons(width: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture { withAnimation { reporting = false } }
            VStack(spacing: 8) {
                ForEach(Community.ReportReason.allCases, id: \.self) { reason in
                    slipButton(reasonName(reason)) {
                        reporting = false
                        Task { await club.report(post, reason: reason) }
                    }
                }
                slipButton(Text("Block \(post.author.name)"), red: true) {
                    reporting = false
                    Task { await club.block(post) }
                }
            }
            .frame(width: width)
        }
        .transition(.opacity)
    }

    private func slipButton(_ title: Text, red: Bool = false, action: @escaping () -> Void) -> some View {
        Button { Haptic.click(); action() } label: {
            title.font(.custom("American Typewriter", size: 19).weight(.semibold))
                .foregroundStyle(red ? Color(red: 0.72, green: 0.16, blue: 0.1) : KitArt.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Image(uiImage: ClubArt.slip).resizable())
        }
        .buttonStyle(.plain)
    }

    private func reasonName(_ r: Community.ReportReason) -> Text {
        switch r {
        case .nudity: Text("Nudity")
        case .violence: Text("Violence")
        case .hate: Text("Hate")
        case .spam: Text("Spam")
        case .notKoco: Text("Not taken with Koco")
        case .other: Text("Something else")
        }
    }

    private func close() {
        withAnimation(.easeIn(duration: 0.2)) { club.viewing = nil }
    }
}


/// The community's passing word (reported, blocked…), over the whole bag,
/// whether or not a picture is open; gone after a moment.
struct ClubNote: View {
    @ObservedObject private var club = ClubModel.shared
    var body: some View {
        if let note = club.note {
            note.font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(.black.opacity(0.75)))
                .frame(maxHeight: .infinity, alignment: .top).padding(.top, 24)
                .allowsHitTesting(false)
                .transition(.opacity)
                .task(id: club.noteID) {
                    let mine = club.noteID
                    // Cancelled when a newer word comes: that one keeps its time.
                    guard (try? await Task.sleep(for: .seconds(2.5))) != nil, club.noteID == mine else { return }
                    withAnimation { club.note = nil }
                }
        }
    }
}


/// Posting: a kraft folder of one's own pictures taken with Koco (the
/// system's picker can't tell them apart, so only Koco's own record of its
/// shots), one chosen, a line to go with it, put in (community_post_v2).
struct ClubPostFolder: View {
    @ObservedObject private var club = ClubModel.shared
    @ObservedObject private var log = ShotLog.shared
    @State private var chosen: ShotLog.Shot?
    @State private var caption = ""

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.9, 760), h = geo.size.height * 0.86
            // Every Koco picture, any day (lazily drawn as the folder scrolls).
            let shots = log.shots.sorted { $0.date > $1.date }
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .onTapGesture { close() }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Post one").font(.custom("American Typewriter", size: 26).weight(.semibold))
                        Spacer()
                        Button("Cancel") { close() }.font(.custom("American Typewriter", size: 18))
                            .disabled(club.sending)   // once sending, it goes in; no false cancel
                    }
                    Text("Only pictures taken with Koco").font(.custom("American Typewriter", size: 15)).opacity(0.7)
                    if shots.isEmpty {
                        Text("No pictures taken with Koco yet. Take one first.")
                            .font(.custom("American Typewriter", size: 19))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                                ForEach(shots, id: \.asset) { shot in
                                    AssetThumbnail(id: shot.asset, side: 300)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                        .overlay(RoundedRectangle(cornerRadius: 3)
                                            .strokeBorder(Color(red: 0.72, green: 0.16, blue: 0.1), lineWidth: chosen == shot ? 4 : 0))
                                        .contentShape(Rectangle())
                                        .onTapGesture { Haptic.click(); chosen = shot }
                                        .accessibilityAddTraits(chosen == shot ? [.isButton, .isSelected] : .isButton)
                                }
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        TextField("", text: $caption, prompt: Text("Say something (optional)").foregroundStyle(KitArt.ink.opacity(0.55)))
                            .font(.custom("American Typewriter", size: 18))
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.55)))
                            .onChange(of: caption) { _, new in
                                if new.count > Community.captionLimit { caption = String(new.prefix(Community.captionLimit)) }
                            }
                        Button {
                            guard let shot = chosen else { return }
                            Haptic.click()
                            Task { if await club.post(shot, caption: caption) { close() } }
                        } label: {
                            Text(club.sending ? "Sending…" : "Put it in")
                                .font(.custom("American Typewriter", size: 20).weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18).padding(.vertical, 10)
                                .background(Capsule().fill(Color(red: 0.72, green: 0.16, blue: 0.1).opacity(chosen == nil ? 0.4 : 1)))
                        }
                        .buttonStyle(.plain)
                        .disabled(chosen == nil || club.sending)
                    }
                    Text("Everyone can see what you post.").font(.custom("American Typewriter", size: 14)).opacity(0.65)
                }
                .foregroundStyle(KitArt.ink)
                .padding(22)
                .frame(width: w, height: h)
                .background(Image(uiImage: ClubArt.slip).resizable())
            }
        }
    }

    private func close() {
        guard !club.sending else { return }
        withAnimation(.easeIn(duration: 0.2)) { club.posting = false }
    }
}
