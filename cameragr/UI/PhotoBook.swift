import SwiftUI

/// The photo book, the bag's third pair of pages (GPT art book_spread.jpg,
/// from design/book; places measured on it, in the bag's pixels). Left: the
/// booklet's cover, "it fell asleep", and the note with the theme in the
/// user's own words and the rule. Right: the inner page with three photo
/// mounts and their date stamps, and the pouch with the roll it earns.
enum BookArt {
    static let spread = UIImage(named: "book_spread.jpg") ?? UIImage()
    static let title = CGRect(x: 160, y: 127, width: 422, height: 88)
    /// The printed picture on the cover, where the first day's goes once done.
    static let coverWindow = CGRect(x: 158, y: 256, width: 426, height: 321)
    static let note = CGRect(x: 120, y: 712, width: 490, height: 230)
    static let slots: [CGRect] = [114, 311, 507].map { CGRect(x: 840, y: $0, width: 326, height: 165) }
    static let stamps: [CGPoint] = [190, 385, 583].map { CGPoint(x: 1260, y: $0) }
    static let window = CGRect(x: 840, y: 792, width: 255, height: 121)
    static let tongue = CGRect(x: 1134, y: 778, width: 160, height: 160)
    static let ink = Color(red: 0.2, green: 0.17, blue: 0.13)
    static let red = Color(red: 0.72, green: 0.12, blue: 0.10)
}

private extension CGRect {
    func at(_ s: CGFloat) -> CGRect { CGRect(x: minX * s, y: minY * s, width: width * s, height: height * s) }
}

private extension View {
    func put(_ r: CGRect, _ s: CGFloat, alignment: Alignment = .center) -> some View {
        let p = r.at(s)
        return frame(width: p.width, height: p.height, alignment: alignment).offset(x: p.minX, y: p.minY)
    }
}

/// The left page: the cover's title and the note.
struct BookCoverPage: View {
    @ObservedObject private var book = BookStore.shared
    let s: CGFloat
    /// The book opened at all its pictures, earlier rounds included.
    @State private var browsing = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The cover opens the book at every picture put in.
            Color.clear.contentShape(Rectangle())
                .put(CGRect(x: 100, y: 70, width: 590, height: 610), s)
                .onTapGesture { if !book.issue.entries.isEmpty { browsing = true; Haptic.click() } }
                .accessibilityLabel(Text("Every picture in the book"))
                .accessibilityAddTraits(.isButton)
            // Complete: the cover's picture is the first of the three days.
            if book.isComplete, let first = book.shownDays.first {
                BookPicture(asset: first.asset)
                    .put(BookArt.coverWindow, s)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            Text("It fell asleep")
                .font(.custom("American Typewriter", size: 40 * s).weight(.semibold))
                .foregroundStyle(BookArt.ink)
                .lineLimit(1).minimumScaleFactor(0.5)
                .padding(.horizontal, 16 * s)
                .put(BookArt.title, s)
            VStack(alignment: .leading, spacing: 10 * s) {
                Text("“I can’t stop watching my dog sleep. So soothing!”")
                    .font(.custom("American Typewriter", size: 24 * s).weight(.semibold))
                Text("Three days in a row, take one with Koco and put it in. Porto 400 is yours. Cats and sleepy people count too.")
                    .font(.custom("American Typewriter", size: 20 * s))
                progress.font(.custom("Marker Felt", size: 21 * s)).foregroundStyle(BookArt.red)
                Text("Kept on this iPhone only: restoring purchases can’t bring back the book or its roll.")
                    .font(.custom("American Typewriter", size: 14 * s)).opacity(0.65)
            }
            .foregroundStyle(BookArt.ink)
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.7)
            .put(BookArt.note, s, alignment: .topLeading)
            .allowsHitTesting(false)
            if browsing { allPictures.transition(.opacity) }
        }
        .animation(.easeInOut(duration: 0.2), value: browsing)
    }

    private var allPictures: some View {
        let page = CGRect(x: 60, y: 60, width: 610, height: 900).at(s)
        let entries = book.issue.entries.sorted { $0.day > $1.day }
        let cell = (page.width - 80 * s - 20 * s) / 2
        return ZStack(alignment: .topLeading) {
            Image(uiImage: RollLibrary.cardPaper).resizable()
                .frame(width: page.width, height: page.height)
                .shadow(color: .black.opacity(0.55), radius: 16 * s, y: 8 * s)
            VStack(alignment: .leading, spacing: 18 * s) {
                HStack {
                    Text("It fell asleep").font(.custom("American Typewriter", size: 30 * s).weight(.semibold))
                    Spacer()
                    Button { browsing = false } label: {
                        Text("‹ Back").font(.custom("Marker Felt", size: 26 * s)).foregroundStyle(BookArt.red)
                            .frame(minWidth: 44, minHeight: 44)
                    }.buttonStyle(.plain)
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.fixed(cell), spacing: 20 * s), GridItem(.fixed(cell))], spacing: 20 * s) {
                        ForEach(entries, id: \.day) { entry in
                            VStack(spacing: 6 * s) {
                                BookPicture(asset: entry.asset)
                                    .frame(width: cell, height: cell * 0.7)
                                    .overlay(Rectangle().strokeBorder(Color.white, lineWidth: 6 * s))
                                Text(verbatim: entry.day).font(.custom("American Typewriter", size: 17 * s))
                            }
                        }
                    }
                }
            }
            .foregroundStyle(BookArt.ink)
            .padding(40 * s)
            .frame(width: page.width, height: page.height, alignment: .topLeading)
        }
        .offset(x: page.minX, y: page.minY)
    }

    private var progress: Text {
        if book.isComplete { return Text("Done: three days in a row.") }
        let days = book.run.count
        if days == 0 && book.hasEarlierPictures { return Text("A day was missed: start again today. The pictures before stay.") }
        if days == 0 { return Text("Start today.") }
        return book.hasToday ? Text("\(days) of \(book.issue.requiredDays) days. See you tomorrow.")
                             : Text("\(days) of \(book.issue.requiredDays) days. Today’s still to come.")
    }
}

/// The right page: the three mounts, the stamps, the pouch, and the sheet of
/// today's pictures to choose from.
struct BookInnerPage: View {
    @ObservedObject private var book = BookStore.shared
    @ObservedObject private var shots = ShotLog.shared
    @ObservedObject private var store = FilmStore.shared
    let s: CGFloat
    @State private var choosing = false
    /// The picture picked on today's sheet, waiting for "put it in".
    @State private var picked: ShotLog.Shot?
    /// Something that could not be written, said on the page.
    @State private var trouble: Text?

    var body: some View {
        let shown = book.shownDays
        ZStack(alignment: .topLeading) {
            ForEach(0..<3, id: \.self) { i in
                mount(i, entry: i < shown.count ? shown[i] : nil, next: i == shown.count && !book.isComplete)
            }
            pouch
            if let trouble {
                trouble.font(.custom("Marker Felt", size: 20 * s)).foregroundStyle(BookArt.red)
                    .multilineTextAlignment(.center)
                    .put(CGRect(x: 820, y: 690, width: 540, height: 40), s)
                    .allowsHitTesting(false)
            }
            if choosing { todaySheet.transition(.opacity) }
        }
        .animation(.easeInOut(duration: 0.2), value: choosing)
    }

    @ViewBuilder private func mount(_ i: Int, entry: BookStore.Entry?, next: Bool) -> some View {
        let r = BookArt.slots[i]
        if let entry {
            let today = entry.day == book.today && !book.isComplete
            BookPicture(asset: entry.asset)
                .put(r.insetBy(dx: 10, dy: 10), s)
                .onTapGesture { if today { choosing = true } }
                .allowsHitTesting(today)
                .accessibilityLabel(Text("Picture of \(dayText(entry.day))"))
            stamp(dayText(entry.day), at: BookArt.stamps[i])
        } else if next && !book.hasToday {
            Text("Put today’s in")
                .font(.custom("Marker Felt", size: 24 * s))
                .foregroundStyle(BookArt.ink.opacity(0.55))
                .put(r, s)
                .contentShape(Rectangle())
                .onTapGesture { choosing = true; Haptic.click() }
                .accessibilityAddTraits(.isButton)
        }
    }

    /// A red date stamp, a little crooked, in its dotted circle.
    private func stamp(_ text: String, at c: CGPoint) -> some View {
        Text(verbatim: text)
            .font(.custom("American Typewriter", size: 22 * s).weight(.bold))
            .foregroundStyle(BookArt.red.opacity(0.8))
            .frame(width: 92 * s, height: 92 * s)
            .overlay(Circle().strokeBorder(BookArt.red.opacity(0.75), lineWidth: 3 * s))
            .rotationEffect(.degrees(-12))
            .position(x: c.x * s, y: c.y * s)
            .allowsHitTesting(false)
    }

    private func dayText(_ day: String) -> String {
        let p = day.split(separator: "-")
        guard p.count == 3, let m = Int(p[1]), let d = Int(p[2]) else { return day }
        return "\(m)/\(d)"
    }

    // MARK: Pouch

    private var reward: Film? { FilmLibrary.shared.films.first { $0.id == book.issue.rewardFilmID } }

    private var pouch: some View {
        let w = BookArt.window
        return ZStack(alignment: .topLeading) {
            if let film = reward {
                Canister(film: film, fill: true)
                    .frame(width: w.height * 0.82 * s, height: w.width * 0.86 * s)
                    .rotationEffect(.degrees(-90))
                    .frame(width: w.width * s, height: w.height * s)
                    .offset(x: w.minX * s, y: w.minY * s)
                    .opacity(book.isClaimed ? 0.35 : 1)
                    .allowsHitTesting(false)
            }
            tongueText
                .multilineTextAlignment(.center)
                .lineLimit(3).minimumScaleFactor(0.6)
                .padding(.horizontal, 14 * s).padding(.leading, 12 * s)
                .put(BookArt.tongue, s)
                .contentShape(Rectangle())
                .onTapGesture { claim() }
                .accessibilityAddTraits(canClaim ? .isButton : [])
        }
    }

    private var canClaim: Bool { book.isComplete && !book.isClaimed }

    private var tongueText: some View {
        Group {
            if book.isClaimed {
                Text("Claimed").font(.custom("Marker Felt", size: 24 * s)).foregroundStyle(BookArt.ink.opacity(0.6))
            } else if canClaim {
                Text("Take this roll →").font(.custom("Marker Felt", size: 26 * s)).foregroundStyle(BookArt.red)
            } else {
                Text("Three days in a row and it’s yours").font(.custom("American Typewriter", size: 18 * s)).foregroundStyle(BookArt.ink)
            }
        }
    }

    private func claim() {
        guard canClaim else { return }
        if book.claim(store: store) {
            trouble = nil
            Haptic.stop()
        } else {
            trouble = Text("Couldn’t keep that just now. Tap again.")
        }
    }

    // MARK: Today's pictures

    /// The book's own copy is written first (the picture may later leave
    /// Photos); only then does the picture count.
    private func putIn(_ shot: ShotLog.Shot) {
        choosing = false
        picked = nil
        Task {
            guard let image = await PhotoFetch.image(shot.asset, side: 900),
                  await book.keep(image, for: shot.asset) else {
                trouble = Text("Couldn’t keep that just now. Tap again.")
                return
            }
            guard book.put(shot) else {
                book.forget(shot.asset)   // no copy left behind for a picture not in the book
                trouble = Text("Couldn’t keep that just now. Tap again.")
                return
            }
            trouble = nil
            Haptic.stop()
        }
    }

    private var todaySheet: some View {
        let page = CGRect(x: 790, y: 60, width: 580, height: 900).at(s)
        let today = book.todaysShots(shots.shots)
        return ZStack(alignment: .topLeading) {
            Image(uiImage: RollLibrary.cardPaper).resizable()
                .frame(width: page.width, height: page.height)
                .shadow(color: .black.opacity(0.55), radius: 16 * s, y: 8 * s)
            VStack(alignment: .leading, spacing: 18 * s) {
                HStack {
                    Text("Today’s pictures").font(.custom("American Typewriter", size: 30 * s).weight(.semibold))
                    Spacer()
                    Button { choosing = false; picked = nil } label: {
                        Text("‹ Back").font(.custom("Marker Felt", size: 26 * s)).foregroundStyle(BookArt.red)
                            .frame(minWidth: 44, minHeight: 44)
                    }.buttonStyle(.plain)
                }
                if today.isEmpty {
                    Text("Nothing taken today yet. Close the phone and take one.")
                        .font(.custom("American Typewriter", size: 24 * s))
                } else {
                    Text("Pick one, then put it in.").font(.custom("American Typewriter", size: 20 * s)).opacity(0.7)
                    let cell = (page.width - 80 * s - 20 * s) / 2
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.fixed(cell), spacing: 20 * s), GridItem(.fixed(cell))], spacing: 20 * s) {
                            ForEach(today, id: \.asset) { shot in
                                AssetThumbnail(id: shot.asset, side: 500)
                                    .frame(width: cell, height: cell * 0.7)
                                    .overlay(Rectangle().strokeBorder(Color.white, lineWidth: 6 * s))
                                    .overlay(Rectangle().strokeBorder(BookArt.red, lineWidth: picked == shot ? 4 * s : 0))
                                    .shadow(color: .black.opacity(0.3), radius: 3 * s, y: 2 * s)
                                    .scaleEffect(picked == shot ? 1.04 : 1)
                                    .onTapGesture { picked = shot; Haptic.click() }
                                    .accessibilityLabel(Text("Picture taken at \(shot.date.formatted(date: .omitted, time: .shortened))"))
                                    .accessibilityAddTraits(picked == shot ? [.isButton, .isSelected] : .isButton)
                            }
                        }
                    }
                }
            }
            .foregroundStyle(BookArt.ink)
            .padding(40 * s)
            .padding(.bottom, 60 * s)
            .frame(width: page.width, height: page.height, alignment: .topLeading)
            // Written at the sheet's foot once a picture is picked: a second,
            // deliberate tap puts it in.
            if let picked {
                Button { putIn(picked) } label: {
                    Text("Put it in the book →").font(.custom("Marker Felt", size: 30 * s))
                        .foregroundStyle(BookArt.red)
                        .frame(width: page.width - 80 * s, height: max(60 * s, 44))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: 40 * s, y: page.height - 90 * s)
                .transition(.opacity)
            }
        }
        .offset(x: page.minX, y: page.minY)
        .animation(.easeOut(duration: 0.15), value: picked)
    }
}

/// A picture in the book: its own copy, else the one in Photos.
struct BookPicture: View {
    @ObservedObject private var book = BookStore.shared
    let asset: String
    @State private var kept: UIImage?
    @State private var looked = false

    var body: some View {
        Group {
            if let kept {
                GeometryReader { geo in
                    Image(uiImage: kept).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                }
            } else if looked {
                AssetThumbnail(id: asset, side: 500)
            } else {
                Color.clear
            }
        }
        .task(id: asset) {
            kept = nil
            looked = false
            let found = await book.keepsakeImage(for: asset)
            guard !Task.isCancelled else { return }   // another picture asked for since
            kept = found
            looked = true
        }
    }
}

import Photos
import UniformTypeIdentifiers

/// Pictures from Photos.
enum PhotoFetch {
    /// A picture's saved file, whole, and its file extension.
    static func original(_ id: String) async -> (Data, String)? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        return await withCheckedContinuation { done in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, _ in
                guard let data else { done.resume(returning: nil); return }
                let ext = uti.flatMap { UTType($0)?.preferredFilenameExtension } ?? "jpg"
                done.resume(returning: (data, ext))
            }
        }
    }

    /// One picture, at about `side` pixels.
    static func image(_ id: String, side: CGFloat) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { done in
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: side, height: side),
                                                  contentMode: .aspectFit, options: options) { picture, _ in
                done.resume(returning: picture)
            }
        }
    }
}
