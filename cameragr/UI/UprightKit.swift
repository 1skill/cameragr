import AVFoundation
import Photos
import StoreKit
import SwiftUI

/// The settings page on an upright iPhone: the kit's own objects (GPT art,
/// the same kit_spread picture the Duo's two pages use) laid out top to bottom
/// in the order they are used — the switch plate (three switches, then
/// language, camera and photos), the purchase certificate, the handbook with
/// its cloth bookmarks, the nameplate — and the long brass window at the foot.
/// The plate, the card and the paper are cut from the picture at their flat
/// stretches and the cut stretched, so rows can be as tall as a finger needs
/// and the text as large as it should be; no pixel of the art is changed.
/// The whole page scrolls; the window stays.
struct UprightKit: View {
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared
    @ObservedObject private var language = AppLanguage.shared
    @ObservedObject private var posture = Posture.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    let size: CGSize
    let goPage: (Spread) -> Void

    @State private var saveOriginal = Preferences.saveOriginal
    @State private var shutterSound = Preferences.shutterSound
    @State private var haptics = Haptic.enabled
    @State private var redeeming = false
    @State private var restoreNote: Text?
    @State private var restoring = false
    @State private var choosingLanguage = false
    @State private var camera = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var photos = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var tab = 0
    @State private var licence: String?

    private static let ink = KitArt.ink
    private static let typewriter = "American Typewriter"

    // MARK: Art

    /// Parts of the kit picture, in its own pixels (1456 × 1024).
    private static let spread: CGImage? = KitArt.spread.cgImage
    private static func cut(_ r: CGRect) -> UIImage {
        guard let cg = spread?.cropping(to: r.integral) else { return UIImage() }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }

    /// The plate (x 34…674, y 46…550) and its six rows (recess top, height): rows 1–3 are switches, 4–6 show a value.
    private static let plateX: CGFloat = 34, plateW: CGFloat = 640
    private static let rowTop: [CGFloat] = [122, 191, 260, 329.5, 389.5, 449]
    private static let rowH: [CGFloat] = [52, 52, 52, 45.5, 45.5, 45.5]
    private static let margin: CGFloat = 5
    private static let plateTop = CGRect(x: plateX, y: 46, width: plateW, height: rowTop[0] - margin - 46)
    private static func band(_ i: Int) -> CGRect { CGRect(x: plateX, y: rowTop[i] - margin, width: plateW, height: rowH[i] + 2 * margin) }
    /// The black between two rows, and under the last.
    private static func gap(_ i: Int) -> CGRect {
        let y = rowTop[i] + rowH[i] + margin
        let next = i + 1 < rowTop.count ? rowTop[i + 1] - margin : 500
        return CGRect(x: plateX, y: y, width: plateW, height: max(next - y, 2))
    }
    private static let plateFoot = CGRect(x: plateX, y: 500, width: plateW, height: 50)
    private static let plateImages = (top: cut(plateTop), bands: (0..<6).map { cut(band($0)) },
                                      gaps: (0..<5).map { cut(gap($0)) }, foot: cut(plateFoot))
    /// The empty rows' sprites, in the picture's pixels (as on the Duo's plate).
    private static let thumbOn: [CGRect] = [CGRect(x: 537, y: 126, width: 84, height: 48),
                                            CGRect(x: 536, y: 195, width: 85, height: 48),
                                            CGRect(x: 536, y: 264, width: 85, height: 47)]
    private static let thumbTravel: CGFloat = 46.5
    private static let lampOn: [CGRect] = [CGRect(x: 413, y: 110, width: 80, height: 80),
                                           CGRect(x: 414, y: 178, width: 80, height: 80),
                                           CGRect(x: 414, y: 246, width: 80, height: 80)]
    private static let windows: [CGRect] = [CGRect(x: 441, y: 331, width: 137, height: 41),
                                            CGRect(x: 441, y: 391, width: 137, height: 41),
                                            CGRect(x: 441, y: 451, width: 137, height: 41)]
    /// The label's recess (x 84…418).
    private static let recessX: CGFloat = 84, recessW: CGFloat = 334

    /// The certificate card (x 28…674, y 558…976): its top corners, a stretch of paper, its foot with the two printed boxes.
    private static let cardX: CGFloat = 28, cardW: CGFloat = 646
    private static let cardTop = cut(CGRect(x: cardX, y: 558, width: cardW, height: 122))
    private static let cardMid = cut(CGRect(x: cardX, y: 690, width: cardW, height: 120))
    private static let cardFoot = cut(CGRect(x: cardX, y: 840, width: cardW, height: 136))
    private static let restoreBox = CGRect(x: 97, y: 860, width: 236, height: 60)
    private static let redeemBox = CGRect(x: 376, y: 860, width: 253, height: 60)

    /// The handbook's paper (x 792…1318) with the clasp's strap, its bookmarks (y 704…745) and the nameplate.
    private static let paperX: CGFloat = 792, paperW: CGFloat = 526
    private static let paperTop = cut(CGRect(x: paperX, y: 20, width: paperW, height: 160))
    private static let paperMid = cut(CGRect(x: paperX, y: 200, width: paperW, height: 120))
    private static let paperFoot = cut(CGRect(x: paperX, y: 600, width: paperW, height: 106))
    private static let marks: [CGRect] = [(826, 101), (945, 100), (1065, 97), (1182, 100)].map {
        CGRect(x: $0.0, y: 704, width: $0.1, height: 41)
    }
    private static let marksStrip = cut(CGRect(x: paperX, y: 704, width: paperW, height: 44))
    private static let namePlate = cut(CGRect(x: 830, y: 780, width: 440, height: 158))

    // MARK: Layout

    private var tall: Bool { size.height / size.width > 2.0 }
    private var topInset: CGFloat { tall ? 59 : 20 }
    private var bottomInset: CGFloat { tall ? 30 : 6 }
    private let pad: CGFloat = 12
    private var inner: CGFloat { size.width - 2 * pad }
    /// One point of the plate and the card.
    private var s: CGFloat { inner / Self.plateW }
    /// A row of the plate is at least this tall, a finger's width.
    private let rowPitch: CGFloat = 52
    private var dialH: CGFloat { max(44, inner * PageDial.window.size.height / max(PageDial.window.size.width, 1)) }

    var body: some View {
        ZStack {
            Image(uiImage: UprightFilms.velvet).resizable(resizingMode: .tile).ignoresSafeArea()
            VStack(spacing: 6) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 18) {
                            plate
                            certificate
                            handbook.id("handbook")
                            nameplate.id("nameplate")
                        }
                        .frame(width: inner)
                        .padding(.top, 6).padding(.bottom, 14)
                    }
                    .frame(width: inner)
                    #if DEBUG
                    .onAppear {
                        if let id = UserDefaults.standard.string(forKey: "kitScrollTo") {
                            DispatchQueue.main.async { proxy.scrollTo(id, anchor: .bottom) }   // `-kitScrollTo nameplate`, for checks
                        }
                    }
                    #endif
                }
                dial
            }
            .padding(.horizontal, pad)
            .padding(.top, topInset)
            .padding(.bottom, bottomInset)
            .frame(width: size.width, height: size.height)
            if choosingLanguage { languageCard.transition(.opacity) }
            if let licence { licenceSheet(licence).transition(.opacity) }
        }
        .frame(width: size.width, height: size.height)
        .animation(.easeOut(duration: 0.2), value: choosingLanguage)
        .animation(.easeInOut(duration: 0.2), value: licence)
        .onAppear {
            readAccess()
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "languages") { choosingLanguage = true }   // `-languages 1`, for checks
            if let t = UserDefaults.standard.object(forKey: "kitTab") as? Int { tab = t }
            if let f = UserDefaults.standard.string(forKey: "kitLicence") { licence = f }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { readAccess() } }
        .offerCodeRedemption(isPresented: $redeeming) { _ in Task { await store.refresh() } }
        .accessibilityIdentifier("upright-kit")
    }

    private var dial: some View {
        let k = inner / PageDial.rect.width
        let h = inner * PageDial.window.size.height / max(PageDial.window.size.width, 1)
        return PageDial(spread: .kit, s: k, choose: { goPage($0) }, camera: { goCamera() }, placed: false, labelSize: 15)
            .frame(width: inner, height: h, alignment: .topLeading)
            .frame(height: max(h, 44))
    }

    private func goCamera() {
        Haptic.click()
        model.lookedAt = nil
        model.leaveBag()
    }

    // MARK: The switch plate

    private func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(Self.typewriter, size: size).weight(weight)
    }

    /// Each row as tall as a finger needs: its cut of the plate, and the black under it stretched to fill the pitch.
    private func gapH(_ i: Int) -> CGFloat {
        let natural = Self.gap(i).height * s
        return max(natural, rowPitch - Self.band(i).height * s)
    }

    private var plate: some View {
        VStack(spacing: 0) {
            Image(uiImage: Self.plateImages.top).resizable().frame(width: inner, height: Self.plateTop.height * s)
            row(0)
            row(1)
            row(2)
            row(3)
            row(4)
            row(5)
        }
        .shadow(color: .black.opacity(0.55), radius: 6, y: 3)
    }

    private func rowTitle(_ i: Int) -> Text {
        [Text("Original"), Text("Shutter sound"), Text("Haptics"), Text("Language"), Text("Camera"), Text("Photos")][i]
    }
    private func rowDetail(_ i: Int) -> Text {
        [Text("Save the iPhone original too"), Text("A click when you shoot"), Text("A light tap under your finger"),
         Text("Tap to choose"), Text("For the viewfinder"), Text("Where your pictures go")][i]
    }

    /// One row of the plate: its label on the left, a switch or a value on the right. The whole row is the control.
    private func row(_ i: Int) -> some View {
        let band = Self.band(i)
        let gh = i < 5 ? gapH(i) : Self.plateFoot.height * s   // the last row's tap area runs on into the plate's foot
        let h = band.height * s + gh
        let isSwitch = i < 3
        let on = [saveOriginal, shutterSound, haptics][min(i, 2)]
        let value: Text? = i == 3 ? Text(verbatim: AppLanguage.name(language.code)) : i == 4 ? accessWord(camera) : i == 5 ? accessWord(photos) : nil
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Image(uiImage: Self.plateImages.bands[i]).resizable().frame(width: inner, height: band.height * s)
                if i < 5 { Image(uiImage: Self.plateImages.gaps[i]).resizable().frame(width: inner, height: gh) }
                else { Image(uiImage: Self.plateImages.foot).resizable().frame(width: inner, height: gh) }
            }
            // The label in its recess.
            VStack(alignment: .leading, spacing: 0) {
                rowTitle(i).font(font(17, .semibold)).foregroundStyle(Color(white: 0.86))
                rowDetail(i).font(font(12)).foregroundStyle(Color(white: 0.62))
            }
            .lineLimit(1).minimumScaleFactor(0.9)
            .shadow(color: .black, radius: 0, y: -1)
            .padding(.horizontal, 12)
            .frame(width: Self.recessW * s, height: Self.rowH[i] * s, alignment: .leading)
            .offset(x: (Self.recessX - Self.plateX) * s, y: Self.margin * s)
            .allowsHitTesting(false)
            if isSwitch {
                let lamp = Self.lampOn[i]
                Image(uiImage: KitArt.lampOn[i]).resizable()
                    .frame(width: lamp.width * s, height: lamp.height * s)
                    .offset(x: (lamp.minX - Self.plateX) * s, y: (lamp.minY - band.minY) * s)
                    .opacity(on ? 1 : 0)
                    .allowsHitTesting(false)
                let t = Self.thumbOn[i]
                Image(uiImage: KitArt.thumb[i]).resizable()
                    .frame(width: t.width * s, height: t.height * s)
                    .offset(x: (t.minX - Self.plateX) * s - (on ? 0 : Self.thumbTravel * s), y: (t.minY - band.minY) * s)
                    .animation(.spring(response: 0.22, dampingFraction: 0.8), value: on)
                    .allowsHitTesting(false)
            } else if let value {
                let w = Self.windows[i - 3]
                value.font(font(11.5, .semibold)).tracking(-0.4).foregroundStyle(KitArt.ink)
                    .lineLimit(1).minimumScaleFactor(0.95)
                    .frame(width: w.width * s + 6, height: w.height * s)
                    .offset(x: (w.minX - Self.plateX) * s - 3, y: (w.minY - band.minY) * s)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: inner, height: h, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { act(i) }
        .animation(.easeOut(duration: 0.1), value: on)
        .accessibilityElement()
        .accessibilityLabel(isSwitch ? rowDetail(i) : rowTitle(i))
        .accessibilityValue(isSwitch ? (on ? Text("On") : Text("Off")) : (value ?? Text(verbatim: "")))
        .accessibilityAddTraits(.isButton)
    }

    private func act(_ i: Int) {
        switch i {
        case 0: saveOriginal.toggle(); Preferences.saveOriginal = saveOriginal; Haptic.click()
        case 1: shutterSound.toggle(); Preferences.shutterSound = shutterSound; Haptic.click()
        case 2:
            haptics.toggle(); Haptic.enabled = haptics
            if haptics { Haptic.tap() }
            Haptic.click()
        case 3: Haptic.click(); choosingLanguage = true
        case 4: Haptic.click(); ask(camera: true)
        default: Haptic.click(); ask(camera: false)
        }
    }

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

    // MARK: The language card

    private var languageCard: some View {
        let w = min(inner * 0.78, 320)
        let k = w / 414
        return ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { choosingLanguage = false }
            ZStack(alignment: .topLeading) {
                Image(uiImage: KitArt.languageCard).resizable()
                    .shadow(color: .black.opacity(0.55), radius: 10, y: 6)
                ForEach(Array(AppLanguage.all.enumerated()), id: \.offset) { n, code in
                    let band = KitSwitchPage.cardRows[n]
                    let current = code == language.code
                    let accent = Color(red: 0.72, green: 0.22, blue: 0.08)
                    Button {
                        Haptic.click()
                        withAnimation(.easeInOut(duration: 0.2)) { language.choose(code) }
                        withAnimation(.easeIn(duration: 0.15).delay(0.25)) { choosingLanguage = false }
                    } label: {
                        HStack(spacing: 8) {
                            Text(verbatim: AppLanguage.name(code))
                                .font(font(20, current ? .bold : .regular))
                                .foregroundStyle(current ? accent : KitArt.ink)
                            Spacer(minLength: 0)
                            if current { Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundStyle(accent) }
                        }
                        .padding(.horizontal, 28 * k)
                        .frame(width: w, height: (band.upperBound - band.lowerBound) * k)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .offset(y: band.lowerBound * k)
                    .accessibilityAddTraits(current ? .isSelected : [])
                }
            }
            .frame(width: w, height: w * 606 / 414, alignment: .topLeading)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: The certificate

    private var certificate: some View {
        let k = inner / Self.cardW
        let footH = Self.cardFoot.size.height * k
        return ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Image(uiImage: Self.cardTop).resizable().frame(width: inner, height: Self.cardTop.size.height * k)
                Image(uiImage: Self.cardMid).resizable().frame(maxWidth: .infinity, maxHeight: .infinity)
                Image(uiImage: Self.cardFoot).resizable().frame(width: inner, height: footH)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Koco film certificate").font(font(13)).opacity(0.7)
                (store.ownsAll ? Text("Every film for sale is yours") : Text("\(store.ownedPaidCount) of \(store.paidFilms.count) paid films are yours"))
                    .font(font(21, .semibold))
                if !store.ownsAll {
                    Text("Free films and trial shots are always there.").font(font(14))
                }
                if let free = store.dailyFreeToday, !store.owns(free) {
                    Text("Free today: \(free.name), as many shots as you like. The pictures stay.").font(font(13))
                }
                Text("Limited rolls are earned in the Community, not bought.").font(font(13)).opacity(0.75)
                if let restoreNote {
                    restoreNote.font(.custom("Marker Felt", size: 16))
                        .foregroundStyle(Color(red: 0.72, green: 0.12, blue: 0.10))
                }
            }
            .foregroundStyle(KitArt.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: (500) * k, alignment: .topLeading)
            .padding(.top, 58 * k)
            .padding(.bottom, footH + 4)
            .frame(maxWidth: .infinity, alignment: .top)
            .allowsHitTesting(false)
            // The two printed boxes in the card's foot.
            ZStack(alignment: .topLeading) {
                printedBox(restoring ? Text("Restoring…") : Text("Restore purchases"), Self.restoreBox, k: k) { restore() }
                printedBox(Text("Redeem a code"), Self.redeemBox, k: k) { redeeming = true }
            }
            .frame(width: inner, height: footH, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: inner)
        .shadow(color: .black.opacity(0.5), radius: 5, y: 3)
    }

    /// A printed box in the card's foot (its rect in the picture's pixels, the foot starting at y 840).
    private func printedBox(_ title: Text, _ r: CGRect, k: CGFloat, action: @escaping () -> Void) -> some View {
        let h = max(r.height * k, 44)
        return Button(action: { Haptic.click(); action() }) {
            title.font(font(15, .semibold)).foregroundStyle(KitArt.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 8)
                .frame(width: r.width * k, height: h)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: (r.minX - Self.cardX) * k, y: (r.minY - 840) * k - (h - r.height * k) / 2)
    }

    private func restore() {
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

    // MARK: The handbook

    private var handbook: some View {
        let k = inner / Self.paperW
        return VStack(spacing: 0) {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Image(uiImage: Self.paperTop).resizable().frame(width: inner, height: Self.paperTop.size.height * k)
                    Image(uiImage: Self.paperMid).resizable().frame(maxWidth: .infinity, maxHeight: .infinity)
                    Image(uiImage: Self.paperFoot).resizable().frame(width: inner, height: Self.paperFoot.size.height * k)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Koco handbook").font(.custom("Marker Felt", size: 15)).opacity(0.65)
                    tabTitle.font(font(24, .semibold))
                    VStack(alignment: .leading, spacing: 12) {
                        switch tab {
                        case 0: tips
                        case 1: about
                        case 2: privacy
                        default: licences
                        }
                    }
                }
                .foregroundStyle(Self.ink)
                .frame(width: (1284 - 840) * k, alignment: .topLeading)
                .padding(.top, 80 * k)
                .padding(.bottom, 80 * k)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(width: inner)
            .frame(minHeight: 300 * k)
            bookmarks(k: k)
        }
        .frame(width: inner)
        .shadow(color: .black.opacity(0.5), radius: 5, y: 3)
    }

    private var tabTitle: Text {
        [Text("Tips"), Text("About Koco"), Text("Privacy"), Text("Open-source licences")][tab]
    }

    /// The four cloth bookmarks under the paper: red, yellow, green, blue (ink on the yellow).
    private func bookmarks(k: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: Self.marksStrip).resizable().frame(width: inner, height: Self.marksStrip.size.height * k)
            ForEach(0..<4, id: \.self) { i in
                let r = Self.marks[i]
                let open = tab == i
                let onYellow = i == 1
                let ink: Color = onYellow ? Self.ink : .white
                let title: Text = [Text("Tips"), Text("About"), Text("Privacy"), Text("Licences")][i]
                let h = r.height * k
                title
                    .font(font(13, open ? .bold : .regular))
                    .foregroundStyle(ink.opacity(0.95))
                    .shadow(color: .black.opacity(onYellow ? 0 : 0.5), radius: 0, y: 1)
                    .lineLimit(1).minimumScaleFactor(0.85)
                    .padding(.horizontal, 2)
                    .overlay(alignment: .bottom) {
                        if open { Capsule().fill(ink).frame(height: 2).padding(.horizontal, 8).offset(y: 3) }
                    }
                    .frame(width: r.width * k, height: max(h, 44))
                    .contentShape(Rectangle())
                    .onTapGesture { tab = i; licence = nil; Haptic.click() }
                    .offset(x: (r.minX - Self.paperX) * k, y: -(max(h, 44) - h) / 2 + 2)
                    .accessibilityAddTraits(open ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(width: inner, height: Self.marksStrip.size.height * k + 8, alignment: .topLeading)
    }

    private func bodyText(_ text: Text) -> some View {
        text.font(font(16)).fixedSize(horizontal: false, vertical: true)
    }
    private func tip(_ title: Text, _ text: Text) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            title.font(font(17, .semibold))
            bodyText(text)
        }
    }

    @ViewBuilder private var tips: some View {
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

    @ViewBuilder private var about: some View {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? ""
        tip(Text(verbatim: "Koco Film"), Text("Version \(version) (\(build))"))
        bodyText(Text("A film camera for iPhone: choose a roll, load it and shoot."))
        bodyText(Text("Thanks to everyone who tried the early builds and told us what felt wrong."))
    }

    @ViewBuilder private var privacy: some View {
        bodyText(Text("Koco develops your pictures on your iPhone and saves them to your photo library. Only the pictures you post to the community leave the phone, with your name, the film and your caption; you sign in with Apple to post, and can delete your account at any time."))
        bodyText(Text("Koco uses no analytics or advertising and does not track you. Purchases are handled by Apple; Koco only learns which films your Apple ID owns."))
    }

    @ViewBuilder private var licences: some View {
        bodyText(Text("Film colour and grain come from the open-source Spectral Film LUT, computed from each stock’s spectral and grain data; Grit Neg and CCD were fitted by Koco to real camera samples. Sample originals on the detail pages are AI-generated; the film is rendered live by the app."))
        licenceLink("Spectral Film LUT", "MIT License · © 2026 Jan Lohse", file: "SpectralFilmLUT-LICENSE")
        licenceLink("DSEG LCD fonts", "SIL OFL 1.1 · © 2017 keshikan", file: "DSEG-LICENSE")
    }

    private func licenceLink(_ name: String, _ detail: String, file: String) -> some View {
        Button { licence = file } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name + " ›").font(font(16, .semibold))
                Text(verbatim: detail).font(font(13))
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// A licence's full text on a sheet of card stock over the page, closed with its Back.
    private func licenceSheet(_ file: String) -> some View {
        let text = Bundle.main.url(forResource: file, withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? String(ui: "Licence text missing.")
        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.5).ignoresSafeArea()
            Image(uiImage: RollLibrary.cardPaper).resizable()
                .frame(width: inner, height: size.height - topInset - bottomInset)
                .shadow(color: .black.opacity(0.6), radius: 12, y: 6)
            ScrollView(.vertical) {
                Text(verbatim: text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Self.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24).padding(.top, 64).padding(.bottom, 24)
            }
            .frame(width: inner, height: size.height - topInset - bottomInset)
            Button { licence = nil } label: {
                Text("‹ Back").font(.custom("Marker Felt", size: 22))
                    .foregroundStyle(Color(red: 0.72, green: 0.12, blue: 0.10))
                    .frame(minWidth: 64, minHeight: 44)
            }
            .buttonStyle(.plain)
            .padding(.leading, 14).padding(.top, 10)
        }
        .frame(width: inner, height: size.height - topInset - bottomInset)
        .position(x: size.width / 2, y: topInset + (size.height - topInset - bottomInset) / 2)
        .frame(width: size.width, height: size.height)
    }

    // MARK: The nameplate

    private var nameplate: some View {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? ""
        let build = (info?["CFBundleVersion"] as? String) ?? ""
        let w = min(inner * 0.8, 340)
        return ZStack {
            Image(uiImage: Self.namePlate).resizable().frame(width: w, height: w * 158 / 440)
            VStack(spacing: 4) {
                Text(verbatim: "KOCO FILM").font(font(22, .bold)).tracking(4)
                Text(verbatim: "v\(version) (\(build)) · © 2026 水婴").font(font(12))
            }
            .foregroundStyle(Color(white: 0.28))
            .shadow(color: .white.opacity(0.7), radius: 0, y: 1)
            .lineLimit(1).minimumScaleFactor(0.85)
            .frame(width: w - 40)
        }
        .accessibilityElement(children: .combine)
    }
}
