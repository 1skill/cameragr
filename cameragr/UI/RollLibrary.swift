import Photos
import SwiftUI

/// The phone open flat, held like a book: the camera bag, opened. The fold
/// of the phone is the fold of the bag's lid. On the left, the bag's lining:
/// every roll lying under an elastic strap, a paper tag at its side saying
/// where it stands (in the camera, yours, trial shots left, or its price);
/// the strap of the roll in the camera is empty. On the right, the inside of
/// the lid: a card about the roll being looked at, and a clear photo sleeve
/// holding the pictures taken on it, or, for a roll not shot yet, its samples.
///
/// Tap a roll to look at it (it lifts out of its loop). Tap its tag to use
/// it: choose it as the next roll (it goes in when the phone is closed), try
/// it, or buy it. Tap a picture to see it on the whole screen. The store is
/// this bag: nothing else needs opening.
///
/// The bag is one picture (GPT, `library_bag.jpg`, from
/// `design/library/bag/bag_template.png`); rolls, writing and pictures are
/// placed at rectangles measured on it, in its pixels (1456×1024). The straps
/// are drawn again over the rolls, cut from the same picture, so each roll
/// sits behind its elastic.
struct RollLibrary: View {
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared
    @ObservedObject private var shots = ShotLog.shared
    /// The roll being looked at (not the loaded one, not the chosen one).
    @State private var looking: Film?
    /// A picture shown on the whole screen.
    @State private var viewing: Viewing?

    /// What is open on the whole screen: the pictures as the sleeve showed
    /// them (the same list, so a tap opens the picture tapped), or a sample (index < 0).
    struct Viewing: Equatable { let film: Film; let index: Int; let assets: [String] }

    static let art = CGSize(width: 1456, height: 1024)
    static let bag = UIImage(named: "library_bag.jpg") ?? UIImage()
    /// Measured on the picture (design/library/bag/bag_lr_v2.png, less 40 px
    /// cut from its left): ten short straps at the left end of each place, two
    /// columns of five; the tenth place holds all films.
    static let rowsY: [CGFloat] = [47, 235, 425, 617, 810]
    static let bands: [CGRect] = [28, 388].flatMap { x in
        rowsY.map { y in CGRect(x: x, y: y, width: 58, height: 150) }
    }
    /// Where each roll lies: its spool end under the strap, the rest in view.
    static let places: [CGRect] = [30, 390].flatMap { x in
        rowsY.map { y in CGRect(x: x, y: y + 14, width: 234, height: 122) }
    }
    static let tags: [CGRect] = [282, 636].flatMap { x in
        [88, 276, 470, 662, 853].map { y in CGRect(x: x, y: y, width: 64, height: 72) }
    }
    /// The card under the leather corners, and the six pockets of the sleeve.
    static let card = CGRect(x: 768, y: 42, width: 657, height: 261)
    static let pockets: [CGRect] = [348, 566, 786].flatMap { y in
        [(773, 307), (1111, 325)].map { x, w in CGRect(x: CGFloat(x), y: y, width: CGFloat(w), height: 190) }
    }
    /// The loops cut from the picture, to lay over the rolls.
    static let bandImages: [UIImage] = bands.map { crop($0) }
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
            // Fills the screen whatever its shape (the inner screen is the
            // picture's own shape; elsewhere a sliver is cut off, centred).
            let s = max(canvas.width / Self.art.width, canvas.height / Self.art.height)
            let shift = CGSize(width: (canvas.width - Self.art.width * s) / 2,
                               height: (canvas.height - Self.art.height * s) / 2)
            let film = looking ?? model.film ?? model.films[0]
            ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                Image(uiImage: Self.bag).resizable()
                    .frame(width: Self.art.width * s, height: Self.art.height * s)
                ForEach(Array(model.films.prefix(9).enumerated()), id: \.element.id) { i, roll in
                    loop(i, roll: roll, looked: roll == film, s: s)
                }
                allFilmsLoop(s: s)
                FilmCard(film: film, s: s) { useTag(film) }
                PhotoSleeve(film: film, assets: shots.assets(for: film.id), s: s) { index, shown in
                    viewing = Viewing(film: film, index: index, assets: shown)
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
            if let id = UserDefaults.standard.string(forKey: "look") { looking = model.films.first { $0.id == id } }
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

    /// One loop: its roll held in it (lifted while looked at), the elastic in
    /// front, and the tag below. Empty while the roll is in the camera.
    private func loop(_ i: Int, roll: Film, looked: Bool, s: CGFloat) -> some View {
        let band = Self.bands[i].scaled(s), tag = Self.tags[i].scaled(s), place = Self.places[i].scaled(s)
        let inCamera = roll == model.film && model.arrivingRoll == nil
        // Looked at, or chosen: slid partly out from under its strap.
        let lift: CGFloat = (looked || roll == model.readyToLoad) ? 30 * s : 0
        return ZStack(alignment: .topLeading) {
            if !inCamera {
                // Lying on its side, the name reading left to right.
                Canister(film: roll)
                    .frame(width: place.height, height: place.width)
                    .rotationEffect(.degrees(-90))
                    .frame(width: place.width, height: place.height)
                    .shadow(color: .black.opacity(0.55), radius: lift > 0 ? 10 * s : 3 * s, x: 0, y: lift > 0 ? 8 * s : 2 * s)
                    .offset(x: place.minX - lift, y: place.minY - lift * 0.3)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: lift)
            }
            // The elastic, in front of the roll.
            Image(uiImage: Self.bandImages[i]).resizable()
                .frame(width: band.width, height: band.height)
                .offset(x: band.minX, y: band.minY)
                .allowsHitTesting(false)
            // Tapping the roll (or its empty loop) looks at it.
            Color.clear.contentShape(Rectangle())
                .frame(width: place.width, height: band.height)
                .offset(x: place.minX, y: band.minY)
                .onTapGesture { looking = roll; Haptic.click() }
                .accessibilityElement()
                .accessibilityLabel(roll.name)
                .accessibilityAddTraits(.isButton)
            Tag(text: Text(verbatim: roll.label + "\n") + tagText(roll), ink: tagInk(roll), size: tag.size) { useTag(roll) }
                .offset(x: tag.minX, y: tag.minY)
        }
    }

    /// The tenth loop: all films, a small bundle and one price.
    private func allFilmsLoop(s: CGFloat) -> some View {
        let band = Self.bands[9].scaled(s), tag = Self.tags[9].scaled(s), place = Self.places[9].scaled(s)
        let bundle = Array(model.films.filter { $0.free != true }.prefix(3))
        return ZStack(alignment: .topLeading) {
            // Three rolls, smaller, stacked under the strap: the whole set.
            ForEach(Array(bundle.enumerated()), id: \.element.id) { k, roll in
                Canister(film: roll)
                    .frame(width: 52 * s, height: 150 * s)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 150 * s, height: 52 * s)
                    .shadow(color: .black.opacity(0.5), radius: 3 * s, y: 2 * s)
                    .offset(x: place.minX + 20 * s, y: place.minY - 18 * s + CGFloat(k) * 54 * s)
            }
            Image(uiImage: Self.bandImages[9]).resizable()
                .frame(width: band.width, height: band.height)
                .offset(x: band.minX, y: band.minY)
                .allowsHitTesting(false)
            Tag(text: allFilmsTag, ink: store.ownsAll ? .muted : .price, size: tag.size) {
                guard !store.ownsAll else { return }
                if store.allFilmsPrice == nil {
                    // Prices not loaded (offline): try again.
                    Task { await store.loadProductsIfMissing(force: true) }
                } else {
                    Task { if await store.buy(nil) { Haptic.stop() } }
                }
            }
            .offset(x: tag.minX, y: tag.minY)
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

private extension CGRect {
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
                Text(film.name).font(.custom("American Typewriter", size: 40 * s).weight(.semibold))
                Spacer(minLength: 8 * s)
                Text(verbatim: "ISO \(film.iso)").font(.custom("American Typewriter", size: 24 * s))
            }
            if let note {
                Text(note.tagline).font(.custom("American Typewriter", size: 26 * s).weight(.semibold))
                Text(note.about).font(.custom("American Typewriter", size: 20 * s))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: use) {
                action.font(.custom("Marker Felt", size: 28 * s))
                    .foregroundStyle(Color(red: 0.72, green: 0.12, blue: 0.10))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(ink)
        .lineLimit(2).minimumScaleFactor(0.6)
        // Clear of the leather corners at the top.
        .padding(.horizontal, 44 * s).padding(.top, 58 * s).padding(.bottom, 16 * s)
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

    /// One handwritten line under the sleeve: whose pictures these are.
    @ViewBuilder private var note: some View {
        // In the gap between the card and the sleeve: always on screen.
        let y = (RollLibrary.card.maxY + 8) * s
        let text: Text = {
            if !assets.isEmpty && access == .notDetermined { return Text("Tap here to let Koco see your pictures") }
            if !assets.isEmpty && !canRead { return Text("Allow Photos in Settings to see them") }
            if showsSamples { return Text("\(film.name) samples · AI originals, film rendered by Koco") }
            let pages = max(1, (shown.count + 5) / 6)
            return pages > 1 ? Text("\(film.name) · \(shown.count) · \(min(page, pages - 1) + 1)/\(pages)")
                             : Text("\(film.name) · \(shown.count)")
        }()
        Button {
            if access == .notDetermined {
                Task { access = await PHPhotoLibrary.requestAuthorization(for: .readWrite); refresh() }
            } else if !canRead, let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        } label: {
            text.font(.custom("Marker Felt", size: 15 * s / 0.65))
                .foregroundStyle(Color(red: 0.93, green: 0.88, blue: 0.75))
                .lineLimit(1).minimumScaleFactor(0.5)
                .frame(width: 680 * s)
        }
        .buttonStyle(.plain)
        .offset(x: 750 * s, y: y)
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
