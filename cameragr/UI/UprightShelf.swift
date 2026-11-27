import Photos
import SwiftUI

/// What a roll's strip and card say, and the one action the card leads to.
@MainActor enum RollStatus {
    enum Ink { case pencil, red, muted, price }

    /// The one state under a roll on the shelf: in the camera, yours, free
    /// today, trial shots left, or its price.
    static func strip(_ roll: Film, model: CameraModel, store: FilmStore) -> (text: Text, ink: Ink) {
        if roll == model.film { return (Text("In camera"), .muted) }
        if roll == model.readyToLoad { return (Text("Next roll"), .red) }
        if store.awaitingApproval.contains(FilmStore.productID(roll)) { return (Text("Awaiting approval"), .pencil) }
        if roll.isLimited, !store.owns(roll) { return (Text("Community only"), .pencil) }
        if store.owns(roll) { return (roll.free == true ? Text("Free") : Text("Yours"), .pencil) }
        if store.isFreeToday(roll) { return (Text("Free today"), .red) }
        let left = store.trialsLeft(roll)
        if left > 0 { return (Text("\(left) trials left"), .pencil) }
        if let price = store.price(roll) { return (Text(verbatim: price), .price) }
        return (Text(verbatim: "—"), .muted)
    }

    /// The card's one button: try it, buy it, or load it.
    static func primary(_ film: Film, model: CameraModel, store: FilmStore) -> Text {
        if store.awaitingApproval.contains(FilmStore.productID(film)) { return Text("Purchase waiting for approval") }
        let canShoot = store.isUnlocked(film) || store.trialsLeft(film) > 0
        if film == model.film, canShoot { return Text("In the camera") }
        if film == model.readyToLoad || store.isUnlocked(film) { return Text("Load into camera") }
        if store.trialsLeft(film) > 0 { return Text("Try it (\(store.trialsLeft(film)) left)") }
        if film.isLimited, let days = film.earnDays { return Text("Earn it in the Community · \(days) days →") }
        if let price = store.price(film) { return Text("Buy it · \(price)") }
        return Text("Tap to load the price")
    }

    /// Buying it outright is offered next to "try" and "free today" too.
    static func buyOutright(_ film: Film, store: FilmStore) -> String? {
        if store.awaitingApproval.contains(FilmStore.productID(film)) { return nil }
        if store.isFreeToday(film), !store.owns(film) { return store.price(film) }
        guard !store.isUnlocked(film), store.trialsLeft(film) > 0 else { return nil }
        return store.price(film)
    }

    static func color(_ ink: Ink) -> Color {
        switch ink {
        case .pencil: return Color(red: 0.18, green: 0.17, blue: 0.16)
        case .red: return Color(red: 0.72, green: 0.12, blue: 0.10)
        case .muted: return Color(red: 0.42, green: 0.39, blue: 0.34)
        case .price: return Color(red: 0.12, green: 0.25, blue: 0.55)
        }
    }
}

/// The films page on an upright iPhone (research_notes/胶卷选择页调研.md, user
/// 11/27): one large picture on top — the same scene through whichever roll
/// is chosen, with a handle to drag between the original and the roll — or
/// the user's own pictures on that roll; below it the rolls on four leather
/// shelves by kind, each in a velvet cradle with one narrow paper strip
/// (name and ISO, and its one state). Tap a roll to choose it; tap it again
/// and its strip opens into a small card over the picture's foot with one
/// button. Buying every film is one brass plate under the shelves; the long
/// brass window at the foot. All art is GPT's (design/films_shelf/).
struct UprightFilms: View {
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared
    @ObservedObject private var language = AppLanguage.shared
    @ObservedObject private var shots = ShotLog.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    let start: CameraModel.BagOpening
    let size: CGSize
    @Binding var looking: Film?
    let goPage: (Spread) -> Void

    /// The chosen roll's strip opened into its card.
    @State private var opened = false
    /// "My photos" instead of the samples.
    @State private var mine = false
    @State private var scene = 0
    @State private var mineIndex = 0
    /// The roll flying into the camera.
    @State private var loading: Film?
    @State private var viewing: RollLibrary.Viewing?
    @State private var own: OwnPhoto?
    @State private var access = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    /// The user's pictures on this roll that are still in Photos.
    @State private var shown: [String] = []
    @AppStorage("seenNewFilms") private var seenNew = ""

    static let ink = Color(red: 0.16, green: 0.13, blue: 0.10)
    static let muted = Color(red: 0.42, green: 0.39, blue: 0.34)
    static let cream = Color(red: 0.93, green: 0.89, blue: 0.80)

    static let velvet: UIImage = {
        guard let cg = RollLibrary.velvet.cgImage else { return RollLibrary.velvet }
        return UIImage(cgImage: cg, scale: 3, orientation: .up)
    }()

    // MARK: Art (GPT parts sheet design/films_shelf/parts_sheet_gpt.png, cut with tools/cut_parts.swift)

    /// A picture stretched sideways between its ends, at `height` points.
    static func strip(_ name: String, height: CGFloat, ends: CGFloat) -> UIImage {
        guard let picture = UIImage(named: name), let cg = picture.cgImage else { return UIImage() }
        let scale = CGFloat(cg.height) / height
        let sized = UIImage(cgImage: cg, scale: scale, orientation: .up)
        return sized.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: ends / scale, bottom: 0, right: ends / scale),
                                    resizingMode: .stretch)
    }
    static let cradle = UIImage(named: "shelf_cradle") ?? UIImage()
    static let cradleLit = UIImage(named: "shelf_cradle_lit") ?? UIImage()
    static let divider = UIImage(named: "shelf_divider") ?? UIImage()
    static let tab = UIImage(named: "shelf_tab") ?? UIImage()
    static let card = UIImage(named: "film_card") ?? UIImage()
    /// The red leather button plate on the card (film_card.png pixels, 779 × 289).
    static let cardButton = CGRect(x: 519.0 / 779, y: 183.0 / 289, width: 238.0 / 779, height: 87.0 / 289)
    static let handle = (rest: UIImage(named: "compare_handle") ?? UIImage(), held: UIImage(named: "compare_handle_down") ?? UIImage())

    /// The scenes every roll is shown on, the same whichever roll is chosen, so
    /// rolls can be compared (AI originals; the app renders each roll itself).
    static let sceneFiles = ["portra400_1", "kodachrome64_1", "cine500t_1", "c200_3", "gold200_1"]
    static var scenes: [FilmNote.Sample] {
        let all = FilmNotes.all.values.flatMap(\.samples)
        return sceneFiles.compactMap { file in all.first { $0.file == file } }
    }

    // MARK: Layout

    private var film: Film { looking ?? start.look ?? model.readyToLoad ?? model.film ?? model.films[0] }
    private var tall: Bool { size.height / size.width > 2.0 }
    private var topInset: CGFloat { tall ? 59 : 20 }
    private var bottomInset: CGFloat { tall ? 30 : 6 }
    private let pad: CGFloat = 12
    static let columns = 5
    private var inner: CGFloat { size.width - 2 * pad }
    private var slotW: CGFloat { inner / CGFloat(Self.columns) }
    private var cradleW: CGFloat { slotW - 6 }
    private var cradleH: CGFloat { cradleW * 242 / 466 }
    private let labelH: CGFloat = 27
    private let lipH: CGFloat = 11
    private let lift: CGFloat = 5
    private var rowH: CGFloat { lift + cradleH + 1 + labelH + lipH }
    private let rowGap: CGFloat = 3
    private let tabsH: CGFloat = 40
    private var plateH: CGFloat { max(30, inner * 73 / 824) }
    private var dialH: CGFloat {
        max(44, inner * PageDial.window.size.height / max(PageDial.window.size.width, 1))
    }
    private var shelvesH: CGFloat {
        let n = CGFloat(min(rows.count, 4))
        return n * rowH + max(0, n - 1) * rowGap
    }
    /// What the picture gets: the rest, at most 5 : 4.
    private var photoH: CGFloat {
        let rest = size.height - topInset - bottomInset - tabsH - shelvesH - plateH - dialH - 6 * 6
        return max(120, min(rest, inner / 1.25))
    }

    /// One shelf board: up to five rolls, and where each kind starts on it.
    struct Row: Identifiable {
        let id: Int
        var films: [Film] = []
        var starts: [Int: Film.Shelf] = [:]
    }

    /// The rolls by kind, five to a board. A kind starts a board of its own
    /// unless it fits in what is left of the one before (slides and black and
    /// white share one, a divider between them).
    static func rows(_ films: [Film], columns: Int = columns) -> [Row] {
        var rows: [Row] = []
        for kind in Film.Shelf.allCases {
            var group = films.filter { $0.shelfKind == kind }
            guard !group.isEmpty else { continue }
            if var last = rows.last, !last.films.isEmpty, columns - last.films.count >= group.count {
                last.starts[last.films.count] = kind
                last.films += group
                rows[rows.count - 1] = last
                continue
            }
            var first = true
            while !group.isEmpty {
                var row = Row(id: rows.count)
                row.films = Array(group.prefix(columns))
                if first { row.starts[0] = kind; first = false }
                group.removeFirst(row.films.count)
                rows.append(row)
            }
        }
        return rows
    }
    private var rows: [Row] { Self.rows(model.films) }

    // MARK: Body

    var body: some View {
        ZStack {
            Image(uiImage: Self.velvet).resizable(resizingMode: .tile).ignoresSafeArea()
            VStack(spacing: 6) {
                // What the picture can't use is shared above it and above the shelves.
                Spacer(minLength: 0)
                photo
                tabs
                Spacer(minLength: 0)
                shelves
                plate
                dial
            }
            .padding(.horizontal, pad)
            .padding(.top, topInset)
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
        .onAppear {
            refresh()
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "filmCard") { var t = Transaction(); t.disablesAnimations = true; withTransaction(t) { opened = true } }
            if UserDefaults.standard.bool(forKey: "filmsMine") { mine = true }
            #endif
        }
        .onChange(of: film) { _, _ in mineIndex = 0; refresh() }
        .onChange(of: shots.assets(for: film.id)) { _, _ in refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        .accessibilityIdentifier("upright-films")
    }

    // MARK: The picture

    private var photo: some View {
        ZStack(alignment: .bottom) {
            Group {
                if mine { minePicture } else { samplePicture }
            }
            .frame(width: inner, height: photoH)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.6), radius: 5, y: 3)
            if opened { filmCard.transition(.asymmetric(insertion: .scale(scale: 0.2, anchor: .bottom).combined(with: .opacity),
                                                        removal: .opacity)) }
        }
        .frame(width: inner, height: photoH)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: opened)
    }

    @ViewBuilder private var samplePicture: some View {
        let scenes = Self.scenes
        if scenes.isEmpty {
            RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.4))
        } else {
            SceneCompare(film: film, sample: scenes[scene % scenes.count], handle: Self.handle)
        }
    }

    @ViewBuilder private var minePicture: some View {
        let assets = shots.assets(for: film.id)
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.45))
            if !shown.isEmpty {
                let i = min(mineIndex, shown.count - 1)
                AssetThumbnail(id: shown[i], side: 1400, fill: true)
                    .contentShape(Rectangle())
                    .onTapGesture { viewing = RollLibrary.Viewing(film: film, index: i, assets: shown) }
                    .accessibilityElement()
                    .accessibilityIdentifier("album-photo")
                    .accessibilityAddTraits([.isButton, .isImage])
                // Another photo of one's own through the roll, any time.
                trySlip
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
            } else if !assets.isEmpty, !canRead {
                Button(action: askPhotos) {
                    (access == .notDetermined ? Text("Tap here to let Koco see your pictures") : Text("Allow Photos in Settings to see them"))
                        .font(.custom("American Typewriter", size: 15)).foregroundStyle(Self.cream)
                        .multilineTextAlignment(.center).padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 14) {
                    Text("No pictures on \(film.name) yet")
                        .font(.custom("American Typewriter", size: 16).weight(.semibold))
                    Text("Try one of your own photos through it:")
                        .font(.custom("American Typewriter", size: 13))
                        .foregroundStyle(Self.cream.opacity(0.75))
                    trySlip
                }
                .foregroundStyle(Self.cream)
                .multilineTextAlignment(.center)
                .padding(16)
            }
        }
    }

    private var canRead: Bool { access == .authorized || access == .limited }

    /// "Try my photo": the kraft slip from the landscape bag, in a box of its own size.
    private var trySlip: some View {
        let r = TryMyPhotoSlip.place, k: CGFloat = 0.72
        let lift = max(0, 44 - r.height * k) / 2
        return ZStack(alignment: .topLeading) {
            TryMyPhotoSlip(film: film, s: k) { own = $0 }
                .offset(x: -r.minX * k, y: -(r.minY * k - lift))
        }
        .frame(width: r.width * k, height: max(44, r.height * k), alignment: .topLeading)
    }

    // MARK: Samples / My photos, and which picture

    private var tabs: some View {
        let count = mine ? shown.count : Self.scenes.count
        let index = mine ? min(mineIndex, max(0, count - 1)) : scene % max(count, 1)
        return HStack(spacing: 6) {
            tabButton(Text("Sample shots"), on: !mine) { mine = false }
            tabButton(Text("My photos"), on: mine) { mine = true; refresh() }
            Spacer(minLength: 4)
            if count > 1 {
                stepButton("chevron.left", label: Text("Previous picture")) { step(-1, count) }
                Text(verbatim: "\(index + 1) / \(count)")
                    .font(.custom("American Typewriter", size: 14))
                    .foregroundStyle(Self.cream.opacity(0.85))
                    .monospacedDigit()
                stepButton("chevron.right", label: Text("Next picture")) { step(1, count) }
            }
        }
        .frame(height: tabsH)
    }

    private func tabButton(_ title: Text, on: Bool, tap: @escaping () -> Void) -> some View {
        Button {
            Haptic.click()
            tap()
        } label: {
            title
                .font(.custom("American Typewriter", size: 14).weight(on ? .bold : .regular))
                .foregroundStyle(Self.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .frame(minWidth: 84, minHeight: 30)
                .background(Image(uiImage: Self.tab).resizable())
                .opacity(on ? 1 : 0.55)
                .offset(y: on ? -2 : 0)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    private func stepButton(_ symbol: String, label: Text, tap: @escaping () -> Void) -> some View {
        Button {
            Haptic.click()
            tap()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Self.cream.opacity(0.85))
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func step(_ by: Int, _ count: Int) {
        guard count > 0 else { return }
        if mine { mineIndex = (min(mineIndex, count - 1) + by + count) % count }
        else { scene = (scene % count + by + count) % count }
    }

    // MARK: The card

    private var filmCard: some View {
        let w = inner, h = inner * Self.card.size.height / max(Self.card.size.width, 1)
        let b = Self.cardButton
        let note = FilmNotes.all[film.id]
        let shelfName = Self.shelfName(film.shelfKind)
        return ZStack(alignment: .topLeading) {
            Image(uiImage: Self.card).resizable()
                .frame(width: w, height: h)
                .contentShape(Rectangle())
                .onTapGesture { opened = false }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: film.name)
                        .font(.custom("American Typewriter", size: 17).weight(.semibold))
                    (Text(verbatim: "ISO \(film.iso) · ") + shelfName)
                        .font(.custom("American Typewriter", size: 11))
                        .foregroundStyle(Self.muted)
                }
                .lineLimit(1).minimumScaleFactor(0.7)
                if let note {
                    Text(note.tagline)
                        .font(.custom("American Typewriter", size: 13).weight(.semibold))
                        .lineLimit(2).minimumScaleFactor(0.75)
                    if !note.suits.isEmpty {
                        Text("Good for: \(note.suits.joined(separator: " · "))")
                            .font(.custom("American Typewriter", size: 12))
                            .foregroundStyle(Self.muted)
                            .lineLimit(2).minimumScaleFactor(0.75)
                    }
                }
                if let price = RollStatus.buyOutright(film, store: store) {
                    Button(action: buyOutright) {
                        Text("or buy it · \(price)")
                            .font(.custom("American Typewriter", size: 12).weight(.semibold)).underline()
                            .frame(minHeight: 30, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(store.purchasing != nil)
                }
            }
            .foregroundStyle(Self.ink)
            .padding(.top, h * 0.13)
            .padding(.leading, w * 0.06)
            .frame(width: w * (b.minX - 0.07), alignment: .leading)
            .frame(maxHeight: h * 0.95, alignment: .top)
            Button(action: primary) {
                RollStatus.primary(film, model: model, store: store)
                    .font(.custom("American Typewriter", size: 14).weight(.bold))
                    .foregroundStyle(Self.cream)
                    .multilineTextAlignment(.center)
                    .lineLimit(2).minimumScaleFactor(0.55)
                    .padding(.horizontal, 6)
                    .frame(width: b.width * w, height: max(44, b.height * h))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(store.purchasing != nil)
            .offset(x: b.minX * w, y: b.midY * h - max(44, b.height * h) / 2)
            .accessibilityIdentifier("card-action")
        }
        .frame(width: w, height: h)
        .shadow(color: .black.opacity(0.55), radius: 5, y: 3)
        .accessibilityElement(children: .contain)
    }

    static func shelfName(_ shelf: Film.Shelf) -> Text {
        switch shelf {
        case .neg: return Text("Colour negative")
        case .slide: return Text("Slide film")
        case .bw: return Text("Black & white")
        case .instant: return Text("Instant · Digital")
        }
    }

    // MARK: The shelves

    @ViewBuilder private var shelves: some View {
        let content = VStack(spacing: rowGap) {
            ForEach(rows) { row in shelf(row) }
        }
        if rows.count > 4 {
            ScrollView(.vertical, showsIndicators: false) { content }
                .frame(height: shelvesH)
        } else {
            content.frame(height: shelvesH)
        }
    }

    private func shelf(_ row: Row) -> some View {
        let lip = Self.strip("shelf_lip", height: lipH, ends: 40)
        return ZStack(alignment: .bottomLeading) {
            Image(uiImage: lip).resizable()
                .frame(width: inner, height: lipH)
                .shadow(color: .black.opacity(0.6), radius: 2, y: 2)
            HStack(spacing: 0) {
                ForEach(Array(row.films.enumerated()), id: \.element.id) { _, roll in
                    slot(roll)
                }
                Spacer(minLength: 0)
            }
            .frame(width: inner, height: rowH - lipH, alignment: .bottomLeading)
            .offset(y: -lipH)
            // A thin board between two kinds on one shelf.
            ForEach(row.starts.keys.filter { $0 > 0 }.sorted(), id: \.self) { i in
                Image(uiImage: Self.divider).resizable()
                    .frame(width: 5, height: rowH - lift - 2)
                    .offset(x: CGFloat(i) * slotW - 2.5, y: -2)
                    .allowsHitTesting(false)
            }
            // Each kind's cloth tab on the board's edge, under its first roll.
            ForEach(row.starts.keys.sorted(), id: \.self) { i in
                if let kind = row.starts[i] {
                    Self.shelfName(kind)
                        .font(.custom("American Typewriter", size: 8.5).weight(.semibold))
                        .foregroundStyle(Self.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, 7)
                        .frame(height: 14)
                        .background(Image(uiImage: Self.tab).resizable())
                        .offset(x: CGFloat(i) * slotW + 4, y: 1.5)
                        .allowsHitTesting(false)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .frame(width: inner, height: rowH, alignment: .bottomLeading)
    }

    private func slot(_ roll: Film) -> some View {
        let chosen = roll == film
        let status = RollStatus.strip(roll, model: model, store: store)
        let flying = loading == roll
        let label = Self.strip("shelf_label", height: labelH, ends: 34)
        return Button { tap(roll) } label: {
            VStack(spacing: 1) {
                ZStack {
                    Image(uiImage: chosen ? Self.cradleLit : Self.cradle).resizable()
                    Canister(film: roll, fill: true)
                        .frame(width: cradleH * 0.62, height: cradleW * 0.86)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
                        .offset(y: flying ? -size.height * 0.55 : 0)
                        .scaleEffect(flying ? 0.6 : 1)
                        .opacity(flying ? 0 : 1)
                    if roll.new == true, !seen(roll) {
                        Circle().fill(Color(red: 0.86, green: 0.16, blue: 0.12))
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 0.5))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(2)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: cradleW, height: cradleH)
                .offset(y: chosen ? -lift : 0)
                .shadow(color: chosen ? Color(red: 1, green: 0.75, blue: 0.4).opacity(0.45) : .clear, radius: 6)
                VStack(spacing: 0) {
                    Text(verbatim: Self.nameLine(roll))
                        .font(.custom("American Typewriter", size: 9.5).weight(.bold))
                        .foregroundStyle(Self.ink)
                    status.text
                        .font(.custom("American Typewriter", size: 9).weight(.semibold))
                        .foregroundStyle(RollStatus.color(status.ink))
                }
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, 4)
                .frame(width: cradleW, height: labelH)
                .background(Image(uiImage: label).resizable())
            }
            .frame(width: slotW, height: rowH - lipH, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: Self.nameLine(roll)) + Text(verbatim: ", ") + status.text)
        .accessibilityHint(chosen ? Text("Tap again for its card") : Text(""))
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
    }

    /// Its name, with the speed when the name doesn't already say it.
    static func nameLine(_ roll: Film) -> String {
        roll.name.contains(String(roll.iso)) ? roll.name : "\(roll.name) \(roll.iso)"
    }

    // MARK: Every film

    private var plate: some View {
        Button(action: buyAll) {
            plateText
                .font(.custom("American Typewriter", size: 13).weight(.bold))
                .foregroundStyle(Color(red: 0.22, green: 0.16, blue: 0.07))
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, 26)
                .frame(width: inner, height: plateH)
                .background(Image(uiImage: Self.strip("allfilms_plate", height: plateH, ends: 50)).resizable())
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1.5)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.ownsAll || store.purchasing != nil)
        .accessibilityIdentifier("all-films")
    }

    private var plateText: Text {
        if store.ownsAll { return Text("Every film for sale is yours") }
        if store.awaitingApproval.contains(FilmStore.allFilmsID) { return Text("Purchase waiting for approval") }
        if let price = store.allFilmsPrice { return Text("Every film for sale · \(price)") }
        return Text("Every film for sale · tap to load the price")
    }

    // MARK: The window

    private var dial: some View {
        let s = inner / PageDial.rect.width
        let h = inner * PageDial.window.size.height / max(PageDial.window.size.width, 1)
        return PageDial(spread: .films, s: s, choose: { goPage($0) }, camera: { goCamera() },
                        placed: false, labelSize: 15)
            .frame(width: inner, height: h, alignment: .topLeading)
            .frame(height: max(h, 44))
    }

    // MARK: Actions

    private func seen(_ roll: Film) -> Bool { seenNew.split(separator: ",").contains(Substring(roll.id)) }

    /// First tap chooses a roll (the picture turns to it); a second opens its card.
    private func tap(_ roll: Film) {
        Haptic.click()
        if roll.new == true, !seen(roll) { seenNew = (seenNew.isEmpty ? "" : seenNew + ",") + roll.id }
        if roll == film { opened.toggle(); return }
        looking = roll
        opened = false
    }

    private func goCamera() {
        Haptic.click()
        model.lookedAt = nil
        model.leaveBag()
    }

    /// The roll goes in: it lifts off its shelf, and the bag is put away.
    private func load(_ roll: Film) {
        model.chooseInLibrary(roll)
        withAnimation(.easeIn(duration: 0.3)) { loading = roll }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            loading = nil
            guard model.bag != nil, model.readyToLoad != nil else { return }
            model.closeBag()
        }
    }

    /// The card's one button: load it (or try it), earn it, or buy it.
    private func primary() {
        let roll = film
        if store.awaitingApproval.contains(FilmStore.productID(roll)) { Haptic.click(); return }
        let canShoot = store.isUnlocked(roll) || store.trialsLeft(roll) > 0
        if roll == model.film, canShoot { Haptic.click(); return }
        if roll == model.readyToLoad || canShoot {
            load(roll)
        } else if roll.isLimited {
            goPage(.club)   // earned there, never sold
        } else if store.price(roll) != nil {
            Task { if await store.buy(roll) { Haptic.stop(); load(roll) } }
        } else {
            Task { await store.loadProductsIfMissing(force: true) }
        }
    }

    private func buyOutright() {
        let roll = film
        Task { if await store.buy(roll) { Haptic.stop(); load(roll) } }
    }

    private func buyAll() {
        guard !store.ownsAll else { Haptic.click(); return }
        if store.awaitingApproval.contains(FilmStore.allFilmsID) { Haptic.click(); return }
        if store.allFilmsPrice == nil { Task { await store.loadProductsIfMissing(force: true) } }
        else { Task { if await store.buy(nil) { Haptic.stop() } } }
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
}

/// One scene through the chosen roll, to drag between the original and the
/// roll. The last picture stays up while the next roll is rendered, so
/// switching rolls changes only the look.
private struct SceneCompare: View {
    let film: Film
    let sample: FilmNote.Sample
    let handle: (rest: UIImage, held: UIImage)
    @State private var pair: (before: UIImage, after: UIImage)?
    @State private var shownFilm = ""

    var body: some View {
        ZStack {
            if let pair {
                CompareView(before: pair.before, after: pair.after, start: sample.split, filmName: shownName,
                            unit: 1, beforeLabel: "AI original", handle: handle)
            } else {
                RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.4))
                ProgressView().tint(.white)
            }
        }
        .task(id: "\(sample.file)|\(film.id)") {
            let key = "\(sample.file)|\(film.id)"
            if let known = SceneRenders.cache[key] { pair = known; shownFilm = film.name; return }
            guard let url = Bundle.main.url(forResource: sample.file, withExtension: "jpg"),
                  let image = CIImage(contentsOf: url) else { return }
            let film = film, iso = sample.iso
            let made = await Task.detached(priority: .userInitiated) { () -> (before: UIImage, after: UIImage)? in
                // Small enough to turn round quickly as rolls are tapped through.
                let longest = max(image.extent.width, image.extent.height)
                let s = min(1, 1400 / max(longest, 1))
                return FilmRendering.pair(image.transformed(by: CGAffineTransform(scaleX: s, y: s)), film: film, iso: iso)
            }.value
            guard !Task.isCancelled, let made else { return }
            SceneRenders.keep(key, made)
            pair = made
            shownFilm = film.name
        }
    }

    private var shownName: String { shownFilm.isEmpty ? film.name : shownFilm }
}

/// The last few scenes rendered, so going back to a roll is instant.
@MainActor private enum SceneRenders {
    static var cache: [String: (before: UIImage, after: UIImage)] = [:]
    private static var order: [String] = []
    static func keep(_ key: String, _ pair: (before: UIImage, after: UIImage)) {
        cache[key] = pair
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > 8 { cache[order.removeFirst()] = nil }
    }
}
