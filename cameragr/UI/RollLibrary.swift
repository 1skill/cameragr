import Photos
import SwiftUI

/// The phone open flat, held like a book: the camera bag, opened. The fold
/// of the phone is the fold of the bag's lid. On the left, the bag's black
/// velvet lining: every roll lying snug in its own cradle, a paper tag at its
/// side saying where it stands (in the camera, yours, trial shots left, or its
/// price); the cradle of the roll in the camera is empty. The first cradle
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
    /// Words made in code (the "Next" ribbon) follow the chosen language.
    @ObservedObject private var language = AppLanguage.shared
    /// Opened over the closed camera: the pages to show first, and the
    /// clasp that closes it (on the inner screen, closing the phone does).
    var start: CameraModel.BagOpening? = nil
    var showsClasp = false
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared
    @ObservedObject private var shots = ShotLog.shared
    /// The roll being looked at (not the loaded one, not the chosen one).
    @State private var looking: Film? {
        // What is on the card is what goes in when the bag is put away, if
        // no roll was chosen with its tag (user 11/24: "我换了卷").
        didSet { model.lookedAt = looking }
    }
    /// The clasp was done up with nothing to load and a roll in the camera
    /// that can't shoot: say how to choose one (the next press closes anyway).
    @State private var claspNote = false
    /// Looking at the all-films roll instead of a film.
    @State private var lookingAll = false
    /// A roll to bring into view on the belt (its slot), then cleared.
    @State private var scrollTarget: Int?
    /// The pair of pages open, the pair the last turn came from, and how far
    /// through that turn the pages are (1: done).
    @State private var spread: Spread = .films
    @State private var turnFrom: Spread = .films
    @State private var turn: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How far the belt is scrolled (points), to know where a roll lies on screen.
    @State private var beltScroll: CGFloat = 0
    /// Rolls on their way between the belt and the card.
    @State private var flights: [Flight] = []
    struct Flight: Identifiable, Equatable {
        let id = UUID()
        /// A film's id, or "all" for the all-films roll.
        let key: String
        /// Where it is at each step (the first is where it starts) and the
        /// moves between them.
        let stops: [Stop]
        let moves: [Animation]
        var at = 0
        static func == (a: Flight, b: Flight) -> Bool { a.id == b.id && a.at == b.at }
    }
    /// A place on the way: `lift` 1 is held up off the page, larger and
    /// with a longer shadow; 0 lies on it.
    struct Stop: Equatable { let rect: CGRect; let lift: CGFloat }
    /// A picture shown on the whole screen.
    @State private var viewing: Viewing?
    /// One of the user's own photos, tried on the roll looked at.
    @State private var own: OwnPhoto?

    /// What is open on the whole screen: the pictures as the sleeve showed
    /// them (the same list, so a tap opens the picture tapped), or a sample (index < 0).
    struct Viewing: Equatable { let film: Film; let index: Int; let assets: [String] }

    static let art = CGSize(width: 1456, height: 1024)
    static let bag = UIImage(named: "library_bag.jpg") ?? UIImage()
    /// Read off the picture (design/library/bag/bag_fit_v1.png, less 40 px cut
    /// from its left; template bag_fit_template.png). The picture is the inner
    /// screen's own shape with its 55 pt corners, and nothing live comes near
    /// the corners or the hinge. Ten velvet cradles, two columns of five, each
    /// the size of a roll lying on its side; the first holds the all-films roll.
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
    /// The paper tag of each column, cut from the picture: shown small, the
    /// bag hangs a larger one over the drawn tag so its word can be read.
    static let tagPictures: [UIImage] = [crop(tags[0]), crop(tags[5])]
    static let bigTagScale: CGFloat = 1.38

    /// Where a tag's word goes: the drawn tag, or the larger one hung over it.
    static func tagPlace(_ tag: CGRect, s: CGFloat) -> CGRect {
        guard boost(s).isCompactBag else { return tag }
        let w = tag.width * bigTagScale, h = tag.height * bigTagScale
        return CGRect(x: tag.midX - w / 2, y: tag.minY - 2 * s, width: w, height: h)
    }
    /// The velvet round each cradle, cut from the picture to lay back over the
    /// roll's edges.
    static let rims: [UIImage] = cradles.map { crop($0.insetBy(dx: -10, dy: -10)) }
    static let allFilmsRoll = UIImage(named: "roll_allfilms") ?? UIImage()
    /// The red cloth tab clipped on the cradle of the next roll (GPT).
    static let ribbon = UIImage(named: "next_ribbon") ?? UIImage()
    /// The blank band pressed into the velvet under the cradles: how to use the bag.
    /// Where the clasp note shows: just above the page selector.
    static let hint = CGRect(x: 120, y: 876, width: 490, height: 34)
    /// The left page's velvet: a belt of cradles, two to a row, that slides up
    /// and down under the page's fixed stitched frame, so any number of rolls
    /// fits. Its rows are pieces of the bag's own picture: the first row with
    /// the page's top, then the second row repeated, then the page's foot.
    static let page = CGRect(x: 26, y: 26, width: 678, height: 972)
    static let rowPitch: CGFloat = 182
    /// Where the ratchet's stops start: every row in view whole, tags and
    /// their hooks included (rows span y 50…200 of each pitch).
    static let beltLead: CGFloat = 20
    /// Where the belt slides under the fixed pressed band at the page's foot.
    static let beltBottom: CGFloat = 912   // the page selector below (PageDial)
    static let beltTop = crop(CGRect(x: 26, y: 26, width: 678, height: 210))      // to y 236
    static let beltRow = crop(CGRect(x: 26, y: 236, width: 678, height: 182))     // one row, repeats
    /// Plain velvet, tiled behind the belt so its ends never show the bag beneath.
    static let velvet = crop(CGRect(x: 60, y: 198, width: 220, height: 50))
    /// Where the roll being looked at lies on the card, in its well.
    static let cardRoll = CGRect(x: 834, y: 117, width: 166, height: 86)
    /// The well pressed into the card to the roll's outline (GPT,
    /// design/kit/card_slot_v1.png): its felt floor, measured on the 1536 ×
    /// 1024 original (crop 250…1258 × 239…778), is fitted round the roll
    /// with a little clearance, so the well shows round it.
    static let cardSlotPicture = UIImage(named: "card_slot") ?? UIImage()
    static var cardSlot: CGRect {
        let r = cardRoll
        let fx = r.width * 1.05 / 966, fy = r.height * 1.07 / 503
        return CGRect(x: r.minX - r.width * 0.025 - 21 * fx, y: r.minY - r.height * 0.035 - 16 * fy,
                      width: 1008 * fx, height: 539 * fy)
    }
    /// The paper stub that stands in the cradle of the roll in the camera, and
    /// the one clipped to the page's top edge to find it from anywhere (GPT).
    static let stub = UIImage(named: "roll_stub") ?? UIImage()
    static let topStub = CGRect(x: 268, y: 4, width: 178, height: 66)
    /// The right page (the inside of the lid).
    static let lidPage = CGRect(x: 752, y: 26, width: 678, height: 972)
    /// A slot on the belt: cradle, where its roll lies, and its tag (art pixels,
    /// on the belt as if it were not scrolled).
    static func cradle(_ k: Int) -> CGRect {
        CGRect(x: k % 2 == 0 ? 50 : 370, y: 72 + CGFloat(k / 2) * rowPitch, width: 234, height: 122)
    }
    static func tag(_ k: Int) -> CGRect {
        CGRect(x: k % 2 == 0 ? 298 : 621, y: 91 + CGFloat(k / 2) * rowPitch, width: 58, height: 94)
    }
    /// The velvet rim of a slot's cradle: from the first row for the first
    /// row, from the repeated row below.
    static func rim(_ k: Int) -> UIImage { rims[(k % 2) * 5 + min(k / 2, 1)] }
    /// The card under the leather corners, the six pockets of the sleeve, and
    /// the paper tab under the sleeve.
    static let card = CGRect(x: 790, y: 56, width: 616, height: 224)
    static let pockets: [CGRect] = [CGFloat(314), 521, 728].flatMap { y in
        [CGFloat(798), 1105].map { x in CGRect(x: x, y: y, width: 293, height: 193) }
    }
    static let pageTab = CGRect(x: 1050, y: 936, width: 96, height: 40)
    static let pocketImages: [UIImage] = pockets.map { crop($0) }
    /// The card's paper, for sheets laid over the bag.
    static let cardPaper = crop(CGRect(x: 830, y: 110, width: 520, height: 150))

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
                // The bag holds pairs of pages, chosen with the band window at
                // the foot of the left page (PageDial): the films, the
                // maintenance kit, the book, later the club. Each page is
                // drawn once and placed by the turn.
                spreadPage(.films, left: true, s: s) {
                    halfPicture(Self.bag, left: true, s: s)
                    belt(film: film, s: s)
                }
                spreadPage(.films, left: false, s: s) {
                    halfPicture(Self.bag, left: false, s: s)
                    if lookingAll {
                        AllFilmsCard(s: s) { buyAll() }
                        AllFilmsSleeve(films: model.films, s: s) { roll in
                            look(at: roll.id, s: s)
                            scrollTarget = slotOf(roll)
                        }
                    } else {
                        FilmCard(film: film, s: s) { useTag(film) }
                        PhotoSleeve(film: film, assets: shots.assets(for: film.id), s: s) { index, shown in
                            viewing = Viewing(film: film, index: index, assets: shown)
                        }
                        TryMyPhotoSlip(film: film, s: s) { own = $0 }
                    }
                    cardRoll(film: film, s: s)
                }
                spreadPage(.kit, left: true, s: s) {
                    halfPicture(KitArt.board, left: true, s: s)
                    ZStack(alignment: .topLeading) {
                        halfPicture(KitArt.spread, left: true, s: s)
                        KitSwitchPage(s: s)
                    }
                    .modifier(FootRoom(s: s, parts: FootRoom.kit, top: 46))
                }
                spreadPage(.kit, left: false, s: s) {
                    halfPicture(KitArt.spread, left: false, s: s)
                    KitHandbookPage(s: s)
                }
                bagCase(s: s).zIndex(1)
                spreadPage(.book, left: true, s: s) {
                    halfPicture(BookArt.board, left: true, s: s)
                    ZStack(alignment: .topLeading) {
                        halfPicture(BookArt.spread, left: true, s: s)
                        BookCoverPage(s: s)
                    }
                    .modifier(FootRoom(s: s, parts: FootRoom.book, top: 54))
                }
                spreadPage(.book, left: false, s: s) {
                    halfPicture(BookArt.spread, left: false, s: s)
                    BookInnerPage(s: s)
                }
                ForEach(flights) { f in
                    let stop = f.stops[f.at]
                    let r = stop.rect, up = stop.lift
                    rollPicture(key: f.key, rect: r.insetBy(dx: -r.width * 0.06 * up, dy: -r.height * 0.06 * up)
                                    .offsetBy(dx: 0, dy: -10 * s * up))
                        .shadow(color: .black.opacity(0.4 + 0.2 * up), radius: (4 + 14 * up) * s, y: (3 + 16 * up) * s)
                        .allowsHitTesting(false)
                        .zIndex(3)   // over the case: a roll crosses the spine
                }
                // Turning by hand: lift the right page's edge to go on, the
                // left page's edge to go back (user 11/24).
                pageEdges(s: s).zIndex(4)
                // Always on top, a turning page included (user 11/24).
                PageDial(spread: spread, s: s) { turnTo($0) }.zIndex(5)
                clasp(s: s).zIndex(3)
            }
            .offset(shift)
            .environment(\.bagBoost, Self.boost(s))
            .overlay {
                if let viewing {
                    PictureViewer(viewing: viewing, assets: viewing.assets) { self.viewing = nil }
                        .frame(width: canvas.width, height: canvas.height)
                        .transition(.opacity)
                }
                if let own {
                    OwnPhotoViewer(photo: own) { self.own = nil }
                        .frame(width: canvas.width, height: canvas.height)
                }
            }
            .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
            .clipped()
            }
            // The bag's own frame, still while pages turn, turned with the bag
            // however it lies in the interface: edge drags are measured here.
            .coordinateSpace(name: Self.canvasSpace)
            .frame(width: canvas.width, height: canvas.height)
            .rotationEffect(.degrees(upright ? -90 : 0))
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .animation(.easeInOut(duration: 0.2), value: viewing)
        }
        .background(Color.black)
        .onChange(of: start) { _, new in if let new { open(at: new) } }
        // A new opening shows the roll in the camera (its stub), on the card
        // its notes and pictures; the belt brings it into view.
        .onAppear {
            if let roll = model.film { scrollTarget = slotOf(roll) }
            if let start { open(at: start) }
        }
        #if DEBUG
        // `-look <film id>`: start looking at that roll (for checks).
        .onAppear {
            // `-claspNote 1`: as if the clasp was done up with nothing to load.
            if UserDefaults.standard.bool(forKey: "claspNote") { claspNote = true }
            if let id = UserDefaults.standard.string(forKey: "look") {
                if id == "all" { lookingAll = true } else { looking = model.films.first { $0.id == id } }
                if let looking { scrollTarget = slotOf(looking) }
                if UserDefaults.standard.bool(forKey: "kit") { spread = .kit; turnFrom = .kit }
                if UserDefaults.standard.bool(forKey: "book") { spread = .book; turnFrom = .book }
                let days = UserDefaults.standard.integer(forKey: "bookDays")
                if days > 0 { BookStore.shared.demo(days: days, shots: ShotLog.shared.shots) }
            }
            // `-ownDemo <sample>`: as if that bundled picture was picked to try.
            if let name = UserDefaults.standard.string(forKey: "ownDemo"),
               let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
               let data = try? Data(contentsOf: url), let film = looking ?? model.film,
               let pair = FilmRendering.ownPhoto(data, film: film) {
                own = OwnPhoto(film: film, data: data, before: pair.before, after: pair.after)
            }
            // `-turnAt <0…1>`: hold the turn from the films to the kit there.
            let at = UserDefaults.standard.double(forKey: "turnAt")
            if at > 0 { turnFrom = .films; spread = .kit; turn = at }
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
    private func cradled(_ picture: some View, slot k: Int, lifted: Bool, s: CGFloat) -> some View {
        let place = Self.cradle(k).scaled(s), cradle = Self.cradle(k).scaled(s)
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
                Image(uiImage: Self.rim(k)).resizable()
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
    /// roll carries a red cloth tab. While the roll is in the camera its
    /// cradle holds a paper stub instead: tap it to look at that roll.
    private func loop(_ k: Int, roll: Film, looked: Bool, s: CGFloat) -> some View {
        let cradle = Self.cradle(k).scaled(s), tag = Self.tag(k).scaled(s), place = Self.cradle(k).scaled(s)
        let inCamera = roll == model.film && model.arrivingRoll == nil
        let next = roll == model.readyToLoad
        // Away on the card (or on its way there or back): the cradle is empty.
        let away = looked || flights.contains { $0.key == roll.id }
        return ZStack(alignment: .topLeading) {
            if !away {
                // Lying on its side, the name reading left to right.
                cradled(Canister(film: roll, fill: true)
                            .frame(width: place.height, height: place.width)
                            .rotationEffect(.degrees(-90)),
                        slot: k, lifted: false, s: s)
            }
            Color.clear.contentShape(Rectangle())
                .frame(width: cradle.width, height: cradle.height)
                .offset(x: cradle.minX, y: cradle.minY)
                .onTapGesture { look(at: roll.id, s: s) }
                .accessibilityElement()
                .accessibilityLabel(roll.name)
                .accessibilityValue(next ? Text("Next roll") : Text(verbatim: ""))
                .accessibilityAddTraits(.isButton)
            if next && !inCamera && !away { nextRibbon(cradle: cradle, s: s) }
            bigTag(k, tag, s: s)
            let t = Self.tagPlace(tag, s: s)
            // Today's free roll: its tag says only that, on two lines.
            Tag(text: Self.boost(s).isCompactBag || freeTodayTag(roll) ? tagText(roll) : Text(verbatim: roll.label + "\n") + tagText(roll),
                ink: tagInk(roll), size: t.size) { useTag(roll) }
                .offset(x: t.minX, y: t.minY)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: next)
    }

    /// The red cloth tab clipped over the cradle's top lip, hanging down over
    /// the spool end of the roll: this one goes in when the phone is closed.
    private func nextRibbon(cradle: CGRect, s: CGFloat) -> some View {
        let w = 44 * s, h = w * Self.ribbon.size.height / max(Self.ribbon.size.width, 1)
        let word = String(ui: "Next").map(String.init).joined(separator: "\n")
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

    /// Shown small: the larger tag, hung from the same pin over the drawn one.
    @ViewBuilder private func bigTag(_ k: Int, _ tag: CGRect, s: CGFloat) -> some View {
        if Self.boost(s).isCompactBag {
            let t = Self.tagPlace(tag, s: s)
            Image(uiImage: Self.tagPictures[k % 2]).resizable()
                .frame(width: t.width, height: t.height)
                .shadow(color: .black.opacity(0.5), radius: 2 * s, y: 1.5 * s)
                .offset(x: t.minX, y: t.minY)
                .allowsHitTesting(false)
        }
    }

    /// The first cradle: the all-films roll, one price for every film.
    private func allFilmsLoop(_ k: Int, s: CGFloat) -> some View {
        let tag = Self.tag(k).scaled(s), place = Self.cradle(k).scaled(s)
        return ZStack(alignment: .topLeading) {
            if !(lookingAll || flights.contains { $0.key == "all" }) {
                cradled(Image(uiImage: Self.allFilmsRoll).resizable()
                            .frame(width: place.height, height: place.width)
                            .rotationEffect(.degrees(-90)),
                        slot: k, lifted: false, s: s)
            }
            Color.clear.contentShape(Rectangle())
                .frame(width: place.width, height: place.height)
                .offset(x: place.minX, y: place.minY)
                .onTapGesture { look(at: "all", s: s) }
                .accessibilityElement()
                .accessibilityLabel(Text("All films"))
                .accessibilityAddTraits(.isButton)
            bigTag(k, tag, s: s)
            let t = Self.tagPlace(tag, s: s)
            Tag(text: allFilmsTag, ink: store.ownsAll ? .muted : .price, size: t.size) { buyAll() }
                .offset(x: t.minX, y: t.minY)
        }
    }

    /// The key of what lies on the card now.
    private var cardKey: String {
        lookingAll ? "all" : (looking ?? model.film ?? model.films[0]).id
    }

    /// Where slot `key`'s cradle is on screen now (the belt scrolled), in points.
    private func cradleOnScreen(_ key: String, s: CGFloat) -> CGRect? {
        guard let k = key == "all" ? slots.firstIndex(where: { $0 == nil }) : slots.firstIndex(where: { $0?.id == key })
        else { return nil }
        let r = Self.cradle(k).scaled(s)
        return r.offsetBy(dx: 0, dy: -beltScroll)
    }

    /// Looks at a roll: it flies from its cradle into the well on the card, and
    /// the roll that was there flies back to its own cradle.
    private func look(at key: String, s: CGFloat) {
        let old = cardKey
        guard key != old else { Haptic.click(); return }
        let pad = Self.cardRoll.scaled(s)
        // A roll still on its way is taken where it is going: no second copy.
        flights.removeAll { $0.key == old || $0.key == key }
        var new: [Flight] = []
        // The roll on the card is lifted straight up out of its well, then
        // carried home; the new one is carried over the well and pressed
        // straight down into it.
        if let home = cradleOnScreen(old, s: s) {
            new.append(Flight(key: old, stops: [Stop(rect: pad, lift: 0), Stop(rect: pad, lift: 1), Stop(rect: home, lift: 0)],
                              moves: [.easeOut(duration: 0.13), .spring(response: 0.42, dampingFraction: 0.88)]))
        }
        if let from = cradleOnScreen(key, s: s) {
            new.append(Flight(key: key, stops: [Stop(rect: from, lift: 0), Stop(rect: pad, lift: 1), Stop(rect: pad, lift: 0)],
                              moves: [.spring(response: 0.42, dampingFraction: 0.9), .easeIn(duration: 0.12)]))
        }
        flights.append(contentsOf: new)
        // Looking at all films is looking at no one roll: closing then loads
        // nothing (user 11/24), unless a tag was tapped.
        if key == "all" { lookingAll = true; model.lookedAt = nil } else { lookingAll = false; looking = model.films.first { $0.id == key } }
        Haptic.click()
        DispatchQueue.main.async { for f in new { advance(f.id) } }
    }

    /// Moves a flight on to its next stop; at the last it lands and is gone.
    private func advance(_ id: UUID) {
        guard let i = flights.firstIndex(where: { $0.id == id }), flights[i].at < flights[i].moves.count else { return }
        let move = flights[i].moves[flights[i].at]
        withAnimation(move) {
            flights[i].at += 1
        } completion: {
            guard let j = flights.firstIndex(where: { $0.id == id }) else { return }
            if flights[j].at < flights[j].moves.count {
                advance(id)
            } else {
                flights.remove(at: j)
            }
        }
    }

    @ViewBuilder private func rollPicture(key: String, rect: CGRect) -> some View {
        Group {
            if key == "all" {
                Image(uiImage: Self.allFilmsRoll).resizable()
            } else if let film = model.films.first(where: { $0.id == key }) {
                Canister(film: film, fill: true)
            }
        }
        .frame(width: rect.height, height: rect.width)
        .rotationEffect(.degrees(-90))
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
    }

    /// The well in the card and the roll being looked at, lying in it.
    @ViewBuilder private func cardRoll(film: Film, s: CGFloat) -> some View {
        let pad = Self.cardSlot.scaled(s)
        Image(uiImage: Self.cardSlotPicture).resizable()
            .frame(width: pad.width, height: pad.height)
            .offset(x: pad.minX, y: pad.minY)
            .allowsHitTesting(false)
        if !flights.contains(where: { $0.key == cardKey }) {
            rollPicture(key: cardKey, rect: Self.cardRoll.scaled(s))
                .shadow(color: .black.opacity(0.4), radius: 2 * s, y: 1.5 * s)
                .allowsHitTesting(false)
            // Chosen as the next roll: its red tab comes with it to the card.
            if !lookingAll, film == model.readyToLoad, film != model.film {
                nextRibbon(cradle: Self.cardRoll.scaled(s), s: s)
            }
        }
    }

    /// What lies on the belt, slot by slot: the all-films roll in the first
    /// place (top left, user 11/24), then the films.
    private var slots: [Film?] {
        let films = model.films
        // The all-films roll first, top left, where it is seen at once (user 11/24).
        return [nil] + films
    }

    private func slotOf(_ roll: Film) -> Int? { slots.firstIndex { $0 == roll } }

    /// The left page: the belt of cradles, scrolling under the page's frame.
    /// It moves with the finger, carries on a little when let go and gives at
    /// the ends; nothing snaps. Half a row shows at the foot when there is
    /// more below. The stub clipped to the top edge finds the roll in the camera.
    @ViewBuilder private func belt(film: Film, s: CGFloat) -> some View {
        let page = Self.page.scaled(s)
        let rows = (slots.count + 1) / 2
        let footY = Self.page.minY + 210 + CGFloat(rows - 1) * Self.rowPitch   // art y where the last row ends
        // Long enough that the far end is a ratchet stop too (never half a row there).
        let view = Self.beltBottom - Self.page.minY
        let natural = footY + 30 - Self.page.minY
        // The far end is the ratchet stop whose bottom row is one empty row
        // after the last roll (five rows show at a stop).
        let lastStop = CGFloat(max(0, rows - 1 + 1 - 4))
        let height = natural > view ? view + lastStop * Self.rowPitch : natural
        ScrollViewReader { reader in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // The velvet: top, repeated rows, foot.
                    Image(uiImage: Self.beltTop).resizable()
                        .frame(width: page.width, height: 210 * s)
                        .offset(x: page.minX, y: page.minY)
                    // Rows down to the very end: below the last roll, one or
                    // more empty slots of the same belt (room for suggestions
                    // later), never the lining underneath (user 11/24).
                    ForEach(1..<max(rows + 1, Int(((height + Self.page.minY - 236) / Self.rowPitch).rounded(.up)) + 1), id: \.self) { r in
                        Image(uiImage: Self.beltRow).resizable()
                            .frame(width: page.width, height: Self.rowPitch * s)
                            .offset(x: page.minX, y: (236 + CGFloat(r - 1) * Self.rowPitch) * s)
                    }
                    // Anchors to scroll a slot into view.
                    ForEach(0..<slots.count, id: \.self) { k in
                        // Placed by padding, not offset: scrolling reads layout.
                        Color.clear.frame(width: 1, height: Self.cradle(k).height * s)
                            .id(k)
                            .padding(.top, Self.cradle(k).minY * s)
                            .padding(.leading, page.minX)
                    }
                    ForEach(Array(slots.enumerated()), id: \.offset) { k, roll in
                        if let roll {
                            loop(k, roll: roll, looked: roll == film && !lookingAll, s: s)
                        } else {
                            allFilmsLoop(k, s: s)
                        }
                    }
                }
                .frame(width: Self.art.width * s, height: (height + Self.page.minY) * s, alignment: .topLeading)
                .offset(x: -page.minX, y: -page.minY - Self.beltLead * s)   // at rest at the top: five whole rows
                .frame(width: page.width, height: height * s, alignment: .topLeading)
            }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { old, y in
                beltScroll = y
                // A ratchet's click at each row passed.
                let pitch = Self.rowPitch * s
                if Int((old / pitch).rounded(.down)) != Int((y / pitch).rounded(.down)) { Haptic.detent() }
            }
            // Like a ratchet: it always comes to rest on whole rows, never a roll cut in half (user 11/24).
            .scrollTargetBehavior(RowRatchet(pitch: Self.rowPitch * s, lead: 0))
            .frame(width: page.width, height: (Self.beltBottom - Self.page.minY) * s)
            // Plain velvet under the belt: pulled past its ends, it is still the bag's lining.
            .background(Image(uiImage: Self.velvet).resizable(resizingMode: .tile))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 60 * s, bottomLeadingRadius: 8 * s,
                                              bottomTrailingRadius: 8 * s, topTrailingRadius: 60 * s))
            // The frame's shade on the velvet at the top and the foot.
            .overlay {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom).frame(height: 26 * s)
                    Spacer(minLength: 0)
                    LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom).frame(height: 30 * s)
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 60 * s, bottomLeadingRadius: 8 * s,
                                                  bottomTrailingRadius: 8 * s, topTrailingRadius: 60 * s))
                .allowsHitTesting(false)
            }
            .offset(x: page.minX, y: page.minY)
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.35)) { reader.scrollTo(target, anchor: .center) }
                scrollTarget = nil
            }
            .onAppear {
                if let target = scrollTarget {
                    reader.scrollTo(target, anchor: .center)
                    scrollTarget = nil
                }
            }
        }
        // The clasp note, just above the page selector at the page's foot.
        if claspNote && model.readyToLoad == nil {
            Text("Tap a roll’s tag to choose it, then do up the clasp")
                .font(.custom("American Typewriter", size: 19 * s * Self.boost(s)).weight(.semibold))
                .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.35))
                .shadow(color: .black.opacity(0.9), radius: 0, x: 0, y: -1 * s)
                .lineLimit(1).minimumScaleFactor(0.4)
                .padding(.horizontal, 16 * s)
                .frame(width: Self.hint.width * s, height: Self.hint.height * s)
                .offset(x: Self.hint.minX * s, y: Self.hint.minY * s)
                .allowsHitTesting(false)
        }
    }

    // MARK: Pages

    /// Opened again while already open (from the Lock Screen camera, or a
    /// trial run out): the pages and the roll asked for, not the ones left.
    private func open(at start: CameraModel.BagOpening) {
        spread = start.spread
        turnFrom = start.spread
        turn = 1
        if let film = start.look {
            lookingAll = false
            looking = film
            scrollTarget = slotOf(film)
        }
    }

    /// How much larger the writing is drawn at this scale (see `bagBoost`).
    static func boost(_ s: CGFloat) -> CGFloat { Swift.min(1.6, Swift.max(1, 0.6 / s)) }

    /// A page's board cut from its pair's picture and drawn only there (a
    /// clipped picture of the whole bag would still take the other page's
    /// touches).
    static let boardRadius: CGFloat = 30
    private static var boards: [String: UIImage] = [:]
    private func halfPicture(_ picture: UIImage, left: Bool, s: CGFloat) -> some View {
        let r = left ? Self.page : Self.lidPage
        let key = "\(ObjectIdentifier(picture).hashValue)-\(left)"
        let cut: UIImage
        if let known = Self.boards[key] { cut = known } else {
            let k = picture.scale
            cut = picture.cgImage?.cropping(to: CGRect(x: r.minX * k, y: r.minY * k, width: r.width * k, height: r.height * k))
                .map { UIImage(cgImage: $0) } ?? UIImage()
            Self.boards[key] = cut
        }
        return Image(uiImage: cut).resizable()
            .frame(width: r.width * s, height: r.height * s)
            .offset(x: r.minX * s, y: r.minY * s)
    }

    /// The bag's case and spine round the two boards: always the films
    /// pair's picture, above the lying pages and under a turning one.
    private func bagCase(s: CGFloat) -> some View {
        Image(uiImage: Self.bag).resizable()
            .frame(width: Self.art.width * s, height: Self.art.height * s)
            .mask {
                Path { p in
                    p.addRect(CGRect(x: 0, y: 0, width: Self.art.width * s, height: Self.art.height * s))
                    p.addRoundedRect(in: Self.page.scaled(s), cornerSize: CGSize(width: Self.boardRadius * s, height: Self.boardRadius * s))
                    p.addRoundedRect(in: Self.lidPage.scaled(s), cornerSize: CGSize(width: Self.boardRadius * s, height: Self.boardRadius * s))
                }
                .fill(style: FillStyle(eoFill: true))
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// One page of a pair (its board), and where the turn puts it. Only the
    /// inner board is a page: the case round it and the spine are one fixed
    /// layer (`bagCase`), so nothing there changes or jumps. A board turns
    /// about its own edge at the spine.
    private func spreadPage(_ pair: Spread, left: Bool, s: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        let role = pageRole(pair, left: left)
        let full = CGSize(width: Self.art.width * s, height: Self.art.height * s)
        let board = (left ? Self.page : Self.lidPage).scaled(s)
        let leaf = role == .leafOut || role == .leafIn
        let hinge = UnitPoint(x: (left ? Self.page.maxX : Self.lidPage.minX) / Self.art.width, y: 0.5)
        return ZStack(alignment: .topLeading) { content() }
            .frame(width: full.width, height: full.height, alignment: .topLeading)
            .modifier(PageTurn(progress: turn, role: role, left: left,
                               cut: PageCut(rect: board, radius: Self.boardRadius * s), hinge: hinge))
            .zIndex(leaf ? 2 : 0)
            .allowsHitTesting(role == .still)
            .accessibilityHidden(role != .still)
    }

    /// Turning forward, the right page goes over to the left: the old left
    /// page stays until the turning board covers it, and the new right page
    /// lies under the old one. Turning back is the mirror.
    private func pageRole(_ pair: Spread, left: Bool) -> PageTurn.Role {
        if turnFrom == spread { return pair == spread ? .still : .hidden }
        let forward = spread.rawValue > turnFrom.rawValue
        let turning = forward ? !left : left    // the board starts on this side
        if pair == turnFrom { return turning ? .leafOut : .covered }
        if pair == spread { return turning ? .revealed : .leafIn }
        return .hidden
    }

    private func turnTo(_ pair: Spread) {
        guard pair != spread, turnFrom == spread else { return }
        Haptic.click()
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.15)) { turnFrom = pair; spread = pair }
            return
        }
        turnFrom = spread
        spread = pair
        turn = 0
        withAnimation(.timingCurve(0.42, 0, 0.3, 1, duration: 0.54)) { turn = 1 } completion: {
            turnFrom = spread
        }
    }

    // MARK: Turning by hand

    /// Where a page's edge can be taken: a strip just inside each board's
    /// outer edge, clear of the screen's own edge (system swipes start in the
    /// outermost points) and of the clasp. Art units.
    static let rightEdge = CGRect(x: 1398, y: 70, width: 32, height: 690)   // outside the card and sleeve
    static let leftEdge = CGRect(x: 26, y: 70, width: 26, height: 820)   // clear of the rolls (from x 50)
    @State private var dragTurn: Spread?

    @ViewBuilder private func pageEdges(s: CGFloat) -> some View {
        let next = Spread(rawValue: spread.rawValue + 1), back = Spread(rawValue: spread.rawValue - 1)
        ZStack(alignment: .topLeading) {
            if next != nil || dragTurn != nil { edge(Self.rightEdge, forward: true, s: s) }
            if back != nil || dragTurn != nil { edge(Self.leftEdge, forward: false, s: s) }
        }
    }

    static let canvasSpace = "bag canvas"
    /// Drags are measured in the bag's canvas (`canvasSpace`), which turns with the bag:
    /// the bag may be drawn turned within the interface (held across, or the
    /// other way up), where a swipe along the bag is not along the screen
    /// (user 11/24: the page would not turn).
    private func edge(_ r: CGRect, forward: Bool, s: CGFloat) -> some View {
        let width = Self.art.width * s * 0.42   // a full turn's drag
        return Color.clear
            .contentShape(Rectangle())
            .frame(width: r.width * s, height: r.height * s)
            .gesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .named(Self.canvasSpace))
                    .onChanged { v in
                        let dx = forward ? -v.translation.width : v.translation.width
                        if dragTurn == nil {
                            guard turnFrom == spread, dx > 0, abs(v.translation.width) > abs(v.translation.height),
                                  let to = Spread(rawValue: spread.rawValue + (forward ? 1 : -1)) else { return }
                            Haptic.click()
                            dragTurn = to
                            turnFrom = spread
                            spread = to
                            turn = 0
                        }
                        turn = min(1, max(0, dx / width))
                    }
                    .onEnded { v in
                        guard dragTurn != nil else { return }
                        dragTurn = nil
                        let dx = forward ? -v.predictedEndTranslation.width : v.predictedEndTranslation.width
                        if dx / width > 0.4 {
                            withAnimation(.timingCurve(0.42, 0, 0.3, 1, duration: 0.3)) { turn = 1 } completion: { turnFrom = spread }
                        } else {
                            // Let go early: the page falls back.
                            withAnimation(.easeOut(duration: 0.25)) { turn = 0 } completion: {
                                spread = turnFrom
                                turn = 1
                            }
                        }
                    }
            )
            .offset(x: r.minX * s, y: r.minY * s)
            .accessibilityHidden(true)
    }

    /// The strap that closes the bag over the camera, on its right edge.
    static let clasp = CGRect(x: 1381, y: 785, width: 72, height: 215)
    static let claspPicture = UIImage(named: "bag_clasp") ?? UIImage()

    /// The leather tabs on the right edge are gone (user 11/23: the right
    /// page is narrow and is for content); the pages are chosen with the
    /// band window at the foot of the left page (`PageDial`).
    @ViewBuilder private func clasp(s: CGFloat) -> some View {
        if showsClasp {
            let c = Self.clasp
            Button { doUpClasp() } label: {
                Image(uiImage: Self.claspPicture).resizable()
                    .frame(width: c.width * s, height: c.height * s)
                    .shadow(color: .black.opacity(0.5), radius: 1.5 * s, x: -1 * s, y: 1 * s)
                    .frame(width: max(c.width * s, 44), height: max(c.height * s, 44))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: c.minX * s - max(0, 44 - c.width * s) / 2, y: c.minY * s)
            .accessibilityElement()
            .accessibilityLabel(model.readyToLoad.map { Text("Close the bag and load \($0.name)") } ?? Text("Close the bag"))
            .accessibilityAddTraits(.isButton)
        }
    }

    /// The paper stub of the roll in the camera.
    private func stubView(_ roll: Film, width: CGFloat, s: CGFloat, lifted: Bool = false) -> some View {
        let height = width * Self.stub.size.height / max(Self.stub.size.width, 1)
        return Image(uiImage: Self.stub).resizable()
            .frame(width: width, height: height)
            .overlay {
                VStack(spacing: 2 * s) {
                    Text("In the camera").font(.custom("Marker Felt", size: 15 * s))
                    Text(verbatim: roll.name).font(.custom("American Typewriter", size: 19 * s).weight(.semibold))
                }
                .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.15))
                .lineLimit(1).minimumScaleFactor(0.5)
                .padding(.leading, width * 0.14).padding(.trailing, width * 0.08)
            }
            .rotationEffect(.degrees(-2))
            .shadow(color: .black.opacity(lifted ? 0.7 : 0.4), radius: (lifted ? 10 : 3) * s, y: (lifted ? 8 : 2) * s)
            .scaleEffect(lifted ? 1.04 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: lifted)
    }

    /// The stub clipped to the page's top edge: always there, it finds the
    /// roll in the camera wherever the belt has been moved to.
    @ViewBuilder private func topStubView(s: CGFloat) -> some View {
        if let roll = model.film {
            let r = Self.topStub.scaled(s)
            stubView(roll, width: r.width, s: s * 0.75)
                .frame(width: r.width, height: max(r.height, 44))
                .contentShape(Rectangle())
                .onTapGesture {
                    looking = roll; lookingAll = false
                    scrollTarget = slotOf(roll)
                    Haptic.click()
                }
                .offset(x: r.minX, y: r.minY)
                .accessibilityElement()
                .accessibilityLabel(Text("In the camera"))
                .accessibilityValue(Text(verbatim: roll.name))
                .accessibilityAddTraits(.isButton)
        }
    }

    /// How to use the bag, pressed into the velvet.
    private func hintLine(_ text: Text? = nil, s: CGFloat) -> some View {
        let r = Self.hint.scaled(s)
        return (text ?? Text("Tap a roll to look · tap its tag to choose · close the phone to load it"))
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
        if store.owns(roll) { return Text("Yours") }
        if store.isFreeToday(roll) { return Text("Free\ntoday") }
        if roll.isLimited { return Text("Not for sale") }
        if store.trialsLeft(roll) > 0 { return Text("Try \(store.trialsLeft(roll))") }
        if let price = store.price(roll) { return Text(verbatim: price) }
        return Text(verbatim: "—")
    }

    private func freeTodayTag(_ roll: Film) -> Bool {
        store.isFreeToday(roll) && !store.owns(roll) && roll != model.film && roll != model.readyToLoad
    }

    private func tagInk(_ roll: Film) -> Tag.Ink {
        if roll == model.readyToLoad || (store.isFreeToday(roll) && !store.owns(roll)) { return .red }
        if roll == model.film { return .muted }
        if !store.isUnlocked(roll) && store.trialsLeft(roll) == 0 { return .price }
        return .pencil
    }

    /// The clasp closes the bag and loads the chosen roll. When the roll in
    /// the camera can't take a picture (its free shots used, not bought) and
    /// none was chosen, the first press says how to choose one instead of
    /// closing (looking at a roll never chooses it); a second press closes.
    private func doUpClasp() {
        if model.readyToLoad == nil, let loaded = model.film, !canShoot(loaded), !claspNote {
            claspNote = true
            Haptic.stop()
            return
        }
        claspNote = false
        model.closeBag()
    }
    private func canShoot(_ roll: Film) -> Bool { store.isUnlocked(roll) || store.trialsLeft(roll) > 0 }

    /// The tag's one action: choose the roll as the next one (or take that
    /// back), or buy it when there is nothing left to try.
    private func useTag(_ roll: Film) {
        looking = roll
        lookingAll = false
        if roll == model.film, store.isUnlocked(roll) || store.trialsLeft(roll) > 0
            || store.awaitingApproval.contains(FilmStore.productID(roll)) { Haptic.click(); return }
        if roll == model.readyToLoad || store.isUnlocked(roll) || store.trialsLeft(roll) > 0 {
            model.chooseInLibrary(roll)
        } else if roll.isLimited {
            turnTo(.book)   // earned there, never sold
        } else if store.price(roll) != nil {
            // Bought is bought, not chosen: choosing stays a tap of its own.
            Task { if await store.buy(roll) { Haptic.stop() } }
        } else {
            Task { await store.loadProductsIfMissing(force: true) }
        }
    }
}

/// The roll belt's ratchet: a flick ends on the nearest stop where every
/// row in view is whole (rows every `pitch`; `lead` clears the frame's top).
struct RowRatchet: ScrollTargetBehavior {
    let pitch: CGFloat
    let lead: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let end = max(0, context.contentSize.height - context.containerSize.height)
        let n = ((target.rect.minY - lead) / pitch).rounded()
        let y = n <= 0 ? 0 : lead + n * pitch
        target.rect.origin.y = min(y, end)
    }
}

extension CGRect {
    func scaled(_ s: CGFloat) -> CGRect { CGRect(x: minX * s, y: minY * s, width: width * s, height: height * s) }
}

/// The card in the lid: the roll being looked at, typed. Its last line is
/// what the tag does, and does the same on a tap.
private struct FilmCard: View {
    @Environment(\.bagBoost) private var b
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
                Text(film.name).font(.custom("American Typewriter", size: 36 * s * b).weight(.semibold))
                Spacer(minLength: 8 * s)
                Text(verbatim: "ISO \(film.iso)").font(.custom("American Typewriter", size: 22 * s * b))
            }
            if let note {
                Text(note.tagline).font(.custom("American Typewriter", size: 22 * s * b).weight(.semibold))
                // Shown small, the card keeps its one line; the rest is for the big screen.
                if !b.isCompactBag {
                    Text(note.about).font(.custom("American Typewriter", size: 16 * s))
                        .lineLimit(showsBookHint ? 2 : 3).fixedSize(horizontal: false, vertical: true)
                }
            }
            // The roll the photo book gives: say so on its card.
            if showsBookHint {
                // Shorter and larger when the bag is small (outer screen).
                (b.isCompactBag ? Text("Or free: three days running in the Book")
                                : Text("Or free: put one a day in the Book, three days running."))
                    .font(.custom("American Typewriter", size: (b.isCompactBag ? 19 : 15) * s * b).weight(.semibold))
                    .foregroundStyle(Color(red: 0.72, green: 0.12, blue: 0.10).opacity(0.85))
            }
            Spacer(minLength: 0)
            Button(action: use) {
                action.font(.custom("Marker Felt", size: 25 * s * b))
                    .foregroundStyle(Color(red: 0.72, green: 0.12, blue: 0.10))
                    // A taller target without taking the card's room.
                    .contentShape(Rectangle().inset(by: -10))
            }
            .buttonStyle(.plain)
            // Free shots left: buying it outright is offered too, not only
            // once they are used up.
            if let price = buyOutright {
                Button {
                    Task { if await store.buy(film) { Haptic.stop() } }
                } label: {
                    Text("or buy it · \(price)")
                        .font(.custom("American Typewriter", size: 17 * s * b).weight(.semibold))
                        .underline()
                        // Kept apart from the line above, so a tap lands on one or the other.
                        .padding(.top, 4 * s)
                        .contentShape(Rectangle().inset(by: -4))
                }
                .buttonStyle(.plain)
                .disabled(store.purchasing != nil)
            }
        }
        .foregroundStyle(ink)
        .lineLimit(2).minimumScaleFactor(0.6)
        // Clear of the leather corners at the top; the last line of the card
        // is the sleeve's note (see PhotoSleeve).
        // Right of the well where the roll lies.
        .padding(.leading, 228 * s).padding(.trailing, 64 * s).padding(.top, 40 * s).padding(.bottom, 38 * s)
        .frame(width: r.width, height: r.height, alignment: .topLeading)
        .offset(x: r.minX, y: r.minY)
    }

    /// The roll the photo book gives, not had yet: its card says so.
    private var showsBookHint: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "bookHint") && film.id == BookStore.shared.issue.rewardFilmID { return true }
        #endif
        return film.id == BookStore.shared.issue.rewardFilmID && !store.isUnlocked(film) && !BookStore.shared.isClaimed
    }

    /// A limited roll not earned yet: how many days running it takes.
    private var earnDays: Int? { film.isLimited && !store.isUnlocked(film) ? film.earnDays : nil }

    /// The price to show under "Try it", for a film not bought that still
    /// has free shots (with none left, the action line itself is the price).
    private var buyOutright: String? {
        // Free today: buying it to keep is offered too.
        if store.isFreeToday(film), !store.owns(film),
           !store.awaitingApproval.contains(FilmStore.productID(film)) { return store.price(film) }
        guard !store.isUnlocked(film), store.trialsLeft(film) > 0,
              !store.awaitingApproval.contains(FilmStore.productID(film)) else { return nil }
        return store.price(film)
    }

    private var action: Text {
        // The roll in the camera with its free shots used: why the shutter
        // brought you here, and what to do.
        if store.awaitingApproval.contains(FilmStore.productID(film)) { return Text("Purchase waiting for approval") }
        if film == model.film, !store.isUnlocked(film), store.trialsLeft(film) == 0 {
            if let price = store.price(film) { return Text("Free shots used up · buy \(price) →") }
            return Text("Free shots used up · choose another roll")
        }
        if film == model.film { return Text("In the camera") }
        if film == model.readyToLoad {
            return model.bag != nil ? Text("Do up the bag’s clasp to load it · tap to undo")
                                    : Text("Close the phone, or turn it upright to shoot · tap to undo")
        }
        if store.awaitingApproval.contains(FilmStore.productID(film)) { return Text("Purchase waiting for approval") }
        if store.isFreeToday(film) && !store.owns(film) { return Text("Free today, as many shots as you like · load it →") }
        if store.isUnlocked(film) { return Text("Load this roll →") }
        if film == store.dailyFreeYesterday, store.trialsLeft(film) == 0, let price = store.price(film) { return Text("Yesterday’s free roll · keep it for \(price) →") }
        if let days = earnDays { return Text("Earn it in the Book · \(days) days →") }
        if store.trialsLeft(film) > 0 { return Text("Try it · \(store.trialsLeft(film)) free shots →") }
        if let price = store.price(film) { return Text("Buy \(price) →") }
        return Text("Prices couldn't be loaded. Check the connection and tap to try again.")
    }
}

/// A paper tag's writing, by hand.
private struct Tag: View {
    @Environment(\.bagBoost) private var boost
    enum Ink { case pencil, red, muted, price }
    let text: Text
    let ink: Ink
    let size: CGSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            text
                // Shown small, the tag carries its state alone, written larger.
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
                            // Pinch or double-tap to look closer; full size.
                            ZoomablePicture { AssetThumbnail(id: id, side: 4096, fill: false) }.tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
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
struct AssetThumbnail: View {
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
    @Environment(\.bagBoost) private var b
    @ObservedObject private var store = FilmStore.shared
    let s: CGFloat
    let buy: () -> Void

    var body: some View {
        let r = RollLibrary.card.scaled(s)
        VStack(alignment: .leading, spacing: 6 * s) {
            Text("All films").font(.custom("American Typewriter", size: 36 * s * b).weight(.semibold))
            // Small (outer screen): the subtitle itself says what it doesn't cover.
            (b.isCompactBag ? Text("Every film for sale, yours to keep") : Text("Every film, yours to keep"))
                .font(.custom("American Typewriter", size: 22 * s * b).weight(.semibold))
            if !b.isCompactBag {
                Text("Every film for sale, now and later, in one purchase. Limited rolls come only from the Book.")
                    .font(.custom("American Typewriter", size: 18 * s))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: buy) {
                action.font(.custom("Marker Felt", size: 25 * s * b))
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
        .padding(.leading, 228 * s).padding(.trailing, 64 * s).padding(.top, 40 * s).padding(.bottom, 8 * s)
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

/// A picture that can be looked at closely: pinch to zoom (up to 5×),
/// double-tap for 2.5× and back, drag about while zoomed. At 1× the
/// surrounding pages swipe as usual.
private struct ZoomablePicture<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var scale: CGFloat = 1
    @State private var settledScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            content()
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(MagnifyGesture()
                    .onChanged { value in scale = min(max(settledScale * value.magnification, 1), 5) }
                    .onEnded { _ in
                        settledScale = scale
                        if scale <= 1.01 { reset() } else { clamp(in: geo.size) }
                    })
                .simultaneousGesture(DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        guard scale > 1 else { return }
                        offset = CGSize(width: settledOffset.width + value.translation.width,
                                        height: settledOffset.height + value.translation.height)
                    }
                    .onEnded { _ in if scale > 1 { clamp(in: geo.size) } },
                    including: scale > 1 ? .all : .subviews)
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        if scale > 1 { reset() } else { scale = 2.5; settledScale = 2.5 }
                    }
                }
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            scale = 1; settledScale = 1; offset = .zero; settledOffset = .zero
        }
    }

    /// Keeps the zoomed picture over the screen: no dragging it off.
    private func clamp(in size: CGSize) {
        let maxX = size.width * (scale - 1) / 2, maxY = size.height * (scale - 1) / 2
        withAnimation(.easeOut(duration: 0.2)) {
            offset = CGSize(width: min(max(offset.width, -maxX), maxX), height: min(max(offset.height, -maxY), maxY))
        }
        settledOffset = offset
    }
}

// MARK: - Turning pages

/// The bag's pairs of pages, in the order of their index tabs.
enum Spread: Int, CaseIterable, Identifiable {
    case films, kit, book
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .films: String(ui: "Films")
        case .kit: String(ui: "Kit")
        case .book: String(ui: "Book")
        }
    }
}

/// A rectangle cut out of a page (a rounded one for a turning board).
struct PageCut: Shape {
    let rect: CGRect
    let radius: CGFloat
    func path(in _: CGRect) -> Path { Path(roundedRect: rect, cornerRadius: radius) }
}

/// A page during a turn. The board turns about the spine (the bag's middle)
/// as one rigid piece: its front goes up to edge-on in the first half, then
/// its back — the next pair's page on that side — comes down in the second.
/// The pages under it darken where it shades them.
struct PageTurn: ViewModifier, Animatable {
    enum Role { case still, hidden, leafOut, leafIn, covered, revealed }
    var progress: Double
    let role: Role
    let left: Bool
    /// The part of the bag this page is.
    let cut: PageCut
    /// The board's edge at the spine, which it turns about.
    let hinge: UnitPoint

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let p = min(max(progress, 0), 1)
        // Lifting the right page turns it about its left edge, towards the
        // viewer; a left page turns the other way.
        let side: Double = left ? 1 : -1
        let angle: Double, shade: Double, shown: Bool
        switch role {
        case .still: angle = 0; shade = 0; shown = true
        case .hidden: angle = 0; shade = 0; shown = false
        case .leafOut: angle = side * 180 * p; shade = 0.55 * min(p * 2, 1); shown = p < 0.5
        // Past edge-on the board keeps coming over towards the viewer, so its
        // free edge, near and large, shrinks back down as it lands.
        case .leafIn: angle = side * 180 * (1 - p); shade = 0.45 * min((1 - p) * 2, 1); shown = p >= 0.5
        // The turning board's shadow on the pages under it: deepest while it
        // stands up near them, gone again by the time the turn ends.
        case .covered: angle = 0; shade = 0.4 * sin(.pi * min(max((p - 0.35) / 0.65, 0), 1)); shown = true
        case .revealed: angle = 0; shade = 0.4 * sin(.pi * min(max(p / 0.65, 0), 1)) * (p < 0.5 ? 1 : 0.6); shown = true
        }
        return content
            .overlay { Color.black.opacity(shade).allowsHitTesting(false) }
            .clipShape(cut)
            // Drawn on the whole bag, but only its own half takes touches:
            // otherwise the right page would swallow the belt's taps.
            .contentShape(cut)
            // A page lying still gets no projection at all: a perspective
            // transform, even at no angle, can keep touches from the belt.
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), anchor: hinge,
                              perspective: role == .leafOut || role == .leafIn ? 0.35 : 0)
            .opacity(shown ? 1 : 0)
    }
}

// MARK: - Small screens

/// How much larger the bag's writing is drawn than its picture, so it stays
/// readable where the whole bag is shown small (over the closed camera, on
/// an upright iPhone): 1 on the inner screen, up to 1.6 on small screens.
struct BagBoostKey: EnvironmentKey { static let defaultValue: CGFloat = 1 }
extension EnvironmentValues {
    var bagBoost: CGFloat {
        get { self[BagBoostKey.self] }
        set { self[BagBoostKey.self] = newValue }
    }
}
extension CGFloat {
    /// The bag shown small: long writing gives way to the essentials.
    var isCompactBag: Bool { self > 1.15 }
}
