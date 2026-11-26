import Photos
import SwiftUI

/// The camera bag on an iPhone that doesn't fold, held upright: one page at a
/// time, filling the screen. Films is laid out for the upright phone
/// (`UprightFilms`); the community and the settings keep the landscape pair
/// they have always had, shown across the phone as before, until their own
/// upright pages are made. The bag does not turn with the hold.
struct UprightBag: View {
    @EnvironmentObject private var model: CameraModel
    let size: CGSize
    @State private var page: Spread
    /// What is on the card survives a visit to the other pages.
    @State private var looking: Film?
    @State private var lookingAll = false
    private let start: CameraModel.BagOpening

    init(start: CameraModel.BagOpening, size: CGSize) {
        self.start = start
        self.size = size
        _page = State(initialValue: start.spread)
    }

    var body: some View {
        Group {
            if page == .films {
                UprightFilms(start: start, size: size, looking: $looking, lookingAll: $lookingAll) { page = $0 }
            } else {
                FixedToPhone(wide: true, turnOnGlass: FoldLayout.bodyTurnOnGlass) {
                    RollLibrary(start: CameraModel.BagOpening(spread: page, look: nil), showsClasp: true,
                                portraitFilms: { page = .films })
                        .environmentObject(model)
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .transition(.opacity)
    }
}

/// What a roll's tag and card say, and the one action they lead to (the
/// same words and rules as the landscape bag's tags and card).
@MainActor enum RollStatus {
    static func tag(_ roll: Film, model: CameraModel, store: FilmStore) -> Text {
        if roll == model.film { return Text("In camera") }
        if roll == model.readyToLoad { return Text("Next roll") }
        if store.awaitingApproval.contains(FilmStore.productID(roll)) { return Text("Awaiting approval") }
        if roll.free == true { return Text("Free") }
        if store.owns(roll) { return Text("Yours") }
        if store.isFreeToday(roll) { return Text("Free\ntoday") }
        if roll.isLimited { return Text("Not for sale") }
        if store.trialsLeft(roll) > 0 { return Text("Try \(store.trialsLeft(roll))") }
        if let price = store.price(roll) { return Text(verbatim: price) }
        return Text(verbatim: "—")
    }

    static func ink(_ roll: Film, model: CameraModel, store: FilmStore) -> Tag.Ink {
        if roll == model.readyToLoad || (store.isFreeToday(roll) && !store.owns(roll)) { return .red }
        if roll == model.film { return .muted }
        if !store.isUnlocked(roll) && store.trialsLeft(roll) == 0 { return .price }
        return .pencil
    }

    /// The card's action line.
    static func action(_ film: Film, model: CameraModel, store: FilmStore) -> Text {
        let waiting = store.awaitingApproval.contains(FilmStore.productID(film))
        if waiting { return Text("Purchase waiting for approval") }
        if film == model.film, !store.isUnlocked(film), store.trialsLeft(film) == 0 {
            if let price = store.price(film) { return Text("Free shots used up · buy \(price) →") }
            return Text("Free shots used up · choose another roll")
        }
        if film == model.film { return Text("In the camera") }
        if film == model.readyToLoad { return Text("Load this roll →") }
        if store.isFreeToday(film) && !store.owns(film) { return Text("Free today, as many shots as you like · load it →") }
        if store.isUnlocked(film) { return Text("Load this roll →") }
        if film == store.dailyFreeYesterday, store.trialsLeft(film) == 0, let price = store.price(film) { return Text("Yesterday’s free roll · keep it for \(price) →") }
        if film.isLimited, let days = film.earnDays { return Text("Earn it in the Community · \(days) days →") }
        if store.trialsLeft(film) > 0 { return Text("Try it · \(store.trialsLeft(film)) free shots →") }
        if let price = store.price(film) { return Text("Buy \(price) →") }
        return Text("Prices couldn't be loaded. Check the connection and tap to try again.")
    }

    /// Buying it outright is offered next to "try" and "free today" too.
    static func buyOutright(_ film: Film, store: FilmStore) -> String? {
        if store.awaitingApproval.contains(FilmStore.productID(film)) { return nil }
        if store.isFreeToday(film), !store.owns(film) { return store.price(film) }
        guard !store.isUnlocked(film), store.trialsLeft(film) > 0 else { return nil }
        return store.price(film)
    }
}

/// The films page: a cream card for the roll being looked at on top, its
/// samples across the full width under it, then the rolls three to a row, each
/// in its velvet cradle with its paper tag, scrolling; the long brass window at
/// the foot. Tapping a roll swaps the card; buying, trying and loading happen
/// on the card.
struct UprightFilms: View {
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared
    @ObservedObject private var language = AppLanguage.shared
    let start: CameraModel.BagOpening
    let size: CGSize
    @Binding var looking: Film?
    @Binding var lookingAll: Bool
    let goPage: (Spread) -> Void

    @State private var viewing: RollLibrary.Viewing?
    @State private var own: OwnPhoto?
    @ObservedObject private var shots = ShotLog.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var access = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    /// The user's pictures on this roll that are still in Photos.
    @State private var shown: [String] = []

    private static let ink = Color(red: 0.16, green: 0.13, blue: 0.10)
    private static let muted = Color(red: 0.42, green: 0.39, blue: 0.34)
    private static let red = Color(red: 0.72, green: 0.12, blue: 0.10)

    /// The card's paper with its two leather corners, cut from the bag's
    /// picture; stretched between the corners so they keep their shape.
    static let cardPaper: UIImage = {
        let cut = RollLibrary.crop(CGRect(x: 796, y: 58, width: 596, height: 214))
        guard let cg = cut.cgImage else { return cut }
        let at2x = UIImage(cgImage: cg, scale: 2, orientation: .up)
        return at2x.resizableImage(withCapInsets: UIEdgeInsets(top: 36, left: 40, bottom: 20, right: 40), resizingMode: .stretch)
    }()
    static let velvet: UIImage = {
        guard let cg = RollLibrary.velvet.cgImage else { return RollLibrary.velvet }
        return UIImage(cgImage: cg, scale: 3, orientation: .up)
    }()

    private var film: Film { looking ?? start.look ?? model.readyToLoad ?? model.film ?? model.films[0] }
    private var tall: Bool { size.height / size.width > 2.0 }
    private var topInset: CGFloat { tall ? 59 : 20 }
    private var bottomInset: CGFloat { tall ? 30 : 6 }
    /// The sample strip gives way on short screens (an SE).
    private var showsStrip: Bool { size.height >= 740 }
    private var pad: CGFloat { 12 }

    var body: some View {
        ZStack {
            Image(uiImage: Self.velvet).resizable(resizingMode: .tile).ignoresSafeArea()
            VStack(spacing: 8) {
                card
                if showsStrip { strip }
                rolls
                dial
            }
            .padding(.horizontal, pad)
            .padding(.top, topInset + 4)
            .padding(.bottom, bottomInset)
            .frame(width: size.width, height: size.height)
            if let viewing {
                PictureViewer(viewing: viewing, assets: [], close: { self.viewing = nil })
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity)
            }
            if let own {
                OwnPhotoViewer(photo: own) { self.own = nil }
                    .frame(width: size.width, height: size.height)
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(.easeInOut(duration: 0.2), value: viewing)
        .onAppear(perform: refresh)
        .onChange(of: film) { _, _ in refresh() }
        .onChange(of: shots.assets(for: film.id)) { _, _ in refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        .accessibilityIdentifier("upright-films")
    }

    // MARK: The card

    @ViewBuilder private var card: some View {
        let note = FilmNotes.all[film.id]
        HStack(alignment: .top, spacing: 12) {
            Group {
                if lookingAll { Image(uiImage: RollLibrary.allFilmsRoll).resizable().scaledToFit() }
                else { Canister(film: film) }
            }
            .frame(width: 44, height: 78)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1.5)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(lookingAll ? String(ui: "All films") : film.name)
                        .font(.custom("American Typewriter", size: 24).weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Spacer(minLength: 6)
                    if !lookingAll { Text(verbatim: "ISO \(film.iso)").font(.custom("American Typewriter", size: 15)) }
                }
                if lookingAll {
                    Text("Every film for sale, yours to keep")
                        .font(.custom("American Typewriter", size: 15).weight(.semibold))
                } else if let note {
                    Text(note.tagline).font(.custom("American Typewriter", size: 15).weight(.semibold))
                }
                Button(action: act) {
                    (lookingAll ? allAction : RollStatus.action(film, model: model, store: store))
                        .font(.custom("Marker Felt", size: 18))
                        .foregroundStyle(lookingAll && store.ownsAll ? Self.muted : Self.red)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("card-action")
                if !lookingAll, let price = RollStatus.buyOutright(film, store: store) {
                    Button {
                        let roll = film
                        Task { if await store.buy(roll) { Haptic.stop(); model.chooseInLibrary(roll); closeSoon() } }
                    } label: {
                        Text("or buy it · \(price)")
                            .font(.custom("American Typewriter", size: 15).weight(.semibold)).underline()
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(store.purchasing != nil)
                }
                if !showsStrip { samplesLine }
            }
        }
        .foregroundStyle(Self.ink)
        .padding(.leading, 34).padding(.trailing, 34).padding(.top, 22).padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Image(uiImage: Self.cardPaper).resizable())
        .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
    }

    /// On a short screen the strip is gone: one line on the card opens the samples.
    @ViewBuilder private var samplesLine: some View {
        let samples = lookingAll ? [] : (FilmNotes.all[film.id]?.samples ?? [])
        HStack(spacing: 6) {
            if !samples.isEmpty {
                Button { viewing = RollLibrary.Viewing(film: film, index: shown.isEmpty ? -1 : 0, assets: shown) } label: {
                    Text("\(film.name) samples · AI originals, film rendered by Koco")
                        .font(.custom("American Typewriter", size: 13))
                        .foregroundStyle(Self.muted)
                        .lineLimit(2).minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if !lookingAll { trySlip }
        }
    }

    private var allAction: Text {
        if store.ownsAll { return Text("All yours") }
        if store.awaitingApproval.contains(FilmStore.allFilmsID) { return Text("Purchase waiting for approval") }
        if let price = store.allFilmsPrice { return Text("Buy all films · \(price) →") }
        return Text("Prices couldn't be loaded. Check the connection and tap to try again.")
    }

    // MARK: Samples

    /// The strip under the card, across the full width: swipe sideways, tap for
    /// the large view. The user's own pictures on this roll first (when Photos
    /// lets us), then the roll's samples (for the all-films roll, one of each
    /// film); "Try my photo" at its head.
    private var strip: some View {
        let samples: [(film: Film, index: Int, sample: FilmNote.Sample)] = lookingAll
            ? model.films.compactMap { f in FilmNotes.all[f.id]?.samples.first.map { (f, 0, $0) } }
            : (FilmNotes.all[film.id]?.samples ?? []).enumerated().map { (film, $0.offset, $0.element) }
        let own = lookingAll ? [] : shown
        let assets = lookingAll ? [] : shots.assets(for: film.id)
        return VStack(spacing: 2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if !lookingAll { trySlip.frame(width: 132, height: 88) }
                    if !assets.isEmpty, !canRead {
                        Button(action: askPhotos) {
                            (access == .notDetermined ? Text("Tap here to let Koco see your pictures") : Text("Allow Photos in Settings to see them"))
                                .font(.custom("American Typewriter", size: 13)).foregroundStyle(Self.ink)
                                .multilineTextAlignment(.center).padding(8)
                                .frame(width: 132, height: 88)
                                .background(Image(uiImage: Self.cardPaper).resizable())
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(Array(own.enumerated()), id: \.offset) { i, id in
                        AssetThumbnail(id: id)
                            .frame(width: 132, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                            .onTapGesture { viewing = RollLibrary.Viewing(film: film, index: i, assets: own) }
                            .accessibilityElement()
                            .accessibilityIdentifier("album-photo")
                            .accessibilityAddTraits([.isButton, .isImage])
                    }
                    ForEach(Array(samples.enumerated()), id: \.offset) { _, item in
                        SampleThumb(film: item.film, sample: item.sample)
                            .frame(width: 132, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                Image(uiImage: RollLibrary.pocketImages[0]).resizable()
                                    .blendMode(.screen).opacity(0.4).allowsHitTesting(false)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if lookingAll { look(item.film) }
                                else { viewing = RollLibrary.Viewing(film: item.film, index: -1 - item.index, assets: []) }
                            }
                            .accessibilityElement()
                            .accessibilityLabel(Text(verbatim: item.film.name))
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 88)
            // Where the pictures come from, said plainly.
            (lookingAll ? Text("One sample from each film · AI originals, film rendered by Koco · tap one to look at that film")
                            : Text("\(film.name) samples · AI originals, film rendered by Koco"))
                .font(.custom("American Typewriter", size: 11)).foregroundStyle(Color(white: 0.62))
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private var canRead: Bool { access == .authorized || access == .limited }

    /// "Try my photo": the kraft slip from the landscape bag, in a box of its own size.
    private var trySlip: some View {
        let r = TryMyPhotoSlip.place, k: CGFloat = 0.62
        let lift = max(0, 44 - r.height * k) / 2
        return ZStack(alignment: .topLeading) {
            TryMyPhotoSlip(film: film, s: k) { own = $0 }
                .offset(x: -r.minX * k, y: -(r.minY * k - lift))
        }
        .frame(width: r.width * k, height: max(44, r.height * k), alignment: .topLeading)
    }

    private func askPhotos() {
        if access == .notDetermined {
            Task { access = await PHPhotoLibrary.requestAuthorization(for: .readWrite); refresh() }
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func refresh() {
        access = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let assets = shots.assets(for: film.id)
        guard canRead, !assets.isEmpty else { shown = []; return }
        var present = Set<String>()
        PHAsset.fetchAssets(withLocalIdentifiers: assets, options: nil).enumerateObjects { a, _, _ in present.insert(a.localIdentifier) }
        shown = assets.filter(present.contains)
    }

    // MARK: Rolls

    private var rolls: some View {
        let gap: CGFloat = 8
        let colW = (size.width - 2 * pad - 2 * gap) / 3
        let columns = Array(repeating: GridItem(.fixed(colW), spacing: gap), count: 3)
        return ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 6) {
                RollCell(width: colW, roll: nil, looked: lookingAll) { lookAll() }
                ForEach(model.films) { roll in
                    RollCell(width: colW, roll: roll, looked: !lookingAll && roll == film) { look(roll) }
                }
            }
            .padding(.top, 6).padding(.bottom, 10)
        }
        .overlay(alignment: .top) {
            LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 10).allowsHitTesting(false)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: The window

    private var dial: some View {
        let w = size.width - 2 * pad
        let s = w / PageDial.rect.width
        let h = w * PageDial.window.size.height / max(PageDial.window.size.width, 1)
        return PageDial(spread: .films, s: s, choose: { goPage($0) }, camera: { goCamera() },
                        placed: false, labelSize: 15)
            .frame(width: w, height: h, alignment: .topLeading)
            .frame(height: max(h, 44))
    }

    // MARK: Actions

    private func look(_ roll: Film) {
        guard roll != film || lookingAll else { Haptic.click(); return }
        looking = roll; lookingAll = false
        Haptic.click()
    }

    private func lookAll() {
        guard !lookingAll else { Haptic.click(); return }
        lookingAll = true
        Haptic.click()
    }

    private func goCamera() {
        Haptic.click()
        model.lookedAt = nil
        model.leaveBag()
    }

    /// A chosen roll goes straight in: the bag is put away (as on the outer
    /// screen of a Duo).
    private func closeSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard model.bag != nil, model.readyToLoad != nil else { return }
            model.closeBag()
        }
    }

    /// The card's one action: choose the roll (and put the bag away), earn it,
    /// or buy it when there is nothing left to try.
    private func act() {
        if lookingAll {
            guard !store.ownsAll else { Haptic.click(); return }
            if store.allFilmsPrice == nil { Task { await store.loadProductsIfMissing(force: true) } }
            else { Task { if await store.buy(nil) { Haptic.stop() } } }
            return
        }
        let roll = film
        let canShoot = store.isUnlocked(roll) || store.trialsLeft(roll) > 0
        if roll == model.film, canShoot || store.awaitingApproval.contains(FilmStore.productID(roll)) { Haptic.click(); return }
        if roll == model.readyToLoad || canShoot {
            model.chooseInLibrary(roll)
            closeSoon()
        } else if roll.isLimited {
            goPage(.club)   // earned there, never sold
        } else if store.price(roll) != nil {
            Task { if await store.buy(roll) { Haptic.stop(); model.chooseInLibrary(roll); closeSoon() } }
        } else {
            Task { await store.loadProductsIfMissing(force: true) }
        }
    }
}

/// One roll in its velvet cradle with its paper tag below. The whole cell is
/// the touch target (it looks at the roll; the card does the rest).
private struct RollCell: View {
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared
    let width: CGFloat
    /// nil: the all-films roll.
    let roll: Film?
    let looked: Bool
    let tap: () -> Void

    var body: some View {
        let f = width / 254                       // the rim picture is 254 × 142 (cradle 234 × 122 and a 10 px margin)
        let cradle = CGRect(x: 10 * f, y: 10 * f, width: 234 * f, height: 122 * f)
        let tagW = width * 0.33, tagH = tagW * 94 / 58
        let tagTop = 142 * f - 18 * f
        Button(action: tap) {
            ZStack(alignment: .topLeading) {
                picture
                    .frame(width: cradle.height, height: cradle.width)
                    .rotationEffect(.degrees(-90))
                    .frame(width: cradle.width, height: cradle.height)
                    .overlay {
                        LinearGradient(stops: [.init(color: .black.opacity(0.55), location: 0),
                                               .init(color: .clear, location: 0.28),
                                               .init(color: .clear, location: 0.72),
                                               .init(color: .black.opacity(0.6), location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                    .offset(x: cradle.minX, y: cradle.minY)
                // The velvet rim over the roll's edge: held in.
                Image(uiImage: RollLibrary.rims[0]).resizable()
                    .frame(width: width, height: 142 * f)
                    .mask {
                        let o = RollLibrary.opening
                        Rectangle().overlay(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 22 * f)
                                .frame(width: cradle.width - (o.left + o.right) * f, height: cradle.height - (o.top + o.bottom) * f)
                                .offset(x: 10 * f + o.left * f, y: 10 * f + o.top * f)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }
                if looked {
                    RoundedRectangle(cornerRadius: 22 * f).stroke(Color(red: 0.86, green: 0.2, blue: 0.14), lineWidth: 2)
                        .frame(width: cradle.width - 2, height: cradle.height - 2)
                        .offset(x: cradle.minX + 1, y: cradle.minY + 1)
                }
                Image(uiImage: RollLibrary.tagPictures[0]).resizable()
                    .frame(width: tagW, height: tagH)
                    .overlay {
                        tagText
                            .font(.custom("Marker Felt", size: 14))
                            .foregroundStyle(tagColor)
                            .multilineTextAlignment(.center)
                            .lineLimit(2).minimumScaleFactor(0.5)
                            .padding(.horizontal, 3).padding(.top, tagH * 0.3)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1.5)
                    .offset(x: (width - tagW) / 2, y: tagTop)
            }
            .frame(width: width, height: tagTop + tagH, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: roll?.name ?? String(ui: "All films")))
        .accessibilityAddTraits(looked ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var picture: some View {
        if let roll { Canister(film: roll, fill: true) } else { Image(uiImage: RollLibrary.allFilmsRoll).resizable() }
    }

    private var tagText: Text {
        guard let roll else {
            if store.ownsAll { return Text("All yours") }
            if let price = store.allFilmsPrice { return Text(verbatim: price) }
            return Text(verbatim: "—")
        }
        return RollStatus.tag(roll, model: model, store: store)
    }

    private var tagColor: Color {
        guard let roll else { return store.ownsAll ? Color(red: 0.42, green: 0.39, blue: 0.34) : Color(red: 0.12, green: 0.25, blue: 0.55) }
        switch RollStatus.ink(roll, model: model, store: store) {
        case .pencil: return Color(red: 0.18, green: 0.17, blue: 0.16)
        case .red: return Color(red: 0.72, green: 0.12, blue: 0.10)
        case .muted: return Color(red: 0.42, green: 0.39, blue: 0.34)
        case .price: return Color(red: 0.12, green: 0.25, blue: 0.55)
        }
    }
}
