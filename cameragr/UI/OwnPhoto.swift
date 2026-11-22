import CoreImage
import ImageIO
import PhotosUI
import SwiftUI

/// "Try my photo", in the bag: a kraft slip tucked under the sleeve (GPT art
/// kraft_slip.png) opens the photo library; the photo picked is shown through
/// the roll looked at, full screen, to compare, and can be saved full size.
/// Processed on the phone only.
struct OwnPhoto: Identifiable {
    let id = UUID()
    let film: Film
    let data: Data
    let before: UIImage
    let after: UIImage
}

/// The slip under the sleeve.
struct TryMyPhotoSlip: View {
    @Environment(\.bagBoost) private var b
    let film: Film
    let s: CGFloat
    let opened: (OwnPhoto) -> Void
    @State private var pick: PhotosPickerItem?
    @State private var working = false
    @State private var failed = false

    static let picture = UIImage(named: "kraft_slip") ?? UIImage()
    /// Beside the sleeve's page tab, on the page's foot (bag pixels).
    static let place = CGRect(x: 826, y: 930, width: 210, height: 53)

    var body: some View {
        let r = Self.place
        PhotosPicker(selection: $pick, matching: .images) {
            Image(uiImage: Self.picture).resizable()
                .frame(width: r.width * s, height: r.height * s)
                .overlay {
                    Group {
                        if working { ProgressView().controlSize(.small).tint(BookArt.ink) }
                        else if failed { Text("Couldn’t open that one") }
                        else { Text("Try my photo") }
                    }
                    .font(.custom("Marker Felt", size: 22 * s * b))
                    .foregroundStyle(failed ? BookArt.red : BookArt.ink)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.leading, 30 * s).padding(.trailing, 20 * s)
                }
                .shadow(color: .black.opacity(0.45), radius: 2 * s, y: 1.5 * s)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(working)
        .offset(x: r.minX * s, y: r.minY * s - max(0, 44 - r.height * s) / 2)
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
        .accessibilityLabel(Text("Try my photo"))
    }

    private func load(_ item: PhotosPickerItem) async {
        working = true
        failed = false
        defer { working = false; pick = nil }   // the same photo can be picked again
        // Not loaded (still in iCloud and offline), or not a picture this phone reads.
        guard let data = try? await item.loadTransferable(type: Data.self) else { failed = true; return }
        let film = film
        let pair = await Task.detached(priority: .userInitiated) { FilmRendering.ownPhoto(data, film: film) }.value
        guard let pair else { failed = true; return }
        Haptic.click()
        opened(OwnPhoto(film: film, data: data, before: pair.before, after: pair.after))
    }
}

/// The photo picked, full screen: drag to compare, then save it or go back.
struct OwnPhotoViewer: View {
    @ObservedObject private var store = FilmStore.shared
    let photo: OwnPhoto
    let close: () -> Void
    @State private var saving = false
    @State private var saved: Bool?

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width - 32, (geo.size.height - 150) * 1.5)
            ZStack {
                Color.black.opacity(0.94).ignoresSafeArea()
                VStack(spacing: 14) {
                    CompareView(before: photo.before, after: photo.after, start: 0.5,
                                filmName: photo.film.name, unit: w / 390)
                        .frame(width: w, height: w / 1.5)
                    Text("Drag the white line to compare. Your photo is processed on this phone and never uploaded.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                    HStack(spacing: 18) {
                        slip(Text("‹ Back"), ink: BookArt.ink, action: close)
                        slip(saveTitle, ink: saved == false ? BookArt.red : BookArt.ink) { save() }
                            .disabled(saving || saved == true)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .transition(.opacity)
    }

    private var saveTitle: Text {
        if saving { return Text("Saving…") }
        switch saved {
        case true?: return Text("In your Photos")
        case false?: return Text("Couldn’t save · try again")
        case nil:
            // Looking is free; keeping a picture on a film not bought uses
            // one of its free shots, as taking one does.
            let film = photo.film
            if store.isUnlocked(film) { return Text("Save it, full size") }
            if store.trialsLeft(film) > 0 { return Text("Save it · 1 of \(store.trialsLeft(film)) free shots") }
            if let price = store.price(film) { return Text("Buy \(price) to save it") }
            return Text("Prices couldn't be loaded. Check the connection and tap to try again.")
        }
    }

    /// A kraft slip with a word on it: the viewer's buttons.
    private func slip(_ title: Text, ink: Color, action: @escaping () -> Void) -> some View {
        Button(action: { Haptic.click(); action() }) {
            Image(uiImage: TryMyPhotoSlip.picture).resizable()
                .frame(width: 210, height: 53)
                .overlay {
                    title.font(.custom("Marker Felt", size: 20))
                        .foregroundStyle(ink)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .padding(.leading, 26).padding(.trailing, 18)
                }
        }
        .buttonStyle(.plain)
    }

    /// Developed again at the photo's own size, and saved to Photos. A film
    /// not bought spends a free shot (given back if saving fails); with none
    /// left, the slip buys the film first.
    private func save() {
        guard !saving, saved != true else { return }
        let film = photo.film
        var usedTrial = false
        if !store.isUnlocked(film) {
            if store.trialsLeft(film) > 0 {
                usedTrial = store.useTrial(film)
                guard usedTrial else { return }
            } else if store.price(film) != nil {
                // Busy from the purchase to the save: a second tap starts nothing.
                saving = true
                Task {
                    let bought = await store.buy(film)
                    saving = false
                    if bought { save() }
                }
                return
            } else {
                Task { await store.loadProductsIfMissing(force: true) }
                return
            }
        }
        saving = true
        let data = photo.data
        Task {
            let jpeg = await Task.detached(priority: .userInitiated) { FilmRendering.fullSize(data, film: film) }.value
            guard let jpeg else {
                if usedTrial { store.returnTrial(film) }
                saving = false; saved = false
                return
            }
            PhotoSaver.save(jpeg) { result in
                Task { @MainActor in
                    saving = false
                    if case .success = result {
                        saved = true
                        Haptic.stop()
                    } else {
                        if usedTrial { store.returnTrial(film) }
                        saved = false
                    }
                }
            }
        }
    }
}

extension FilmRendering {
    /// One of the user's photos through the film at its full size, as a JPEG.
    static func fullSize(_ data: Data, film: Film) -> Data? {
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]),
              !image.extent.isInfinite, image.extent.width >= 1 else { return nil }
        let exif = image.properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let iso = (exif?[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber])?.first?.floatValue ?? 100
        let renderer = FilmRenderer.shared
        let placed = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        let after = renderer.filtered(placed, film: film, iso: iso).cropped(to: placed.extent)
        return renderer.context.jpegRepresentation(of: after, colorSpace: renderer.sRGB,
                                                   options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.92])
    }
}
