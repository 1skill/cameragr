import AVFoundation
import CoreImage
import Photos
import StoreKit
import PhotosUI
import SwiftUI

// Pages opened from the strip beside the open film chamber: a film's detail
// page and the settings. They are drawn inside the body's own frame (fixed to
// the glass like the rest of it), not as system sheets, so they turn with it.

private enum PanelStyle {
    static let background = Color(red: 0.075, green: 0.072, blue: 0.066)
    static let card = Color.white.opacity(0.06)
    static let text = Color(white: 0.92)
    static let muted = Color(white: 0.58)
    static let accent = Color(red: 1.0, green: 0.62, blue: 0.15)
}

/// Covers the body with whichever page is open.
struct PanelHost: View {
    @EnvironmentObject private var model: CameraModel

    var body: some View {
        ZStack {
            if model.isStoreOpen {
                StorePanel().transition(.opacity)
            }
            switch model.panel {
            case .detail(let film):
                FilmDetailPanel(film: film)
                    .id(film.id)
                    .transition(.opacity)
            case .settings:
                SettingsPanel().transition(.opacity)
            case nil:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.panel)
        .animation(.easeInOut(duration: 0.2), value: model.isStoreOpen)
    }
}

private struct CloseButton: View {
    let unit: CGFloat
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15 * unit, weight: .semibold))
                .foregroundStyle(PanelStyle.text)
                .frame(width: 34 * unit, height: 34 * unit)
                .background(Circle().fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

// MARK: - Film detail

struct FilmDetailPanel: View {
    @EnvironmentObject private var model: CameraModel
    let film: Film
    @State private var sampleIndex = 0
    @State private var pick: PhotosPickerItem?
    /// The user's own picture, once picked: shown instead of the samples.
    @State private var own: (before: UIImage, after: UIImage)?
    @State private var working = false

    private var note: FilmNote? { FilmNotes.all[film.id] }

    var body: some View {
        GeometryReader { geo in
            // The body is landscape; sizes follow its height.
            let unit = geo.size.height / 390
            HStack(alignment: .top, spacing: 22 * unit) {
                info(unit: unit)
                    .frame(width: geo.size.width * 0.36)
                compare(unit: unit, width: geo.size.width * 0.64 - 22 * unit - 44 * unit,
                        height: geo.size.height - 40 * unit)
            }
            .padding(.horizontal, 22 * unit)
            .padding(.vertical, 20 * unit)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background(PanelStyle.background)
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task { await loadOwn(item) }
        }
    }

    private func info(unit: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10 * unit) {
            // The top left corner of the body is over the front camera: the
            // controls keep to the right of this row.
            HStack(spacing: 6 * unit) {
                Spacer()
                filmSwitcher(unit: unit)
                CloseButton(unit: unit) { model.panel = nil }
            }
            HStack(alignment: .center, spacing: 14 * unit) {
                Canister(film: film)
                    .frame(width: 44 * unit, height: 88 * unit)
                VStack(alignment: .leading, spacing: 2 * unit) {
                    Text(film.name)
                        .font(.system(size: 24 * unit, weight: .bold))
                        .foregroundStyle(PanelStyle.text)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text("ISO \(film.iso) · \(film.kind == "bw" ? String(localized: "Black & white") : String(localized: "Colour"))")
                        .font(.system(size: 12 * unit, design: .monospaced))
                        .foregroundStyle(PanelStyle.accent)
                }
            }
            if let note {
                // Long words in some languages: the text scrolls, the buttons stay.
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 10 * unit) {
                        Text(note.tagline)
                            .font(.system(size: 16 * unit, weight: .semibold))
                            .foregroundStyle(PanelStyle.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(note.about)
                            .font(.system(size: 13 * unit))
                            .foregroundStyle(PanelStyle.muted)
                            .lineSpacing(3 * unit)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 14 * unit)
                }
                // Fades out at the bottom: more text below, not cut off.
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.82), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
            }
            Spacer(minLength: 0)
            PurchaseBar(film: film, unit: unit)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func filmSwitcher(unit: CGFloat) -> some View {
        let films = model.films
        let index = films.firstIndex(of: film) ?? 0
        return HStack(spacing: 6 * unit) {
            ForEach([(-1, "chevron.left", LocalizedStringKey("Previous film")), (1, "chevron.right", LocalizedStringKey("Next film"))], id: \.0) { step, symbol, label in
                Button {
                    let next = films[(index + step + films.count) % films.count]
                    model.panel = .detail(next)
                    Haptic.click()
                } label: {
                    Image(systemName: symbol)
                        .font(.system(size: 14 * unit, weight: .semibold))
                        .foregroundStyle(PanelStyle.text)
                        .frame(width: 34 * unit, height: 34 * unit)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
            }
        }
    }

    @ViewBuilder
    private func compare(unit: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        let samples = note?.samples ?? []
        VStack(alignment: .leading, spacing: 10 * unit) {
            // Room below the picture for the sample dots, the tags and the
            // note that the samples are AI-generated (which must always show).
            let frameHeight = min(width / 1.5, height - 130 * unit)
            Group {
                if let own {
                    CompareView(before: own.before, after: own.after, start: 0.5, filmName: film.name, unit: unit)
                } else if samples.indices.contains(sampleIndex) {
                    SampleCompare(film: film, sample: samples[sampleIndex], unit: unit)
                        .id(samples[sampleIndex].file)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10 * unit).fill(PanelStyle.card)
                        Text("Samples for this film are on their way.\nTry it on one of your own photos meanwhile.")
                            .multilineTextAlignment(.center)
                            .font(.system(size: 13 * unit))
                            .foregroundStyle(PanelStyle.muted)
                    }
                }
            }
            .frame(width: frameHeight * 1.5, height: frameHeight)
            .overlay { if working { ProgressView().tint(.white) } }

            HStack(spacing: 10 * unit) {
                if samples.count > 1 && own == nil {
                    ForEach(samples.indices, id: \.self) { i in
                        Button { sampleIndex = i } label: {
                            Circle()
                                .fill(i == sampleIndex ? PanelStyle.text : PanelStyle.muted.opacity(0.5))
                                .frame(width: 8 * unit, height: 8 * unit)
                                .padding(4 * unit)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Sample \(i + 1)")
                    }
                }
                if own != nil {
                    Button { own = nil; pick = nil } label: {
                        Text("Samples").font(.system(size: 13 * unit, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PanelStyle.text)
                }
                Spacer()
                PhotosPicker(selection: $pick, matching: .images) {
                    Label("Try my photo", systemImage: "photo.on.rectangle")
                        .font(.system(size: 13 * unit, weight: .semibold))
                        .foregroundStyle(PanelStyle.text)
                        .padding(.horizontal, 12 * unit).padding(.vertical, 7 * unit)
                        .background(Capsule().fill(PanelStyle.card))
                }
            }
            .frame(width: frameHeight * 1.5)
            if own == nil, let note {
                    FlowLayout(spacing: 6 * unit) {
                        ForEach(note.suits, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 11 * unit, weight: .medium))
                                .foregroundStyle(PanelStyle.text)
                                .lineLimit(1)
                                .padding(.horizontal, 9 * unit).padding(.vertical, 4 * unit)
                                .background(Capsule().fill(PanelStyle.card))
                        }
                    }
                    .frame(width: frameHeight * 1.5, alignment: .leading)
            }
            Text(own == nil ? "Drag the white line to compare. Sample originals are AI-generated; the film is rendered live by the app."
                            : "Drag the white line to compare. Your photo is processed on this phone and never uploaded.")
                .font(.system(size: 11 * unit))
                .foregroundStyle(PanelStyle.muted)
        }
    }

    private func loadOwn(_ item: PhotosPickerItem) async {
        working = true
        defer { working = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else { return }
        let film = film
        let result = await Task.detached(priority: .userInitiated) {
            FilmRendering.pair(image, film: film, iso: 100)
        }.value
        if let result { own = result }
    }
}

/// One sample: the bundled original and the film's version, rendered here.
private struct SampleCompare: View {
    let film: Film
    let sample: FilmNote.Sample
    let unit: CGFloat
    @State private var pair: (before: UIImage, after: UIImage)?

    var body: some View {
        ZStack {
            if let pair {
                CompareView(before: pair.before, after: pair.after, start: sample.split, filmName: film.name, unit: unit)
            } else {
                RoundedRectangle(cornerRadius: 10 * unit).fill(PanelStyle.card)
                ProgressView().tint(.white)
            }
        }
        .task {
            guard pair == nil,
                  let url = Bundle.main.url(forResource: sample.file, withExtension: "jpg"),
                  let image = CIImage(contentsOf: url) else { return }
            let film = film, iso = sample.iso
            pair = await Task.detached(priority: .userInitiated) {
                FilmRendering.pair(image, film: film, iso: iso)
            }.value
        }
    }
}

enum FilmRendering {
    /// The picture as it is and through the film, at most 2048 px across.
    static func pair(_ input: CIImage, film: Film, iso: Float) -> (before: UIImage, after: UIImage)? {
        let renderer = FilmRenderer.shared
        let longest = max(input.extent.width, input.extent.height)
        var image = input.transformed(by: CGAffineTransform(translationX: -input.extent.minX, y: -input.extent.minY))
        if longest > 2048 {
            let s = 2048 / longest
            image = image.transformed(by: CGAffineTransform(scaleX: s, y: s))
        }
        let extent = image.extent.integral
        let after = renderer.filtered(image, film: film, iso: iso)
        guard let a = renderer.context.createCGImage(image, from: extent, format: .RGBA8, colorSpace: renderer.sRGB),
              let b = renderer.context.createCGImage(after, from: extent, format: .RGBA8, colorSpace: renderer.sRGB)
        else { return nil }
        return (UIImage(cgImage: a), UIImage(cgImage: b))
    }
}

/// Before and after, one over the other; drag the white line to compare.
struct CompareView: View {
    let before: UIImage
    let after: UIImage
    /// Where the line starts, 0...1 across.
    let start: Double
    let filmName: String
    let unit: CGFloat
    @State private var split: Double?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = (split ?? start) * w
            ZStack(alignment: .topLeading) {
                Image(uiImage: before).resizable().scaledToFill()
                    .frame(width: w, height: geo.size.height).clipped()
                Image(uiImage: after).resizable().scaledToFill()
                    .frame(width: w, height: geo.size.height).clipped()
                    .mask(alignment: .leading) {
                        HStack(spacing: 0) {
                            Color.clear.frame(width: x)
                            Color.black
                        }
                    }
                Rectangle().fill(.white)
                    .frame(width: 2, height: geo.size.height)
                    .shadow(color: .black.opacity(0.4), radius: 3)
                    .offset(x: x - 1)
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 12 * unit, weight: .bold))
                    .foregroundStyle(.black.opacity(0.75))
                    .frame(width: 30 * unit, height: 30 * unit)
                    .background(Circle().fill(.white.opacity(0.92)))
                    .shadow(color: .black.opacity(0.35), radius: 4)
                    .position(x: x, y: geo.size.height / 2)
                tag("iPhone").padding(8 * unit)
                tag("Koco " + filmName).padding(8 * unit)
                    .frame(width: w, alignment: .trailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10 * unit))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let next = min(max(value.location.x / w, 0), 1)
                let previous = split ?? start
                // A light tick as the line passes either end.
                if (next == 0 || next == 1) && next != previous { Haptic.click() }
                split = next
            })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("iPhone original compared with \(filmName)")
            .accessibilityValue("\(Int((split ?? start) * 100))%")
            .accessibilityAdjustableAction { direction in
                let step = direction == .increment ? 0.1 : -0.1
                split = min(max((split ?? start) + step, 0), 1)
            }
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11 * unit, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8 * unit).padding(.vertical, 3 * unit)
            .background(Capsule().fill(.black.opacity(0.55)))
            .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
    }
}

// MARK: - Settings

/// Settings, FIMO's way round: who you are to the store first (what you own,
/// restore, a redeem code), then a few switches, help and the small print.
struct SettingsPanel: View {
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared
    @Environment(\.openURL) private var openURL
    @State private var haptics = Haptic.enabled
    @State private var saveOriginal = Preferences.saveOriginal
    @State private var shutterSound = Preferences.shutterSound
    @State private var redeeming = false
    @State private var page: Page?

    private enum Page: Equatable { case tips, privacy, licences, licence(String) }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        GeometryReader { geo in
            let unit = geo.size.height / 390
            HStack(alignment: .top, spacing: 22 * unit) {
                VStack(alignment: .leading, spacing: 14 * unit) {
                    // Kept clear of the front camera in the top left corner.
                    HStack { Spacer(); CloseButton(unit: unit) { model.panel = nil } }
                    Text("Settings")
                        .font(.system(size: 24 * unit, weight: .bold))
                        .foregroundStyle(PanelStyle.text)
                    membership(unit: unit)
                    Spacer(minLength: 0)
                }
                .frame(width: geo.size.width * 0.34, alignment: .leading)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16 * unit) {
                        if AppLinks.appStore != nil || AppLinks.social != nil {
                            section("Share", unit: unit) {
                                if let url = AppLinks.appStore {
                                    ShareLink(item: url, message: Text("Koco — a film camera for iPhone")) {
                                        rowLabel("Recommend Koco to a friend", symbol: "square.and.arrow.up", unit: unit)
                                    }
                                    .buttonStyle(.plain)
                                    divider
                                }
                                if let url = AppLinks.writeReview {
                                    row("Rate Koco", symbol: "star", unit: unit) { openURL(url) }
                                    divider
                                }
                                if let url = AppLinks.social {
                                    row("Follow Koco", symbol: "person.2", unit: unit) { openURL(url) }
                                }
                            }
                        }
                        section("Shooting", unit: unit) {
                            toggle("Save the iPhone original too", isOn: $saveOriginal, unit: unit) { Preferences.saveOriginal = $0 }
                            divider
                            toggle("Shutter sound", isOn: $shutterSound, unit: unit,
                                   note: "Some regions always play it.") { Preferences.shutterSound = $0 }
                            divider
                            toggle("Haptics", isOn: $haptics, unit: unit) { on in
                                Haptic.enabled = on
                                if on { Haptic.tap() }
                            }
                        }
                        section("Help", unit: unit) {
                            row("Tips", symbol: "lightbulb", unit: unit) { page = .tips }
                            divider
                            row("Camera and Photos access", symbol: "lock.shield", detail: accessSummary, unit: unit) {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                            if let mail = AppLinks.supportEmail, let url = URL(string: "mailto:\(mail)") {
                                divider
                                row("Send feedback", symbol: "envelope", detail: mail, unit: unit) { openURL(url) }
                            }
                        }
                        section("About", unit: unit) {
                            row("Privacy", symbol: "hand.raised", unit: unit) { page = .privacy }
                            divider
                            row("Terms of use", symbol: "doc.text", unit: unit) { openURL(AppLinks.terms) }
                            divider
                            row("Open-source licences", symbol: "chevron.left.forwardslash.chevron.right", unit: unit) { page = .licences }
                            divider
                            HStack {
                                Text("Version").font(.system(size: 14 * unit)).foregroundStyle(PanelStyle.text)
                                Spacer()
                                Text(verbatim: version).font(.system(size: 12 * unit, design: .monospaced))
                                    .foregroundStyle(PanelStyle.muted)
                            }
                        }
                    }
                    .padding(.bottom, 30 * unit)
                }
            }
            .padding(.horizontal, 22 * unit)
            .padding(.vertical, 18 * unit)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background(PanelStyle.background)
            .overlay { if let page { subpage(page, unit: unit) } }
        }
        .offerCodeRedemption(isPresented: $redeeming) { _ in
            Task { await store.refresh() }
        }
        #if DEBUG
        // `-settingsPage tips|privacy|licences|spectral|dseg`: open a sub-page, for layout checks.
        .onAppear {
            switch UserDefaults.standard.string(forKey: "settingsPage") {
            case "tips": page = .tips
            case "privacy": page = .privacy
            case "licences": page = .licences
            case "spectral": page = .licence("SpectralFilmLUT-LICENSE")
            case "dseg": page = .licence("DSEG-LICENSE")
            default: break
            }
        }
        #endif
    }

    // MARK: Membership

    private func membership(unit: CGFloat) -> some View {
        let total = store.paidFilms.count
        return VStack(alignment: .leading, spacing: 10 * unit) {
            HStack(spacing: -4 * unit) {
                ForEach(store.paidFilms.prefix(4)) { film in
                    Canister(film: film).frame(width: 22 * unit, height: 44 * unit)
                        .opacity(store.isUnlocked(film) ? 1 : 0.35)
                }
            }
            Text(store.ownsAll ? "All films are yours" : "\(store.ownedPaidCount) of \(total) paid films are yours")
                .font(.system(size: 15 * unit, weight: .bold))
                .foregroundStyle(PanelStyle.text)
                .fixedSize(horizontal: false, vertical: true)
            if !store.ownsAll {
                Text("Free films and trial shots are always there.")
                    .font(.system(size: 11 * unit))
                    .foregroundStyle(PanelStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                model.panel = nil
                model.isStoreOpen = true
            } label: {
                Text(store.ownsAll ? "Film store" : "Get more films")
                    .font(.system(size: 13 * unit, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8 * unit)
                    .background(Capsule().fill(PanelStyle.accent))
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 7 * unit) {
                Button("Restore purchases") { Task { await store.restore() } }
                Button("Redeem a code") { redeeming = true }
            }
            .font(.system(size: 12 * unit, weight: .medium))
            .foregroundStyle(PanelStyle.accent)
            .buttonStyle(.plain)
        }
        .padding(14 * unit)
        .background(RoundedRectangle(cornerRadius: 14 * unit)
            .fill(LinearGradient(colors: [PanelStyle.accent.opacity(0.2), PanelStyle.card],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
    }

    private var accessSummary: LocalizedStringKey {
        let camera = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        let photos = [.authorized, .limited].contains(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        switch (camera, photos) {
        case (true, true): return "Allowed"
        case (false, false): return "Not allowed"
        case (false, true): return "Camera not allowed"
        case (true, false): return "Photos not allowed"
        }
    }

    // MARK: Rows

    private var divider: some View { Divider().overlay(Color.white.opacity(0.08)) }

    private func section<Content: View>(_ title: LocalizedStringKey, unit: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7 * unit) {
            Text(title)
                .font(.system(size: 12 * unit, weight: .semibold))
                .kerning(1 * unit)
                .foregroundStyle(PanelStyle.muted)
                .padding(.leading, 4 * unit)
            VStack(alignment: .leading, spacing: 10 * unit) { content() }
                .padding(.horizontal, 14 * unit).padding(.vertical, 11 * unit)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12 * unit).fill(PanelStyle.card))
        }
    }

    private func rowLabel(_ title: LocalizedStringKey, symbol: String, detail: LocalizedStringKey? = nil, unit: CGFloat) -> some View {
        HStack(spacing: 10 * unit) {
            Image(systemName: symbol)
                .font(.system(size: 14 * unit))
                .foregroundStyle(PanelStyle.accent)
                .frame(width: 20 * unit)
            Text(title).font(.system(size: 14 * unit)).foregroundStyle(PanelStyle.text)
            Spacer(minLength: 6 * unit)
            if let detail { Text(detail).font(.system(size: 12 * unit)).foregroundStyle(PanelStyle.muted) }
            Image(systemName: "chevron.right").font(.system(size: 11 * unit, weight: .semibold)).foregroundStyle(PanelStyle.muted)
        }
        .contentShape(Rectangle())
    }

    private func row(_ title: LocalizedStringKey, symbol: String, detail: LocalizedStringKey? = nil, unit: CGFloat,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) { rowLabel(title, symbol: symbol, detail: detail, unit: unit) }
            .buttonStyle(.plain)
    }

    private func row(_ title: LocalizedStringKey, symbol: String, detail: String, unit: CGFloat,
                     action: @escaping () -> Void) -> some View {
        row(title, symbol: symbol, detail: LocalizedStringKey(detail), unit: unit, action: action)
    }

    private func toggle(_ title: LocalizedStringKey, isOn: Binding<Bool>, unit: CGFloat, note: LocalizedStringKey? = nil,
                        onChange: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2 * unit) {
                Text(title).font(.system(size: 14 * unit)).foregroundStyle(PanelStyle.text)
                if let note { Text(note).font(.system(size: 11 * unit)).foregroundStyle(PanelStyle.muted) }
            }
        }
        .tint(PanelStyle.accent)
        .onChange(of: isOn.wrappedValue) { _, on in onChange(on) }
    }

    // MARK: Pages

    private func subpage(_ page: Page, unit: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12 * unit) {
            HStack {
                if case .licence = page {
                    Button { self.page = .licences } label: {
                        Image(systemName: "chevron.left").font(.system(size: 15 * unit, weight: .semibold))
                            .foregroundStyle(PanelStyle.text)
                            .frame(width: 34 * unit, height: 34 * unit)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
                Spacer()
                CloseButton(unit: unit) { self.page = nil }
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12 * unit) {
                    switch page {
                    case .tips: tips(unit: unit)
                    case .privacy: privacy(unit: unit)
                    case .licences: licences(unit: unit)
                    case .licence(let file): licenceText(file, unit: unit)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 30 * unit)
            }
        }
        .padding(.horizontal, 26 * unit).padding(.vertical, 18 * unit)
        .background(PanelStyle.background)
    }

    private func pageTitle(_ text: LocalizedStringKey, unit: CGFloat) -> some View {
        Text(text).font(.system(size: 22 * unit, weight: .bold)).foregroundStyle(PanelStyle.text)
    }

    private func paragraph(_ text: LocalizedStringKey, unit: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 13 * unit))
            .foregroundStyle(PanelStyle.muted)
            .lineSpacing(3 * unit)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func tip(_ title: LocalizedStringKey, _ text: LocalizedStringKey, unit: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3 * unit) {
            Text(title).font(.system(size: 14 * unit, weight: .semibold)).foregroundStyle(PanelStyle.text)
            paragraph(text, unit: unit)
        }
    }

    @ViewBuilder
    private func tips(unit: CGFloat) -> some View {
        pageTitle("Tips", unit: unit)
        tip("Change film", "Tap the film door on the right to open the chamber, then tap the roll to rewind it and pick another.", unit: unit)
        tip("The Camera Control button", "In the iPhone’s Settings › Camera › Camera Control, choose Koco to open it with a press, even from the Lock Screen.", unit: unit)
        tip("Lock Screen and Control Center", "Add Koco from the Lock Screen’s and Control Center’s controls to start shooting without unlocking.", unit: unit)
        tip("Foldable iPhone", "Open the phone halfway: the outer half is the camera, the inner half becomes a waist-level finder.", unit: unit)
        tip("Try a film on your photos", "On a film’s page, choose Try my photo to see it on any picture from your library.", unit: unit)
    }

    @ViewBuilder
    private func privacy(unit: CGFloat) -> some View {
        pageTitle("Privacy", unit: unit)
        paragraph("Koco works entirely on your iPhone. Your pictures are developed on the phone and saved to your photo library; nothing is uploaded, and Koco has no servers or accounts.", unit: unit)
        paragraph("Koco collects no personal data, uses no analytics or advertising, and does not track you. Purchases are handled by Apple; Koco only learns which films your Apple ID owns.", unit: unit)
        paragraph("The camera is used only to take pictures, and the photo library only to save them and to open pictures you choose to try a film on.", unit: unit)
    }

    @ViewBuilder
    private func licences(unit: CGFloat) -> some View {
        pageTitle("Open-source licences", unit: unit)
        paragraph("Film colour and grain come from the open-source Spectral Film LUT, computed from each stock’s spectral and grain data; GR Neg and CCD were fitted by Koco to real camera samples. Sample originals on the detail pages are AI-generated; the film is rendered live by the app.", unit: unit)
        VStack(alignment: .leading, spacing: 10 * unit) {
            row("Spectral Film LUT", symbol: "doc.plaintext", detail: "MIT License · © 2026 Jan Lohse", unit: unit) {
                page = .licence("SpectralFilmLUT-LICENSE")
            }
            divider
            row("DSEG LCD fonts", symbol: "doc.plaintext", detail: "SIL OFL 1.1 · © 2017 keshikan", unit: unit) {
                page = .licence("DSEG-LICENSE")
            }
        }
        .padding(14 * unit)
        .background(RoundedRectangle(cornerRadius: 12 * unit).fill(PanelStyle.card))
    }

    private func licenceText(_ file: String, unit: CGFloat) -> some View {
        let text = Bundle.main.url(forResource: file, withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? String(localized: "Licence text missing.")
        // Licence files are wrapped at 80 columns: at this size a full line
        // fits the page, so the text keeps its own line breaks instead of
        // breaking again a word before the end.
        return Text(text)
            .font(.system(size: 10 * unit, design: .monospaced))
            .foregroundStyle(PanelStyle.text)
            .textSelection(.enabled)
    }
}

// MARK: - Buying

/// Under a film's description: load it, try it, or buy it.
private struct PurchaseBar: View {
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared
    let film: Film
    let unit: CGFloat

    var body: some View {
        let unlocked = store.isUnlocked(film)
        let inUse = film == model.film
        VStack(alignment: .leading, spacing: 8 * unit) {
            if !unlocked {
                let waiting = store.awaitingApproval.contains(FilmStore.productID(film))
                    || store.awaitingApproval.contains(FilmStore.allFilmsID)
                Text(waiting ? "Purchase waiting for approval"
                     : store.trialsLeft(film) > 0 ? "\(store.trialsLeft(film)) free trial shots left" : "Free trial shots used up")
                    .font(.system(size: 12 * unit))
                    .foregroundStyle(waiting ? PanelStyle.accent : PanelStyle.muted)
            }
            HStack(spacing: 8 * unit) {
                if !(unlocked && inUse) {
                    pill(unlocked ? "Load this roll" : (inUse ? "Trying" : "Try it"),
                         filled: unlocked, enabled: !inUse && (unlocked || store.trialsLeft(film) > 0)) {
                        load()
                    }
                } else {
                    pill("In use", filled: false, enabled: false) {}
                }
                if !unlocked, let price = store.price(film) {
                    pill(store.purchasing == FilmStore.productID(film) ? "…" : "Buy \(price)", filled: true,
                         enabled: store.purchasing == nil) {
                        Task { if await store.buy(film) { Haptic.stop() } }
                    }
                }
            }
            if !unlocked, !store.ownsAll, let all = store.allFilmsPrice {
                Button {
                    Task { if await store.buy(nil) { Haptic.stop() } }
                } label: {
                    Text("Or all films for \(all), new ones included")
                        .font(.system(size: 12 * unit, weight: .medium))
                        .foregroundStyle(PanelStyle.accent)
                        .underline()
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)
                .disabled(store.purchasing != nil)
            }
        }
    }

    private func load() {
        model.panel = nil
        model.isStoreOpen = false
        model.isBayOpen = false
        if film != model.film { model.load(film) }
    }

    private func pill(_ title: LocalizedStringKey, filled: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14 * unit, weight: .semibold))
                .foregroundStyle(filled ? .black : (enabled ? PanelStyle.text : PanelStyle.muted))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10 * unit)
                .background(Capsule().fill(filled ? PanelStyle.accent : PanelStyle.card))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// All films, FIMO-style: a card per film with its samples, and what it
/// takes to use it right on the card. A card opens the film's page.
struct StorePanel: View {
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared

    var body: some View {
        GeometryReader { geo in
            let unit = geo.size.height / 390
            VStack(spacing: 12 * unit) {
                // The top left corner is over the front camera: the title starts after it.
                HStack(spacing: 14 * unit) {
                    Text("Films")
                        .font(.system(size: 24 * unit, weight: .bold))
                        .foregroundStyle(PanelStyle.text)
                    Spacer()
                    Button("Restore purchases") { Task { await store.restore() } }
                        .font(.system(size: 13 * unit, weight: .medium))
                        .foregroundStyle(PanelStyle.accent)
                        .buttonStyle(.plain)
                    CloseButton(unit: unit) { model.isStoreOpen = false }
                }
                .padding(.leading, geo.size.width * 0.12)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10 * unit) {
                        allFilms(unit: unit)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10 * unit), GridItem(.flexible(), spacing: 10 * unit)],
                                  spacing: 10 * unit) {
                            ForEach(sorted) { film in
                                StoreCard(film: film, unit: unit)
                            }
                        }
                    }
                    .padding(.bottom, 24 * unit)
                }
            }
            .padding(.horizontal, 18 * unit)
            .padding(.top, 16 * unit)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .background(PanelStyle.background)
        }
    }

    /// Yours first (free and bought), then the rest, each in catalogue order.
    private var sorted: [Film] {
        let films = model.films
        return films.filter(store.isUnlocked) + films.filter { !store.isUnlocked($0) }
    }

    private func allFilms(unit: CGFloat) -> some View {
        HStack(spacing: 14 * unit) {
            HStack(spacing: -6 * unit) {
                ForEach(store.paidFilms.prefix(4)) { film in
                    Canister(film: film).frame(width: 26 * unit, height: 52 * unit)
                }
            }
            VStack(alignment: .leading, spacing: 3 * unit) {
                Text("All films")
                    .font(.system(size: 17 * unit, weight: .bold))
                    .foregroundStyle(PanelStyle.text)
                Text(store.ownsAll ? "Every film is yours, including new ones as they come."
                                   : "Every film, now and later. One purchase, shared with your family.")
                    .font(.system(size: 12 * unit))
                    .foregroundStyle(PanelStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if store.ownsAll {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22 * unit))
                    .foregroundStyle(PanelStyle.accent)
            } else if let price = store.allFilmsPrice {
                Button {
                    Task { if await store.buy(nil) { Haptic.stop() } }
                } label: {
                    Text(store.purchasing == FilmStore.allFilmsID ? "…" : price)
                        .font(.system(size: 15 * unit, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16 * unit).padding(.vertical, 8 * unit)
                        .background(Capsule().fill(PanelStyle.accent))
                }
                .buttonStyle(.plain)
                .disabled(store.purchasing != nil)
            }
        }
        .padding(14 * unit)
        .background(RoundedRectangle(cornerRadius: 14 * unit)
            .fill(LinearGradient(colors: [PanelStyle.accent.opacity(0.22), PanelStyle.card],
                                 startPoint: .leading, endPoint: .trailing)))
    }
}

private struct StoreCard: View {
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared
    let film: Film
    let unit: CGFloat

    var body: some View {
        let unlocked = store.isUnlocked(film)
        Button {
            model.panel = .detail(film)
            Haptic.tap()
        } label: {
            VStack(alignment: .leading, spacing: 8 * unit) {
                HStack(alignment: .top, spacing: 10 * unit) {
                    Canister(film: film).frame(width: 26 * unit, height: 52 * unit)
                    VStack(alignment: .leading, spacing: 2 * unit) {
                        Text(film.name)
                            .font(.system(size: 15 * unit, weight: .bold))
                            .foregroundStyle(PanelStyle.text)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text(FilmNotes.all[film.id]?.tagline ?? "")
                            .font(.system(size: 11 * unit))
                            .foregroundStyle(PanelStyle.muted)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    status(unlocked: unlocked)
                }
                HStack(spacing: 6 * unit) {
                    ForEach((FilmNotes.all[film.id]?.samples ?? []).prefix(3), id: \.file) { sample in
                        Thumbnail(film: film, sample: sample)
                            .aspectRatio(1.5, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 5 * unit))
                    }
                }
            }
            .padding(12 * unit)
            .background(RoundedRectangle(cornerRadius: 14 * unit).fill(PanelStyle.card))
            .overlay(RoundedRectangle(cornerRadius: 14 * unit)
                .stroke(film == model.film ? PanelStyle.accent.opacity(0.7) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(film.name)
    }

    @ViewBuilder
    private func status(unlocked: Bool) -> some View {
        if film == model.film && unlocked {
            tag("In use", filled: false)
        } else if unlocked {
            Button { use() } label: { tag("Use", filled: false) }.buttonStyle(.plain)
        } else if let price = store.price(film) {
            Button {
                Task { if await store.buy(film) { Haptic.stop() } }
            } label: { tag(store.purchasing == FilmStore.productID(film) ? "…" : LocalizedStringKey(price), filled: true) }
            .buttonStyle(.plain)
            .disabled(store.purchasing != nil)
        }
    }

    private func use() {
        model.isStoreOpen = false
        model.isBayOpen = false
        model.load(film)
    }

    private func tag(_ text: LocalizedStringKey, filled: Bool) -> some View {
        Text(text)
            .font(.system(size: 12 * unit, weight: .bold))
            .foregroundStyle(filled ? .black : PanelStyle.accent)
            .padding(.horizontal, 10 * unit).padding(.vertical, 5 * unit)
            .background(Capsule().fill(filled ? PanelStyle.accent : .clear))
            .overlay(Capsule().stroke(PanelStyle.accent, lineWidth: filled ? 0 : 1))
    }
}

/// A small sample through its film, rendered once and kept.
private struct Thumbnail: View {
    let film: Film
    let sample: FilmNote.Sample
    @State private var image: UIImage?
    @MainActor private static var cache: [String: UIImage] = [:]
    /// Emptied when the system runs short of memory; redrawn when next shown.
    @MainActor private static let forgetsOnMemoryWarning: Void = {
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
                                               object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Thumbnail.cache.removeAll() }
        }
    }()

    var body: some View {
        ZStack {
            Color.white.opacity(0.05)
            if let image { Image(uiImage: image).resizable().scaledToFill() }
        }
        .task {
            Self.forgetsOnMemoryWarning
            let key = film.id + "/" + sample.file
            if let hit = Self.cache[key] { image = hit; return }
            guard let url = Bundle.main.url(forResource: sample.file, withExtension: "jpg"),
                  let full = CIImage(contentsOf: url) else { return }
            let film = film, iso = sample.iso
            let small = full.transformed(by: CGAffineTransform(scaleX: 360 / full.extent.width, y: 360 / full.extent.width))
            let rendered = await Task.detached(priority: .utility) {
                FilmRendering.pair(small, film: film, iso: iso)?.after
            }.value
            if let rendered { Self.cache[key] = rendered; image = rendered }
        }
    }
}


/// Lays its children out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width + 0.5 { y += row + spacing; x = 0; row = 0 }
            x += size.width + spacing
            row = max(row, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, width), height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Wrap where the measuring wrapped: at the width offered, not at the
        // (possibly narrower) width this layout answered with, and with a
        // hair of slack, so rounding cannot push the last tag to a new row
        // that was never measured, over whatever lies below.
        let limit = bounds.minX + max(bounds.width, proposal.width ?? 0) + 0.5
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > limit { y += row + spacing; x = bounds.minX; row = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}
