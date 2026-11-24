import AVFoundation
import Photos
import StoreKit
import SwiftUI

/// The maintenance spread: the bag's second pair of pages, turned to with
/// the index tabs (GPT art, kit_spread.jpg from design/kit/kit_spread_template.png,
/// in the bag's own pixels). The left page is for doing — three switches on
/// a plate and the purchase certificate; the right page is for reading — the
/// handbook with its cloth bookmarks and the nameplate.
enum KitArt {
    static let spread = UIImage(named: "kit_spread.jpg") ?? UIImage()
    /// The left board with nothing on it (GPT), under the page set smaller.
    static let board = UIImage(named: "kit_board.jpg") ?? UIImage()
    /// Each row's slider thumb and its lamp lit warm orange, cut from GPT's
    /// drawing of this very plate with the thumbs in its slots
    /// (design/kit/switch/plate4_on.png); the spread carries the same plate
    /// drawn empty (plate4_empty.png), so thumb and slot are one drawing.
    static let thumb = (0..<3).map { UIImage(named: "kit_thumb_\($0)") ?? UIImage() }
    static let languageCard = UIImage(named: "language_card") ?? UIImage()
    static let lampOn = (0..<3).map { UIImage(named: "kit_lamp_on_\($0)") ?? UIImage() }
    static let ink = Color(red: 0.2, green: 0.17, blue: 0.13)
    static let cream = Color(red: 0.93, green: 0.89, blue: 0.80)
}

private extension CGRect {
    func at(_ s: CGFloat) -> CGRect { CGRect(x: minX * s, y: minY * s, width: width * s, height: height * s) }
}

private extension View {
    /// Places a view on the bag at a rect in bag pixels.
    func place(_ r: CGRect, _ s: CGFloat, alignment: Alignment = .center) -> some View {
        let p = r.at(s)
        return frame(width: p.width, height: p.height, alignment: alignment).offset(x: p.minX, y: p.minY)
    }
}

/// The left page: the switch plate and the certificate.
struct KitSwitchPage: View {
    @Environment(\.bagBoost) private var b
    @ObservedObject private var store = FilmStore.shared
    let s: CGFloat
    @State private var saveOriginal = Preferences.saveOriginal
    @State private var shutterSound = Preferences.shutterSound
    @State private var haptics = Haptic.enabled
    @State private var redeeming = false
    /// What the last restore came to, written on the certificate.
    @State private var restoreNote: Text?
    @State private var restoring = false

    /// Measured on the picture (bag pixels): the plate's six rows (GPT,
    /// design/kit/switch/plate6_on.png and plate6_empty.png). Rows 1–3 are
    /// switches (label recess, lamp, slot); rows 4–6 show a value (label
    /// recess, paper window, arrow key): language, camera, photos.
    static let recessY: [CGFloat] = [122, 191, 260, 329.5, 389.5, 449]
    static let recessH: [CGFloat] = [52, 52, 52, 45.5, 45.5, 45.5]
    static let thumbOn: [CGRect] = [CGRect(x: 537, y: 126, width: 84, height: 48),
                                    CGRect(x: 536, y: 195, width: 85, height: 48),
                                    CGRect(x: 536, y: 264, width: 85, height: 47)]
    /// How far the thumb moves to the slot's left end (off): the same gap at either end.
    static let thumbTravel: CGFloat = 46.5
    static let lampOn: [CGRect] = [CGRect(x: 413, y: 110, width: 80, height: 80),
                                   CGRect(x: 414, y: 178, width: 80, height: 80),
                                   CGRect(x: 414, y: 246, width: 80, height: 80)]
    static let windows: [CGRect] = [CGRect(x: 441, y: 331, width: 137, height: 41),
                                    CGRect(x: 441, y: 391, width: 137, height: 41),
                                    CGRect(x: 441, y: 451, width: 137, height: 41)]
    /// The language list: a paper card clipped over the plate (GPT, language_card.png,
    /// 414×606 as stored), and its five ruled rows in the card's own pixels.
    static let card = CGRect(x: 300, y: 70, width: 290, height: 424)
    static let cardRows: [ClosedRange<CGFloat>] = [76.5...186.5, 186.5...274, 274...361.5, 361.5...450.5, 450.5...542.5]
    static let certificateText = CGRect(x: 110, y: 616, width: 500, height: 230)
    static let restore = CGRect(x: 97, y: 860, width: 236, height: 60)
    static let redeem = CGRect(x: 376, y: 860, width: 253, height: 60)

    var body: some View {
        ZStack(alignment: .topLeading) {
            switchRow(0, title: Text("Original"), detail: Text("Save the iPhone original too"), isOn: $saveOriginal) { Preferences.saveOriginal = $0 }
            switchRow(1, title: Text("Shutter sound"), detail: Text("A click when you shoot"), isOn: $shutterSound) { Preferences.shutterSound = $0 }
            switchRow(2, title: Text("Haptics"), detail: Text("A light tap under your finger"), isOn: $haptics) { on in
                Haptic.enabled = on
                if on { Haptic.tap() }
            }
            valueRow(3, title: Text("Language"), detail: Text("Tap to choose"), value: Text(verbatim: languageName)) {
                withAnimation(.easeOut(duration: 0.2)) { choosingLanguage = true }
            }
            valueRow(4, title: Text("Camera"), detail: Text("For the viewfinder"), value: accessWord(camera)) {
                ask(camera: true)
            }
            valueRow(5, title: Text("Photos"), detail: Text("Where your pictures go"), value: accessWord(photos)) {
                ask(camera: false)
            }
            certificate
            if choosingLanguage { languageCard }
        }
        .onAppear {
            readAccess()
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "languages") { choosingLanguage = true }   // `-languages 1`, for checks
            #endif
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { readAccess() } }
        .offerCodeRedemption(isPresented: $redeeming) { _ in Task { await store.refresh() } }
    }
    @ObservedObject private var language = AppLanguage.shared

    private var languageName: String { AppLanguage.name(language.code) }
    @State private var choosingLanguage = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var camera = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var photos = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    /// Camera and Photos as the system has them, read again on every return.
    private func readAccess() {
        camera = AVCaptureDevice.authorizationStatus(for: .video)
        photos = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    private func accessWord(_ status: AVAuthorizationStatus) -> Text {
        switch status {
        case .authorized: Text("Allowed")
        case .notDetermined: Text("Not asked yet")
        default: Text("Not allowed")
        }
    }
    private func accessWord(_ status: PHAuthorizationStatus) -> Text {
        switch status {
        case .authorized: Text("Allowed")
        case .limited: Text("Limited")
        case .notDetermined: Text("Not asked yet")
        default: Text("Not allowed")
        }
    }
    /// Not asked yet: ask now. Otherwise only iOS Settings can change it.
    private func ask(camera isCamera: Bool) {
        if isCamera, camera == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in DispatchQueue.main.async { readAccess() } }
        } else if !isCamera, photos == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in DispatchQueue.main.async { readAccess() } }
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    /// A value row: its name, the value in the paper window; the arrow key
    /// (or the whole row) acts.
    private func valueRow(_ i: Int, title: Text, detail: Text, value: Text, action: @escaping () -> Void) -> some View {
        let w = i - 3
        return ZStack(alignment: .topLeading) {
            rowLabels(i, title: title, detail: detail)
            value
                .font(.custom("American Typewriter", size: 19 * s * b).weight(.semibold))
                .foregroundStyle(KitArt.ink)
                .lineLimit(1).minimumScaleFactor(0.5)
                .padding(.horizontal, 8 * s)
                .place(Self.windows[w], s)
                .allowsHitTesting(false)
            Color.clear.contentShape(Rectangle())
                .place(CGRect(x: 80, y: Self.recessY[i] - 6, width: 560, height: Self.recessH[i] + 12), s)
                .onTapGesture { Haptic.click(); action() }
                .accessibilityElement()
                .accessibilityLabel(title)
                .accessibilityValue(value)
                .accessibilityAddTraits(.isButton)
        }
    }

    /// The languages on a paper card clipped over the plate: tap one to
    /// switch at once; tap anywhere else to put the card away.
    private var languageCard: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.35)
                .frame(width: 1456 * s, height: 1024 * s)
                .offset(x: -200 * s, y: -100 * s)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeIn(duration: 0.15)) { choosingLanguage = false } }
            ZStack(alignment: .topLeading) {
                Image(uiImage: KitArt.languageCard).resizable()
                    .shadow(color: .black.opacity(0.55), radius: 10 * s, y: 6 * s)
                let k = Self.card.width / 414
                ForEach(Array(AppLanguage.all.enumerated()), id: \.offset) { n, code in
                    let band = Self.cardRows[n]
                    let current = code == language.code
                    Button {
                        Haptic.click()
                        withAnimation(.easeInOut(duration: 0.2)) { language.choose(code) }
                        withAnimation(.easeIn(duration: 0.15).delay(0.25)) { choosingLanguage = false }
                    } label: {
                        HStack(spacing: 8 * s) {
                            Text(verbatim: AppLanguage.name(code))
                                .font(.custom("American Typewriter", size: 24 * s * b).weight(current ? .bold : .regular))
                                .foregroundStyle(current ? Color(red: 0.72, green: 0.22, blue: 0.08) : KitArt.ink)
                            Spacer(minLength: 0)
                            if current {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18 * s, weight: .bold))
                                    .foregroundStyle(Color(red: 0.72, green: 0.22, blue: 0.08))
                            }
                        }
                        .padding(.horizontal, 26 * s)
                        .frame(width: Self.card.width * s, height: (band.upperBound - band.lowerBound) * k * s)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .offset(y: band.lowerBound * k * s)
                    .accessibilityAddTraits(current ? .isSelected : [])
                }
            }
            .place(Self.card, s)
            .transition(.scale(scale: 0.92, anchor: .top).combined(with: .opacity))
        }
    }

    private func rowLabels(_ i: Int, title: Text, detail: Text) -> some View {
        VStack(alignment: .leading, spacing: 2 * s) {
            title.font(.custom("American Typewriter", size: 22 * s * b).weight(.semibold))
                .foregroundStyle(Color(white: 0.84))
            if !b.isCompactBag {
                detail.font(.custom("American Typewriter", size: 14 * s * b))
                    .foregroundStyle(Color(white: 0.58))
            }
        }
        .lineLimit(1).minimumScaleFactor(0.55)
        .shadow(color: .black, radius: 0, y: -1 * s)
        .padding(.horizontal, 18 * s)
        .place(CGRect(x: 84, y: Self.recessY[i], width: 334, height: Self.recessH[i]), s, alignment: .leading)
        .allowsHitTesting(false)
    }

    private func switchRow(_ i: Int, title: Text, detail: Text, isOn: Binding<Bool>, apply: @escaping (Bool) -> Void) -> some View {
        let y = Self.recessY[i]
        return ZStack(alignment: .topLeading) {
            rowLabels(i, title: title, detail: detail)
            // The lamp lights; the thumb slides to the slot's other end.
            Image(uiImage: KitArt.lampOn[i]).resizable()
                .place(Self.lampOn[i], s)
                .opacity(isOn.wrappedValue ? 1 : 0)
                .allowsHitTesting(false)
            Image(uiImage: KitArt.thumb[i]).resizable()
                .place(Self.thumbOn[i], s)
                .offset(x: isOn.wrappedValue ? 0 : -Self.thumbTravel * s)
                .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isOn.wrappedValue)
                .allowsHitTesting(false)
            // The whole row is the switch.
            Color.clear.contentShape(Rectangle())
                .place(CGRect(x: 80, y: y - 6, width: 560, height: Self.recessH[i] + 12), s)
                .onTapGesture {
                    isOn.wrappedValue.toggle()
                    apply(isOn.wrappedValue)
                    Haptic.click()
                }
                .accessibilityElement()
                .accessibilityLabel(detail)
                .accessibilityValue(isOn.wrappedValue ? Text("On") : Text("Off"))
                .accessibilityAddTraits(.isButton)
        }
        .animation(.easeOut(duration: 0.1), value: isOn.wrappedValue)
    }

    private var certificate: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 12 * s) {
                Text("Koco film certificate").font(.custom("American Typewriter", size: 21 * s * b)).opacity(0.7)
                (store.ownsAll ? Text("Every film for sale is yours") : Text("\(store.ownedPaidCount) of \(store.paidFilms.count) paid films are yours"))
                    .font(.custom("American Typewriter", size: 34 * s * b).weight(.semibold))
                    .lineLimit(2)
                if !store.ownsAll {
                    Text("Free films and trial shots are always there.").font(.custom("American Typewriter", size: 20 * s * b))
                        .lineLimit(2)
                }
                // What else you can shoot, said the same way as on the tags:
                // today's free roll, and the limited rolls (never sold).
                if let free = store.dailyFreeToday, !store.owns(free) {
                    Text("Free today: \(free.name), as many shots as you like. The pictures stay.")
                        .font(.custom("American Typewriter", size: 18 * s * b)).lineLimit(2)
                }
                Text("Limited rolls are earned in the Book, not bought.")
                    .font(.custom("American Typewriter", size: 18 * s * b)).lineLimit(1).opacity(0.75)
                if let restoreNote {
                    restoreNote.font(.custom("Marker Felt", size: 22 * s * b))
                        .foregroundStyle(Color(red: 0.72, green: 0.12, blue: 0.10))
                        .lineLimit(2)
                }
            }
            .foregroundStyle(KitArt.ink)
            .minimumScaleFactor(0.6)
            .place(Self.certificateText, s, alignment: .topLeading)
            .allowsHitTesting(false)
            printedBox(restoring ? Text("Restoring…") : Text("Restore purchases"), Self.restore) {
                guard !restoring else { return }
                restoring = true
                restoreNote = nil
                Task {
                    let before = store.ownedPaidCount
                    let reached = await store.restore()
                    restoring = false
                    restoreNote = !reached ? Text("The App Store could not be reached. Try again later.")
                        : store.ownedPaidCount > before ? Text("Purchases restored.")
                        : Text("No other purchases on this Apple ID.")
                }
            }
            printedBox(Text("Redeem a code"), Self.redeem) { redeeming = true }
        }
    }

    private func printedBox(_ title: Text, _ rect: CGRect, action: @escaping () -> Void) -> some View {
        Button(action: { Haptic.click(); action() }) {
            title.font(.custom("American Typewriter", size: 23 * s * b).weight(.semibold))
                .foregroundStyle(KitArt.ink)
                .lineLimit(1).minimumScaleFactor(0.5)
                // Clear of the printed box's border.
                .padding(.horizontal, max(18 * s, 18))
                .frame(width: rect.width * s, height: max(rect.height * s, 44))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: rect.minX * s, y: rect.minY * s - max(0, 44 - rect.height * s) / 2)
    }
}

/// The right page: the handbook (title above, the section's text on the
/// ruled paper, four cloth bookmarks under it) and the nameplate. A licence
/// opens as a sheet over the whole page.
struct KitHandbookPage: View {
    @Environment(\.bagBoost) private var b
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    let s: CGFloat
    @State private var tab = 0
    @State private var moreBelow = false
    @ObservedObject private var posture = Posture.shared
    @State private var licence: String?
    @State private var cameraAllowed = false
    @State private var photosAllowed = false

    /// Measured on the picture.
    static let title = CGRect(x: 836, y: 72, width: 452, height: 80)
    static let text = CGRect(x: 840, y: 160, width: 444, height: 526)
    static let marks: [CGRect] = [(826, 101), (945, 100), (1065, 97), (1182, 100)].map {
        CGRect(x: $0.0, y: 704, width: $0.1, height: 41)
    }
    static let nameplate = CGRect(x: 880, y: 806, width: 350, height: 112)
    static let page = CGRect(x: 760, y: 34, width: 662, height: 956)
    private static let ink = KitArt.ink

    var body: some View {
        ZStack(alignment: .topLeading) {
            titleView
            booklet
            ForEach(0..<4, id: \.self) { i in mark(i) }
            nameplate
            if let licence { licenceSheet(licence) }
        }
        .onAppear(perform: readAccess)
        .onChange(of: scenePhase) { _, phase in if phase == .active { readAccess() } }
        .animation(.easeInOut(duration: 0.2), value: licence)
    }

    private var tabTitle: Text {
        [Text("Tips"), Text("About Koco"), Text("Privacy"), Text("Open-source licences")][tab]
    }

    private var titleView: some View {
        VStack(alignment: .leading, spacing: 2 * s) {
            Text("Koco handbook").font(.custom("Marker Felt", size: 20 * s * b)).opacity(0.65)
            tabTitle.font(.custom("American Typewriter", size: 34 * s * b).weight(.semibold))
        }
        .foregroundStyle(Self.ink)
        .lineLimit(1).minimumScaleFactor(0.6)
        .place(Self.title, s, alignment: .leading)
        .allowsHitTesting(false)
    }

    /// The bookmarks' cloth: red, yellow, green, blue (ink on the yellow).
    private func mark(_ i: Int) -> some View {
        let title: Text = [Text("Tips"), Text("About"), Text("Privacy"), Text("Licences")][i]
        let r = Self.marks[i]
        let open = tab == i
        let onYellow = i == 1
        let ink: Color = onYellow ? Self.ink : .white
        // The word sits on its cloth; on a small screen the target grows
        // downwards only, so the word never slides off the cloth.
        let frame = CGRect(x: r.minX * s, y: r.minY * s - 6 * s, width: r.width * s, height: r.height * s + 26 * s)
        let reach = max(0, 44 - frame.height)
        let traits: AccessibilityTraits = open ? [.isButton, .isSelected] : .isButton
        return title
            .font(.custom("American Typewriter", size: 20 * s * b).weight(open ? .bold : .regular))
            .foregroundStyle(ink.opacity(0.95))
            .shadow(color: .black.opacity(onYellow ? 0 : 0.5), radius: 0, y: 1 * s)
            .lineLimit(1).minimumScaleFactor(0.5)
            .padding(.horizontal, 6 * s)
            .overlay(alignment: .bottom) {
                // The open section: a line stitched under its word.
                if open {
                    Capsule().fill(ink)
                        .frame(height: 2.5 * s).padding(.horizontal, 10 * s).offset(y: 4 * s)
                }
            }
            .frame(width: frame.width, height: frame.height)
            .padding(.bottom, reach)
            .contentShape(Rectangle())
            .onTapGesture { tab = i; licence = nil; Haptic.click() }
            .offset(x: frame.minX, y: frame.minY)
            .accessibilityAddTraits(traits)
    }

    private var nameplate: some View {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? ""
        // The build number too, so a tester can tell builds apart (user 11/24).
        let build = (info?["CFBundleVersion"] as? String) ?? ""
        return VStack(spacing: 6 * s) {
            Text(verbatim: "KOCO FILM").font(.custom("American Typewriter", size: 34 * s * b).weight(.bold)).tracking(6 * s)
            Text(verbatim: "v\(version) (\(build)) · © 2026 水婴").font(.custom("American Typewriter", size: 18 * s * b))
        }
        .foregroundStyle(Color(white: 0.28))
        .shadow(color: .white.opacity(0.7), radius: 0, y: 1 * s)
        .lineLimit(1).minimumScaleFactor(0.6)
        .place(Self.nameplate, s)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }

    private func readAccess() {
        cameraAllowed = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        photosAllowed = [.authorized, .limited].contains(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    private var booklet: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14 * s) {
                switch tab {
                case 0: tips
                case 1: about
                case 2: privacy
                default: licences
                }
            }
            .foregroundStyle(Self.ink)
            .frame(width: Self.text.width * s, alignment: .leading)
            .padding(.vertical, 6 * s)
        }
        // More below: the last lines fade into the paper, so the page reads
        // as one that goes on. At the end the text stays whole.
        .onScrollGeometryChange(for: Bool.self) { g in
            g.contentOffset.y + g.containerSize.height < g.contentSize.height - 2
        } action: { _, more in moreBelow = more }
        .mask {
            VStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .black.opacity(moreBelow ? 0 : 1)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 34 * s * b)
            }
        }
        .place(Self.text, s)
    }

    private func body(_ text: Text) -> some View {
        text.font(.custom("American Typewriter", size: 25 * s * b)).fixedSize(horizontal: false, vertical: true)
    }
    private func tip(_ title: Text, _ text: Text) -> some View {
        VStack(alignment: .leading, spacing: 4 * s) {
            title.font(.custom("American Typewriter", size: 26 * s * b).weight(.semibold))
            body(text)
        }
    }

    @ViewBuilder private var tips: some View {
        // How film is changed, and the half fold, depend on the phone folding.
        if posture.isFoldingPhone {
            tip(Text("Change film"), Text("Open the phone flat: tap a roll to look at it, tap its tag to choose it, and close the phone all the way to load it. Closed, you can also open the film door and pick another roll."))
        } else {
            tip(Text("Change film"), Text("Open the film door and tap FILMS: in the bag, tap a roll to look at it, tap its tag to choose it, and do up the bag’s clasp to load it."))
        }
        tip(Text("The Camera Control button"), Text("In the iPhone’s Settings › Camera › Camera Control, choose Koco to open it with a press, even from the Lock Screen."))
        tip(Text("Lock Screen and Control Center"), Text("Add Koco from the Lock Screen’s and Control Center’s controls to start shooting without unlocking."))
        if posture.isFoldingPhone {
            tip(Text("Half-folded"), Text("Fold the phone halfway like a laptop: the lower half becomes a waist-level finder with a level and a shutter key, the upper half is the camera."))
        }
    }

    /// The yellow tab: about Koco (user 11/24; access moved to the plate).
    @ViewBuilder private var about: some View {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? ""
        tip(Text(verbatim: "Koco Film"), Text("Version \(version) (\(build))"))
        body(Text("A film camera for iPhone: choose a roll, load it and shoot."))
        body(Text("Thanks to everyone who tried the early builds and told us what felt wrong."))
    }

    @ViewBuilder private var privacy: some View {
        body(Text("Koco develops your pictures on your iPhone and saves them to your photo library. Only the pictures you post to the community leave the phone, with your name, the film and your caption; you sign in with Apple to post, and can delete your account at any time."))
        body(Text("Koco uses no analytics or advertising and does not track you. Purchases are handled by Apple; Koco only learns which films your Apple ID owns."))
    }

    @ViewBuilder private var licences: some View {
        body(Text("Film colour and grain come from the open-source Spectral Film LUT, computed from each stock’s spectral and grain data; Grit Neg and CCD were fitted by Koco to real camera samples. Sample originals on the detail pages are AI-generated; the film is rendered live by the app."))
        licenceLink("Spectral Film LUT", "MIT License · © 2026 Jan Lohse", file: "SpectralFilmLUT-LICENSE")
        licenceLink("DSEG LCD fonts", "SIL OFL 1.1 · © 2017 keshikan", file: "DSEG-LICENSE")
    }

    private func licenceLink(_ name: String, _ detail: String, file: String) -> some View {
        Button { licence = file } label: {
            VStack(alignment: .leading, spacing: 2 * s) {
                Text(verbatim: name + " ›").font(.custom("American Typewriter", size: 24 * s * b).weight(.semibold))
                Text(verbatim: detail).font(.custom("American Typewriter", size: 19 * s * b))
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    /// A licence's full text on a sheet of the bag's card stock laid over the
    /// whole page: large enough to read, scrolling, closed with its tab.
    private func licenceSheet(_ file: String) -> some View {
        let text = Bundle.main.url(forResource: file, withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? String(ui: "Licence text missing.")
        let sheet = Self.page.at(s)
        return ZStack(alignment: .topLeading) {
            Image(uiImage: RollLibrary.cardPaper).resizable()
                .frame(width: sheet.width, height: sheet.height)
                .shadow(color: .black.opacity(0.6), radius: 18 * s, y: 8 * s)
            ScrollView(.vertical) {
                Text(verbatim: text)
                    .font(.system(size: 21 * s, design: .monospaced))
                    .foregroundStyle(Self.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40 * s).padding(.top, 90 * s).padding(.bottom, 40 * s)
            }
            .frame(width: sheet.width, height: sheet.height)
            Button { licence = nil } label: {
                Text("‹ Back").font(.custom("Marker Felt", size: 30 * s * b))
                    .foregroundStyle(Color(red: 0.72, green: 0.12, blue: 0.10))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .offset(x: 30 * s, y: 18 * s)
        }
        .offset(x: sheet.minX, y: sheet.minY)
        .transition(.opacity)
    }
}
