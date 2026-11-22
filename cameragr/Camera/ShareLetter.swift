import AVFoundation
import SwiftUI
import UIKit

/// What the SHARE key sends from the review.
enum ShareKind: Int, CaseIterable, Identifiable {
    case video, letter, photo
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .video: String(localized: "Video")
        case .letter: String(localized: "Letter")
        case .photo: String(localized: "Photo")
        }
    }
    /// The line under the slide, saying what goes out.
    var hint: String {
        switch self {
        case .video: String(localized: "The iPhone picture turning into the film · SHARE to send")
        case .letter: String(localized: "Tap the picture for the other line · SHARE to send")
        case .photo: String(localized: "Just this picture · SHARE to send")
        }
    }
}

/// The "your turn" letter: the picture in a clear sleeve on the desk, its
/// roll beside it and a paper tag with Koco Film, the film, and a line to a
/// friend (GPT art letter_base.jpg, 1080 × 1350, from design/share; places
/// measured on it).
enum ShareLetter {
    static let size = CGSize(width: 1080, height: 1350)
    static let base = UIImage(named: "letter_base.jpg")
    static let photo = CGRect(x: 120, y: 115, width: 741, height: 872)
    static let canister = CGRect(x: 890, y: 1010, width: 156, height: 300)
    /// The tag's writing, clear of its string hole on the left.
    static let tag = CGRect(x: 190, y: 1112, width: 610, height: 168)
    /// The print's paper, round a picture that doesn't fill the window.
    static let paper = UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1)

    /// The lines a tag can carry: anything that made your day, and the first
    /// theme's (a sleeping pet).
    static var lines: [String] {
        [String(localized: "This made my day. Send me one from yours."),
         String(localized: "Mine’s asleep again. Your turn.")]
    }

    static func make(photo picture: UIImage, filmID: String?, filmName: String, line: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            base?.draw(in: CGRect(origin: .zero, size: size))
            // The picture, whole and upright, on the print's paper.
            paper.setFill()
            ctx.fill(photo)
            let fit = AVMakeRect(aspectRatio: picture.size, insideRect: photo)
            picture.draw(in: fit)
            // Its roll, standing on the desk.
            if let id = filmID, let roll = UIImage(named: "roll_\(id)") {
                ctx.cgContext.saveGState()
                ctx.cgContext.setShadow(offset: CGSize(width: 6, height: 10), blur: 18,
                                        color: UIColor.black.withAlphaComponent(0.45).cgColor)
                roll.draw(in: AVMakeRect(aspectRatio: roll.size, insideRect: canister))
                ctx.cgContext.restoreGState()
            }
            // The tag, written in ink.
            let ink = UIColor(red: 0.18, green: 0.13, blue: 0.09, alpha: 0.92)
            let head = UIFont(name: "AmericanTypewriter-Semibold", size: 32) ?? .boldSystemFont(ofSize: 32)
            let body = UIFont(name: "AmericanTypewriter", size: 34) ?? .systemFont(ofSize: 34)
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byWordWrapping
            style.lineSpacing = 4
            NSAttributedString(string: "Koco Film · \(filmName)",
                               attributes: [.font: head, .foregroundColor: ink])
                .draw(in: CGRect(x: tag.minX, y: tag.minY, width: tag.width, height: 44))
            let said = lines[max(0, min(line, lines.count - 1))]
            NSAttributedString(string: said, attributes: [.font: body, .foregroundColor: ink, .paragraphStyle: style])
                .draw(with: CGRect(x: tag.minX, y: tag.minY + 58, width: tag.width, height: tag.height - 58),
                      options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
        }
    }
}

/// The share tray, over the finder while reviewing (GPT art share_tray.jpg,
/// measured in the finder's 707 × 472): the letter or picture as it will go
/// out, a three-way slide (video, letter, photo), and a line saying what the
/// SHARE key will send. A tap off the controls puts the tray away.
struct ShareTray: View {
    @EnvironmentObject private var model: CameraModel
    static let picture = UIImage(named: "share_tray.jpg") ?? UIImage()
    static let knob = UIImage(named: "kit_knob") ?? UIImage()
    static let size = CGSize(width: 707, height: 472)
    static let preview = CGRect(x: 257, y: 40, width: 193, height: 250)
    static let channel = CGRect(x: 150, y: 357, width: 407, height: 50)
    static let detents: [CGFloat] = [218, 353, 488]
    static let labels = CGRect(x: 150, y: 318, width: 407, height: 30)
    static let hint = CGRect(x: 150, y: 422, width: 407, height: 30)

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / Self.size.width
            ZStack(alignment: .topLeading) {
                Image(uiImage: Self.picture).resizable()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture { model.closeShareTray() }
                    .accessibilityLabel(Text("Put the share tray away"))
                    .accessibilityAddTraits(.isButton)
                preview(k)
                ForEach(ShareKind.allCases) { kind in
                    Text(kind.title)
                        .font(.system(size: max(15 * k, 11), weight: model.shareKind == kind ? .bold : .medium, design: .rounded))
                        .kerning(1.5 * k)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(white: model.shareKind == kind ? 0.92 : 0.55))
                        .frame(width: 120 * k, height: Self.labels.height * k)
                        .position(x: Self.detents[kind.rawValue] * k, y: Self.labels.midY * k)
                        .allowsHitTesting(false)
                }
                slide(k)
                Text(model.shareKind.hint)
                    // Readable on the outer screen, where the tray is small.
                    .font(.system(size: max(12 * k, 10), weight: .medium))
                    .foregroundStyle(Color(white: 0.78))
                    .lineLimit(1).minimumScaleFactor(0.85)
                    .frame(width: Self.hint.width * k, height: Self.hint.height * k)
                    .position(x: Self.hint.midX * k, y: Self.hint.midY * k)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22 * k))
        }
    }

    @ViewBuilder private func preview(_ k: CGFloat) -> some View {
        let r = Self.preview
        let shown = model.shareKind == .letter ? model.letterPreview : model.lastPair?.after
        ZStack {
            Color.black
            if let shown { Image(uiImage: shown).resizable().scaledToFit() }
        }
        .frame(width: r.width * k, height: r.height * k)
        .position(x: r.midX * k, y: r.midY * k)
        .onTapGesture { if model.shareKind == .letter { model.flipLetterLine() } }
        .accessibilityLabel(model.shareKind == .letter ? Text("Letter: tap for the other line") : Text("Picture to share"))
    }

    private func slide(_ k: CGFloat) -> some View {
        let c = Self.channel
        let knobH = c.height * 0.86 * k, knobW = knobH * Self.knob.size.width / max(Self.knob.size.height, 1)
        let x = Self.detents[model.shareKind.rawValue]
        return ZStack(alignment: .topLeading) {
            Image(uiImage: Self.knob).resizable()
                .frame(width: knobW, height: knobH)
                .position(x: x * k, y: c.midY * k)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: model.shareKind)
                .allowsHitTesting(false)
            // The whole channel takes the finger: a tap or a slide stops at
            // the nearest of the three detents.
            Color.clear.contentShape(Rectangle())
                .frame(width: c.width * k, height: max(c.height * k + 20 * k, 44))
                .position(x: c.midX * k, y: c.midY * k)
                .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                    let at = c.minX + g.location.x / k
                    let nearest = Self.detents.enumerated().min { abs($0.element - at) < abs($1.element - at) }?.offset ?? 1
                    if let kind = ShareKind(rawValue: nearest), kind != model.shareKind {
                        model.shareKind = kind
                        Haptic.click()
                    }
                })
                .accessibilityElement()
                .accessibilityLabel(Text("What to share"))
                .accessibilityValue(Text(model.shareKind.title))
                .accessibilityAdjustableAction { direction in
                    let step = direction == .increment ? 1 : -1
                    if let kind = ShareKind(rawValue: model.shareKind.rawValue + step) { model.shareKind = kind }
                }
        }
    }
}
