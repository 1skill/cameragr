import SwiftUI

/// The page selector (user 11/25, from design/community/v6/nav/1c_narrow_club):
/// one narrow brass window set in the middle of the bag's bottom edge, the
/// same place and size on every pair of pages (no more widening, narrowing or
/// moving on the community's). Behind its glass a strip of page names slides,
/// the open one under the red needle; turning the pages slides it along, like
/// tuning an old radio. Drag along the glass to turn; tap a name showing at
/// either side to go there. The window is GPT art (window_narrow_gpt.png);
/// the names are text, so every language reads them.
struct PageDial: View {
    /// Page names are made in code: drawn again when the language changes.
    @ObservedObject private var language = AppLanguage.shared
    let spread: Spread
    let s: CGFloat
    let choose: (Spread) -> Void
    @Environment(\.bagBoost) private var b
    @GestureState private var drag: CGFloat = 0
    @State private var lastDetent: Int?

    static let window = UIImage(named: "nav_window_narrow") ?? UIImage()
    static let needle = UIImage(named: "nav_needle") ?? UIImage()
    /// In the bag's art units: centred under the spine, on the bottom edge.
    static let rect: CGRect = {
        let w: CGFloat = 250
        let h = w * window.size.height / max(window.size.width, 1)
        return CGRect(x: 728 - w / 2, y: 1008 - h, width: w, height: h)   // inside the bag's bottom edge
    }()
    /// The same on every spread.
    static func rect(for _: Spread) -> CGRect { rect }
    /// The leather seat GPT drew under it in each bag picture (art units):
    /// layers over the pages (the community's sleeve) leave it showing.
    static let seat = CGRect(x: 572, y: 946, width: 312, height: 78)
    /// The glass, as fractions of the window picture.
    static let glass = CGRect(x: 0.03, y: 0.15, width: 0.94, height: 0.68)

    private var pages: [Spread] { Spread.shown }
    private var index: Int { pages.firstIndex(of: spread) ?? 0 }

    var body: some View {
        let r = Self.rect, w = r.width * s, h = r.height * s
        let g = CGRect(x: Self.glass.minX * w, y: Self.glass.minY * h, width: Self.glass.width * w, height: Self.glass.height * h)
        // One name per stop, a whole window apart: only the open one shows
        // (user 11/25: room for one word), the next slides in as the page turns.
        let step = g.width
        let shift = -CGFloat(index) * step + drag
        ZStack(alignment: .topLeading) {
            Image(uiImage: Self.window).resizable()
                .frame(width: w, height: h)
                .shadow(color: .black.opacity(0.55), radius: 3 * s, y: 2 * s)
            ZStack(alignment: .leading) {
                ForEach(Array(pages.enumerated()), id: \.element) { i, page in
                    let x = g.width / 2 + CGFloat(i) * step + shift
                    let centred = abs(x - g.width / 2) < step / 2
                    Button { if !centred { choose(page) } } label: {
                        Text(verbatim: page.title)
                            .font(.custom("American Typewriter", size: 17 * s * min(b, 1.3)).weight(.semibold))
                            .foregroundStyle(centred ? Color(red: 0.62, green: 0.1, blue: 0.06)
                                                     : Color(red: 0.22, green: 0.16, blue: 0.1).opacity(0.75))
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .frame(width: step * 0.9, height: max(g.height, 44))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(false)   // touched through the window (below); VoiceOver picks any by name
                    .position(x: x, y: g.height * 0.38)
                    .accessibilityLabel(Text(verbatim: page.title))
                    .accessibilityAddTraits(page == spread ? [.isSelected] : [])
                }
            }
            .frame(width: g.width, height: g.height)
            .clipShape(Capsule())
            .offset(x: g.minX, y: g.minY)
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: index)
            // Faint arrows at the ends where there is a page that way: a tap there turns.
            ForEach([-1, 1], id: \.self) { d in
                if pages.indices.contains(index + d) {
                    Image(systemName: d < 0 ? "chevron.compact.left" : "chevron.compact.right")
                        .font(.system(size: g.height * 0.45, weight: .semibold))
                        .foregroundStyle(Color(red: 0.25, green: 0.18, blue: 0.12).opacity(0.35))
                        .position(x: d < 0 ? g.minX + g.height * 0.45 : g.maxX - g.height * 0.45, y: g.minY + g.height * 0.4)
                        .allowsHitTesting(false)
                }
            }
            // The needle, fixed in the middle.
            // Short, on the scale under the name (never across it).
            let nh = g.height * 0.42, nw = nh * Self.needle.size.width / max(Self.needle.size.height, 1)
            Image(uiImage: Self.needle).resizable()
                .frame(width: nw, height: nh)
                .shadow(color: .black.opacity(0.3), radius: 1 * s, x: 0.5 * s, y: 0.5 * s)
                .position(x: w / 2, y: g.maxY - nh / 2)
                .allowsHitTesting(false)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .contentShape(Rectangle())
        // A tap at either end of the window turns that way, one page.
        .onTapGesture { at in
            let to = at.x < w / 3 ? index - 1 : at.x > w * 2 / 3 ? index + 1 : index
            if pages.indices.contains(to), to != index { Haptic.click(); choose(pages[to]) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page-dial")
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .updating($drag) { v, state, _ in state = v.translation.width }
                .onChanged { v in
                    // A click at each name the needle passes.
                    let at = Int(((CGFloat(index) * step - v.translation.width) / step).rounded())
                    if at != lastDetent, pages.indices.contains(at) { lastDetent = at; Haptic.detent() }
                }
                .onEnded { v in
                    lastDetent = nil
                    // Where the strip was let go, nudged on by a quick flick.
                    let flick = (v.predictedEndTranslation.width - v.translation.width) * 0.25
                    let at = Int(((CGFloat(index) * step - v.translation.width - flick) / step).rounded())
                    let to = pages[min(max(at, 0), pages.count - 1)]
                    if to != spread { choose(to) }
                }
        )
        .offset(x: r.minX * s, y: r.minY * s)
    }
}

/// The kit's and the book's left pages make room for the page selector:
/// their objects (the switch plate and certificate; the book and its note)
/// are cut out of the page by their own outlines and set a little smaller,
/// higher, on the empty felt laid under them (`KitArt.board`,
/// GPT) — the board's own edge and stitching stay full size (user 11/24:
/// shrinking the whole page showed its edges). Touches follow the objects.
struct FootRoom: ViewModifier {
    let s: CGFloat
    /// The objects on the page, in the art's units.
    let parts: [CGRect]
    /// Their top, kept where it is.
    let top: CGFloat

    static let page = CGRect(x: 26, y: 26, width: 678, height: 972)
    static let kit = [CGRect(x: 34, y: 46, width: 640, height: 504), CGRect(x: 28, y: 558, width: 646, height: 418)]

    private var k: CGFloat {
        let bottom = parts.map(\.maxY).max() ?? Self.page.maxY
        return min(1, (PageDial.rect.minY - 10 - top) / (bottom - top))
    }

    func body(content: Content) -> some View {
        let art = CGSize(width: 1456, height: 1024)
        let shape = Path { p in
            for r in parts { p.addRoundedRect(in: r.scaled(s), cornerSize: CGSize(width: 18 * s, height: 18 * s)) }
        }
        content
            .frame(width: art.width * s, height: art.height * s, alignment: .topLeading)
            .mask { shape.fill(Color.black).frame(width: art.width * s, height: art.height * s, alignment: .topLeading) }
            .contentShape(shape)
            .scaleEffect(k, anchor: UnitPoint(x: Self.page.midX / art.width, y: top / art.height))
    }
}
