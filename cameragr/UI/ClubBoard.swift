import SwiftUI

/// The community's two layouts tried side by side (user 11/27: "两个都做出来看看").
/// A: a narrow left column (theme, this week's picks, member card) beside a
/// grid of pictures. B: a band across the top (theme, picks, name plate) that
/// scrolls away over a grid across both pages, the filters staying on top.
/// Both: the filters (whose pictures, which film) sit right above the grid;
/// every entry has its picture; writing 13–22 pt, nothing under 11 pt, every
/// tap 44 pt. The outer screen (and any small canvas) is one compact layout
/// for both. Debug builds switch with a small tag on the page; release keeps B.
enum ClubStyle: String { case a, b }

@MainActor
final class ClubStyleSetting: ObservableObject {
    static let shared = ClubStyleSetting()
    @Published var style: ClubStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: "clubStyle") }
    }
    private init() {
        #if DEBUG
        // `-clubStyle a|b` for checks; otherwise what was chosen last.
        style = UserDefaults.standard.string(forKey: "clubStyle").flatMap(ClubStyle.init(rawValue:)) ?? .b
        #else
        style = .b   // the switch isn't shown in release builds until the user has chosen
        #endif
    }
}

extension ClubArt {
    /// GPT parts (design/community/club-ab): the index band, the notes paper,
    /// a blank card and the vermilion "+N" slip.
    static let band = UIImage(named: "club_band") ?? UIImage()
    static let notes = UIImage(named: "club_notes") ?? UIImage()
    static let blankCard = UIImage(named: "club_cardblank") ?? UIImage()
    static let plusSlip = UIImage(named: "club_plusslip") ?? UIImage()
    static let seal = UIImage(named: "club_seal") ?? UIImage()
    static let memberPaper = UIImage(named: "club_member_tall") ?? UIImage()
    static let dayBox = UIImage(named: "club_box") ?? UIImage()
    static let inkDot = UIImage(named: "club_inkdot") ?? UIImage()
    static let red = Color(red: 0.72, green: 0.16, blue: 0.1)
    /// The board covers both pages; the bag's units.
    static let boardRect = CGRect(x: 26, y: 26, width: 1404, height: 972)
}

/// The typewriter face the community writes in, at a size in points.
private func tw(_ size: CGFloat) -> Font { .custom("American Typewriter", size: size) }

/// A round red seal with someone's first letter: the community's avatar
/// (no pictures of people are kept; the member card's seal, smaller).
struct ClubSeal: View {
    let name: String
    let size: CGFloat
    var body: some View {
        Text(verbatim: name.first.map { String($0).uppercased() } ?? "·")
            .font(tw(size * 0.52).weight(.bold))
            .foregroundStyle(Color(red: 0.99, green: 0.95, blue: 0.88))
            .lineLimit(1).minimumScaleFactor(0.5)
            .frame(width: size, height: size)
            .background(Image(uiImage: ClubArt.seal).resizable())
            .accessibilityHidden(true)
    }
}

/// The vermilion paper slip with "+N" (board club-1127-plus), at a height in points.
struct PlusSlip: View {
    let n: Int
    var height: CGFloat = 20
    var body: some View {
        Text(verbatim: n > 99 ? "+99" : "+\(n)")
            .font(.system(size: max(11, height * 0.6), weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.leading, height * 0.35).padding(.trailing, height * 0.7)
            .frame(height: height)
            .background(Image(uiImage: ClubArt.plusSlip).resizable()
                .shadow(color: .black.opacity(0.25), radius: 0.8, y: 0.6))
            .fixedSize()
            .accessibilityHidden(true)
    }
}

/// Where the filters' drop cards come from (their tags' bounds).
private struct FilterAnchorKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// The community board, over both pages of the bag (in place of framework E).
struct ClubBoard: View {
    @ObservedObject private var club = ClubModel.shared
    @ObservedObject private var setting = ClubStyleSetting.shared
    @ObservedObject private var language = AppLanguage.shared
    let s: CGFloat
    /// The open drop card: "who" or "film".
    @State private var open: String?
    @State private var blocking: String?
    /// The grid's pictures on screen (their places in the list), and the top
    /// one kept when someone's page opens, to come back to it (Codex review).
    @State private var onScreen: Set<Int> = []
    @State private var keptTop: String?
    @GestureState private var drag: CGFloat = 0

    /// Screens this wide get the two-page layouts; the outer screen the compact one.
    static func isCompact(_ s: CGFloat) -> Bool { ClubArt.boardRect.width * s < 800 }
    /// Style A's left column, in points, and its gap.
    static let columnWidth: CGFloat = 290
    static let pad: CGFloat = 12
    /// Style A's grid, in the bag's frame (points): where the viewer opens.
    static func gridRect(_ s: CGFloat) -> CGRect {
        let r = ClubArt.boardRect.scaled(s)
        let x = r.minX + pad + columnWidth + pad
        return CGRect(x: x, y: r.minY, width: r.maxX - x, height: r.height)
    }

    var body: some View {
        let r = ClubArt.boardRect.scaled(s)
        let compact = Self.isCompact(s)
        // The dial lies over the board's foot: the grid scrolls on past it.
        let foot = PageDial.rect.height * s + 10
        ZStack(alignment: .topLeading) {
            if !club.isOpen {
                Text("The community opens soon.")
                    .font(tw(20)).foregroundStyle(KitArt.ink)
                    .padding(18)
                    .background(Image(uiImage: ClubArt.slip).resizable())
                    .padding(Self.pad)
            } else if compact {
                compactLayout(size: r.size, foot: foot)
            } else if setting.style == .a {
                layoutA(size: r.size, foot: foot)
            } else {
                layoutB(size: r.size, foot: foot)
            }
        }
        .frame(width: r.width, height: r.height, alignment: .topLeading)
        .overlayPreferenceValue(FilterAnchorKey.self) { anchors in
            GeometryReader { g in
                if let key = open, let a = anchors[key] {
                    let tag = g[a]
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001)
                            .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { open = nil } }
                            .accessibilityHidden(true)
                        dropCard(key)
                            .offset(x: min(tag.minX, g.size.width - dropWidth(key) - 8), y: tag.maxY + 2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .offset(x: r.minX, y: r.minY)
        .task { await club.load() }
        .onChange(of: club.filmApplies) { if !club.filmApplies, open == "film" { open = nil } }
    }

    #if DEBUG
    /// Debug builds only: "A | B", to compare the two on the phone.
    private var styleSwitch: some View {
        Button {
            Haptic.click()
            withAnimation(.easeOut(duration: 0.2)) { setting.style = setting.style == .a ? .b : .a }
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: "A").fontWeight(setting.style == .a ? .bold : .regular).opacity(setting.style == .a ? 1 : 0.45)
                Text(verbatim: "|").opacity(0.4)
                Text(verbatim: "B").fontWeight(setting.style == .b ? .bold : .regular).opacity(setting.style == .b ? 1 : 0.45)
            }
            .font(tw(14)).foregroundStyle(KitArt.ink)
            .padding(.horizontal, 10).frame(height: 28)
            .background(Image(uiImage: ClubArt.blankCard).resizable())
            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "Community style \(setting.style.rawValue.uppercased())"))
        .accessibilityIdentifier("club-style")
    }
    #endif

    // MARK: Layouts

    /// A: the column on the left, the grid on the right with its filters pinned.
    private func layoutA(size: CGSize, foot: CGFloat) -> some View {
        let col = Self.columnWidth, pad = Self.pad
        let gridW = size.width - col - pad * 3
        return HStack(alignment: .top, spacing: pad) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    if club.scope.isPerson, let card = club.authorCard {
                        personCard(card, width: col)
                    } else {
                        themeCard(width: col, vertical: true)
                        if showsPicks { picksCard(width: col, height: 96) }
                        if club.signedIn { memberCard(width: col) } else { ClubSignIn(width: col, s: 1) }
                    }
                }
                .padding(.bottom, foot)
            }
            .frame(width: col)
            grid(columns: 4, width: gridW, foot: foot, band: nil)
                .frame(width: gridW)
        }
        .padding(.horizontal, pad)
        .padding(.top, pad)
    }

    /// B: the band, then the filters (pinned), then the grid, all one scroll.
    private func layoutB(size: CGSize, foot: CGFloat) -> some View {
        let w = size.width - Self.pad * 2
        return grid(columns: 4, width: w, foot: foot, band: AnyView(bandB(width: w)))
            .padding(.horizontal, Self.pad)
            .padding(.top, Self.pad)
    }

    /// The outer screen: a band of cards one slides through, filters, three or two columns.
    private func compactLayout(size: CGSize, foot: CGFloat) -> some View {
        let w = size.width - Self.pad * 2
        let cols = w >= 560 ? 3 : 2
        return grid(columns: cols, width: w, foot: foot, band: AnyView(compactBand(width: w)))
            .padding(.horizontal, Self.pad)
            .padding(.top, 8)
    }

    // MARK: The grid

    private func grid(columns: Int, width: CGFloat, foot: CGFloat, band: AnyView?) -> some View {
        let gap: CGFloat = 12
        let cw = floor((width - gap * CGFloat(columns - 1)) / CGFloat(columns))
        let items = Array(repeating: GridItem(.fixed(cw), spacing: gap), count: columns)
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if let band { band.padding(.bottom, 8).id("top") } else { Color.clear.frame(height: 0).id("top") }
                    Section {
                        if club.posts.isEmpty {
                            notice.frame(width: min(width, 520), alignment: .leading).padding(.top, 8)
                        } else {
                            LazyVGrid(columns: items, alignment: .leading, spacing: gap) {
                                ForEach(Array(club.posts.enumerated()), id: \.element.id) { i, post in
                                    card(post, width: cw)
                                        .id(post.id)
                                        .onAppear {
                                            onScreen.insert(i)
                                            if i + 8 >= club.posts.count { Task { await club.loadMore() } }
                                        }
                                        .onDisappear { onScreen.remove(i) }
                                }
                            }
                            .padding(.top, 6)
                        }
                    } header: {
                        filterRow(width: width)
                    }
                }
                .padding(.bottom, foot)
            }
            // Someone's page opening: the top picture is kept; back from it, the grid returns there.
            .onChange(of: club.scope) { old, new in
                if new.isPerson, !old.isPerson, let i = onScreen.min(), club.posts.indices.contains(i) { keptTop = club.posts[i].id }
            }
            .onChange(of: club.restoreToken) {
                let target = keptTop
                Task { @MainActor in
                    if let target, club.posts.contains(where: { $0.id == target }) { proxy.scrollTo(target, anchor: .top) }
                    else { proxy.scrollTo("top", anchor: .top) }
                }
            }
        }
        .frame(width: width)
    }

    /// One picture: the photo on a card, then two lines: who, then the film and the hearts.
    private func card(_ post: Community.Post, width w: CGFloat) -> some View {
        let inset: CGFloat = 6
        let photoW = w - inset * 2, photoH = floor(photoW * 0.75)
        return VStack(alignment: .leading, spacing: 5) {
            PostPicture(url: post.thumbURL)
                .frame(width: photoW, height: photoH)
                .clipped()
                .overlay(Rectangle().stroke(Color.black.opacity(0.12), lineWidth: 0.5))
            HStack(spacing: 6) {
                ClubSeal(name: post.author.name, size: 20)
                Text(verbatim: post.author.name)
                    .font(tw(13).weight(.semibold)).lineLimit(1)
            }
            HStack(spacing: 4) {
                Text(verbatim: FilmNames.short(post.filmId))
                    .font(tw(12)).opacity(0.75).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: post.likedByMe ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ClubArt.red)
                Text(verbatim: "\(post.likeCount)").font(tw(13))
            }
        }
        .foregroundStyle(KitArt.ink)
        .padding(inset)
        .padding(.bottom, 2)
        .frame(width: w, alignment: .leading)
        .background(Image(uiImage: ClubArt.blankCard).resizable()
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1))
        .contentShape(Rectangle())
        .onTapGesture {
            Haptic.click()
            withAnimation(.easeOut(duration: 0.25)) { club.viewing = post }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(post.author.name), \(FilmNames.short(post.filmId)), \(post.likeCount) likes"))
        .accessibilityAddTraits(.isButton)
    }

    /// Why the grid is empty: being read, couldn't be read (retry), or nothing there.
    private var notice: some View {
        let (text, retry, more): (Text, Bool, Bool) = {
            if club.failed { return (Text("Couldn’t load. Tap to try again."), true, false) }
            if club.hasMore, !club.loading { return (Text("Nothing here yet. Tap to look further."), true, true) }
            if club.loading { return (Text("Getting the pictures…"), false, false) }
            if club.filmApplies, let film = club.film { return (Text("No pictures on \(FilmNames.short(film)) here yet. Choose “Any film” to see more."), false, false) }
            switch club.scope {
            case .theme: return (Text("Nothing posted to this theme yet."), false, false)
            case .everyone: return (Text("No pictures yet."), false, false)
            case .following: return (Text("Follow someone and their pictures come here."), false, false)
            case .picks: return (club.picksFailed ? Text("Couldn’t load. Tap to try again.") : Text("No picks this week yet."), club.picksFailed, false)
            case .author: return (Text("No public pictures yet."), false, false)
            }
        }()
        return Button {
            guard retry else { return }
            Haptic.click()
            Task { if more { await club.loadMore() } else { await club.reloadAlbumAgain() } }
        } label: {
            HStack(spacing: 8) {
                if club.loading { ProgressView().controlSize(.small) }
                if retry { Image(systemName: "arrow.clockwise") }
                text.lineLimit(3)
            }
            .font(tw(16)).foregroundStyle(KitArt.ink)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(Image(uiImage: ClubArt.slip).resizable())
        }
        .buttonStyle(.plain)
        .disabled(!retry)
    }

    // MARK: Filters (user 11/27: whose pictures is a filter, beside the film)

    private var whoIsFollowing: Bool { club.scope == .following }

    private func filterRow(width: CGFloat) -> some View {
        HStack(spacing: 10) {
            if !club.scope.isPerson, club.signedIn {
                filterTag("who", icon: AnyView(Image(systemName: whoIsFollowing ? "person.crop.circle.badge.checkmark" : "person.2.fill")
                                                .font(.system(size: 17, weight: .semibold)).foregroundStyle(KitArt.ink.opacity(0.8))
                                                .frame(width: 26)),
                          title: whoIsFollowing ? Text("Following") : Text("Everyone"), label: Text("Whose pictures"))
            }
            if club.signedIn, club.filmApplies {
                filterTag("film", icon: AnyView(Image(uiImage: ClubArt.rollIcon(club.film)).resizable().scaledToFit().frame(width: 26, height: 30)),
                          title: filmName(club.film), label: Text("Film"))
            }
            Spacer(minLength: 6)
            context.font(tw(13)).foregroundStyle(KitArt.ink.opacity(0.7)).lineLimit(1).minimumScaleFactor(0.85)
            #if DEBUG
            if !Self.isCompact(s) { styleSwitch }
            #endif
        }
        .padding(.horizontal, 8)
        .frame(width: width, height: 50)
        .background(Image(uiImage: ClubArt.band).resizable().shadow(color: .black.opacity(0.25), radius: 1.5, y: 1))
    }

    /// What the grid shows now, in words.
    private var context: Text {
        switch club.scope {
        case .theme: return club.theme.map { Text("Theme: \(Community.Theme.text($0.title, language: language.code))") } ?? Text(verbatim: "")
        case .everyone: return Text("Everyone’s newest pictures, from every theme.")
        case .following: return Text("Pictures by people you follow")
        case .picks: return Text("This week’s picks")
        case .author: return Text(verbatim: club.authorCard?.name ?? "")
        }
    }

    private func filmName(_ id: String?) -> Text { id.map { Text(verbatim: FilmNames.short($0)) } ?? Text("Any film") }
    private var films: [String?] { [nil] + FilmLibrary.shared.films.filter { !$0.isLimited }.map { Optional($0.id) } }

    private func filterTag(_ key: String, icon: AnyView, title: Text, label: Text) -> some View {
        Button {
            Haptic.click()
            withAnimation(.easeOut(duration: 0.18)) { open = open == key ? nil : key }
        } label: {
            HStack(spacing: 8) {
                icon
                title.font(tw(15).weight(.semibold)).lineLimit(1)
                Image(systemName: open == key ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold)).opacity(0.55)
            }
            .foregroundStyle(KitArt.ink)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Image(uiImage: ClubArt.picker).resizable()
                .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .anchorPreference(key: FilterAnchorKey.self, value: .bounds) { [key: $0] }
        .accessibilityLabel(label)
        .accessibilityValue(title)
    }

    private func dropWidth(_ key: String) -> CGFloat { key == "who" ? 230 : 420 }

    @ViewBuilder private func dropCard(_ key: String) -> some View {
        if key == "who" {
            VStack(alignment: .leading, spacing: 0) {
                dropItem(icon: AnyView(Image(systemName: "person.2.fill").font(.system(size: 17)).frame(width: 28)),
                         title: Text("Everyone"), on: !whoIsFollowing) {
                    Task { await club.choose(club.theme) }
                }
                dropItem(icon: AnyView(Image(systemName: "person.crop.circle.badge.checkmark").font(.system(size: 17)).frame(width: 28)),
                         title: Text("Following"), on: whoIsFollowing) {
                    Task { await club.chooseScope(.following) }
                }
            }
            .padding(12)
            .frame(width: dropWidth(key), alignment: .leading)
            .background(Image(uiImage: ClubArt.dropCard).resizable().shadow(color: .black.opacity(0.25), radius: 3, y: 1))
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 0) {
                ForEach(films, id: \.self) { id in
                    dropItem(icon: AnyView(Image(uiImage: ClubArt.rollIcon(id)).resizable().scaledToFit().frame(width: 24, height: 34)),
                             title: filmName(id), on: id == club.film) {
                        Task { await club.chooseFilm(id) }
                    }
                }
            }
            .padding(12)
            .frame(width: dropWidth(key))
            .background(Image(uiImage: ClubArt.dropCard).resizable().shadow(color: .black.opacity(0.25), radius: 3, y: 1))
        }
    }

    private func dropItem(icon: AnyView, title: Text, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.click()
            withAnimation(.easeOut(duration: 0.18)) { open = nil }
            action()
        } label: {
            HStack(spacing: 8) {
                icon
                title.font(tw(15).weight(on ? .semibold : .regular)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if on { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)) }
            }
            .foregroundStyle(KitArt.ink)
            .padding(.horizontal, 6)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: The band (B) and the compact band

    private func bandB(width: CGFloat) -> some View {
        let h: CGFloat = 150
        let plate: CGFloat = club.signedIn ? 250 : 300
        return HStack(spacing: 12) {
            if club.scope.isPerson, let card = club.authorCard {
                personCard(card, width: width - 24)
            } else {
                themeCard(width: nil, vertical: false, height: h - 20)
                if showsPicks { picksCard(width: 250, height: h - 20) }
                if club.signedIn { namePlate(width: plate, height: h - 20) } else { ClubSignIn(width: plate, s: 0.75) }
            }
        }
        .padding(10)
        .frame(width: width, height: h, alignment: .leading)
        .background(Image(uiImage: ClubArt.band).resizable().shadow(color: .black.opacity(0.3), radius: 2, y: 1))
    }

    private func compactBand(width: CGFloat) -> some View {
        let h: CGFloat = 118
        return Group {
            if club.scope.isPerson, let card = club.authorCard {
                personCard(card, width: width)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        themeCard(width: min(330, width * 0.62), vertical: false, height: h - 16)
                        if showsPicks { picksCard(width: 220, height: h - 16) }
                        if club.signedIn { namePlate(width: 220, height: h - 16) } else { ClubSignIn(width: 260, s: 0.6) }
                    }
                    .padding(8)
                }
                .frame(width: width, height: h)
                .background(Image(uiImage: ClubArt.band).resizable().shadow(color: .black.opacity(0.3), radius: 2, y: 1))
            }
        }
    }

    // MARK: The entries

    /// No picks yet: the entry stays away (retro 11); a failed read still shows, to retry.
    private var showsPicks: Bool { club.signedIn && (club.picksFailed || !(club.picks ?? []).isEmpty) }

    private func kindName(_ kind: Community.Theme.Kind) -> Text {
        switch kind {
        case .daily: Text("Today")
        case .weekly: Text("This week")
        case .festival: Text("Limited run")
        }
    }

    private func timeLeft(_ theme: Community.Theme) -> String {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.maximumUnitCount = 1
        f.allowedUnits = [.day, .hour, .minute]
        var cal = Calendar.current
        cal.locale = Locale(identifier: language.code)
        f.calendar = cal
        return f.string(from: max(60, theme.endsAt.timeIntervalSinceNow)) ?? ""
    }

    /// The theme's picture: its newest one as last seen, else the theme's own cover.
    private func cover(_ theme: Community.Theme) -> URL? { club.covers[theme.id]?.thumbURL ?? theme.coverURL }

    private func photo(_ url: URL?, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let url { PostPicture(url: url) } else { Color.black.opacity(0.25) }
        }
        .frame(width: width, height: height)
        .clipped()
        .padding(4)
        .background(Color(red: 0.98, green: 0.96, blue: 0.91))
        .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
        .accessibilityHidden(true)
    }

    /// The theme: its picture, what kind and how long, the name big, who is
    /// posting (real names from its pictures), and "Post". A swipe goes to the
    /// next theme; a tap shows its pictures.
    @ViewBuilder
    private func themeCard(width: CGFloat?, vertical: Bool, height: CGFloat? = nil) -> some View {
        if let theme = club.theme {
            let on = club.scope == .theme
            let names = club.themeNames
            let words = VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    kindName(theme.kind)
                    Text(verbatim: "·")
                    theme.isOpen(at: Date()) ? Text("Ends in \(timeLeft(theme))") : Text("Ended")
                }
                .font(tw(13)).opacity(0.65).lineLimit(1).minimumScaleFactor(0.85)
                Text(verbatim: Community.Theme.text(theme.title, language: language.code))
                    .font(tw(22).weight(.bold)).lineLimit(1).minimumScaleFactor(0.75)
                    .accessibilityAddTraits(.isHeader)
                if club.signedIn, !club.loading, on {
                    HStack(spacing: 6) {
                        HStack(spacing: -5) {
                            ForEach(Array(names.prefix(3).enumerated()), id: \.offset) { _, n in ClubSeal(name: n, size: 22) }
                        }
                        (names.isEmpty ? Text("No one has posted yet. Be the first.")
                         : club.hasMore ? Text("\(names.count)+ posting") : Text("\(names.count) posting"))
                            .font(tw(13)).opacity(0.75).lineLimit(2).minimumScaleFactor(0.85)
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    if club.signedIn, theme.isOpen(at: Date()) {
                        Button {
                            Haptic.click()
                            withAnimation(.easeOut(duration: 0.25)) { club.posting = true }
                        } label: {
                            (Text(Image(systemName: "plus")) + Text(verbatim: " ") + Text("Post"))
                                .font(tw(17).weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14).frame(height: 34)
                                .background(Image(uiImage: ClubArt.plusSlip).resizable())
                                .frame(minHeight: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Post"))
                    }
                }
            }
            .foregroundStyle(KitArt.ink)
            Group {
                if vertical, let width {
                    VStack(alignment: .leading, spacing: 8) {
                        photo(cover(theme), width: width - 32, height: 118)
                        words.frame(height: 128)
                    }
                    .padding(12)
                    .frame(width: width, alignment: .leading)
                } else {
                    let h = height ?? 130
                    HStack(alignment: .top, spacing: 12) {
                        photo(cover(theme), width: h - 8, height: h - 8)
                        words.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .padding(.trailing, 8)
                    .frame(width: width, height: h, alignment: .topLeading)
                    .frame(maxWidth: width == nil ? .infinity : width)
                }
            }
            .background(vertical ? AnyView(Image(uiImage: ClubArt.blankCard).resizable()
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)) : AnyView(Color.clear))
            .overlay(alignment: .bottomLeading) {
                // The one being looked at is underlined in red.
                if on { Rectangle().fill(ClubArt.red).frame(width: 36, height: 3).padding(.leading, vertical ? 12 : 4).padding(.bottom, vertical ? 8 : -4) }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !on else { return }
                Haptic.click()
                Task { await club.choose(theme) }
            }
            .offset(x: drag * 0.2)
            // Sideways only, beside the grid's own scrolling (never in its way).
            .simultaneousGesture(DragGesture(minimumDistance: 14)
                .updating($drag) { v, st, _ in if abs(v.translation.width) > abs(v.translation.height) * 2 { st = v.translation.width } }
                .onEnded { v in
                    if abs(v.translation.width) > 40, abs(v.translation.width) > abs(v.translation.height) * 2 { turnTheme(v.translation.width < 0 ? 1 : -1) }
                })
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: Text("Next theme")) { turnTheme(1) }
        } else if club.loading {
            ProgressView().frame(width: width ?? 200, height: height ?? 120)
        } else if club.failed {
            notice.frame(width: width ?? 300)
        }
    }

    private func turnTheme(_ d: Int) {
        let list = club.themes
        guard let i = list.firstIndex(where: { $0.id == club.theme?.id }) else { return }
        let j = i + d
        guard list.indices.contains(j) else { Haptic.detent(); return }
        Haptic.click()
        Task { await club.choose(list[j]) }
    }

    /// This week's picks, the same kind of entry as the theme: the first
    /// picked picture, "Picks", how many and by how many people.
    private func picksCard(width: CGFloat, height: CGFloat) -> some View {
        let picks = club.picks ?? []
        let on = club.scope == .picks
        let people = Set(picks.map(\.author.id)).count
        return Button {
            Haptic.click()
            Task { await club.chooseScope(.picks) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                photo(club.picksCover?.thumbURL, width: height - 30, height: height - 30)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "star.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Image(uiImage: ClubArt.seal).resizable())
                            .offset(x: 10, y: -8)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text("This week’s picks").font(tw(18).weight(.bold)).lineLimit(2).minimumScaleFactor(0.8)
                    if club.picksFailed {
                        Label("Couldn’t load. Tap to try again.", systemImage: "arrow.clockwise").font(tw(13)).lineLimit(2)
                    } else {
                        Text("\(picks.count) pictures · \(people) photographers").font(tw(13)).opacity(0.7).lineLimit(2)
                        (Text("See all") + Text(verbatim: " ›")).font(tw(15).weight(.semibold)).foregroundStyle(ClubArt.red)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(KitArt.ink)
            .padding(10)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(Image(uiImage: ClubArt.blankCard).resizable().shadow(color: .black.opacity(0.3), radius: 2, y: 1))
            .overlay(alignment: .bottomLeading) {
                if on { Rectangle().fill(ClubArt.red).frame(width: 36, height: 3).padding(.leading, 10).padding(.bottom, 6) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { if club.picksFailed { Task { await club.refreshPicks() } } })
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Everything new since "Mine" was last opened, on one slip.
    private var freshCount: Int {
        guard let f = club.card?.fresh else { return 0 }
        return f.likes + f.comments + f.followers + f.letters
    }

    /// B's name plate: one's seal, name, likes and followers, and the slip
    /// with what's new peeking out of its top edge. Opens "Mine".
    private func namePlate(width: CGFloat, height: CGFloat) -> some View {
        let name = club.me?.profile.name ?? ""
        return Button {
            Haptic.click()
            Task { await club.openMine() }
        } label: {
            HStack(spacing: 10) {
                ClubSeal(name: name.isEmpty ? "K" : name, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    (name.isEmpty ? Text("Mine") : Text("Mine") + Text(verbatim: " · \(name)"))
                        .font(tw(17).weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                    Text("Likes \(club.card?.likes ?? 0) · Followers \(club.card?.followers ?? 0)")
                        .font(tw(13)).opacity(0.75).lineLimit(2).minimumScaleFactor(0.9)
                    Text("Shots \(ShotLog.shared.shots.count)").font(tw(13)).opacity(0.75).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(KitArt.ink)
            .padding(12)
            .frame(width: width, height: height, alignment: .leading)
            .background(Image(uiImage: ClubArt.blankCard).resizable().shadow(color: .black.opacity(0.3), radius: 2, y: 1))
            .overlay(alignment: .topTrailing) {
                if freshCount > 0 { PlusSlip(n: freshCount, height: 22).offset(x: 6, y: -9) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Mine"))
        .accessibilityValue(freshCount > 0 ? Text("Something new") : Text(verbatim: ""))
        .task(id: club.me?.profile.id) { await club.refreshMineCard() }
    }

    /// This week's days and which had a public picture of one's own.
    private var weekDays: [(posted: Bool, future: Bool)] {
        var cal = Calendar.current
        cal.locale = Locale(identifier: language.code)
        let today = cal.startOfDay(for: Date())
        guard let start = cal.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        // Only the server's approval days (QUEUE 11/27): none lit until the card is read.
        let days: Set<String> = Set(club.card?.days ?? [])
        return (0..<7).compactMap { k in
            guard let d = cal.date(byAdding: .day, value: k, to: start) else { return nil }
            let c = cal.dateComponents([.year, .month, .day], from: d)
            let key = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
            return (days.contains(key), d > today)
        }
    }

    private func figure(_ n: Int?, _ word: Text, fresh: Int = 0) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: n.map { $0 >= 10_000 ? String(format: "%.1fk", Double($0) / 1000) : "\($0)" } ?? "–")
                .font(tw(20).weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
            word.font(tw(13)).opacity(0.65).lineLimit(1).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) { if fresh > 0 { PlusSlip(n: fresh, height: 18).offset(x: 4, y: -14) } }
    }

    /// A's member card: seal, name, line; four figures (what's new on a red
    /// slip over each); this week's days and the run. Opens "Mine".
    private func memberCard(width: CGFloat) -> some View {
        let card = club.card, fresh = card?.fresh ?? .init()
        let name = club.me?.profile.name ?? ""
        return Button {
            Haptic.click()
            Task { await club.openMine() }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ClubSeal(name: name.isEmpty ? "K" : name, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        (name.isEmpty ? Text("Mine") : Text("Mine") + Text(verbatim: " · \(name)"))
                            .font(tw(17).weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                        if let bio = club.me?.bio, !bio.isEmpty {
                            Text(verbatim: bio).font(tw(13)).opacity(0.65).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    if fresh.letters > 0 {
                        Image(systemName: "envelope").font(.system(size: 15)).opacity(0.7)
                            .overlay(alignment: .topTrailing) { PlusSlip(n: fresh.letters, height: 16).offset(x: 14, y: -10) }
                            .padding(.trailing, 12)
                    }
                }
                HStack(spacing: 0) {
                    figure(ShotLog.shared.shots.count, Text("Shots"))
                    figure(card?.likes, Text("Likes"), fresh: fresh.likes + fresh.comments)
                    figure(card?.followers, Text("Followers"), fresh: fresh.followers)
                    figure(card?.following, Text("Following"))
                }
                .padding(.top, 6)
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        ForEach(Array(weekDays.enumerated()), id: \.offset) { _, d in
                            ZStack {
                                Image(uiImage: ClubArt.dayBox).resizable()
                                if d.posted { Image(uiImage: ClubArt.inkDot).resizable().frame(width: 10, height: 10) }
                            }
                            .frame(width: 20, height: 20)
                            .opacity(d.future ? 0.5 : 1)
                        }
                    }
                    .accessibilityHidden(true)
                    Group {
                        if club.me?.claimable != nil {
                            Text("A roll is waiting in Mine")
                        } else if let c = card, c.streak > 0 {
                            Text("\(c.streak)-day run · best \(c.longest)")
                        }
                    }
                    .font(tw(12)).lineLimit(2).minimumScaleFactor(0.92).opacity(0.75)
                }
            }
            .foregroundStyle(KitArt.ink)
            .padding(.horizontal, 16).padding(.vertical, 16)
            .frame(width: width, alignment: .topLeading)
            .background(Image(uiImage: ClubArt.memberPaper).resizable()
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Mine"))
        .accessibilityValue(fresh.any ? Text("Something new") : Text(verbatim: ""))
        .task(id: club.me?.profile.id) { await club.refreshMineCard() }
    }

    // MARK: Someone's page (S2)

    /// Their seal and name, their line and films, follow, write, block, and the way back.
    private func personCard(_ card: Community.AuthorCard, width: CGFloat) -> some View {
        let other = card.id != club.me?.profile.id
        let row = width > 500
        let head = HStack(spacing: 12) {
            ClubSeal(name: card.name, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: card.name).font(tw(22).weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
                if club.authorFailed {
                    Button { Task { await club.readAuthorCard(card.id) } } label: {
                        Label("Couldn’t load. Tap to try again.", systemImage: "arrow.clockwise").font(tw(13))
                    }.buttonStyle(.plain)
                } else if let bio = card.bio {
                    Text(verbatim: bio).font(tw(15).italic()).lineLimit(2)
                } else if card.films > 0, let top = card.topFilm {
                    Text("Mostly \(FilmNames.short(top)) · film stocks used: \(card.films)").font(tw(13)).opacity(0.75).lineLimit(2)
                }
            }
        }
        let actions = HStack(spacing: 14) {
            if other, club.followsKnown {
                AuthorFollowLabel(author: .init(id: card.id, name: card.name), s: 0.7)
                Button {
                    Haptic.click()
                    Task { await club.openLetter(with: .init(id: card.id, name: card.name)) }
                } label: {
                    Label("Write a letter", systemImage: "envelope").font(tw(15).weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if other {
                Button {
                    Haptic.click()
                    if blocking == card.id {
                        blocking = nil
                        Task { await club.block(.init(id: card.id, name: card.name)) }
                    } else { blocking = card.id }
                } label: {
                    Label(blocking == card.id ? "Block \(card.name)? Tap again" : "Block", systemImage: "hand.raised")
                        .font(tw(15)).foregroundStyle(blocking == card.id ? ClubArt.red : KitArt.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        let back = Button {
            Haptic.click()
            Task { await club.leaveAuthor() }
        } label: {
            Label("Back to the album", systemImage: "chevron.left").font(tw(15).weight(.semibold))
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        return Group {
            if row {
                HStack(spacing: 16) { back; head; Spacer(minLength: 0); actions }
            } else {
                VStack(alignment: .leading, spacing: 8) { back; head; actions }
            }
        }
        .foregroundStyle(KitArt.ink)
        .padding(12)
        .frame(width: width, alignment: .leading)
        .background(Image(uiImage: ClubArt.blankCard).resizable().shadow(color: .black.opacity(0.3), radius: 2, y: 1))
    }
}
