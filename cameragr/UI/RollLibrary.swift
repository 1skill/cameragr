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
    static let hint = CGRect(x: 120, y: 946, width: 410, height: 34)
    /// The left page's velvet: a belt of cradles, two to a row, that slides up
    /// and down under the page's fixed stitched frame, so any number of rolls
    /// fits. Its rows are pieces of the bag's own picture: the first row with
    /// the page's top, then the second row repeated, then the page's foot.
    static let page = CGRect(x: 26, y: 26, width: 678, height: 972)
    static let rowPitch: CGFloat = 182
    /// Where the belt slides under the fixed pressed band at the page's foot.
    static let beltBottom: CGFloat = 938
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
                // The bag holds pairs of pages, turned with the index tabs on
                // its right edge: the films, the maintenance kit, later the
                // club. Each page is drawn once and placed by the turn.
                page(.films, left: true, s: s) {
                    Image(uiImage: Self.bag).resizable()
                        .frame(width: Self.art.width * s, height: Self.art.height * s)
                    belt(film: film, s: s)
                }
                page(.films, left: false, s: s) {
                    Image(uiImage: Self.bag).resizable()
                        .frame(width: Self.art.width * s, height: Self.art.height * s)
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
                    }
                    cardRoll(film: film, s: s)
                }
                page(.kit, left: true, s: s) {
                    Image(uiImage: KitArt.spread).resizable()
                        .frame(width: Self.art.width * s, height: Self.art.height * s)
                    KitSwitchPage(s: s)
                }
                page(.kit, left: false, s: s) {
                    Image(uiImage: KitArt.spread).resizable()
                        .frame(width: Self.art.width * s, height: Self.art.height * s)
                    KitHandbookPage(s: s)
                }
                ForEach(flights) { f in
                    let stop = f.stops[f.at]
                    let r = stop.rect, up = stop.lift
                    rollPicture(key: f.key, rect: r.insetBy(dx: -r.width * 0.06 * up, dy: -r.height * 0.06 * up)
                                    .offsetBy(dx: 0, dy: -10 * s * up))
                        .shadow(color: .black.opacity(0.4 + 0.2 * up), radius: (4 + 14 * up) * s, y: (3 + 16 * up) * s)
                        .allowsHitTesting(false)
                }
                indexTabs(s: s)
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
        // A new opening shows the roll in the camera (its stub), on the card
        // its notes and pictures; the belt brings it into view.
        .onAppear {
            if let roll = model.film { scrollTarget = slotOf(roll) }
        }
        #if DEBUG
        // `-look <film id>`: start looking at that roll (for checks).
        .onAppear {
            if let id = UserDefaults.standard.string(forKey: "look") {
                if id == "all" { lookingAll = true } else { looking = model.films.first { $0.id == id } }
                if let looking { scrollTarget = slotOf(looking) }
                if UserDefaults.standard.bool(forKey: "kit") { spread = .kit; turnFrom = .kit }
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
            Tag(text: allFilmsTag, ink: store.ownsAll ? .muted : .price, size: tag.size) { buyAll() }
                .offset(x: tag.minX, y: tag.minY)
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
        if key == "all" { lookingAll = true } else { lookingAll = false; looking = model.films.first { $0.id == key } }
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

    /// What lies on the belt, slot by slot: the first nine films, the
    /// all-films roll in the tenth place, then the rest.
    private var slots: [Film?] {
        let films = model.films
        return Array(films.prefix(9)) + [nil] + Array(films.dropFirst(9))
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
        let height = footY + 30 - Self.page.minY
        ScrollViewReader { reader in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // The velvet: top, repeated rows, foot.
                    Image(uiImage: Self.beltTop).resizable()
                        .frame(width: page.width, height: 210 * s)
                        .offset(x: page.minX, y: page.minY)
                    ForEach(1..<max(rows, 1), id: \.self) { r in
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
                .frame(width: Self.art.width * s, height: (footY + 30) * s, alignment: .topLeading)
                .offset(x: -page.minX, y: -page.minY)
                .frame(width: page.width, height: height * s, alignment: .topLeading)
            }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in beltScroll = y }
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
        // How to use the bag, on the fixed pressed band at the page's foot
        // (the bag's own picture shows there): the belt ends above it.
        (slots.count > 10 ? Text("Tap a roll to look · its tag to choose · close to load · slide for more")
                           : Text("Tap a roll to look · tap its tag to choose · close the phone to load it"))
            .font(.custom("American Typewriter", size: 19 * s))
            .foregroundStyle(Color(white: 0.58))
            .shadow(color: .black.opacity(0.9), radius: 0, x: 0, y: -1 * s)
            .lineLimit(1).minimumScaleFactor(0.5)
            .padding(.horizontal, 16 * s)
            .frame(width: Self.hint.width * s, height: Self.hint.height * s)
            .offset(x: Self.hint.minX * s, y: Self.hint.minY * s)
            .allowsHitTesting(false)
    }

    // MARK: Pages

    /// One page of a pair, cut from the whole bag at the spine (each pair has
    /// its own picture and things), and where the turn puts it.
    private func page(_ pair: Spread, left: Bool, s: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        let role = pageRole(pair, left: left)
        let full = CGSize(width: Self.art.width * s, height: Self.art.height * s)
        let half = CGRect(x: left ? 0 : full.width / 2, y: 0, width: full.width / 2, height: full.height)
        // A turning page is the inner board only; the case round it stays.
        let board = (left ? Self.page : Self.lidPage).scaled(s)
        let leaf = role == .leafOut || role == .leafIn
        return ZStack(alignment: .topLeading) { content() }
            .frame(width: full.width, height: full.height, alignment: .topLeading)
            .modifier(PageTurn(progress: turn, role: role, left: left,
                               cut: PageCut(rect: leaf ? board : half, radius: leaf ? 30 * s : 0)))
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

    /// The leather index tabs riveted to the bag's right edge, one per pair
    /// of pages; the open one stands out a little further and lighter.
    static let indexTab = UIImage(named: "index_tab") ?? UIImage()
    static let tabYs: [CGFloat] = [318, 500]

    private func indexTabs(s: CGFloat) -> some View {
        ForEach(Spread.allCases) { pair in
            let open = pair == spread
            let w: CGFloat = 72, h: CGFloat = 165
            Image(uiImage: Self.indexTab).resizable()
                .frame(width: w * s, height: h * s)
                .brightness(open ? 0.05 : -0.1)
                .overlay { tabWord(pair.title, open: open, s: s) }
                .shadow(color: .black.opacity(0.55), radius: 4 * s, x: -2 * s, y: 2 * s)
                .frame(width: max(w * s, 44), height: h * s)
                .contentShape(Rectangle())
                .onTapGesture { turnTo(pair) }
                .offset(x: (open ? 1384 : 1396) * s, y: Self.tabYs[pair.rawValue] * s)
                .animation(.easeInOut(duration: 0.2), value: open)
                .accessibilityElement()
                .accessibilityLabel(Text(verbatim: pair.title))
                .accessibilityAddTraits(open ? [.isButton, .isSelected] : .isButton)
        }
    }

    /// Pressed into the leather: Chinese, Japanese and Korean stack down the
    /// tab, other languages run along it.
    @ViewBuilder private func tabWord(_ word: String, open: Bool, s: CGFloat) -> some View {
        Group {
            if word.unicodeScalars.allSatisfy({ $0.value >= 0x2E80 }) {
                Text(verbatim: word.map(String.init).joined(separator: "\n"))
                    .font(.custom("American Typewriter", size: 26 * s).weight(.semibold))
                    .multilineTextAlignment(.center).lineSpacing(-2 * s)
                    .minimumScaleFactor(0.6)
            } else {
                Text(verbatim: word.uppercased())
                    .font(.custom("American Typewriter", size: 22 * s).weight(.semibold))
                    .tracking(2 * s)
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(90))
            }
        }
        .foregroundStyle(Color(red: 0.95, green: 0.86, blue: 0.70).opacity(open ? 0.95 : 0.65))
        .shadow(color: .black.opacity(0.7), radius: 0, y: -1 * s)
        .offset(x: 5 * s)
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
                Text(note.about).font(.custom("American Typewriter", size: 16 * s))
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
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
        // Right of the well where the roll lies.
        .padding(.leading, 228 * s).padding(.trailing, 30 * s).padding(.top, 40 * s).padding(.bottom, 38 * s)
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
        .padding(.leading, 228 * s).padding(.trailing, 30 * s).padding(.top, 40 * s).padding(.bottom, 8 * s)
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
    case films, kit
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .films: String(localized: "Films")
        case .kit: String(localized: "Kit")
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
        case .leafIn: angle = -side * 180 * (1 - p); shade = 0.45 * min((1 - p) * 2, 1); shown = p >= 0.5
        case .covered: angle = 0; shade = 0.5 * max(0, (p - 0.45) / 0.55); shown = true
        case .revealed: angle = 0; shade = 0.5 * max(0, 1 - p / 0.6); shown = true
        }
        return content
            .overlay { Color.black.opacity(shade).allowsHitTesting(false) }
            .clipShape(cut)
            // Drawn on the whole bag, but only its own half takes touches:
            // otherwise the right page would swallow the belt's taps.
            .contentShape(cut)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), anchor: .center, perspective: 0.35)
            .opacity(shown ? 1 : 0)
    }
}
