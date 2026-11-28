import SwiftUI

/// The community on the open bag (user 11/27: style A, done properly).
/// One rule: the narrow column says whom or what the page is about, the
/// wide side holds the pictures. Home: the theme, this week's picks and
/// one's member card, each standing in a shallow leather pocket sewn on the
/// left page; a person's page (one's own or someone else's): their archive
/// card in the same place and their pictures beside it — no panel over the
/// bag. The album has three columns, and the gap between the first two lies
/// on the spine: the left page holds the column and one row of prints, the
/// right page two (four would cut prints on the spine). Writing 13–24 pt,
/// nothing under 11 pt, every tap 44 pt. The outer screen (and any small
/// canvas) keeps a band across the top over the same album.
extension ClubArt {
    /// GPT parts (design/community/club-ab and a-polish/parts).
    static let band = UIImage(named: "club_band") ?? UIImage()
    static let notes = UIImage(named: "club_notes") ?? UIImage()
    static let blankCard = UIImage(named: "club_cardblank") ?? UIImage()
    static let plusSlip = UIImage(named: "club_plusslip") ?? UIImage()
    static let seal = UIImage(named: "club_seal") ?? UIImage()
    static let memberPaper = UIImage(named: "club_member_tall") ?? UIImage()
    static let dayBox = UIImage(named: "club_box") ?? UIImage()
    static let inkDot = UIImage(named: "club_inkdot") ?? UIImage()
    // Stretched parts are given the point size they are drawn at, so their
    // fixed ends (the caps below) keep their shape.
    static let pocketLip = part("club_pocketlip", height: 18)
    static let corner = UIImage(named: "club_corner") ?? UIImage()
    static let ear = part("club_ear", height: 44)
    static let kraftStrip = part("club_kraftstrip", height: 14)
    static let archive = UIImage(named: "club_archive") ?? UIImage()
    static let redTag = part("club_redtag", height: 36)
    static let creamTag = part("club_creamtag", height: 36)
    static let backTab = part("club_backtab", height: 38)
    static func part(_ name: String, height: CGFloat) -> UIImage {
        guard let i = UIImage(named: name), let cg = i.cgImage else { return UIImage() }
        return UIImage(cgImage: cg, scale: CGFloat(cg.height) / height, orientation: .up)
    }
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

/// A paper tag (red or cream) as a button's face: the art stretched only in its middle.
private struct TagFace: ViewModifier {
    let red: Bool
    func body(content: Content) -> some View {
        content
            .foregroundStyle(red ? Color.white : KitArt.ink)
            .padding(.leading, 14).padding(.trailing, red ? 22 : 14)
            .frame(height: 36)
            .background(Image(uiImage: red ? ClubArt.redTag : ClubArt.creamTag)
                .resizable(capInsets: red ? EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 22) : EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                .shadow(color: .black.opacity(0.25), radius: 1, y: 0.8))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

/// A card standing in a shallow leather pocket: the pocket's stitched lip
/// covers only the card's blank bottom margin (keep `margin` free there).
private struct InPocket: ViewModifier {
    static let margin: CGFloat = 14
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            Image(uiImage: ClubArt.pocketLip)
                .resizable(capInsets: EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                .frame(height: 18)
                .padding(.horizontal, -5)
                .offset(y: 6)
                .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// Where the filters' drop cards come from (their tags' bounds).
private struct FilterAnchorKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// The community board, over both pages of the bag.
struct ClubBoard: View {
    @ObservedObject private var club = ClubModel.shared
    @ObservedObject private var language = AppLanguage.shared
    let s: CGFloat
    /// The open drop card: "who" or "film".
    @State private var open: String?
    @State private var blocking: String?
    /// The grid's pictures on screen (their places in the list), and the top
    /// one kept when someone's page opens, to come back to it (Codex review).
    @State private var onScreen: Set<Int> = []
    @State private var keptTop: String?
    /// The theme film's place (in frames) and whether a finger has moved it (then it stops by itself).
    @State private var stripPos: CGFloat = Self.filmAt ?? 0
    #if DEBUG
    /// `-clubFilmAt 2.4`: the film held there (between frames too), for checks.
    static let filmAt: CGFloat? = UserDefaults.standard.object(forKey: "clubFilmAt").map { _ in CGFloat(UserDefaults.standard.double(forKey: "clubFilmAt")) }
    #else
    static let filmAt: CGFloat? = nil
    #endif
    @State private var stripTouched = false

    /// Screens this wide get the two pages; the outer screen the compact layout.
    static func isCompact(_ s: CGFloat) -> Bool { ClubArt.boardRect.width * s < 800 }
    static let pad: CGFloat = 12
    /// How far the film reaches past the column, into the margins either side.
    static let filmBleed: CGFloat = 8
    /// The film's box for a width: the slits' height at the film's size.
    static func stripHeight(_ w: CGFloat) -> CGFloat {
        let h = ThemeFilm.filmHeight(width: w, height: .infinity)
        return ceil((h + 6) / ThemeFilm.cut.height)
    }
    /// The album's gaps; the one between its first two columns lies on the spine.
    static let gap: CGFloat = 24

    /// The column's width for a board this wide: the album's first gap
    /// centred on the spine (the board's middle), three columns to the right edge.
    static func columnWidth(_ boardWidth: CGFloat) -> CGFloat {
        // x0 (album's left) + cw + gap/2 = W/2, with 3cw + 2gap = W - x0 - pad.
        let x0 = boardWidth / 4 + pad / 2 + gap / 4
        return floor(x0 - pad * 2)
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
            } else {
                pages(size: r.size, foot: foot)
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

    // MARK: Layouts

    /// Who the page is about: a person's page (theirs or one's own) or the community's.
    private var person: Community.AuthorCard? { club.scope.isPerson ? club.authorCard : nil }

    /// The two pages: the column in the left page's pockets, the album beside it.
    private func pages(size: CGSize, foot: CGFloat) -> some View {
        let pad = Self.pad
        let col = Self.columnWidth(size.width)
        let albumW = size.width - col - pad * 3
        return HStack(alignment: .top, spacing: pad) {
            VStack(alignment: .leading, spacing: 4) {
                if person == nil, club.theme != nil {
                    // The film lies on the leather itself, as wide as the column and its
                    // margins allow (polish 2): the cards scroll under it.
                    let w = col + Self.filmBleed * 2
                    strip(width: w, height: Self.stripHeight(w))
                        .frame(width: col)
                        .transition(.opacity)
                }
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        if let card = person {
                            backTab
                            archiveCard(card, width: col)
                        } else {
                            themeCard(width: col, vertical: true)
                            if club.signedIn { memberCard(width: col) } else { ClubSignIn(width: col, s: 0.85) }
                        }
                    }
                    .padding(.top, person == nil ? 0 : 8)
                    .padding(.bottom, 24)
                    // A page turning to another section: the column's card is changed.
                    .id(person?.id ?? "home")
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                }
            }
            .frame(width: col)
            .animation(.easeInOut(duration: 0.3), value: person?.id)
            Group {
                if club.isOwnPage, club.mineOpen {
                    VStack(spacing: 0) {
                        header(width: albumW)
                        // The news on the right page only, its piles on the left page's album column.
                        ClubMinePanel(embedded: true, spine: Self.gap)
                            .frame(width: albumW)
                            .padding(.top, 10)
                            .padding(.bottom, foot)
                    }
                } else {
                    grid(columns: 3, width: albumW, foot: foot, band: nil)
                }
            }
            .frame(width: albumW)
        }
        .padding(.horizontal, pad)
        .padding(.top, pad)
    }

    /// The outer screen: a band of cards one slides through, filters, three or two columns.
    private func compactLayout(size: CGSize, foot: CGFloat) -> some View {
        let w = size.width - Self.pad * 2
        let cols = w >= 560 ? 3 : 2
        return Group {
            if club.isOwnPage, club.mineOpen {
                VStack(spacing: 8) {
                    compactBand(width: w)
                    header(width: w)
                    ClubMinePanel(embedded: true, rowPiles: true).frame(width: w).padding(.bottom, foot)
                }
            } else {
                grid(columns: cols, width: w, foot: foot, band: AnyView(compactBand(width: w)))
            }
        }
        .padding(.horizontal, Self.pad)
        .padding(.top, 8)
    }

    // MARK: The album

    private func grid(columns: Int, width: CGFloat, foot: CGFloat, band: AnyView?) -> some View {
        let gap = columns == 3 && !Self.isCompact(s) ? Self.gap : 12
        let cw = floor((width - gap * CGFloat(columns - 1)) / CGFloat(columns))
        let items = Array(repeating: GridItem(.fixed(cw), spacing: gap), count: columns)
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if let band { band.padding(.bottom, 8).id("top") } else { Color.clear.frame(height: 0).id("top") }
                    Section {
                        if club.posts.isEmpty {
                            notice.frame(width: min(width, 520), alignment: .leading).padding(.top, 10)
                        } else {
                            LazyVGrid(columns: items, alignment: .leading, spacing: 16) {
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
                            .padding(.top, 10)
                        }
                    } header: {
                        header(width: width)
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

    /// One picture: a print on cream paper held by two photo corners, then
    /// two lines: who, then the film and the hearts.
    private func card(_ post: Community.Post, width w: CGFloat) -> some View {
        let inset: CGFloat = 8
        let photoW = w - inset * 2, photoH = floor(photoW * 0.75)
        let corner: CGFloat = min(20, photoW * 0.1)
        return VStack(alignment: .leading, spacing: 6) {
            PostPicture(url: post.thumbURL)
                .frame(width: photoW, height: photoH)
                .clipped()
                .overlay(Rectangle().stroke(Color.black.opacity(0.12), lineWidth: 0.5))
                // The corners (art: the right angle bottom-left) turned to the top-left and bottom-right.
                .overlay(alignment: .topLeading) {
                    Image(uiImage: ClubArt.corner).resizable().frame(width: corner, height: corner)
                        .rotationEffect(.degrees(90)).offset(x: -3, y: -3)
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(uiImage: ClubArt.corner).resizable().frame(width: corner, height: corner)
                        .rotationEffect(.degrees(-90)).offset(x: 3, y: 3)
                }
            HStack(spacing: 6) {
                ClubSeal(name: post.author.name, size: 22)
                Text(verbatim: post.author.name)
                    .font(tw(15).weight(.semibold)).lineLimit(1)
            }
            HStack(spacing: 4) {
                Text(verbatim: FilmNames.short(post.filmId))
                    .font(tw(13).italic()).opacity(0.75).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: post.likedByMe ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ClubArt.red)
                Text(verbatim: "\(post.likeCount)").font(tw(14))
            }
        }
        .foregroundStyle(KitArt.ink)
        .padding(inset)
        .padding(.bottom, 2)
        .frame(width: w, alignment: .leading)
        .background(Image(uiImage: ClubArt.blankCard).resizable()
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1.2))
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

    // MARK: The album's top edge: a kraft strip with index ears (filters, or the page's sides)

    private var whoIsFollowing: Bool { club.scope == .following }

    private func header(width: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if let card = person {
                if club.isOwnPage {
                    ear(selected: !club.mineOpen, id: "own-works") {
                        Text("My pictures").font(tw(15).weight(.semibold)).lineLimit(1)
                    } action: {
                        withAnimation(.easeOut(duration: 0.2)) { club.mineOpen = false }
                    }
                    ear(selected: club.mineOpen, id: "own-news") {
                        HStack(spacing: 6) {
                            Image(systemName: "envelope").font(.system(size: 14, weight: .semibold))
                            Text("News & account").font(tw(15).weight(.semibold)).lineLimit(1)
                        }
                        .overlay(alignment: .topTrailing) {
                            if freshCount > 0, !club.mineOpen { PlusSlip(n: freshCount, height: 18).offset(x: 18, y: -14) }
                        }
                    } action: {
                        Task { await club.openMine() }
                    }
                } else {
                    ear(selected: true, id: "their-works") {
                        Text("\(card.name)’s pictures").font(tw(15).weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    } action: {}
                }
            } else {
                if club.signedIn {
                    filterTag("who", icon: AnyView(Image(systemName: whoIsFollowing ? "person.crop.circle.badge.checkmark" : "person.2.fill")
                                                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(KitArt.ink.opacity(0.8))
                                                    .frame(width: 24)),
                              title: whoIsFollowing ? Text("Following") : Text("Everyone"), label: Text("Whose pictures"))
                }
                if club.signedIn, club.filmApplies {
                    filterTag("film", icon: AnyView(Image(uiImage: ClubArt.rollIcon(club.film)).resizable().scaledToFit().frame(width: 22, height: 28)),
                              title: filmName(club.film), label: Text("Film"))
                }
            }
            Spacer(minLength: 6)
            if person == nil, !Self.isCompact(s) {
                context.font(tw(13)).foregroundStyle(KitArt.ink.opacity(0.75)).lineLimit(1).minimumScaleFactor(0.85)
                    .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 6)
        .frame(width: width, height: 56, alignment: .bottomLeading)
        .background(alignment: .bottom) {
            // The strip the ears rise from, along the album's top.
            Image(uiImage: ClubArt.kraftStrip)
                .resizable(capInsets: EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                .frame(height: 14)
                .shadow(color: .black.opacity(0.3), radius: 1.2, y: 1)
                .accessibilityHidden(true)
        }
    }

    /// One index ear on the strip; the chosen one stands a little taller.
    private func ear(selected: Bool, id: String, @ViewBuilder label: () -> some View, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.click()
            action()
        } label: {
            label()
                .foregroundStyle(KitArt.ink.opacity(selected ? 1 : 0.6))
                .padding(.horizontal, 36)
                .padding(.bottom, 4)
                .frame(height: selected ? 44 : 38)
                .background(Image(uiImage: ClubArt.ear)
                    .resizable(capInsets: EdgeInsets(top: 0, leading: 34, bottom: 0, trailing: 34))
                    .opacity(selected ? 1 : 0.85))
                .padding(.bottom, 6)
                .frame(minHeight: 44, alignment: .bottom)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
            HStack(spacing: 6) {
                icon
                title.font(tw(15).weight(.semibold)).lineLimit(1)
                Image(systemName: open == key ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold)).opacity(0.55)
            }
            .foregroundStyle(KitArt.ink)
            .padding(.horizontal, 36)
            .padding(.bottom, 4)
            .frame(height: 44)
            .background(Image(uiImage: ClubArt.ear)
                .resizable(capInsets: EdgeInsets(top: 0, leading: 34, bottom: 0, trailing: 34)))
            .padding(.bottom, 6)
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

    // MARK: The outer screen's band

    private func compactBand(width: CGFloat) -> some View {
        let h: CGFloat = 134
        return Group {
            if let card = person {
                VStack(alignment: .leading, spacing: 4) {
                    backTab
                    personRow(card, width: width)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        themeCard(width: min(330, width * 0.62), vertical: false, height: h - 16)
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
        .overlay(Rectangle().stroke(Color.black.opacity(0.12), lineWidth: 0.5))
        .accessibilityHidden(true)
    }

    /// The red "Post" tag.
    private var postTag: some View {
        Button {
            Haptic.click()
            withAnimation(.easeOut(duration: 0.25)) { club.posting = true }
        } label: {
            (Text(Image(systemName: "plus")) + Text(verbatim: " ") + Text("Post"))
                .font(tw(17).weight(.bold))
                .modifier(TagFace(red: true))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Post"))
    }

    /// What the film shows: the themes, then this week's picks when there are
    /// some (polish 2: the picks are a frame on the film, not a card of their own).
    private enum Reel: Equatable {
        case theme(Community.Theme)
        case picks
    }
    private var reel: [Reel] {
        club.themes.map { .theme($0) } + (hasPicks ? [.picks] : [])
    }
    /// Picks to show, or a read that failed (the frame stays, to try again; Codex review).
    private var hasPicks: Bool { club.signedIn && (club.picksFailed || !(club.picks ?? []).isEmpty) }
    /// The frame the grid is on now: the picks, or the chosen theme.
    private var chosenIndex: Int? {
        if club.scope == .picks, hasPicks { return reel.firstIndex(of: .picks) }
        return club.themes.firstIndex { $0.id == club.theme?.id }
    }

    /// The entry on the film's middle frame and whether the grid shows it.
    @ViewBuilder
    private func themeCard(width: CGFloat?, vertical: Bool, height: CGFloat? = nil) -> some View {
        if let chosen = club.theme {
            let list = reel
            let shown = list.isEmpty ? .theme(chosen) : list[ThemeFilm.index(stripPos, list.count)]
            let words: AnyView = {
                switch shown {
                case .theme(let theme): return AnyView(themeWords(theme, on: club.scope == .theme && theme.id == chosen.id))
                case .picks: return AnyView(picksWords)
                }
            }()
            let post = HStack {
                Spacer(minLength: 0)
                switch shown {
                case .theme(let theme):
                    // Another theme pulled into view (or the picks in the grid): look at it first.
                    if theme.id != chosen.id || club.scope == .picks {
                        seeAll { Task { await club.choose(theme) } }
                    } else if club.signedIn, theme.isOpen(at: Date()) { postTag }
                case .picks:
                    if club.picksFailed {
                        Button {
                            Haptic.click()
                            Task { await club.refreshPicks() }
                        } label: {
                            Label("Try again", systemImage: "arrow.clockwise").font(tw(16).weight(.bold)).modifier(TagFace(red: false))
                        }
                        .buttonStyle(.plain)
                    } else if club.scope != .picks { seeAll { Task { await club.chooseScope(.picks) } } }
                }
            }
            Group {
                if vertical, let width {
                    VStack(alignment: .leading, spacing: 8) {
                        words
                        post
                    }
                    .padding(12)
                    .padding(.bottom, InPocket.margin)
                    .frame(width: width, alignment: .leading)
                    .background(Image(uiImage: ClubArt.blankCard).resizable()
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1))
                    .modifier(InPocket())
                } else {
                    let h = height ?? 130
                    HStack(alignment: .top, spacing: 10) {
                        let sw = floor(h * 1.45)
                        strip(width: sw, height: h)
                        VStack(alignment: .leading, spacing: 0) { words; Spacer(minLength: 0); post }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .padding(.trailing, 8)
                    .frame(width: width, height: h, alignment: .topLeading)
                    .frame(maxWidth: width == nil ? .infinity : width)
                }
            }
            .accessibilityElement(children: .contain)
        } else if club.loading {
            ProgressView().frame(width: width ?? 200, height: height ?? 120)
        } else if club.failed {
            notice.frame(width: width ?? 300)
        }
    }

    /// "See all ›" on a cream tag: show the entry on the film in the grid.
    private func seeAll(_ run: @escaping () -> Void) -> some View {
        Button {
            Haptic.click()
            run()
        } label: {
            (Text("See all") + Text(verbatim: " ›")).font(tw(16).weight(.bold)).modifier(TagFace(red: false))
        }
        .buttonStyle(.plain)
    }

    /// A theme's lines: what kind and how long, its name big, who is posting.
    private func themeWords(_ theme: Community.Theme, on: Bool) -> some View {
        let names = club.themeNames
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                kindName(theme.kind)
                Text(verbatim: "·")
                theme.isOpen(at: Date()) ? Text("Ends in \(timeLeft(theme))") : Text("Ended")
            }
            .font(tw(13)).opacity(0.7).lineLimit(1).minimumScaleFactor(0.85)
            Text(verbatim: Community.Theme.text(theme.title, language: language.code))
                .font(tw(22).weight(.bold)).lineLimit(2).minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if club.signedIn, !club.loading, on {
                HStack(spacing: 6) {
                    HStack(spacing: -5) {
                        ForEach(Array(names.prefix(3).enumerated()), id: \.offset) { _, n in ClubSeal(name: n, size: 20) }
                    }
                    (names.isEmpty ? Text("No one has posted yet. Be the first.")
                     : club.hasMore ? Text("\(names.count)+ posting") : Text("\(names.count) posting"))
                        .font(tw(13)).opacity(0.75).lineLimit(2).minimumScaleFactor(0.85)
                }
            }
        }
        .foregroundStyle(KitArt.ink)
    }

    /// The picks' lines, in the same places as a theme's.
    private var picksWords: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(ClubArt.red)
                Text("Picks")
            }
            .font(tw(13)).opacity(0.8).lineLimit(1)
            Text("This week’s picks")
                .font(tw(22).weight(.bold)).lineLimit(2).minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if club.picksFailed {
                Text("Couldn’t load. Tap to try again.").font(tw(13)).opacity(0.75).lineLimit(2)
            } else {
                Text("\((club.picks ?? []).count) pictures").font(tw(13)).opacity(0.75).lineLimit(1)
            }
        }
        .foregroundStyle(KitArt.ink)
    }

    /// The film: each theme's picture (its newest public one, or the fogged
    /// blank when it has none), then the picks' first picture.
    private func strip(width: CGFloat, height: CGFloat) -> some View {
        let list = reel
        let frames: [ThemeFilm.Frame] = list.enumerated().map { i, entry in
            switch entry {
            case .theme(let t):
                return .init(url: cover(t), title: Community.Theme.text(t.title, language: language.code), code: "\(i + 1)A")
            case .picks:
                return .init(url: club.picksCover?.thumbURL, title: String(localized: "This week’s picks"), code: "★")
            }
        }
        return ThemeFilm(frames: frames, pos: $stripPos, touched: $stripTouched, width: width, height: height) { i in
            guard list.indices.contains(i) else { return }
            switch list[i] {
            case .theme(let t): if club.scope != .theme || t.id != club.theme?.id { Task { await club.choose(t) } }
            case .picks:
                if club.picksFailed { Task { await club.refreshPicks() } }
                else if club.scope != .picks { Task { await club.chooseScope(.picks) } }
            }
        }
        .onAppear { syncStrip() }
        .onChange(of: chosenIndex) { syncStrip() }
        .onChange(of: list.count) { syncStrip() }
    }

    /// The film brought to the chosen entry, the short way round.
    private func syncStrip() {
        guard Self.filmAt == nil else { return }
        let n = reel.count
        guard let i = chosenIndex, n > 0 else { return }
        let now = ThemeFilm.index(stripPos, n)
        guard now != i else { return }
        var d = (i - now) % n
        if d > n / 2 { d -= n } else if d < -n / 2 { d += n }
        withAnimation(.easeInOut(duration: 0.5)) { stripPos = stripPos.rounded() + CGFloat(d) }
    }

    /// Everything new since "Mine" was last opened, on one slip.
    private var freshCount: Int {
        guard let f = club.card?.fresh else { return 0 }
        return f.likes + f.comments + f.followers + f.letters
    }

    private func openOwn() {
        guard let me = club.me else { return }
        Haptic.click()
        Task { await club.openAuthor(.init(id: me.profile.id, name: me.profile.name)) }
    }

    /// The outer screen's name plate: one's seal, name, likes and followers,
    /// what's new on the slip. Opens one's own page.
    private func namePlate(width: CGFloat, height: CGFloat) -> some View {
        let name = club.me?.profile.name ?? ""
        return Button(action: openOwn) {
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
        VStack(spacing: 1) {
            Text(verbatim: n.map { $0 >= 10_000 ? String(format: "%.1fk", Double($0) / 1000) : "\($0)" } ?? "–")
                .font(tw(20).weight(.bold)).lineLimit(1)
            word.font(tw(13)).opacity(0.7).lineLimit(1)
        }
        .fixedSize()
        .overlay(alignment: .topTrailing) { if fresh > 0 { PlusSlip(n: fresh, height: 18).offset(x: 14, y: -12) } }
    }

    /// One's four figures: in a row when they fit the card, else two by two.
    private var figures: some View {
        let card = club.card, fresh = card?.fresh ?? .init()
        let all = [
            AnyView(figure(ShotLog.shared.shots.count, Text("Shots"))),
            AnyView(figure(card?.likes, Text("Likes"), fresh: fresh.likes + fresh.comments)),
            AnyView(figure(card?.followers, Text("Followers"), fresh: fresh.followers)),
            AnyView(figure(card?.following, Text("Following"))),
        ]
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { ForEach(0..<4, id: \.self) { i in all[i] } }
            Grid(horizontalSpacing: 18, verticalSpacing: 10) {
                GridRow { all[0]; all[1] }
                GridRow { all[2]; all[3] }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// This week's seven boxes and the run.
    private var weekRow: some View {
        VStack(alignment: .leading, spacing: 4) {
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
                    Text("A roll is waiting in Rewards")
                } else if let c = club.card, c.streak > 0 {
                    Text("\(c.streak)-day run · best \(c.longest)")
                }
            }
            .font(tw(13)).lineLimit(2).opacity(0.75)
        }
    }

    /// The member card in its pocket: seal and name, the four figures (what's
    /// new on a red slip), this week. Opens one's own page.
    private func memberCard(width: CGFloat) -> some View {
        let fresh = club.card?.fresh ?? .init()
        let name = club.me?.profile.name ?? ""
        return Button(action: openOwn) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ClubSeal(name: name.isEmpty ? "K" : name, size: 40)
                    Text(verbatim: name.isEmpty ? "Koco" : name)
                        .font(tw(18).weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    if fresh.letters > 0 {
                        Image(systemName: "envelope").font(.system(size: 15)).opacity(0.7)
                            .overlay(alignment: .topTrailing) { PlusSlip(n: fresh.letters, height: 16).offset(x: 14, y: -10) }
                            .padding(.trailing, 12)
                    }
                }
                figures
                weekRow
            }
            .foregroundStyle(KitArt.ink)
            .padding(.horizontal, 12).padding(.top, 14)
            .padding(.bottom, 10 + InPocket.margin)
            .frame(width: width, alignment: .topLeading)
            .background(Image(uiImage: ClubArt.memberPaper).resizable()
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1))
            .modifier(InPocket())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Mine"))
        .accessibilityValue(fresh.any ? Text("Something new") : Text(verbatim: ""))
        .accessibilityIdentifier("club-member")
        .task(id: club.me?.profile.id) { await club.refreshMineCard() }
    }

    // MARK: A person's page (one's own or someone else's)

    /// "← Community": a kraft arrow tab at the column's top.
    private var backTab: some View {
        Button {
            Haptic.click()
            Task { await club.leaveAuthor() }
        } label: {
            (Text(Image(systemName: "arrow.left")) + Text(verbatim: "  ") + Text("Community"))
                .font(tw(15).weight(.semibold)).foregroundStyle(KitArt.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.leading, 34).padding(.trailing, 16)
                .frame(height: 38)
                .background(Image(uiImage: ClubArt.backTab)
                    .resizable(capInsets: EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 10))
                    .shadow(color: .black.opacity(0.3), radius: 1.2, y: 1))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Back to the community"))
        .accessibilityIdentifier("club-back")
    }

    @ViewBuilder private func personLine(_ card: Community.AuthorCard) -> some View {
        if club.authorFailed {
            Button { Task { await club.readAuthorCard(card.id) } } label: {
                Label("Couldn’t load. Tap to try again.", systemImage: "arrow.clockwise").font(tw(13))
                    .frame(minHeight: 44)
            }.buttonStyle(.plain)
        } else {
            if let bio = card.bio { Text(verbatim: bio).font(tw(15).italic()).lineLimit(3) }
            if card.films > 0, let top = card.topFilm {
                Text("Mostly \(FilmNames.short(top)) · film stocks used: \(card.films)").font(tw(13)).opacity(0.75).lineLimit(2)
            }
        }
    }

    /// Follow (red tag; cream once followed), write, block — someone else's only.
    @ViewBuilder private func personActions(_ card: Community.AuthorCard) -> some View {
        let author = Community.Author(id: card.id, name: card.name)
        if club.followsKnown {
            let on = club.followingIDs.contains(card.id)
            Button {
                Haptic.click()
                Task { await club.toggleFollow(author) }
            } label: {
                (on ? Text("Followed") : Text("Follow")).font(tw(16).weight(.bold)).lineLimit(1).modifier(TagFace(red: !on))
            }
            .buttonStyle(.plain)
            .disabled(club.followBusy.contains(card.id))
            .accessibilityLabel(on ? Text("Following \(card.name)") : Text("Follow \(card.name)"))
            Button {
                Haptic.click()
                Task { await club.openLetter(with: .init(id: card.id, name: card.name)) }
            } label: {
                Label("Write a letter", systemImage: "envelope").font(tw(15).weight(.semibold)).lineLimit(1)
                    .modifier(TagFace(red: false))
            }
            .buttonStyle(.plain)
        }
        Button {
            Haptic.click()
            if blocking == card.id {
                blocking = nil
                Task { await club.block(author) }
            } else { blocking = card.id }
        } label: {
            Label(blocking == card.id ? "Block \(card.name)? Tap again" : "Block", systemImage: "hand.raised")
                .font(tw(13)).foregroundStyle(blocking == card.id ? ClubArt.red : KitArt.ink.opacity(0.7))
                .lineLimit(2)
                .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The archive card in the column's pocket: seal, name, line, and for
    /// someone else follow/write/block; for oneself the four figures and the week.
    private func archiveCard(_ card: Community.AuthorCard, width: CGFloat) -> some View {
        let own = card.id == club.me?.profile.id
        return VStack(alignment: .leading, spacing: 10) {
            ClubSeal(name: card.name, size: 56)
            Text(verbatim: card.name).font(tw(24).weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Rectangle().fill(KitArt.ink.opacity(0.2)).frame(height: 1)
            personLine(card)
            if own {
                figures.padding(.top, 4)
                weekRow
            } else {
                VStack(alignment: .leading, spacing: 6) { personActions(card) }.padding(.top, 4)
            }
        }
        .foregroundStyle(KitArt.ink)
        .padding(.horizontal, 14).padding(.top, 16)
        .padding(.bottom, 12 + InPocket.margin)
        .frame(width: width, alignment: .topLeading)
        .background(Image(uiImage: ClubArt.archive).resizable()
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1))
        .modifier(InPocket())
    }

    /// The outer screen's person row, under the back tab.
    private func personRow(_ card: Community.AuthorCard, width: CGFloat) -> some View {
        let own = card.id == club.me?.profile.id
        return HStack(alignment: .center, spacing: 12) {
            ClubSeal(name: card.name, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: card.name).font(tw(20).weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
                personLine(card)
            }
            Spacer(minLength: 0)
            if own {
                figures
            } else {
                HStack(spacing: 8) { personActions(card) }
            }
        }
        .foregroundStyle(KitArt.ink)
        .padding(12)
        .frame(width: width, alignment: .leading)
        .background(Image(uiImage: ClubArt.archive).resizable().shadow(color: .black.opacity(0.3), radius: 2, y: 1))
    }
}

/// A length of positive film pulled out of a slit cut in the leather on the
/// left and pushed into one on the right (user 11/27): each frame is one
/// entry's picture (a theme, or this week's picks). Every five seconds it is
/// pulled one frame to the right by hand — a little slack taken up, a tug, a
/// catch, a second tug, a stop — until a finger moves it; drags settle on a
/// frame; a tap on the middle frame opens it. The film lies on the leather
/// and dives into each cut, shaded where it goes down; it is narrower than
/// the cuts. Art: GPT's frame unit (its window clear) repeated, the stitched
/// slit, and a light-fogged blank for a frame with no picture
/// (design/community/a-polish, a-polish2).
struct ThemeFilm: View {
    struct Frame {
        let url: URL?
        let title: String
        /// The edge print under the frame ("1A", or "★" for the picks).
        let code: String
    }
    let frames: [Frame]
    @Binding var pos: CGFloat
    @Binding var touched: Bool
    let width: CGFloat
    let height: CGFloat
    var open: (Int) -> Void
    @State private var base: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let frameArt = UIImage(named: "club_filmframe") ?? UIImage()
    static let slitArt = UIImage(named: "club_filmslit") ?? UIImage()
    static let fogArt = UIImage(named: "club_filmfog") ?? UIImage()
    /// The frame unit's shape and its clear window, as parts of it.
    static let aspect: CGFloat = 958 / 722
    static let window = CGRect(x: 0.0365, y: 0.1717, width: 0.928, height: 0.658)
    static let slitAspect: CGFloat = 193 / 898
    /// The cut in the slit art, as parts of it (measured: x 81–111, y 96–797 of 193×898).
    static let cut = CGRect(x: 0.42, y: 0.107, width: 0.155, height: 0.78)
    /// How much of each neighbour shows beside the middle frame.
    static let sliver: CGFloat = 7
    /// Snapshots and renders: the film stays on the chosen frame.
    static let still = UserDefaults.standard.object(forKey: "snap") != nil || UserDefaults.standard.object(forKey: "render") != nil

    /// The entry at a film position, for n entries (the film runs round).
    static func index(_ pos: CGFloat, _ n: Int) -> Int {
        guard n > 0 else { return 0 }
        let k = Int(pos.rounded()) % n
        return k < 0 ? k + n : k
    }

    /// The film's height for a box: as big as the width allows with the middle
    /// frame whole between the cuts and a sliver of each neighbour, and no
    /// taller than the cuts the box can hold (they are a little taller than the film).
    static func filmHeight(width: CGFloat, height: CGFloat) -> CGFloat {
        // u + 2·sliver = width − 2·(cut's inner edge from the slit's outer edge), slit = (h + 6)/cut.height tall.
        let k = slitAspect / cut.height * cut.maxX * 2
        let byWidth = (width - 6 * k - 2 * sliver) / (aspect + k)
        let byHeight = height * cut.height - 6
        return floor(max(20, min(byWidth, byHeight)))
    }

    var body: some View {
        let n = frames.count
        let h = Self.filmHeight(width: width, height: height)
        let u = h * Self.aspect
        let slitH = ceil((h + 6) / Self.cut.height), slitW = slitH * Self.slitAspect
        let mid = width / 2, cy = height / 2
        // The film shows from one cut's middle to the other's; it darkens as it goes down.
        let inner = slitW * Self.cut.maxX, centre = slitW * Self.cut.midX
        let first = Int(pos.rounded(.down)) - 2
        ZStack(alignment: .topLeading) {
            slit.frame(width: slitW, height: slitH).offset(y: cy - slitH / 2)
            slit.frame(width: slitW, height: slitH).offset(x: width - slitW, y: cy - slitH / 2)
            ZStack(alignment: .topLeading) {
                if n > 0 {
                    ForEach(first...(first + 4), id: \.self) { k in
                        let i = ((k % n) + n) % n
                        frame(frames[i], h: h, u: u)
                            .position(x: mid + (pos - CGFloat(k)) * u, y: cy)
                    }
                }
            }
            .frame(width: width, height: height)
            // Going down into the cuts: the film's ends in shadow.
            .overlay {
                HStack(spacing: 0) {
                    LinearGradient(colors: [.black.opacity(0.9), .black.opacity(0)], startPoint: .leading, endPoint: .trailing)
                        .frame(width: inner - centre + 6)
                    Spacer(minLength: 0)
                    LinearGradient(colors: [.black.opacity(0), .black.opacity(0.9)], startPoint: .leading, endPoint: .trailing)
                        .frame(width: inner - centre + 6)
                }
                .padding(.horizontal, centre)
                .frame(height: h)
                .allowsHitTesting(false)
            }
            .mask(Rectangle().frame(width: width - centre * 2, height: h + 2))
            // Lying on the leather: a little shadow under its edges.
            .shadow(color: .black.opacity(0.45), radius: 1.2, y: 1)
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 6)
            .onChanged { v in
                if base == nil { base = pos; touched = true }
                pos = (base ?? pos) + v.translation.width / u
            }
            .onEnded { v in
                let from = base ?? pos
                let to = (from + v.predictedEndTranslation.width / u).rounded()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.92)) { pos = min(max(to, from - 3), from + 3) }
                base = nil
                Haptic.click()
            })
        .onTapGesture { if n > 0 { Haptic.click(); open(Self.index(pos, n)) } }
        // Pulled one frame every five seconds while no one has touched it.
        .task(id: touched) {
            guard !touched, !reduceMotion, n > 1, !Self.still else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, !touched else { return }
                await pull()
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: n > 0 ? frames[Self.index(pos, n)].title : ""))
        .accessibilityAddTraits(.isButton)
        .accessibilityAdjustableAction { d in
            touched = true
            withAnimation { pos = pos.rounded() + (d == .increment ? 1 : -1) }
        }
        .accessibilityIdentifier("club-strip")
    }

    /// One pull by hand: the slack taken up, a quick tug, the film catching on
    /// the cut for a moment, a second shorter tug, and it stops just past and settles back.
    private func pull() async {
        let start = pos.rounded()
        let steps: [(to: CGFloat, animation: Animation, wait: Double)] = [
            (-0.035, .easeOut(duration: 0.12), 0.12),
            (0.62, .timingCurve(0.55, 0, 0.75, 0.9, duration: 0.24), 0.24),
            (0.66, .easeOut(duration: 0.14), 0.14),
            (1.025, .timingCurve(0.5, 0, 0.3, 1, duration: 0.3), 0.3),
            (1.0, .spring(response: 0.22, dampingFraction: 0.7), 0.25),
        ]
        for step in steps {
            guard !Task.isCancelled, !touched else { return }
            withAnimation(step.animation) { pos = start + step.to }
            try? await Task.sleep(for: .seconds(step.wait))
        }
    }

    private var slit: some View {
        Image(uiImage: Self.slitArt).resizable()
            .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
            .accessibilityHidden(true)
    }

    /// One frame: the picture (or the fogged blank) behind the unit's clear
    /// window, the frame's code on its edge.
    private func frame(_ f: Frame, h: CGFloat, u: CGFloat) -> some View {
        let w = Self.window
        return ZStack(alignment: .topLeading) {
            Group {
                if let url = f.url { PostPicture(url: url) } else { Image(uiImage: Self.fogArt).resizable() }
            }
            .frame(width: u * w.width + 2, height: h * w.height + 2)
            .clipped()
            .offset(x: u * w.minX - 1, y: h * w.minY - 1)
            Image(uiImage: Self.frameArt).resizable().frame(width: u, height: h)
            Text(verbatim: f.code)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(red: 0.93, green: 0.5, blue: 0.16))
                .offset(x: u * 0.72, y: h * (1 - w.minY / 2) - 8)
        }
        .frame(width: u, height: h)
    }
}
