import SwiftUI
import Photos

/// One's own pictures from a roll in the film album, looked at the way the
/// community's are (user 11/24): the picture beside a narrow slip, zoomed
/// inside its frame; a double tap goes full screen (filling the glass, the
/// words over it, a tap hides them); a sideways swipe goes on through the
/// roll. A picture that went into the Community shows its likes there, and
/// opens its comments.
struct OwnPicturesViewer: View {
    @ObservedObject private var club = ClubModel.shared
    @ObservedObject private var log = ShotLog.shared
    let film: Film
    let assets: [String]
    let start: Int
    /// How far the glass goes past this view's frame (the bag's margins).
    var outset: CGFloat = 0
    let close: () -> Void

    @State private var index = 0
    @State private var direction = 1
    @State private var fullScreen = UserDefaults.standard.bool(forKey: "ownFull")   // `-ownFull 1`, for checks
    @State private var wordsShown = true
    @State private var aspect: CGFloat = 1.5
    /// The post this picture went into, if it did: read off the account's
    /// own list, so it follows likes, deletions and a change of account.
    private var post: Community.Post? { asset.flatMap { club.ownPost(asset: $0) } }

    private var asset: String? { assets.indices.contains(index) ? assets[index] : nil }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let wide = w > h * 1.1
            ZStack {
                Color.black.opacity(fullScreen ? 1 : 0.92).ignoresSafeArea()
                    .onTapGesture { if !fullScreen { close() } }
                if let asset {
                    if fullScreen {
                        ZoomablePicture(onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) { wordsShown.toggle() }
                        }, onSwipe: { step($0) }) { AssetThumbnail(id: asset, side: 4096, fill: true) }
                            .padding(-outset)
                            .ignoresSafeArea()
                            .id(asset)
                            .transition(slide)
                        if wordsShown {
                            slip
                                .frame(width: sideWidth(w))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                .padding(16)
                                .transition(.opacity)
                        }
                    } else {
                        let box = wide ? CGSize(width: w - sideWidth(w) - 48, height: h * 0.84)
                                       : CGSize(width: w * 0.9, height: h * 0.6)
                        let pic = fit(box)
                        let picture = ZoomablePicture(onDoubleTap: { goFull(true) }, onSwipe: { step($0) }) {
                            AssetThumbnail(id: asset, side: 4096, fill: false)
                        }
                        .frame(width: pic.width, height: pic.height)
                        .id(asset)
                        .transition(slide)
                        if wide {
                            HStack(alignment: .top, spacing: 14) {
                                picture
                                slip.frame(width: sideWidth(w))
                            }
                        } else {
                            VStack(spacing: 10) {
                                picture
                                slip.frame(width: max(pic.width, min(w * 0.9, 420)))
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if !fullScreen || wordsShown {
                    HStack(spacing: 6) {
                        Button { goFull(!fullScreen) } label: {
                            Image(systemName: fullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(.black.opacity(0.5)))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(fullScreen ? "Exit Full Screen" : "Full Screen"))
                        Button("Close", action: close)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(.black.opacity(0.5)))
                    }
                    .padding(16)
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            index = min(max(start, 0), max(assets.count - 1, 0))
        }
        .task(id: asset) {
            aspect = 1.5
            guard let asset, let size = Self.size(of: asset), size.height > 0 else { return }
            aspect = size.width / size.height
        }
        // Once on opening, only when one of these pictures went in (signed out: no request).
        .task {
            await club.refreshOwn(assets: assets)
        }
    }

    /// The roll's name, the day, where it is in the roll; and, posted, its
    /// likes and the way to its comments.
    private var slip: some View {
        let shot = asset.flatMap { a in log.shots.first { $0.asset == a } }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: film.name).font(.custom("American Typewriter", size: 17, relativeTo: .body).weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 6)
                Text(verbatim: "\(index + 1) / \(assets.count)")
                    .font(.custom("American Typewriter", size: 12, relativeTo: .body)).opacity(0.6)
            }
            if let shot {
                Text(shot.date, format: .dateTime.year().month().day().hour().minute())
                    .font(.custom("American Typewriter", size: 12, relativeTo: .body)).opacity(0.75)
            }
            if let post {
                Divider().overlay(KitArt.ink.opacity(0.25)).padding(.vertical, 4)
                HStack(spacing: 10) {
                    Text("Posted to the Community")
                        .font(.custom("American Typewriter", size: 13, relativeTo: .body))
                    Spacer(minLength: 4)
                    Label("\(post.likeCount)", systemImage: post.likedByMe ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
                        .fixedSize()
                }
                Button {
                    Haptic.click()
                    withAnimation(.easeOut(duration: 0.25)) { club.viewing = post }
                } label: {
                    Text("See comments")
                        .font(.custom("American Typewriter", size: 14, relativeTo: .body).weight(.semibold))
                        .underline(color: KitArt.ink.opacity(0.3))
                        .frame(minHeight: 36).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(KitArt.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Image(uiImage: ClubArt.slip).resizable())
    }

    private func sideWidth(_ w: CGFloat) -> CGFloat { min(320, w * 0.3) }

    private func fit(_ box: CGSize) -> CGSize {
        let k = min(box.width / aspect, box.height)
        return CGSize(width: k * aspect, height: k)
    }

    private var slide: AnyTransition {
        .asymmetric(insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .opacity)
    }

    private func step(_ d: Int) {
        let j = index + d
        guard assets.indices.contains(j) else { Haptic.detent(); return }
        Haptic.click()
        direction = d
        withAnimation(.easeOut(duration: 0.25)) { index = j }
    }

    private func goFull(_ on: Bool) {
        Haptic.click()
        withAnimation(.easeInOut(duration: 0.22)) { fullScreen = on; wordsShown = true }
    }

    /// The picture's pixel size, from Photos, without loading it.
    private static func size(of id: String) -> CGSize? {
        guard let a = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        return CGSize(width: a.pixelWidth, height: a.pixelHeight)
    }
}
