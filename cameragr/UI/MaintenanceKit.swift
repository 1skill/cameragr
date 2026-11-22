import AVFoundation
import Photos
import StoreKit
import SwiftUI

/// The maintenance kit in the bag's lid: the app's settings as things in
/// the bag (GPT art, kit_page.jpg from design/kit/kit_template.png). Three
/// slide switches with lamps, a little instruction booklet with coloured
/// index tabs, and the purchase certificate. It takes the place of the card
/// and the sleeve on the right page while it is out.
struct MaintenanceKit: View {
    @ObservedObject private var store = FilmStore.shared
    @Environment(\.openURL) private var openURL
    /// The right page, in bag pixels, and the bag's scale.
    let page: CGRect
    let s: CGFloat
    @State private var saveOriginal = Preferences.saveOriginal
    @State private var shutterSound = Preferences.shutterSound
    @State private var haptics = Haptic.enabled
    @State private var tab = 0
    @State private var licence: String?
    @State private var redeeming = false
    @State private var cameraAllowed = false
    @State private var photosAllowed = false
    @Environment(\.scenePhase) private var scenePhase

    static let picture = UIImage(named: "kit_page.jpg") ?? UIImage()
    static let knob = UIImage(named: "kit_knob") ?? UIImage()
    static let lamp = UIImage(named: "kit_lamp") ?? UIImage()
    /// Measured on the picture, in page pixels (678 × 972, as the template).
    static let switchY: [CGFloat] = [110, 230, 350]
    /// The booklet's two pages (measured): the title on the upper one, the
    /// text scrolling on the lower, so no line runs over the fold.
    static let bookTop = CGRect(x: 350, y: 70, width: 268, height: 215)
    static let book = CGRect(x: 350, y: 318, width: 268, height: 262)
    static let tabYs: [CGFloat] = [87, 199, 309, 418]
    static let certificate = CGRect(x: 24, y: 636, width: 630, height: 300)

    private func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: (page.minX + x) * s, y: (page.minY + y) * s, width: w * s, height: h * s)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: Self.picture).resizable()
                .frame(width: page.width * s, height: page.height * s)
                .offset(x: page.minX * s, y: page.minY * s)
            switchRow(0, title: Text("Save the iPhone original too"), short: Text("Original"), isOn: $saveOriginal) { Preferences.saveOriginal = $0 }
            switchRow(1, title: Text("Shutter sound"), short: Text("Shutter sound"), isOn: $shutterSound) { Preferences.shutterSound = $0 }
            switchRow(2, title: Text("Haptics"), short: Text("Haptics"), isOn: $haptics) { on in
                Haptic.enabled = on
                if on { Haptic.tap() }
            }
            bookTitle
            booklet
            ForEach(0..<4, id: \.self) { i in tabLabel(i) }
            certificateView
        }
        // Access is read again on coming back (from Settings, say).
        .onAppear(perform: readAccess)
        .onChange(of: scenePhase) { _, phase in if phase == .active { readAccess() } }
        // A licence is read on a whole sheet of paper laid over the bag.
        .overlay(alignment: .topLeading) { if let licence { licenceSheet(licence) } }
        .offerCodeRedemption(isPresented: $redeeming) { _ in Task { await store.refresh() } }
    }

    // MARK: Switches

    private func switchRow(_ i: Int, title: Text, short: Text, isOn: Binding<Bool>, apply: @escaping (Bool) -> Void) -> some View {
        let y = Self.switchY[i]
        let slot = r(44, y, 96, 52)
        let knobH = slot.height * 0.86, knobW = knobH * Self.knob.size.width / max(Self.knob.size.height, 1)
        return ZStack(alignment: .topLeading) {
            Image(uiImage: Self.knob).resizable()
                .frame(width: knobW, height: knobH)
                .offset(x: slot.minX + (isOn.wrappedValue ? slot.width - knobW - 4 * s : 4 * s),
                        y: slot.minY + (slot.height - knobH) / 2)
                .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isOn.wrappedValue)
            if isOn.wrappedValue {
                let lamp = r(152 - 8, y + 16 - 8, 36, 36)
                Image(uiImage: Self.lamp).resizable()
                    .frame(width: lamp.width, height: lamp.height)
                    .offset(x: lamp.minX, y: lamp.minY)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            let label = r(184, y + 6, 118, 40)
            short.font(.custom("American Typewriter", size: 17 * s).weight(.semibold))
                .foregroundStyle(Color(white: 0.78))
                .shadow(color: .black, radius: 0, y: -1 * s)
                .lineLimit(1).minimumScaleFactor(0.5)
                .frame(width: label.width, height: label.height)
                .offset(x: label.minX, y: label.minY)
                .allowsHitTesting(false)
            Color.clear.contentShape(Rectangle())
                .frame(width: r(0, 0, 270, 70).width, height: max(r(0, 0, 0, 70).height, 44))
                .offset(x: slot.minX - 10 * s, y: slot.minY - 9 * s)
                .onTapGesture {
                    isOn.wrappedValue.toggle()
                    apply(isOn.wrappedValue)
                    Haptic.click()
                }
                .accessibilityElement()
                .accessibilityLabel(title)
                .accessibilityValue(isOn.wrappedValue ? Text("On") : Text("Off"))
                .accessibilityAddTraits(.isButton)
        }
        .animation(.easeOut(duration: 0.15), value: isOn.wrappedValue)
    }

    // MARK: Booklet

    private static let ink = Color(red: 0.2, green: 0.17, blue: 0.13)

    private func tabLabel(_ i: Int) -> some View {
        let t = r(634, Self.tabYs[i], 30, 96)
        let title: Text = [Text("Tips"), Text("Access"), Text("Privacy"), Text("Licences")][i]
        return title
            .font(.custom("American Typewriter", size: 12 * s).weight(tab == i ? .bold : .regular))
            .foregroundStyle(Self.ink)
            .lineLimit(1).minimumScaleFactor(0.5)
            .frame(width: t.height, height: t.width)
            .rotationEffect(.degrees(90))
            .frame(width: t.width, height: t.height)
            .contentShape(Rectangle())
            .onTapGesture { tab = i; licence = nil; Haptic.click() }
            .offset(x: t.minX, y: t.minY)
            .accessibilityAddTraits(tab == i ? [.isButton, .isSelected] : .isButton)
    }

    private func readAccess() {
        cameraAllowed = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        photosAllowed = [.authorized, .limited].contains(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    private var tabTitle: Text {
        [Text("Tips"), Text("Camera & Photos access"), Text("Privacy"), Text("Open-source licences")][tab]
    }

    /// The upper page: the booklet's name and the section open.
    private var bookTitle: some View {
        let b = r(Self.bookTop.minX, Self.bookTop.minY, Self.bookTop.width, Self.bookTop.height)
        return VStack(spacing: 10 * s) {
            Text("Koco handbook").font(.custom("Marker Felt", size: 18 * s)).opacity(0.7)
            tabTitle.font(.custom("American Typewriter", size: 26 * s).weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Self.ink)
        .lineLimit(2).minimumScaleFactor(0.6)
        .frame(width: b.width, height: b.height)
        .offset(x: b.minX, y: b.minY)
        .allowsHitTesting(false)
    }

    private var booklet: some View {
        let b = r(Self.book.minX, Self.book.minY, Self.book.width, Self.book.height)
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10 * s) {
                switch tab {
                case 0: tips
                case 1: access
                case 2: privacy
                default: licences
                }
            }
            .foregroundStyle(Self.ink)
            .frame(width: b.width, alignment: .leading)
            .padding(.vertical, 6 * s)
        }
        .frame(width: b.width, height: b.height)
        .offset(x: b.minX, y: b.minY)
    }

    private func heading(_ text: Text) -> some View {
        text.font(.custom("American Typewriter", size: 23 * s).weight(.semibold))
    }
    private func body(_ text: Text) -> some View {
        text.font(.custom("American Typewriter", size: 18 * s)).fixedSize(horizontal: false, vertical: true)
    }
    private func tip(_ title: Text, _ text: Text) -> some View {
        VStack(alignment: .leading, spacing: 3 * s) {
            title.font(.custom("American Typewriter", size: 19 * s).weight(.semibold))
            body(text)
        }
    }

    @ViewBuilder private var tips: some View {
        tip(Text("Change film"), Text("Open the phone flat: tap a roll to look at it, tap its tag to choose it, and close the phone all the way to load it. Closed, you can also open the film door and pick another roll."))
        tip(Text("The Camera Control button"), Text("In the iPhone’s Settings › Camera › Camera Control, choose Koco to open it with a press, even from the Lock Screen."))
        tip(Text("Lock Screen and Control Center"), Text("Add Koco from the Lock Screen’s and Control Center’s controls to start shooting without unlocking."))
        tip(Text("Half-folded"), Text("Fold the phone halfway like a laptop: the lower half becomes a waist-level finder with a level and a shutter key, the upper half is the camera."))
    }

    @ViewBuilder private var access: some View {
        let camera = cameraAllowed, photos = photosAllowed
        body(camera ? Text("Camera: allowed") : Text("Camera: not allowed"))
        body(photos ? Text("Photos: allowed") : Text("Photos: not allowed"))
        if !(camera && photos), let url = URL(string: UIApplication.openSettingsURLString) {
            Button { openURL(url) } label: {
                Text("Open Settings →").font(.custom("Marker Felt", size: 18 * s))
                    .foregroundStyle(Color(red: 0.72, green: 0.12, blue: 0.10))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var privacy: some View {
        body(Text("Koco works entirely on your iPhone. Your pictures are developed on the phone and saved to your photo library; nothing is uploaded, and Koco has no servers or accounts."))
        body(Text("Koco collects no personal data, uses no analytics or advertising, and does not track you. Purchases are handled by Apple; Koco only learns which films your Apple ID owns."))
    }

    @ViewBuilder private var licences: some View {
        do {
            body(Text("Film colour and grain come from the open-source Spectral Film LUT, computed from each stock’s spectral and grain data; Grit Neg and CCD were fitted by Koco to real camera samples. Sample originals on the detail pages are AI-generated; the film is rendered live by the app."))
            licenceLink("Spectral Film LUT", "MIT License · © 2026 Jan Lohse", file: "SpectralFilmLUT-LICENSE")
            licenceLink("DSEG LCD fonts", "SIL OFL 1.1 · © 2017 keshikan", file: "DSEG-LICENSE")
        }
    }

    private func licenceLink(_ name: String, _ detail: String, file: String) -> some View {
        Button { licence = file } label: {
            VStack(alignment: .leading, spacing: 1 * s) {
                Text(verbatim: name + " ›").font(.custom("American Typewriter", size: 15 * s).weight(.semibold))
                Text(verbatim: detail).font(.custom("American Typewriter", size: 12 * s))
            }
        }
        .buttonStyle(.plain)
    }

    /// A licence's full text on a sheet of the bag's card stock, laid over
    /// the whole bag: large enough to read, scrolling, closed with its tab.
    private func licenceSheet(_ file: String) -> some View {
        let text = Bundle.main.url(forResource: file, withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? String(localized: "Licence text missing.")
        let sheet = CGRect(x: 60 * s, y: 40 * s, width: 1336 * s, height: 944 * s)
        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.45)
                .frame(width: 1456 * s, height: 1024 * s)
                .onTapGesture { licence = nil }
            Image(uiImage: RollLibrary.cardPaper).resizable()
                .frame(width: sheet.width, height: sheet.height)
                .shadow(color: .black.opacity(0.6), radius: 18 * s, y: 8 * s)
                .offset(x: sheet.minX, y: sheet.minY)
            ScrollView(.vertical) {
                Text(verbatim: text)
                    .font(.system(size: 20 * s, design: .monospaced))
                    .foregroundStyle(Self.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 60 * s).padding(.vertical, 50 * s)
            }
            .frame(width: sheet.width, height: sheet.height)
            .offset(x: sheet.minX, y: sheet.minY)
            Button { licence = nil } label: {
                Text("‹ Back").font(.custom("Marker Felt", size: 26 * s))
                    .foregroundStyle(Color(red: 0.72, green: 0.12, blue: 0.10))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .offset(x: sheet.maxX - 160 * s, y: sheet.minY + 10 * s)
        }
        .transition(.opacity)
    }

    // MARK: Certificate

    private var certificateView: some View {
        let c = r(Self.certificate.minX + 60, Self.certificate.minY + 46, Self.certificate.width - 120, 160)
        let restore = r(70, 860, 240, 52), redeem = r(368, 860, 240, 52)
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8 * s) {
                Text("Koco film certificate").font(.custom("American Typewriter", size: 15 * s)).foregroundStyle(Self.ink.opacity(0.7))
                (store.ownsAll ? Text("All films are yours") : Text("\(store.ownedPaidCount) of \(store.paidFilms.count) paid films are yours"))
                    .font(.custom("American Typewriter", size: 24 * s).weight(.semibold))
                if !store.ownsAll {
                    Text("Free films and trial shots are always there.").font(.custom("American Typewriter", size: 15 * s))
                }
            }
            .foregroundStyle(Self.ink)
            .lineLimit(2).minimumScaleFactor(0.6)
            .frame(width: c.width, height: c.height, alignment: .topLeading)
            .offset(x: c.minX, y: c.minY)
            printedBox(Text("Restore purchases"), restore) { Task { await store.restore() } }
            printedBox(Text("Redeem a code"), redeem) { redeeming = true }
        }
    }

    private func printedBox(_ title: Text, _ rect: CGRect, action: @escaping () -> Void) -> some View {
        Button(action: { Haptic.click(); action() }) {
            title.font(.custom("American Typewriter", size: 19 * s).weight(.semibold))
                .foregroundStyle(Self.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: rect.width, height: max(rect.height, 44))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: rect.minX, y: rect.minY - max(0, 44 - rect.height) / 2)
    }
}
