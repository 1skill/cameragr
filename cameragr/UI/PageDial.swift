import SwiftUI

/// The page selector at the foot of the bag's left page (user 11/23, chosen
/// from design/nav/nav_sliders.png): an old radio's band window — a brass
/// frame round an arched glass over a cream dial card — with the pages'
/// names on the card and a red pointer on the open one, moved by a knurled
/// knob under the window. Tap a name, or slide along the window. The window,
/// pointer and knob are GPT art (design/nav/parts); the names are text so
/// every language reads them.
struct PageDial: View {
    let spread: Spread
    let s: CGFloat
    let choose: (Spread) -> Void
    @Environment(\.bagBoost) private var b
    @GestureState private var dragX: CGFloat?

    static let window = UIImage(named: "nav_window") ?? UIImage()
    static let needle = UIImage(named: "nav_needle") ?? UIImage()
    static let knob = UIImage(named: "nav_knob") ?? UIImage()
    /// In the bag's art units, centred on the left board (26…704).
    static let rect: CGRect = {
        // As wide as the board allows (user: room to add more later).
        let w: CGFloat = 610
        let h = w * window.size.height / max(window.size.width, 1)
        return CGRect(x: 365 - w / 2, y: 993 - h, width: w, height: h)
    }()
    /// The glass's inner span, measured on the picture.
    static let inner: ClosedRange<CGFloat> = 0.07...0.93

    private var pages: [Spread] { Spread.allCases }

    /// Where page i's name sits across the window, 0…1.
    private func at(_ i: Int) -> CGFloat {
        let span = Self.inner.upperBound - Self.inner.lowerBound
        return Self.inner.lowerBound + span * (CGFloat(i) + 0.5) / CGFloat(pages.count)
    }

    private func nearest(_ x: CGFloat) -> Spread {
        let u = x / (Self.rect.width * s)
        return pages.min { abs(at($0.rawValue) - u) < abs(at($1.rawValue) - u) } ?? spread
    }

    var body: some View {
        let r = Self.rect, w = r.width * s, h = r.height * s
        let needleX = dragX.map { min(max($0, w * Self.inner.lowerBound), w * Self.inner.upperBound) }
            ?? w * at(spread.rawValue)
        let needleH = h * 0.36, needleW = needleH * Self.needle.size.width / max(Self.needle.size.height, 1)
        let knobW = 40 * s, knobH = knobW * Self.knob.size.height / max(Self.knob.size.width, 1)
        ZStack(alignment: .topLeading) {
            Image(uiImage: Self.window).resizable()
                .frame(width: w, height: h)
                .shadow(color: .black.opacity(0.6), radius: 3 * s, y: 2 * s)
            ForEach(pages) { page in
                let open = page == spread
                // Each name is a button (tap it, or VoiceOver it); sliding
                // along the window moves the pointer (the drag below).
                Button { choose(page) } label: {
                    Text(verbatim: page.title)
                        .font(.custom("American Typewriter", size: 21 * s * min(b, 1.3)).weight(.semibold))
                        .foregroundStyle(open ? Color(red: 0.72, green: 0.12, blue: 0.08)
                                              : Color(red: 0.20, green: 0.14, blue: 0.09))
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .padding(.bottom, h * 0.22)
                        .frame(width: max(w * 0.86 / CGFloat(pages.count), 44), height: max(h, 44))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .position(x: w * at(page.rawValue), y: h / 2)
                .accessibilityLabel(Text(verbatim: page.title))
                .accessibilityAddTraits(open ? [.isSelected] : [])
            }
            Image(uiImage: Self.needle).resizable()
                .frame(width: needleW, height: needleH)
                .shadow(color: .black.opacity(0.35), radius: 1 * s, x: 1 * s, y: 1 * s)
                .position(x: needleX, y: h * 0.86 - needleH / 2)
                .allowsHitTesting(false)
            Image(uiImage: Self.knob).resizable()
                .frame(width: knobW, height: knobH)
                .shadow(color: .black.opacity(0.5), radius: 1.5 * s, y: 1.5 * s)
                .position(x: needleX, y: h + knobH * 0.15)
                .allowsHitTesting(false)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: spread)
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .updating($dragX) { v, state, _ in state = v.location.x }
                .onEnded { v in choose(nearest(v.location.x)) }
        )
        .offset(x: r.minX * s, y: r.minY * s)
    }
}

/// The kit's and the book's left pages make room for the page selector:
/// their objects (the switch plate and certificate; the book and its note)
/// are cut out of the page by their own outlines and set a little smaller,
/// higher, on the empty felt laid under them (`KitArt.board`, `BookArt.board`,
/// GPT) — the board's own edge and stitching stay full size (user 11/24:
/// shrinking the whole page showed its edges). Touches follow the objects.
struct FootRoom: ViewModifier {
    let s: CGFloat
    /// The objects on the page, in the art's units.
    let parts: [CGRect]
    /// Their top, kept where it is.
    let top: CGFloat

    static let page = CGRect(x: 26, y: 26, width: 678, height: 972)
    static let kit = [CGRect(x: 34, y: 46, width: 632, height: 498), CGRect(x: 28, y: 558, width: 646, height: 418)]
    static let book = [CGRect(x: 58, y: 54, width: 604, height: 640), CGRect(x: 88, y: 684, width: 550, height: 276)]

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
