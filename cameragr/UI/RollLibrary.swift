import Photos
import SwiftUI

/// The phone open flat: the film library. One half shows the rolls, the
/// other the pictures taken on the roll being looked at, like a contact
/// sheet. Looking changes nothing; choosing a roll marks it ready to load,
/// and it goes into the camera when the phone is closed.
struct RollLibrary: View {
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared
    @ObservedObject private var shots = ShotLog.shared
    /// The roll being looked at (not the loaded one, not the chosen one).
    @State private var looking: Film?

    var body: some View {
        GeometryReader { geo in
            let half = CGSize(width: geo.size.width, height: geo.size.height / 2)
            let unit = half.height / 390
            let film = looking ?? model.readyToLoad ?? model.film ?? model.films[0]
            VStack(spacing: 0) {
                rolls(current: film, unit: unit)
                    .frame(width: half.width, height: half.height)
                Rectangle().fill(Color.black).frame(height: 2)
                ContactSheet(film: film, assets: shots.assets(for: film.id), unit: unit)
                    .frame(width: half.width, height: half.height - 2)
            }
            .background(PanelStyle.background)
        }
    }

    // MARK: Rolls

    private func rolls(current: Film, unit: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12 * unit) {
            HStack(alignment: .firstTextBaseline) {
                Text("Films").font(.system(size: 26 * unit, weight: .bold)).foregroundStyle(PanelStyle.text)
                Spacer()
                status(unit: unit)
            }
            ScrollViewReader { reader in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10 * unit) {
                        ForEach(model.films) { film in
                            card(film, looked: film == current, unit: unit).id(film.id)
                        }
                    }
                    .padding(.horizontal, 2 * unit)
                }
                .onAppear { reader.scrollTo(current.id, anchor: .center) }
            }
            .frame(height: 150 * unit)
            if let note = FilmNotes.all[current.id] {
                Text(note.tagline)
                    .font(.system(size: 15 * unit, weight: .semibold))
                    .foregroundStyle(PanelStyle.text)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            action(for: current, unit: unit)
        }
        .padding(.horizontal, 22 * unit)
        .padding(.top, 24 * unit)
        .padding(.bottom, 18 * unit)
    }

    /// What is in the camera, and what goes in next.
    @ViewBuilder private func status(unit: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 2 * unit) {
            if let loaded = model.film {
                Text("In the camera: \(loaded.name)")
                    .font(.system(size: 12 * unit, weight: .medium)).foregroundStyle(PanelStyle.muted)
            }
            if let next = model.readyToLoad {
                Text("Ready to load: \(next.name)")
                    .font(.system(size: 12 * unit, weight: .semibold)).foregroundStyle(PanelStyle.accent)
            }
        }
        .lineLimit(1).minimumScaleFactor(0.7)
    }

    private func card(_ film: Film, looked: Bool, unit: CGFloat) -> some View {
        let loaded = film == model.film
        let ready = film == model.readyToLoad
        return Button {
            looking = film       // only looking: the roll in the camera stays
            Haptic.click()
        } label: {
            VStack(spacing: 6 * unit) {
                Canister(film: film).frame(width: 40 * unit, height: 80 * unit)
                Text(film.name)
                    .font(.system(size: 11 * unit, weight: .semibold))
                    .foregroundStyle(PanelStyle.text)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Group {
                    if loaded { Text("In use") }
                    else if ready { Text("Ready to load") }
                    else if !store.isUnlocked(film) { Image(systemName: "lock.fill") }
                    else { Text(" ") }
                }
                .font(.system(size: 9 * unit, weight: .bold))
                .foregroundStyle(ready || loaded ? PanelStyle.accent : PanelStyle.muted)
            }
            .frame(width: 84 * unit, height: 140 * unit)
            .background(RoundedRectangle(cornerRadius: 12 * unit).fill(PanelStyle.card))
            .overlay(RoundedRectangle(cornerRadius: 12 * unit)
                .stroke(looked ? PanelStyle.text.opacity(0.8) : (ready ? PanelStyle.accent : .clear), lineWidth: 2 * unit))
        }
        .buttonStyle(.plain)
    }

    /// The one button: choose this roll, take the choice back, or buy it.
    @ViewBuilder private func action(for film: Film, unit: CGFloat) -> some View {
        let unlocked = store.isUnlocked(film)
        let trials = store.trialsLeft(film)
        let waiting = store.awaitingApproval.contains(FilmStore.productID(film))
            || store.awaitingApproval.contains(FilmStore.allFilmsID)
        if waiting {
            Text("Purchase waiting for approval")
                .font(.system(size: 13 * unit, weight: .medium)).foregroundStyle(PanelStyle.accent)
        } else if film == model.film && (unlocked || trials > 0) {
            pill("In the camera", filled: false, unit: unit) {}.disabled(true)
        } else if film == model.readyToLoad {
            VStack(alignment: .leading, spacing: 6 * unit) {
                Text("Close the phone to load it.")
                    .font(.system(size: 13 * unit, weight: .medium)).foregroundStyle(PanelStyle.accent)
                pill("Keep the roll in the camera", filled: false, unit: unit) { model.chooseInLibrary(film) }
            }
        } else if film != model.film && (unlocked || trials > 0) {
            VStack(alignment: .leading, spacing: 6 * unit) {
                if !unlocked {
                    Text("\(trials) free trial shots left")
                        .font(.system(size: 12 * unit)).foregroundStyle(PanelStyle.muted)
                }
                pill("Load this roll", filled: true, unit: unit) { model.chooseInLibrary(film) }
            }
        } else if store.price(film) == nil {
            Text("This film can't be bought right now. Try again later.")
                .font(.system(size: 12 * unit)).foregroundStyle(PanelStyle.muted)
        } else if let price = store.price(film) {
            VStack(alignment: .leading, spacing: 6 * unit) {
                Text("Free trial shots used up")
                    .font(.system(size: 12 * unit)).foregroundStyle(PanelStyle.muted)
                pill("Buy \(price)", filled: true, unit: unit) {
                    Task { if await store.buy(film) { Haptic.stop() } }
                }
                .disabled(store.purchasing != nil)
            }
        }
    }

    private func pill(_ title: LocalizedStringKey, filled: Bool, unit: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15 * unit, weight: .semibold))
                .foregroundStyle(filled ? .black : PanelStyle.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11 * unit)
                .background(Capsule().fill(filled ? PanelStyle.accent : PanelStyle.card))
        }
        .buttonStyle(.plain)
    }
}

/// The pictures taken on one roll, newest first: a plain grid for now.
private struct ContactSheet: View {
    let film: Film
    let assets: [String]
    let unit: CGFloat
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var access = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    /// The roll's pictures still in Photos (deleted or hidden ones drop out).
    @State private var shown: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10 * unit) {
            HStack {
                Text("Pictures on this roll")
                    .font(.system(size: 15 * unit, weight: .semibold)).foregroundStyle(PanelStyle.text)
                Spacer()
                if canRead {
                    Text("\(shown.count)")
                        .font(.system(size: 13 * unit, design: .monospaced)).foregroundStyle(PanelStyle.muted)
                }
            }
            if assets.isEmpty {
                hint("No pictures on this roll yet.")
            } else if access == .notDetermined {
                VStack(spacing: 10 * unit) {
                    hint("Allow access to Photos to see your pictures here.")
                    button("Allow access") {
                        Task {
                            access = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                            refresh()
                        }
                    }
                }
            } else if !canRead {
                VStack(spacing: 10 * unit) {
                    hint("Allow access to Photos to see your pictures here.")
                    button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            } else if shown.isEmpty {
                hint("These pictures were deleted, or Koco can't see them with the access it has.")
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4 * unit), count: 4),
                              spacing: 4 * unit) {
                        ForEach(shown, id: \.self) { id in
                            AssetThumbnail(id: id).aspectRatio(1, contentMode: .fill)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 22 * unit)
        .padding(.vertical, 18 * unit)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: refresh)
        .onChange(of: assets) { _, _ in refresh() }
        // Access may have been changed in Settings meanwhile.
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
    }

    private var canRead: Bool { access == .authorized || access == .limited }

    private func refresh() {
        access = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard canRead, !assets.isEmpty else { shown = []; return }
        let found = PHAsset.fetchAssets(withLocalIdentifiers: assets, options: nil)
        var present = Set<String>()
        found.enumerateObjects { asset, _, _ in present.insert(asset.localIdentifier) }
        shown = assets.filter(present.contains)   // keeps newest first
    }

    private func hint(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 13 * unit)).foregroundStyle(PanelStyle.muted)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 40 * unit)
    }

    private func button(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14 * unit, weight: .semibold)).foregroundStyle(PanelStyle.text)
                .padding(.horizontal, 18 * unit).padding(.vertical, 9 * unit)
                .background(Capsule().fill(PanelStyle.card))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
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
