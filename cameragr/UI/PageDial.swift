import SwiftUI

/// The page selector (user 11/25, from design/community/v6/nav/1b_wide_club,
/// made slimmer, its glass's highlight even at both ends): one long brass
/// window across the bag's bottom edge, the same on every pair of pages, the
/// four names on its scale (Camera first, then the three pages) and a short red needle under the open one,
/// sliding to the next as the pages turn. Tap a name, or slide along the
/// glass. The window is GPT art (window_long_gpt.png); the names are text.
struct PageDial: View {
    /// Page names are made in code: drawn again when the language changes.
    @ObservedObject private var language = AppLanguage.shared
    let spread: Spread
    let s: CGFloat
    let choose: (Spread) -> Void
    /// The Camera entry: back to shooting (not a page).
    let camera: () -> Void
    @Environment(\.bagBoost) private var b
    @GestureState private var dragX: CGFloat?
    @State private var lastDetent: Int?

    static let window = UIImage(named: "nav_window_long") ?? UIImage()
    static let needle = UIImage(named: "nav_needle") ?? UIImage()
    /// In the bag's art units: centred under the spine, on the bottom edge, slim.
    static let rect: CGRect = {
        let w: CGFloat = 640
        let h = w * window.size.height / max(window.size.width, 1)
        return CGRect(x: 728 - w / 2, y: 1014 - h, width: w, height: h)
    }()
    /// The same on every spread.
    static func rect(for _: Spread) -> CGRect { rect }
    /// The glass, as fractions of the window picture.
    static let glass = CGRect(x: 0.035, y: 0.14, width: 0.93, height: 0.72)

    /// The scale's entries: Camera, then the pages. Camera is never the open one.
    private var pages: [Spread?] { [nil] + Spread.shown.map { Optional($0) } }
    private var index: Int { pages.firstIndex(of: spread) ?? 1 }
    private func title(_ page: Spread?) -> String { page?.title ?? String(ui: "Camera") }
    private func go(_ page: Spread?) {
        if let page { if page != spread { choose(page) } } else { camera() }
    }

    /// Where page i's name sits across the window, in points.
    private func x(_ i: Int, _ g: CGRect) -> CGFloat {
        g.minX + g.width * (CGFloat(i) + 0.5) / CGFloat(pages.count)
    }
    private func nearest(_ px: CGFloat, _ g: CGRect) -> Int {
        let u = (px - g.minX) / g.width * CGFloat(pages.count) - 0.5
        return min(max(Int(u.rounded()), 0), pages.count - 1)
    }

    var body: some View {
        let r = Self.rect, w = r.width * s, h = r.height * s
        let g = CGRect(x: Self.glass.minX * w, y: Self.glass.minY * h, width: Self.glass.width * w, height: Self.glass.height * h)
        let needleX = dragX.map { min(max($0, g.minX), g.maxX) } ?? x(index, g)
        ZStack(alignment: .topLeading) {
            Image(uiImage: Self.window).resizable()
                .frame(width: w, height: h)
                .shadow(color: .black.opacity(0.55), radius: 3 * s, y: 2 * s)
            ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                let open = page == spread
                Button { go(page) } label: {
                    Text(verbatim: title(page))
                        .font(.custom("American Typewriter", size: 17 * s * min(b, 1.3)).weight(.semibold))
                        .foregroundStyle(open ? Color(red: 0.62, green: 0.1, blue: 0.06)
                                              : Color(red: 0.22, green: 0.16, blue: 0.1).opacity(0.8))
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .frame(width: g.width / CGFloat(pages.count) * 0.92, height: max(h, 44))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .position(x: x(i, g), y: g.minY + g.height * 0.38)
                .accessibilityLabel(Text(verbatim: title(page)))
                .accessibilityAddTraits(open ? [.isSelected] : [])
            }
            // A short needle on the scale, under the open name (never across it).
            let nh = g.height * 0.42, nw = nh * Self.needle.size.width / max(Self.needle.size.height, 1)
            Image(uiImage: Self.needle).resizable()
                .frame(width: nw, height: nh)
                .shadow(color: .black.opacity(0.3), radius: 1 * s, x: 0.5 * s, y: 0.5 * s)
                .position(x: needleX, y: g.maxY - nh / 2)
                .allowsHitTesting(false)
                .animation(.spring(response: 0.42, dampingFraction: 0.8), value: index)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page-dial")
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .updating($dragX) { v, state, _ in state = v.location.x }
                .onChanged { v in
                    let at = nearest(v.location.x, g)
                    if at != lastDetent { lastDetent = at; Haptic.detent() }
                }
                .onEnded { v in
                    lastDetent = nil
                    go(pages[nearest(v.location.x, g)])
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
