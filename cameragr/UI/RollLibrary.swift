import Photos
import SwiftUI

/// The phone open flat, held like a book: the camera bag, opened. The fold
/// of the phone is the fold of the bag's lid. On the left, the bag's black
/// velvet lining: every roll lying snug in its own cradle, a paper tag at its
/// side saying where it stands (in the camera, yours, trial shots left, or its
/// price); the cradle of the roll in the camera is empty. The tenth cradle
/// holds the all-films roll, one price for every film. On the right, the
/// inside of the lid: a card about the roll being looked at, and a clear photo
/// sleeve holding the pictures taken on it, or, for a roll not shot yet, its
/// samples.
///
/// Tap a roll to look at it (it lifts out of its cradle). Tap its tag to use
/// it: choose it as the next roll (it goes in when the phone is closed), try
/// it, or buy it. Tap a picture to see it on the whole screen. The store is
/// this bag: nothing else needs opening.
///
/// The bag is one picture (GPT, `library_bag.jpg`, from
/// `design/library/bag/bag_velvet_template.png`); rolls, writing and pictures
/// are placed at rectangles measured on it, in its pixels (1456×1024). The
/// velvet rim of each cradle is drawn again over its roll, cut from the same
/// picture, so the roll sits held in the velvet.
struct RollLibrary: View {
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared
    @ObservedObject private var shots = ShotLog.shared
    /// The roll being looked at (not the loaded one, not the chosen one).
    @State private var looking: Film?
    /// Looking at the all-films roll instead of a film.
    @State private var lookingAll = false
    /// A picture shown on the whole screen.
    @State private var viewing: Viewing?

    /// What is open on the whole screen: the pictures as the sleeve showed
    /// them (the same list, so a tap opens the picture tapped), or a sample (index < 0).
    struct Viewing: Equatable { let film: Film; let index: Int; let assets: [String] }

    static let art = CGSize(width: 1456, height: 1024)
    static let bag = UIImage(named: "library_bag.jpg") ?? UIImage()
    /// Read off the picture (design/library/bag/bag_fit_v1.png, less 40 px cut
    /// from its left; template bag_fit_template.png). The picture is the inner
    /// screen's own shape with its 55 pt corners, and nothing live comes near
    /// the corners or the hinge. Ten velvet cradles, two columns of five, each
    /// the size of a roll lying on its side; the tenth holds the all-films roll.
    static let rowsY: [CGFloat] = [72, 254, 436, 618, 800]
    static let cradles: [CGRect] = [CGFloat(50), 370].flatMap { x in
        rowsY.map { y in CGRect(x: x, y: y, width: 234, height: 122) }
    }
    /// Where each roll lies: the whole cradle, so the velvet lip laid back over
    /// it holds its top and bottom edges.
    static let places: [CGRect] = cradles
    /// The cradle's opening inside the velvet lip (measured): this much of the
    /// roll shows; the rest is under the lip.
    static let opening = UIEdgeInsets(top: 11, left: 3, bottom: 10, right: 3)
    static let tags: [CGRect] = [CGFloat(298), 621].flatMap { x in
        rowsY.map { y in CGRect(x: x, y: y + 19, width: 58, height: 94) }
    }
    /// The velvet round each cradle, cut from the picture to lay back over the
    /// roll's edges.
    static let rims: [UIImage] = cradles.map { crop($0.insetBy(dx: -10, dy: -10)) }
    static let allFilmsRoll = UIImage(named: "roll_allfilms") ?? UIImage()
    /// The red cloth tab clipped on the cradle of the next roll (GPT).
    static let ribbon = UIImage(named: "next_ribbon") ?? UIImage()
    /// The blank band pressed into the velvet under the cradles: how to use the bag.
    static let hint = CGRect(x: 120, y: 946, width: 490, height: 34)
    /// The card under the leather corners, the six pockets of the sleeve, and
    /// the paper tab under the sleeve.
    static let card = CGRect(x: 790, y: 56, width: 616, height: 224)
    static let pockets: [CGRect] = [CGFloat(314), 521, 728].flatMap { y in
        [CGFloat(798), 1105].map { x in CGRect(x: x, y: y, width: 293, height: 193) }
    }
    static let pageTab = CGRect(x: 1050, y: 936, width: 96, height: 40)
    static let pocketImages: [UIImage] = pockets.map { crop($0) }

    static func crop(_ r: CGRect) -> UIImage {
        guard let cg = bag.cgImage?.cropping(to: r) else { return UIImage() }
        return UIImage(cgImage: cg)
    }

    var body: some View {
        GeometryReader { geo in
            // Held like a book: the bag is landscape. An upright window (the
            // interface kept upright by rotation lock) gets it turned a quarter.
            let upright = geo.size.height > geo.size.width
            let canvas = upright ? CGSize(width: geo.size.height, height: geo.size.width) : geo.size
            // The inner screen is the picture's own shape; elsewhere it fits
            // whole, centred, never cut.
            let s = min(canvas.width / Self.art.width, canvas.height / Self.art.height)
            let shift = CGSize(width: (canvas.width - Self.art.width * s) / 2,
                               height: (canvas.height - Self.art.height * s) / 2)
            let film = looking ?? model.film ?? model.films[0]
            ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                Image(uiImage: Self.bag).resizable()
                    .frame(width: Self.art.width * s, height: Self.art.height * s)
                ForEach(Array(model.films.prefix(9).enumerated()), id: \.element.id) { i, roll in
                    loop(i, roll: roll, looked: roll == film && !lookingAll, s: s)
                }
                allFilmsLoop(s: s)
                hintLine(s: s)
                if lookingAll {
                    AllFilmsCard(s: s) { buyAll() }
                    AllFilmsSleeve(films: Array(model.films.prefix(9)), s: s) { roll in
                        looking = roll; lookingAll = false; Haptic.click()
                    }
                } else {
                    FilmCard(film: film, s: s) { useTag(film) }
                    PhotoSleeve(film: film, assets: shots.assets(for: film.id), s: s) { index, shown in
                        viewing = Viewing(film: film, index: index, assets: shown)
                    }
                }
            }
            .offset(shift)
            .overlay {
                if let viewing {
                    PictureViewer(viewing: viewing, assets: viewing.assets) { self.viewing = nil }
                        .frame(width: canvas.width, height: canvas.height)
                        .transition(.opacity)
                }
            }
            .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
            .clipped()
            }
            .frame(width: canvas.width, height: canvas.height)
            .rotationEffect(.degrees(upright ? -90 : 0))
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .animation(.easeInOut(duration: 0.2), value: viewing)
        }
        .background(Color.black)
        #if DEBUG
        // `-look <film id>`: start looking at that roll (for checks).
        .onAppear {
            if let id = UserDefaults.standard.string(forKey: "look") {
                if id == "all" { lookingAll = true } else { looking = model.films.first { $0.id == id } }
            }
            // `-next <film id>`: that roll chosen as the next one (for checks).
            if let id = UserDefaults.standard.string(forKey: "next"), let roll = model.films.first(where: { $0.id == id }) {
                Task { try? await Task.sleep(for: .seconds(2)); model.chooseInLibrary(roll) }
            }
        }
        // `-demoShots 1`: files the library's newest photos under the loaded
        // roll, so the sleeve can be checked in the simulator.
        .onAppear {
            guard UserDefaults.standard.bool(forKey: "demoShots"), let film = model.film,
                  ShotLog.shared.assets(for: film.id).isEmpty else { return }
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = 14
            PHAsset.fetchAssets(with: .image, options: options).enumerateObjects { asset, _, _ in
                ShotLog.shared.add(asset: asset.localIdentifier, film: film.id)
            }
        }
        #endif
    }

    // MARK: Loops

    /// A roll lying in its cradle, held by the velvet round it: the rim cut
    /// from the picture covers its edge, and the curve shades its top and
    /// bottom. Lifted out (looked at or chosen), it sits above the velvet.
    private func cradled(_ picture: some View, cradle i: Int, lifted: Bool, s: CGFloat) -> some View {
        let place = Self.places[i].scaled(s), cradle = Self.cradles[i].scaled(s)
        let pad = 10 * s
        return ZStack(alignment: .topLeading) {
            picture
                .frame(width: place.width, height: place.height)
                .overlay {
                    // The velvet curves round the roll: darker at top and bottom.
                    LinearGradient(stops: [.init(color: .black.opacity(lifted ? 0 : 0.55), location: 0),
                                           .init(color: .clear, location: 0.28),
                                           .init(color: .clear, location: 0.72),
                                           .init(color: .black.opacity(lifted ? 0 : 0.6), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(lifted ? 0.7 : 0), radius: 14 * s, x: 4 * s, y: 12 * s)
                .scaleEffect(lifted ? 1.05 : 1)
                .offset(x: place.minX, y: place.minY - (lifted ? 14 * s : 0))
            if !lifted {
                // The velvet rim over the roll's edge: no gap, held in.
                Image(uiImage: Self.rims[i]).resizable()
                    .frame(width: cradle.width + 2 * pad, height: cradle.height + 2 * pad)
                    .mask {
                        let o = Self.opening
                        Rectangle().overlay(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 22 * s)
                                .frame(width: cradle.width - (o.left + o.right) * s,
                                       height: cradle.height - (o.top + o.bottom) * s)
                                .offset(x: pad + o.left * s, y: pad + o.top * s)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }
                    .offset(x: cradle.minX - pad, y: cradle.minY - pad)
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: lifted)
    }

    /// One cradle: its roll (lifted while looked at) and its tag; the next
    /// roll carries a red cloth tab. Empty while the roll is in the camera.
    private func loop(_ i: Int, roll: Film, looked: Bool, s: CGFloat) -> some View {
        let cradle = Self.cradles[i].scaled(s), tag = Self.tags[i].scaled(s), place = Self.places[i].scaled(s)
        let inCamera = roll == model.film && model.arrivingRoll == nil
        let lifted = looked
        let next = roll == model.readyToLoad
        return ZStack(alignment: .topLeading) {
            if !inCamera {
                // Lying on its side, the name reading left to right.
                cradled(Canister(film: roll, fill: true)
                            .frame(width: place.height, height: place.width)
                            .rotationEffect(.degrees(-90)),
                        cradle: i, lifted: lifted, s: s)
            }
            Color.clear.contentShape(Rectangle())
                .frame(width: cradle.width, height: cradle.height)
                .offset(x: cradle.minX, y: cradle.minY)
                .onTapGesture { looking = roll; lookingAll = false; Haptic.click() }
                .accessibilityElement()
                .accessibilityLabel(roll.name)
                .accessibilityValue(next ? Text("Next roll") : Text(verbatim: ""))
                .accessibilityAddTraits(.isButton)
            if next && !inCamera { nextRibbon(cradle: cradle, s: s) }
            Tag(text: Text(verbatim: roll.label + "\n") + tagText(roll), ink: tagInk(roll), size: tag.size) { useTag(roll) }
                .offset(x: tag.minX, y: tag.minY)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: next)
    }

    /// The red cloth tab clipped over the cradle's top lip, hanging down over
    /// the spool end of the roll: this one goes in when the phone is closed.
    private func nextRibbon(cradle: CGRect, s: CGFloat) -> some View {
        let w = 44 * s, h = w * Self.ribbon.size.height / max(Self.ribbon.size.width, 1)
        let word = String(localized: "Next").map(String.init).joined(separator: "\n")
        return Image(uiImage: Self.ribbon).resizable()
            .frame(width: w, height: h)
            .overlay(alignment: .center) {
                Text(verbatim: word)
                    .font(.custom("Marker Felt", size: 13 * s))
                    .foregroundStyle(Color(red: 0.98, green: 0.93, blue: 0.84))
                    .multilineTextAlignment(.center).lineSpacing(-2 * s)
                    .minimumScaleFactor(0.5)
                    .padding(.top, h * 0.12).padding(.bottom, h * 0.16)
            }
            .shadow(color: .black.opacity(0.6), radius: 3 * s, y: 2 * s)
            .offset(x: cradle.minX + 8 * s, y: cradle.minY - 12 * s)
            .transition(.move(edge: .top).combined(with: .opacity))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The tenth cradle: the all-films roll, one price for every film.
    private func allFilmsLoop(s: CGFloat) -> some View {
        let tag = Self.tags[9].scaled(s), place = Self.places[9].scaled(s)
        return ZStack(alignment: .topLeading) {
            cradled(Image(uiImage: Self.allFilmsRoll).resizable()
                        .frame(width: place.height, height: place.width)
                        .rotationEffect(.degrees(-90)),
                    cradle: 9, lifted: lookingAll, s: s)
                .onTapGesture { lookingAll = true; Haptic.click() }
                .accessibilityElement()
                .accessibilityLabel(Text("All films"))
                .accessibilityAddTraits(.isButton)
            Tag(text: allFilmsTag, ink: store.ownsAll ? .muted : .price, size: tag.size) { buyAll() }
                .offset(x: tag.minX, y: tag.minY)
        }
    }

    /// How to use the bag, pressed into the velvet.
    private func hintLine(s: CGFloat) -> some View {
        let r = Self.hint.scaled(s)
        return Text("Tap a roll to look · tap its tag to choose · close the phone to load it")
            .font(.custom("American Typewriter", size: 19 * s))
            .foregroundStyle(Color(white: 0.58))
            .shadow(color: .black.opacity(0.9), radius: 0, x: 0, y: -1 * s)
            .lineLimit(1).minimumScaleFactor(0.5)
            .padding(.horizontal, 16 * s)
            .frame(width: r.width, height: r.height)
            .offset(x: r.minX, y: r.minY)
            .allowsHitTesting(false)
    }

    private func buyAll() {
        guard !store.ownsAll else { Haptic.click(); return }
        if store.allFilmsPrice == nil {
            Task { await store.loadProductsIfMissing(force: true) }   // prices not loaded: try again
        } else {
            Task { if await store.buy(nil) { Haptic.stop() } }
        }
    }

    private var allFilmsTag: Text {
        if store.ownsAll { return Text("All yours") }
        if let price = store.allFilmsPrice { return Text("All films\n\(price)") }
        return Text("All films\nTry again")
    }

    // MARK: Tags

    /// What a roll's tag says.
    private func tagText(_ roll: Film) -> Text {
        if roll == model.film { return Text("In camera") }
        if roll == model.readyToLoad { return Text("Next roll") }
        if store.awaitingApproval.contains(FilmStore.productID(roll)) { return Text("Awaiting approval") }
        if roll.free == true { return Text("Free") }
        if store.isUnlocked(roll) { return Text("Yours") }
        if store.trialsLeft(roll) > 0 { return Text("Try \(store.trialsLeft(roll))") }
        if let price = store.price(roll) { return Text(verbatim: price) }
        return Text(verbatim: "—")
    }

    private func tagInk(_ roll: Film) -> Tag.Ink {
        if roll == model.readyToLoad { return .red }
        if roll == model.film { return .muted }
        if !store.isUnlocked(roll) && store.trialsLeft(roll) == 0 { return .price }
        return .pencil
    }

    /// The tag's one action: choose the roll as the next one (or take that
    /// back), or buy it when there is nothing left to try.
    private func useTag(_ roll: Film) {
        looking = roll
        lookingAll = false
        if roll == model.film { Haptic.click(); return }
        if roll == model.readyToLoad || store.isUnlocked(roll) || store.trialsLeft(roll) > 0 {
            model.chooseInLibrary(roll)
        } else if store.price(roll) != nil {
            Task { if await store.buy(roll) { model.chooseInLibrary(roll); Haptic.stop() } }
        } else {
            Task { await store.loadProductsIfMissing(force: true) }
        }
    }
}

extension CGRect {
    func scaled(_ s: CGFloat) -> CGRect { CGRect(x: minX * s, y: minY * s, width: width * s, height: height * s) }
}

/// The card in the lid: the roll being looked at, typed. Its last line is
/// what the tag does, and does the same on a tap.
private struct FilmCard: View {
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared
    let film: Film
    let s: CGFloat
    let use: () -> Void

    var body: some View {
        let r = RollLibrary.card.scaled(s)
        let note = FilmNotes.all[film.id]
        let ink = Color(red: 0.16, green: 0.13, blue: 0.10)
        VStack(alignment: .leading, spacing: 6 * s) {
            HStack(alignment: .firstTextBaseline) {
                Text(film.name).font(.custom("American Typewriter", size: 36 * s).weight(.semibold))
                Spacer(minLength: 8 * s)
                Text(verbatim: "ISO \(film.iso)").font(.custom("American Typewriter", size: 22 * s))
            }
            if let note {
                Text(note.tagline).font(.custom("American Typewriter", size: 22 * s).weight(.semibold))
                Text(note.about).font(.custom("American Typewriter", size: 18 * s))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: use) {
                action.font(.custom("Marker Felt", size: 25 * s))
                    .foregroundStyle(Color(red: 0.72, green: 0.12, blue: 0.10))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(ink)
        .lineLimit(2).minimumScaleFactor(0.6)
        // Clear of the leather corners at the top; the last line of the card
        // is the sleeve's note (see PhotoSleeve).
        .padding(.horizontal, 44 * s).padding(.top, 40 * s).padding(.bottom, 38 * s)
        .frame(width: r.width, height: r.height, alignment: .topLeading)
        .offset(x: r.minX, y: r.minY)
    }

    private var action: Text {
        if film == model.film { return Text("In the camera") }
        if film == model.readyToLoad { return Text("Close the phone to load it · tap to undo") }
        if store.awaitingApproval.contains(FilmStore.productID(film)) { return Text("Purchase waiting for approval") }
        if store.isUnlocked(film) { return Text("Load this roll →") }
        if store.trialsLeft(film) > 0 { return Text("Try it · \(store.trialsLeft(film)) free shots →") }
        if let price = store.price(film) { return Text("Buy \(price) →") }
        return Text("Prices couldn't be loaded. Check the connection and tap to try again.")
    }
}

/// A paper tag's writing, by hand.
private struct Tag: View {
    enum Ink { case pencil, red, muted, price }
    let text: Text
    let ink: Ink
    let size: CGSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            text
                .font(.custom("Marker Felt", size: size.width * 0.24))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.5)
                .padding(.horizontal, size.width * 0.06)
                .padding(.top, size.height * 0.28)        // under the tag's hole
                .frame(width: size.width, height: size.height)
                .rotationEffect(.degrees(-2))
        }
        .buttonStyle(.plain)
    }

    private var color: Color {
        switch ink {
        case .pencil: Color(red: 0.18, green: 0.17, blue: 0.16)
        case .red: Color(red: 0.72, green: 0.12, blue: 0.10)
        case .muted: Color(red: 0.42, green: 0.39, blue: 0.34)
        case .price: Color(red: 0.12, green: 0.25, blue: 0.55)
        }
    }
}

/// The clear sleeve in the lid: nine pockets, the roll's pictures newest
/// first (swipe for more), or its samples if it has none yet.
private struct PhotoSleeve: View {
    let film: Film
    let assets: [String]
    let s: CGFloat
    let open: (Int, [String]) -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var access = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var shown: [String] = []
    @State private var page = 0

    private var canRead: Bool { access == .authorized || access == .limited }
    private var samples: [FilmNote.Sample] { FilmNotes.all[film.id]?.samples ?? [] }
    /// No pictures of the user's on this roll: its samples instead.
    private var showsSamples: Bool { assets.isEmpty || !canRead || shown.isEmpty }

    var body: some View {
        let pockets = RollLibrary.pockets
        let pages = max(1, (shown.count + 5) / 6)
        let first = min(page, pages - 1) * 6
        ZStack(alignment: .topLeading) {
            ForEach(0..<pockets.count, id: \.self) { i in
                let r = pockets[i].scaled(s)
                Group {
                    if showsSamples {
                        if i < samples.count {
                            SampleThumb(film: film, sample: samples[i]).onTapGesture { open(-1 - i, []) }
                        }
                    } else if first + i < shown.count {
                        AssetThumbnail(id: shown[first + i]).onTapGesture { open(first + i, shown) }
                    }
                }
                .frame(width: r.width, height: r.height)
                .clipped()
                // The sleeve's shine over the picture, from the bag's own picture.
                .overlay {
                    Image(uiImage: RollLibrary.pocketImages[i]).resizable()
                        .blendMode(.screen).opacity(0.55).allowsHitTesting(false)
                }
                .offset(x: r.minX, y: r.minY)
            }
            note
            pageTab
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 30).onEnded { drag in
            guard !showsSamples, abs(drag.translation.width) > abs(drag.translation.height) else { return }
            let next = page + (drag.translation.width < 0 ? 1 : -1)
            if (0..<pages).contains(next) { withAnimation(.easeOut(duration: 0.2)) { page = next }; Haptic.click() }
        })
        .onAppear(perform: refresh)
        .onChange(of: assets) { _, _ in page = 0; refresh() }
        .onChange(of: film) { _, _ in page = 0; refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
    }

    /// One typed line at the foot of the card: whose pictures these are.
    @ViewBuilder private var note: some View {
        let card = RollLibrary.card.scaled(s)
        let text: Text = {
            if !assets.isEmpty && access == .notDetermined { return Text("Tap here to let Koco see your pictures") }
            if !assets.isEmpty && !canRead { return Text("Allow Photos in Settings to see them") }
            if showsSamples { return Text("\(film.name) samples · AI originals, film rendered by Koco") }
            return Text("\(film.name) · \(shown.count)")
        }()
        Button {
            if access == .notDetermined {
                Task { access = await PHPhotoLibrary.requestAuthorization(for: .readWrite); refresh() }
            } else if !canRead, let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        } label: {
            text.font(.custom("American Typewriter", size: 15 * s))
                .foregroundStyle(Color(red: 0.42, green: 0.39, blue: 0.34))
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: card.width - 88 * s, height: 26 * s, alignment: .leading)
        }
        .buttonStyle(.plain)
        .offset(x: card.minX + 44 * s, y: card.maxY - 34 * s)
    }

    /// The paper tab under the sleeve: which page, when there are several.
    @ViewBuilder private var pageTab: some View {
        let r = RollLibrary.pageTab.scaled(s)
        let pages = max(1, (shown.count + 5) / 6)
        if !showsSamples && pages > 1 {
            Text(verbatim: "\(min(page, pages - 1) + 1)/\(pages)")
                .font(.custom("Marker Felt", size: 20 * s))
                .foregroundStyle(Color(red: 0.18, green: 0.17, blue: 0.16))
                .frame(width: r.width, height: r.height)
                .offset(x: r.minX, y: r.minY)
                .allowsHitTesting(false)
        }
    }

    private func refresh() {
        access = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard canRead, !assets.isEmpty else { shown = []; return }
        let found = PHAsset.fetchAssets(withLocalIdentifiers: assets, options: nil)
        var present = Set<String>()
        found.enumerateObjects { asset, _, _ in present.insert(asset.localIdentifier) }
        // Missing pictures are only left out, never forgotten (hidden ones come back).
        shown = assets.filter(present.contains)
    }
}

/// A sample through its film, small, for a pocket.
private struct SampleThumb: View {
    let film: Film
    let sample: FilmNote.Sample
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
            if let image { Image(uiImage: image).resizable().scaledToFill() }
        }
        .task(id: film.id + sample.file) {
            let key = film.id + sample.file
            image = nil   // never the last roll's picture while this one renders
            guard let url = Bundle.main.url(forResource: sample.file, withExtension: "jpg"),
                  let full = CIImage(contentsOf: url) else { return }
            let small = full.transformed(by: CGAffineTransform(scaleX: 480 / full.extent.width, y: 480 / full.extent.width))
            let film = film, iso = sample.iso
            let rendered = await Task.detached(priority: .userInitiated) { FilmRendering.pair(small, film: film, iso: iso)?.after }.value
            // A late result for a roll looked at before is dropped.
            if !Task.isCancelled, key == self.film.id + self.sample.file { image = rendered }
        }
    }
}

/// A picture on the whole open screen. The user's own: swipe through the
/// roll. A sample: drag the line to compare with its original.
private struct PictureViewer: View {
    let viewing: RollLibrary.Viewing
    let assets: [String]
    let close: () -> Void
    @State private var index = 0
    @State private var pair: (before: UIImage, after: UIImage)?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.92).ignoresSafeArea()
                if viewing.index < 0 {
                    sample(width: geo.size.width)
                } else {
                    TabView(selection: $index) {
                        ForEach(Array(assets.enumerated()), id: \.offset) { i, id in
                            AssetThumbnail(id: id, side: 2000, fill: false).tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onTapGesture(perform: close)
                    .overlay(alignment: .topTrailing) {
                        Button("Close", action: close)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(.black.opacity(0.5)))
                            .padding(16)
                    }
                }
            }
        }
        .onAppear { index = max(viewing.index, 0) }
    }

    @ViewBuilder private func sample(width: CGFloat) -> some View {
        let samples = FilmNotes.all[viewing.film.id]?.samples ?? []
        let i = -1 - viewing.index
        VStack(spacing: 14) {
            if let pair {
                CompareView(before: pair.before, after: pair.after, start: 0.5, filmName: viewing.film.name, unit: width / 390)
                    .frame(width: width - 24, height: (width - 24) / 1.5)
            } else {
                ProgressView().tint(.white)
            }
            Text("Drag the white line to compare. Sample originals are AI-generated; the film is rendered live by the app.")
                .font(.footnote).foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center).padding(.horizontal, 24)
            Button("Close", action: close).foregroundStyle(.white)
        }
        .task {
            guard samples.indices.contains(i),
                  let url = Bundle.main.url(forResource: samples[i].file, withExtension: "jpg"),
                  let image = CIImage(contentsOf: url) else { return }
            let film = viewing.film, iso = samples[i].iso
            pair = await Task.detached(priority: .userInitiated) { FilmRendering.pair(image, film: film, iso: iso) }.value
        }
    }
}

/// One picture from Photos. A picture no longer there shows as empty.
private struct AssetThumbnail: View {
    let id: String
    var side: CGFloat = 400
    var fill = true
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if fill { Color.white.opacity(0.05) }
                if let image {
                    if fill { Image(uiImage: image).resizable().scaledToFill() }
                    else { Image(uiImage: image).resizable().scaledToFit() }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .task(id: id) {
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return }
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            image = await withCheckedContinuation { done in
                var resumed = false
                PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: side, height: side),
                                                      contentMode: fill ? .aspectFill : .aspectFit, options: options) { picture, info in
                    let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if !degraded && !resumed { resumed = true; done.resume(returning: picture) }
                }
            }
        }
    }
}

/// The card in the lid while the all-films roll is looked at: a collector's
/// certificate. Its last line buys it, like the roll's tag.
private struct AllFilmsCard: View {
    @ObservedObject private var store = FilmStore.shared
    let s: CGFloat
    let buy: () -> Void

    var body: some View {
        let r = RollLibrary.card.scaled(s)
        VStack(alignment: .leading, spacing: 6 * s) {
            Text("All films").font(.custom("American Typewriter", size: 36 * s).weight(.semibold))
            Text("Every film, yours to keep").font(.custom("American Typewriter", size: 22 * s).weight(.semibold))
            Text("Every film here now and every one added later, in one purchase. Shoot any of them as much as you like.")
                .font(.custom("American Typewriter", size: 18 * s))
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: buy) {
                action.font(.custom("Marker Felt", size: 25 * s))
                    .foregroundStyle(store.ownsAll ? Color(red: 0.42, green: 0.39, blue: 0.34) : Color(red: 0.72, green: 0.12, blue: 0.10))
            }
            .buttonStyle(.plain)
            Text("One sample from each film · AI originals, film rendered by Koco · tap one to look at that film")
                .font(.custom("American Typewriter", size: 15 * s))
                .foregroundStyle(Color(red: 0.42, green: 0.39, blue: 0.34))
                .frame(height: 26 * s)
        }
        .foregroundStyle(Color(red: 0.16, green: 0.13, blue: 0.10))
        .lineLimit(2).minimumScaleFactor(0.6)
        .padding(.horizontal, 44 * s).padding(.top, 40 * s).padding(.bottom, 8 * s)
        .frame(width: r.width, height: r.height, alignment: .topLeading)
        .offset(x: r.minX, y: r.minY)
    }

    private var action: Text {
        if store.ownsAll { return Text("All yours") }
        if store.awaitingApproval.contains(FilmStore.allFilmsID) { return Text("Purchase waiting for approval") }
        if let price = store.allFilmsPrice { return Text("Buy all films · \(price) →") }
        return Text("Prices couldn't be loaded. Check the connection and tap to try again.")
    }
}

/// The sleeve while the all-films roll is looked at: one sample of each film,
/// six a page (swipe for the rest); a tap looks at that film.
private struct AllFilmsSleeve: View {
    let films: [Film]
    let s: CGFloat
    let look: (Film) -> Void
    @State private var page = 0

    var body: some View {
        let pockets = RollLibrary.pockets
        let pages = max(1, (films.count + 5) / 6)
        let first = min(page, pages - 1) * 6
        ZStack(alignment: .topLeading) {
            ForEach(0..<pockets.count, id: \.self) { i in
                let r = pockets[i].scaled(s)
                Group {
                    if first + i < films.count, let sample = FilmNotes.all[films[first + i].id]?.samples.first {
                        let film = films[first + i]
                        SampleThumb(film: film, sample: sample)
                            .overlay(alignment: .bottomLeading) {
                                Text(verbatim: film.name)
                                    .font(.custom("Marker Felt", size: 18 * s))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.8), radius: 2 * s)
                                    .padding(8 * s)
                            }
                            .onTapGesture { look(film) }
                            .accessibilityElement()
                            .accessibilityLabel(film.name)
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .frame(width: r.width, height: r.height)
                .clipped()
                .overlay {
                    Image(uiImage: RollLibrary.pocketImages[i]).resizable()
                        .blendMode(.screen).opacity(0.55).allowsHitTesting(false)
                }
                .offset(x: r.minX, y: r.minY)
            }
            if pages > 1 {
                let tab = RollLibrary.pageTab.scaled(s)
                Text(verbatim: "\(min(page, pages - 1) + 1)/\(pages)")
                    .font(.custom("Marker Felt", size: 20 * s))
                    .foregroundStyle(Color(red: 0.18, green: 0.17, blue: 0.16))
                    .frame(width: tab.width, height: tab.height)
                    .offset(x: tab.minX, y: tab.minY)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 30).onEnded { drag in
            guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
            let next = page + (drag.translation.width < 0 ? 1 : -1)
            if (0..<pages).contains(next) { withAnimation(.easeOut(duration: 0.2)) { page = next }; Haptic.click() }
        })
    }
}
