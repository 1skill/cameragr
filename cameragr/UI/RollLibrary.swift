import Photos
import SwiftUI

/// The phone open flat: the film library, as two real things on the two
/// halves of the screen. Above, a film-cabinet drawer: each roll stands in
/// its foam pocket, and the pocket of the roll in the camera is empty. Below,
/// a light table: the pictures taken on the roll being looked at, as slides.
///
/// Tap a roll to look at it (it lifts, its slides come up); tap it again to
/// choose it: the card on the drawer says so, and the roll goes into the
/// camera when the phone is closed. Looking alone changes nothing.
///
/// The drawer and the light table are pictures (GPT, `library_*.jpg`, made
/// from `design/library/*_template.png`); the rolls, slides and writing are
/// placed at the template's measured rectangles, in picture pixels (1442×1024).
struct RollLibrary: View {
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared
    @ObservedObject private var shots = ShotLog.shared
    /// The roll being looked at (not the loaded one, not the chosen one).
    @State private var looking: Film?

    static let art = CGSize(width: 1442, height: 1024)
    static let drawerArt = UIImage(named: "library_drawer.jpg") ?? UIImage()
    /// The drawer's ten pockets, two rows of five.
    static let pockets: [CGRect] = (0..<2).flatMap { row in
        (0..<5).map { col in CGRect(x: 93 + CGFloat(col) * 256, y: 110 + CGFloat(row) * 360, width: 200, height: 300) }
    }
    /// The cream card in the brass holder on the drawer's front.
    static let card = CGRect(x: 548, y: 874, width: 340, height: 90)

    var body: some View {
        GeometryReader { geo in
            let half = CGSize(width: geo.size.width, height: geo.size.height / 2)
            let film = looking ?? model.readyToLoad ?? model.film ?? model.films[0]
            VStack(spacing: 0) {
                drawer(looked: film, size: half)
                LightTable(film: film, assets: shots.assets(for: film.id))
                    .frame(width: half.width, height: half.height)
            }
        }
        .background(Color.black)
        #if DEBUG
        // `-demoShots 1`: files the library's newest photos under the loaded
        // roll, so the light table can be checked in the simulator.
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

    // MARK: Drawer

    private func drawer(looked: Film, size: CGSize) -> some View {
        let s = size.width / Self.art.width
        return ZStack(alignment: .topLeading) {
            // The picture and what is placed on it share one scale.
            Image(uiImage: Self.drawerArt).resizable()
                .frame(width: Self.art.width * s, height: Self.art.height * s)
            ForEach(Array(model.films.prefix(Self.pockets.count).enumerated()), id: \.element.id) { i, film in
                pocket(film, rect: Self.pockets[i].scaled(s), looked: film == looked)
            }
            cardText(looked: looked)
                .frame(width: Self.card.width * s, height: Self.card.height * s)
                .offset(x: Self.card.minX * s, y: Self.card.minY * s)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    /// One pocket: its roll standing in it, lifted while looked at; empty
    /// when the roll is in the camera.
    private func pocket(_ film: Film, rect: CGRect, looked: Bool) -> some View {
        let inCamera = film == model.film
        let ready = film == model.readyToLoad
        let lift: CGFloat = looked || ready ? rect.height * 0.08 : 0
        return Button {
            if looked && !inCamera { choose(film) } else { looking = film }
            Haptic.click()
        } label: {
            ZStack {
                Color.clear
                if inCamera {
                    // Its pocket is empty: the roll is in the camera.
                    Text("In the camera")
                        .font(.custom("American Typewriter", size: rect.width * 0.11))
                        .foregroundStyle(Color(white: 0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, rect.width * 0.08)
                } else {
                    Canister(film: film)
                        .frame(width: rect.width * 0.82, height: rect.width * 0.82 / 0.68)
                        .shadow(color: .black.opacity(0.7), radius: lift > 0 ? rect.width * 0.08 : rect.width * 0.02,
                                y: lift > 0 ? rect.width * 0.06 : 0)
                        .offset(y: -lift)
                        .overlay(alignment: .topTrailing) {
                            // Not bought and no trial shots left: a small lock on its lid.
                            if !store.isUnlocked(film) && store.trialsLeft(film) == 0 {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: rect.width * 0.12))
                                    .foregroundStyle(Color(white: 0.85))
                                    .offset(y: -lift)
                            }
                        }
                }
            }
            .frame(width: rect.width, height: rect.height)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: lift)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(film.name)
        .offset(x: rect.minX, y: rect.minY)
    }

    private func choose(_ film: Film) {
        if store.isUnlocked(film) || store.trialsLeft(film) > 0 || film == model.readyToLoad {
            model.chooseInLibrary(film)
        } else {
            Task { if await store.buy(film) { model.chooseInLibrary(film); Haptic.stop() } }
        }
    }

    /// What the card on the drawer says: the roll looked at, and what to do with it.
    private func cardText(looked: Film) -> some View {
        let line: LocalizedStringKey
        if looked == model.film {
            line = "In the camera"
        } else if looked == model.readyToLoad {
            line = "Close the phone to load it · tap to undo"
        } else if store.awaitingApproval.contains(FilmStore.productID(looked)) {
            line = "Purchase waiting for approval"
        } else if store.isUnlocked(looked) {
            line = "Tap again to load it"
        } else if store.trialsLeft(looked) > 0 {
            line = "Tap again to try it · \(store.trialsLeft(looked)) shots"
        } else if let price = store.price(looked) {
            line = "Tap again to buy · \(price)"
        } else {
            line = "Can't be bought right now"
        }
        return GeometryReader { g in
            VStack(spacing: g.size.height * 0.04) {
                Text(looked.name)
                    .font(.custom("American Typewriter", size: g.size.height * 0.36).weight(.semibold))
                Text(line)
                    .font(.custom("American Typewriter", size: g.size.height * 0.22))
            }
            .foregroundStyle(Color(red: 0.16, green: 0.13, blue: 0.10))
            .lineLimit(1).minimumScaleFactor(0.5)
            .frame(width: g.size.width, height: g.size.height)
        }
    }
}

private extension CGRect {
    func scaled(_ s: CGFloat) -> CGRect { CGRect(x: minX * s, y: minY * s, width: width * s, height: height * s) }
}

/// The light table: the roll's pictures, newest first, as slides in their
/// mounts, twelve at a time; swipe for more. Writing on the masking tape.
private struct LightTable: View {
    let film: Film
    let assets: [String]
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var access = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    /// The roll's pictures still in Photos (deleted or hidden ones drop out).
    @State private var shown: [String] = []
    @State private var page = 0

    /// The twelve slide windows, four by three, and the tape.
    static let windows: [CGRect] = (0..<3).flatMap { row in
        (0..<4).map { col in CGRect(x: 158 + CGFloat(col) * 300, y: 215 + CGFloat(row) * 280, width: 180, height: 120) }
    }
    static let tape = CGRect(x: 123, y: 40, width: 520, height: 80)
    static let tableArt = UIImage(named: "library_lighttable.jpg") ?? UIImage()

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / RollLibrary.art.width
            let pages = max(1, (shown.count + 11) / 12)
            let onPage = Array(shown.dropFirst(min(page, pages - 1) * 12).prefix(12))
            ZStack(alignment: .topLeading) {
                Image(uiImage: Self.tableArt).resizable()
                    .frame(width: RollLibrary.art.width * s, height: RollLibrary.art.height * s)
                ForEach(Array(onPage.enumerated()), id: \.element) { i, id in
                    let r = Self.windows[i]
                    AssetThumbnail(id: id)
                        .frame(width: r.width * s, height: r.height * s)
                        .offset(x: r.minX * s, y: r.minY * s)
                }
                tapeText(pages: pages)
                    .frame(width: Self.tape.width * s, height: Self.tape.height * s)
                    .offset(x: Self.tape.minX * s, y: Self.tape.minY * s)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 30).onEnded { drag in
                guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                let next = page + (drag.translation.width < 0 ? 1 : -1)
                if (0..<pages).contains(next) { withAnimation(.easeOut(duration: 0.2)) { page = next }; Haptic.click() }
            })
        }
        .onAppear(perform: refresh)
        .onChange(of: assets) { _, _ in page = 0; refresh() }
        // Access may have been changed in Settings meanwhile.
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
    }

    private var canRead: Bool { access == .authorized || access == .limited }

    /// Handwritten on the tape: the roll and how many pictures, or what is missing.
    private func tapeText(pages: Int) -> some View {
        let text: Text
        var action: (() -> Void)?
        if assets.isEmpty {
            text = Text("\(film.name) — no pictures yet")
        } else if access == .notDetermined {
            text = Text("Tap to let Koco see your pictures")
            action = {
                Task {
                    access = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    refresh()
                }
            }
        } else if !canRead {
            text = Text("Allow Photos in Settings to see them")
            action = { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
        } else if shown.isEmpty {
            text = Text("\(film.name) — pictures deleted or hidden")
        } else if pages > 1 {
            text = Text("\(film.name) · \(shown.count) · \(min(page, pages - 1) + 1)/\(pages)")
        } else {
            text = Text("\(film.name) · \(shown.count)")
        }
        return GeometryReader { g in
            Button { action?() } label: {
                text
                    .font(.custom("Marker Felt", size: g.size.height * 0.42))
                    .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.2).opacity(0.85))
                    .lineLimit(1).minimumScaleFactor(0.4)
                    .frame(width: g.size.width, height: g.size.height)
                    .rotationEffect(.degrees(-1.2))
            }
            .buttonStyle(.plain)
            .disabled(action == nil)
        }
    }

    private func refresh() {
        access = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard canRead, !assets.isEmpty else { shown = []; return }
        let found = PHAsset.fetchAssets(withLocalIdentifiers: assets, options: nil)
        var present = Set<String>()
        found.enumerateObjects { asset, _, _ in present.insert(asset.localIdentifier) }
        // Missing pictures are only left off the table, never forgotten: a
        // hidden or unselected picture looks just like a deleted one here.
        shown = assets.filter(present.contains)   // keeps newest first
    }
}

/// One picture from Photos, small. A picture no longer there shows as empty.
private struct AssetThumbnail: View {
    let id: String
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.opacity(0.05)
                if let image { Image(uiImage: image).resizable().scaledToFill() }
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
                PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 300, height: 300),
                                                      contentMode: .aspectFill, options: options) { picture, info in
                    let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if !degraded && !resumed { resumed = true; done.resume(returning: picture) }
                }
            }
        }
    }
}
