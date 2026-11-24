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
    static let knob = UIImage(named: "kit_knob") ?? UIImage()
    static let lamp = UIImage(named: "kit_lamp") ?? UIImage()
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

    /// Measured on the picture: the plate's three rows (label recess, lamp,
    /// switch channel) and the certificate's printed boxes.
    static let rowY: [CGFloat] = [100, 248, 396]
    static let lampY: [CGFloat] = [148, 294, 440]
    static let lampX: CGFloat = 456
    static let channel = (x: CGFloat(498), width: CGFloat(128), dy: CGFloat(22), height: CGFloat(56))
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
            certificate
        }
        .offerCodeRedemption(isPresented: $redeeming) { _ in Task { await store.refresh() } }
    }

    private func switchRow(_ i: Int, title: Text, detail: Text, isOn: Binding<Bool>, apply: @escaping (Bool) -> Void) -> some View {
        let y = Self.rowY[i]
        let c = Self.channel
        let slot = CGRect(x: c.x, y: y + c.dy, width: c.width, height: c.height).at(s)
        let knobH = slot.height * 0.86, knobW = knobH * KitArt.knob.size.width / max(KitArt.knob.size.height, 1)
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4 * s) {
                title.font(.custom("American Typewriter", size: 28 * s * b).weight(.semibold))
                    .foregroundStyle(Color(white: 0.84))
                if !b.isCompactBag {
                    detail.font(.custom("American Typewriter", size: 19 * s * b))
                        .foregroundStyle(Color(white: 0.58))
                }
            }
            .lineLimit(1).minimumScaleFactor(0.55)
            .shadow(color: .black, radius: 0, y: -1 * s)
            .padding(.horizontal, 18 * s)
            .place(CGRect(x: 84, y: y + 6, width: 340, height: 84), s, alignment: .leading)
            .allowsHitTesting(false)
            if isOn.wrappedValue {
                Image(uiImage: KitArt.lamp).resizable()
                    .frame(width: 60 * s, height: 60 * s)
                    .offset(x: (Self.lampX - 30) * s, y: (Self.lampY[i] - 30) * s)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            Image(uiImage: KitArt.knob).resizable()
                .frame(width: knobW, height: knobH)
                .offset(x: slot.minX + (isOn.wrappedValue ? slot.width - knobW - 5 * s : 5 * s),
                        y: slot.minY + (slot.height - knobH) / 2)
                .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isOn.wrappedValue)
                .allowsHitTesting(false)
            // The whole row is the switch.
            Color.clear.contentShape(Rectangle())
                .place(CGRect(x: 80, y: y, width: 560, height: 96), s)
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
        .animation(.easeOut(duration: 0.15), value: isOn.wrappedValue)
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
        [Text("Tips"), Text("Camera & Photos access"), Text("Privacy"), Text("Open-source licences")][tab]
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
        let title: Text = [Text("Tips"), Text("Access"), Text("Privacy"), Text("Licences")][i]
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
        return VStack(spacing: 6 * s) {
            Text(verbatim: "KOCO FILM").font(.custom("American Typewriter", size: 34 * s * b).weight(.bold)).tracking(6 * s)
            Text(verbatim: "v\(version) · © 2026 水婴").font(.custom("American Typewriter", size: 18 * s * b))
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
                case 1: access
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

    @ViewBuilder private var access: some View {
        let camera = cameraAllowed, photos = photosAllowed
        body(camera ? Text("Camera: allowed") : Text("Camera: not allowed"))
        body(photos ? Text("Photos: allowed") : Text("Photos: not allowed"))
        if !(camera && photos), let url = URL(string: UIApplication.openSettingsURLString) {
            Button { openURL(url) } label: {
                Text("Open Settings →").font(.custom("Marker Felt", size: 26 * s * b))
                    .foregroundStyle(Color(red: 0.72, green: 0.12, blue: 0.10))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var privacy: some View {
        body(Text("Koco works entirely on your iPhone. Your pictures are developed on the phone and saved to your photo library; nothing is uploaded, and Koco has no servers or accounts."))
        body(Text("Koco collects no personal data, uses no analytics or advertising, and does not track you. Purchases are handled by Apple; Koco only learns which films your Apple ID owns."))
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
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? String(localized: "Licence text missing.")
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
