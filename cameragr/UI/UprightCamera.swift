import SwiftUI

/// Where everything on the upright body goes, for one screen size (points).
/// The plate picture (`upright_plate.jpg`, GPT, 784×2007) is cut into five
/// bands across: the top with the window's upper edge, the window's sides
/// (stretched to the window's height), the window's lower edge, the plain
/// leather (stretched or squeezed to fill), and the bottom edge. So the body
/// fills any iPhone's screen without black bars, and the window takes what
/// height the controls below leave it.
struct UprightLayout: Equatable {
    /// The plate picture's size and its bands, in its own pixels.
    static let plate = CGSize(width: 784, height: 2007)
    static let topBand: ClosedRange<CGFloat> = 0...400         // from the top edge (its Dynamic Island lies over the real one)
    static let shortTopBand: ClosedRange<CGFloat> = 100...400  // a phone without one: below the drawn island…
    static let topFillBand: ClosedRange<CGFloat> = 88...100    // …and this plain strip stretched up to the screen's edge
    static let sideBand: ClosedRange<CGFloat> = 400...700      // the window's straight sides
    static let lowerBand: ClosedRange<CGFloat> = 700...940     // the window's lower edge, a little leather
    static let leatherBand: ClosedRange<CGFloat> = 940...1800  // plain leather
    static let bottomBand: ClosedRange<CGFloat> = 1800...1925  // screws and the body's lower edge (it ends at 1912)
    /// The body's metal frame starts here; the window's glass, edge to edge.
    static let frameTopPx: CGFloat = 116
    static let glassPx = CGRect(x: 66, y: 200, width: 680, height: 690)
    static let bodyEndPx: CGFloat = 1912
    static let glassRadiusPx: CGFloat = 40

    let size: CGSize
    /// Plate pixels to points, across.
    let s: CGFloat
    /// The controls' scale (1 on a 402-point-wide screen).
    let k: CGFloat
    let glass: CGRect
    /// Where each band of the plate is drawn.
    let bands: [(source: ClosedRange<CGFloat>, frame: CGRect)]
    let nameplate: CGRect
    let lastFrame: CGRect   // the last picture, at the end of the nameplate's row
    /// The film chamber when the door is open: the Duo's chamber, standing, over the
    /// lower body from the LCD row down.
    let chamber: CGRect
    let switchRect: CGRect  // the body colour switch, between the nameplate and the last picture
    let lcd: CGRect
    let ev: CGRect          // the track, with its scale printed above it
    let keys: [CGRect]      // flash, flip, lens, format
    let door: CGRect
    let shutter: CGRect
    let bodyEnd: CGFloat

    static func == (a: UprightLayout, b: UprightLayout) -> Bool { a.size == b.size }

    init(size: CGSize) {
        self.size = size
        let w = size.width, h = size.height
        let s = w / Self.plate.width
        let k = min(max(w / 402, 0.9), 1.1)
        self.s = s
        self.k = k
        // Phones with a Dynamic Island or a notch are the tall ones; the SE
        // has a status bar strip on top and no home indicator.
        let tall = h / w > 2.0
        let safeTop: CGFloat = tall ? 59 : 20
        let bottomGap: CGFloat = tall ? 30 : 6
        let frameTop = safeTop
        let glassTop = frameTop + (Self.glassPx.minY - Self.frameTopPx) * s
        let bodyEnd = h - bottomGap
        self.bodyEnd = bodyEnd
        let glassW = Self.glassPx.width * s
        let glassX = Self.glassPx.minX * s

        // Fixed heights below the window, and the door, which may give way on a short screen.
        let bezel = 30 * s
        let fixed = (10 + 30 + 6 + 60 + 12 + 44 + 14 + 10) * k
        var doorH = 187 * k
        var g = bodyEnd - glassTop - bezel - fixed - doorH
        let gMin = glassW * 0.85
        if g < gMin {
            let give = min(gMin - g, doorH - 130 * k)
            doorH -= give
            g += give
        }
        // The window no taller than this: what is left over spreads between the rows.
        let gMax = glassW * 1.15
        var spare: CGFloat = 0
        if g > gMax { spare = g - gMax; g = gMax }
        // Never so short the plate's own window edges would overlap.
        g = max(g, (Self.sideBand.lowerBound - Self.glassPx.minY + Self.glassPx.maxY - Self.lowerBand.lowerBound) * s + 1)
        glass = CGRect(x: glassX, y: glassTop, width: glassW, height: g)

        // The plate's bands.
        let top = tall ? Self.topBand : Self.shortTopBand
        let topY = frameTop - (Self.frameTopPx - top.lowerBound) * s
        let topH = (top.upperBound - top.lowerBound) * s
        let lowerH = (Self.lowerBand.upperBound - Self.lowerBand.lowerBound) * s
        let lowerY = glass.maxY - (Self.glassPx.maxY - Self.lowerBand.lowerBound) * s
        let bottomH = (Self.bottomBand.upperBound - Self.bottomBand.lowerBound) * s
        // The body runs to the screen's bottom edge (the controls keep clear
        // of the home indicator above it).
        let bottomY = h + (Self.bottomBand.upperBound - Self.bodyEndPx) * s - bottomH
        bands = (topY > 0 ? [(Self.topFillBand, CGRect(x: 0, y: 0, width: w, height: topY))] : []) + [
            (top, CGRect(x: 0, y: topY, width: w, height: topH)),
            (Self.sideBand, CGRect(x: 0, y: topY + topH, width: w, height: max(0, lowerY - topY - topH))),
            (Self.lowerBand, CGRect(x: 0, y: lowerY, width: w, height: lowerH)),
            (Self.leatherBand, CGRect(x: 0, y: lowerY + lowerH, width: w, height: max(0, bottomY - lowerY - lowerH))),
            (Self.bottomBand, CGRect(x: 0, y: bottomY, width: w, height: bottomH)),
        ]

        // The controls, top down from the window.
        let gap = spare / 4
        let left = glass.minX, right = glass.maxX, width = right - left
        var y = glass.maxY + bezel + 10 * k + gap
        nameplate = CGRect(x: left + 4 * k, y: y + 4 * k, width: 96 * k, height: 22 * k)
        lastFrame = CGRect(x: right - 46 * k, y: y, width: 46 * k, height: 30 * k)
        let switchW = 84 * k
        switchRect = CGRect(x: (left + 100 * k + right - 46 * k - switchW) / 2, y: y + (30 * k - switchW * 82 / 214) / 2,
                            width: switchW, height: switchW * 82 / 214)
        y += (30 + 6) * k + gap
        let lcdW = 60 * k * 454 / 166
        lcd = CGRect(x: left, y: y, width: lcdW, height: 60 * k)
        ev = CGRect(x: left + lcdW + 14 * k, y: y, width: width - lcdW - 14 * k, height: 60 * k)
        y += (60 + 12) * k + gap
        let keyGap = 10 * k
        let keyW = (width - 3 * keyGap) / 4
        keys = (0..<4).map { CGRect(x: left + CGFloat($0) * (keyW + keyGap), y: y, width: keyW, height: 44 * k) }
        y += (44 + 14) * k + gap
        let doorW = doorH * 341 / 375
        door = CGRect(x: left, y: y, width: doorW, height: doorH)
        let shutterSide = min(132 * k, right - door.maxX - 24 * k)
        shutter = CGRect(x: right - shutterSide - 6 * k, y: door.midY - shutterSide / 2,
                         width: shutterSide, height: shutterSide)
        let chamberTop = lcd.minY - 8 * k
        let chamberH = min(bodyEnd - 8 * k - chamberTop, width * 802 / 532)
        let chamberW = chamberH * 532 / 802
        chamber = CGRect(x: left + (width - chamberW) / 2, y: bodyEnd - 8 * k - chamberH, width: chamberW, height: chamberH)
    }
}

/// The camera on an iPhone that doesn't fold, held upright: an upright sister
/// of the landscape body. A big finder window on top; the nameplate, the LCD
/// and the exposure slide below it; four keys; then the film door (tap: the
/// bag) and the shutter. Held sideways the body stays put (the interface is
/// held portrait) and every label turns to read upright where it is; the
/// finder shows the picture's real frame either way.
struct UprightCameraBody: View {
    @EnvironmentObject private var model: CameraModel
    let size: CGSize

    @ObservedObject private var theme = BodyTheme.shared
    static var plate: UIImage { BodyTheme.shared.art("upright_plate.jpg") }
    static func part(_ name: String) -> UIImage { BodyTheme.shared.art("upright_\(name).png") }

    var body: some View {
        let layout = UprightLayout(size: size)
        ZStack(alignment: .topLeading) {
            Color.black
            PlateBands(layout: layout)
            UprightFinder(glass: layout.glass, radius: UprightLayout.glassRadiusPx * layout.s)
                .uprightPlace(layout.glass)
            Image(uiImage: Self.part("nameplate")).resizable().interpolation(.high)
                .overlay {
                    // The maker's name, engraved: it stays along its plate (a
                    // name on a body, not a label to read).
                    Text(verbatim: "KOCO")
                        .font(.system(size: layout.nameplate.height * 0.56, weight: .heavy))
                        .kerning(layout.nameplate.height * 0.22)
                        .foregroundStyle(Color(white: 0.12).opacity(0.85))
                        .shadow(color: .white.opacity(0.45), radius: 0, y: 0.6)
                }
                .uprightPlace(layout.nameplate)
                .accessibilityHidden(true)
            UprightLastFrame().uprightPlace(layout.lastFrame)
            UprightSwitch(k: layout.k).uprightPlace(layout.switchRect)
            UprightLCD(turn: model.labelTurn).uprightPlace(layout.lcd)
            UprightEV(turn: model.labelTurn, k: layout.k).uprightPlace(layout.ev)
            keys(layout)
            UprightDoor(open: model.isBayOpen, turn: model.labelTurn) {
                // The door opens on the chamber (the Duo's): rewind, take out, load happen in it.
                if !model.isBayOpen { model.toggleBay() }
            }
            .uprightPlace(layout.door)
            UprightShutter().uprightPlace(layout.shutter)
                .opacity(model.isBayOpen ? 0 : 1)   // on the door, which has swung away
                .animation(.easeOut(duration: 0.2), value: model.isBayOpen)
                .allowsHitTesting(!model.isBayOpen)
            // The chamber stands over the lower body while the door is open. Always
            // there (so the arriving roll's change plays), seen only when open.
            FilmChamber()
                .frame(width: layout.chamber.width, height: layout.chamber.height)
                .clipShape(RoundedRectangle(cornerRadius: 10 * layout.k, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10 * layout.k, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.6), lineWidth: 2))
                .shadow(color: .black.opacity(0.5), radius: 8, y: 3)
                .rotationEffect(.degrees(model.labelTurn))
                .position(x: layout.chamber.midX, y: layout.chamber.midY)
                .opacity(model.isBayOpen ? 1 : 0)
                .allowsHitTesting(model.isBayOpen && model.bag == nil)
                .accessibilityHidden(!model.isBayOpen)
                .animation(.easeInOut(duration: 0.3).delay(model.isBayOpen ? 0.25 : 0), value: model.isBayOpen)

            // The bag: one page at a time, upright, filling the screen. Its
            // community and settings pages are still the landscape pair.
            if let bag = model.bag {
                UprightBag(start: bag, size: size)
                    .zIndex(100)
            }
            // The detail page or the settings (and the store) over it: still landscape.
            if model.panel != nil || model.isStoreOpen {
                FixedToPhone(wide: true, turnOnGlass: FoldLayout.bodyTurnOnGlass) {
                    PanelHost().environmentObject(model)
                }
                .frame(width: size.width, height: size.height)
                .transition(.opacity)
                .zIndex(101)
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: model.labelTurn)
    }

    @ViewBuilder private func keys(_ layout: UprightLayout) -> some View {
        let turn = model.labelTurn
        UprightKey(index: 0, frame: layout.keys[0], turn: turn, label: "Flash",
                   value: LocalizedStringKey(model.flash.title), lit: model.flash != .off,
                   symbol: model.flash == .off ? "bolt.slash.fill" : "bolt.fill",
                   text: nil, caption: model.flash == .auto ? "AUTO" : model.flash == .on ? "ON" : "FLASH") {
            model.cycleFlash()
        }
        UprightKey(index: 1, frame: layout.keys[1], turn: turn, label: "Switch camera",
                   value: model.isFrontCamera ? "Front" : "Rear", lit: model.isFrontCamera,
                   symbol: "arrow.triangle.2.circlepath.camera.fill", text: nil,
                   caption: model.isFrontCamera ? "FRONT" : "FLIP") {
            model.flipCamera()
        }
        UprightKey(index: 2, frame: layout.keys[2], turn: turn, label: "Zoom",
                   value: LocalizedStringKey(Self.zoomText(model.zoom)), lit: false,
                   symbol: nil, text: Self.zoomText(model.zoom), caption: "LENS") {
            model.toggleLens()
        }
        if model.isReviewing {
            // Looking at the last picture, the format key shares it: the
            // first press opens the share tray, the next sends.
            UprightKey(index: 3, frame: layout.keys[3], turn: turn, label: "Share",
                       value: LocalizedStringKey(model.shareKind.title),
                       lit: model.isShareTrayOpen || model.isMakingShare,
                       symbol: model.isMakingShare ? "hourglass" : "square.and.arrow.up", text: nil,
                       caption: "SHARE") {
                model.pressShare()
            }
        } else {
            UprightKey(index: 3, frame: layout.keys[3], turn: turn, label: "Format",
                       value: model.isSquare ? "Square" : "3 to 2", lit: model.isSquare,
                       symbol: model.isSquare ? "square" : "rectangle.portrait", text: nil,
                       caption: model.isSquare ? "1:1" : "3:2") {
                model.toggleFormat()
            }
        }
    }

    static func zoomText(_ zoom: CGFloat) -> String {
        String(format: zoom == zoom.rounded() ? "%.0f×" : "%.1f×", zoom)
    }
}

private extension View {
    /// Sizes and positions a view at a rectangle of the enclosing top-leading ZStack.
    func uprightPlace(_ rect: CGRect) -> some View {
        frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
    }
}

/// Lays its content out the way the phone is held and turns it to read
/// upright, in place: for a quarter turn the content gets the frame's height
/// as its width.
struct TurnInPlace<Content: View>: View {
    let turn: Double
    @ViewBuilder var content: (_ sideways: Bool) -> Content

    var body: some View {
        GeometryReader { geo in
            let sideways = abs(abs(turn) - 90) < 1
            content(sideways)
                .frame(width: sideways ? geo.size.height : geo.size.width,
                       height: sideways ? geo.size.width : geo.size.height)
                .rotationEffect(.degrees(turn))
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

/// The plate picture, in its five bands.
private struct PlateBands: View {
    let layout: UprightLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(layout.bands.enumerated()), id: \.offset) { _, band in
                Self.slice(band.source)
                    .resizable()
                    .interpolation(.high)
                    .uprightPlace(band.frame)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static var cache: [Bool: [ClosedRange<CGFloat>: Image]] = [:]
    static func slice(_ rows: ClosedRange<CGFloat>) -> Image {
        if let made = cache[BodyTheme.shared.isLight]?[rows] { return made }
        let plate = UprightCameraBody.plate
        let made: Image
        if let whole = plate.cgImage {
            let k = CGFloat(whole.width) / UprightLayout.plate.width
            let crop = CGRect(x: 0, y: rows.lowerBound * k, width: CGFloat(whole.width),
                              height: (rows.upperBound - rows.lowerBound) * k)
            made = whole.cropping(to: crop).map { Image(uiImage: UIImage(cgImage: $0)) } ?? Image(uiImage: plate)
        } else {
            made = Image(uiImage: plate)
        }
        cache[BodyTheme.shared.isLight, default: [:]][rows] = made
        return made
    }
}

/// The finder window. The camera's picture lies across the phone, so here
/// it is turned a quarter, whole: the sensor's long side runs the window's
/// height. The frame the picture will hold (3:2, or 1:1) is marked on it and
/// the rest dimmed; it is the same patch of the scene however the phone is
/// held: upright it makes an upright picture, held sideways a landscape one.
private struct UprightFinder: View {
    @EnvironmentObject private var model: CameraModel
    let glass: CGRect
    let radius: CGFloat

    var body: some View {
        // The preview fills the window's width (user 11/27, C): the sensor's
        // short side runs across, so its long side (4:3) is taller than the
        // window and the top and bottom run past it.
        let sensor = CGSize(width: glass.width, height: glass.width * 4 / 3)
        let frame = UprightFinderFrame.frame(in: sensor, square: model.isSquare)
        // The part of the real capture frame the window shows.
        let shown = CGSize(width: min(frame.width, glass.width), height: min(frame.height, glass.height))
        ZStack {
            ZStack {
            Color.black
            PreviewView(store: model.frames, showsFullHeight: true)
                .frame(width: sensor.height, height: sensor.width)
                .rotationEffect(.degrees(90))
                .frame(width: sensor.width, height: sensor.height)
            // Outside the frame: seen, dimmed, not taken.
            Rectangle().fill(Color.black.opacity(0.55))
                .mask {
                    Rectangle().overlay {
                        Rectangle().frame(width: frame.width, height: frame.height).blendMode(.destinationOut)
                    }
                    .compositingGroup()
                }
                .frame(width: sensor.width, height: sensor.height)
                .allowsHitTesting(false)
            // Corner marks at the capture frame's corners as far as the window shows them,
            // and a thin line along each side that is whole inside it.
            FrameMarks(size: shown, cutTop: frame.height > glass.height + 0.5, cutSide: frame.width > glass.width + 0.5)
                .stroke(Color(red: 1.0, green: 0.96, blue: 0.84).opacity(0.9), lineWidth: 1.5)
                .frame(width: shown.width, height: shown.height)
                .allowsHitTesting(false)
            if model.showsGrid {
                GridLines().frame(width: frame.width, height: frame.height)
            }
            EllipticalGradient(colors: [.clear, .black.opacity(0.3)],
                               center: .center, startRadiusFraction: 0.35, endRadiusFraction: 0.8)
                .allowsHitTesting(false)
            }
            .frame(width: glass.width, height: glass.height)
            .clipped()
            TurnInPlace(turn: model.labelTurn) { _ in
                Color.clear.overlay(alignment: .bottom) { UsedUpNote() }
            }
            ShutterBlades()
            if model.isReviewing, let shot = model.lastThumbnail {
                // The last picture, whole, until a tap goes back to the scene.
                ZStack {
                    Color.black
                    Image(uiImage: shot).resizable().scaledToFit()
                }
                .accessibilityLabel("Last picture")
            }
            if model.isShareTrayOpen {
                ShareTray().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.isSquare)
        .frame(width: glass.width, height: glass.height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { if model.isReviewing { model.toggleReview() } else { model.toggleGrid() } }
        .accessibilityLabel("Viewfinder")
    }

}

/// Corner brackets with a hairline between them along the sides the window shows whole.
private struct FrameMarks: Shape {
    let size: CGSize
    /// The frame runs past the window above and below (its top and bottom edges are not seen).
    let cutTop: Bool
    let cutSide: Bool

    func path(in r: CGRect) -> Path {
        var p = Path()
        let a = min(r.width, r.height) * 0.09
        let inset = r.insetBy(dx: 1, dy: 1)
        for (x, dx) in [(inset.minX, 1.0), (inset.maxX, -1.0)] {
            for (y, dy) in [(inset.minY, 1.0), (inset.maxY, -1.0)] {
                p.move(to: CGPoint(x: x + dx * a, y: y))
                p.addLine(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x, y: y + dy * a))
            }
        }
        // A thin line along the sides that are the real frame's edges.
        if !cutSide || cutTop {
            p.move(to: CGPoint(x: inset.minX, y: inset.minY)); p.addLine(to: CGPoint(x: inset.minX, y: inset.maxY))
            p.move(to: CGPoint(x: inset.maxX, y: inset.minY)); p.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
        }
        if !cutTop {
            p.move(to: CGPoint(x: inset.minX, y: inset.minY)); p.addLine(to: CGPoint(x: inset.maxX, y: inset.minY))
            p.move(to: CGPoint(x: inset.minX, y: inset.maxY)); p.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
        }
        return p
    }
}

enum UprightFinderFrame {
    /// The picture's frame on the turned sensor: 3:2 takes its full length.
    static func frame(in sensor: CGSize, square: Bool) -> CGSize {
        square ? CGSize(width: sensor.width, height: sensor.width)
               : CGSize(width: sensor.height * 2 / 3, height: sensor.height)
    }
}

/// The body colour switch: the empty track cut from the body picture with the
/// GPT knob on it; a tap or a slide flips every body between dark and light.
private struct UprightSwitch: View {
    let k: CGFloat
    @ObservedObject private var theme = BodyTheme.shared

    var body: some View {
        GeometryReader { geo in
            let cut = BodyTheme.trackCut
            let s = geo.size.width / cut.width
            let knob = BodyTheme.knobSize
            let at = theme.isLight ? BodyTheme.trackKnobRight : BodyTheme.trackKnobLeft
            ZStack(alignment: .topLeading) {
                SwitchMarks(scale: s, origin: CGPoint(x: -cut.minX * s, y: -cut.minY * s))
                Image(uiImage: theme.trackSprite).resizable().interpolation(.high)
                    .mask {
                        RoundedRectangle(cornerRadius: 30 * s).padding(6 * s).blur(radius: 3 * s)
                    }
                Image(uiImage: theme.art("body_knob.png")).resizable().interpolation(.high)
                    .frame(width: knob.width * s, height: knob.height * s)
                    .shadow(color: .black.opacity(0.4), radius: 2 * s, y: 1.5 * s)
                    .position(x: at.x * s, y: at.y * s)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: theme.isLight)
        }
        // The touch reaches well past the track.
        .overlay {
            Color.clear
                .frame(width: max(84 * k, 96), height: 48)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { drag in
                    let want = abs(drag.translation.width) > 10 ? drag.translation.width > 0 : !theme.isLight
                    guard want != theme.isLight else { return }
                    Haptic.tap()
                    theme.isLight = want
                })
        }
        .accessibilityElement()
        .accessibilityLabel("Body colour")
        .accessibilityValue(theme.isLight ? Text("Light") : Text("Dark"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { theme.isLight.toggle() }
    }
}

/// The LCD: the film, the frame's shape and the zoom, in segment type.
/// Held sideways it reads as a column, upright where it is.
private struct UprightLCD: View {
    @ObservedObject private var theme = BodyTheme.shared
    @EnvironmentObject private var model: CameraModel
    let turn: Double

    var body: some View {
        _ = LCDReadout.fonts
        let glass = CGRect(x: 27.0 / 454, y: 29.0 / 166, width: 399.0 / 454, height: 107.0 / 166)
        return GeometryReader { geo in
            let inner = CGRect(x: geo.size.width * glass.minX, y: geo.size.height * glass.minY,
                               width: geo.size.width * glass.width, height: geo.size.height * glass.height)
            ZStack(alignment: .topLeading) {
                Image(uiImage: UprightCameraBody.part("lcd")).resizable().interpolation(.high)
                TurnInPlace(turn: turn) { sideways in
                    readout(sideways: sideways, h: inner.height)
                }
                .frame(width: inner.width, height: inner.height)
                .position(x: inner.midX, y: inner.midY)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(Text(model.film?.name ?? "No film"))
    }

    private var code: String {
        (model.usedUp != nil ? "END" : (model.film.map { $0.lcd ?? $0.name } ?? "----"))
            .uppercased().replacingOccurrences(of: " ", with: "!")
    }

    @ViewBuilder private func readout(sideways: Bool, h: CGFloat) -> some View {
        let format = model.isSquare ? "1:1" : "3:2"
        let zoom = String(format: "%.1fX", model.zoom)
        if sideways {
            // A narrow column: one item to a line.
            // `h` is the column's width here (the glass's height).
            VStack(spacing: h * 0.16) {
                LCDReadout.Segments(text: String(code.prefix(4)), ghost: "~~~~", face: "DSEG14Classic-Italic", size: h * 0.26, h: h * 0.5)
                LCDReadout.Segments(text: format, ghost: "~:~", face: "DSEG14Classic-Italic", size: h * 0.26, h: h * 0.5)
                LCDReadout.Segments(text: zoom, ghost: "8.8X", face: "DSEG14Classic-Italic", size: h * 0.26, h: h * 0.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        } else {
            HStack(spacing: h * 0.22) {
                LCDReadout.Segments(text: code, ghost: "~~~~~", face: "DSEG14Classic-Italic", size: h * 0.40, h: h)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: h * 0.10) {
                    LCDReadout.Segments(text: format, ghost: "~:~", face: "DSEG14Classic-Italic", size: h * 0.20, h: h)
                    LCDReadout.Segments(text: zoom, ghost: "8.8X", face: "DSEG14Classic-Italic", size: h * 0.20, h: h)
                }
            }
            .padding(.horizontal, h * 0.16)
        }
    }
}

/// The exposure slide: −2 to +2 in thirds, along its slot. Double tap: 0.
private struct UprightEV: View {
    @ObservedObject private var theme = BodyTheme.shared
    @EnvironmentObject private var model: CameraModel
    let turn: Double
    let k: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let trackH = min(w * 111 / 411, geo.size.height - 16 * k)
            let trackY = geo.size.height - trackH
            // The slot inside the track picture.
            let slot = CGRect(x: w * 22 / 411, y: trackY + trackH * 31 / 111,
                              width: w * 366 / 411, height: trackH * 43 / 111)
            let knob = CGSize(width: slot.height * 0.95 * 70 / 110 * 1.6, height: slot.height * 1.6)
            let travel = (slot.width - knob.width) / 2
            let x = slot.midX + CGFloat(model.exposureBias / 2) * travel
            ZStack(alignment: .topLeading) {
                Image(uiImage: UprightCameraBody.part("ev_track")).resizable().interpolation(.high)
                    .frame(width: w, height: trackH)
                    .position(x: w / 2, y: trackY + trackH / 2)
                // The printed scale above the slot: each mark turns where it is.
                ForEach(Array(["−2", "−1", "0", "+1", "+2"].enumerated()), id: \.offset) { i, mark in
                    let mx = slot.midX + CGFloat(i - 2) / 2 * travel
                    TurnInPlace(turn: turn) { _ in
                        Text(verbatim: mark)
                            .font(.system(size: 11 * k, weight: i == 2 ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(i == 2 ? theme.litInk : theme.keyInk)
                            .fixedSize()
                    }
                    .frame(width: 22 * k, height: 14 * k)
                    .position(x: mx, y: trackY - 7 * k)
                    .allowsHitTesting(false)
                }
                Image(uiImage: UprightCameraBody.part("ev_knob")).resizable().interpolation(.high)
                    .frame(width: knob.width, height: knob.height)
                    .shadow(color: .black.opacity(0.55), radius: 2, y: 1.5)
                    .position(x: x, y: slot.midY)
                    .animation(.easeOut(duration: 0.08), value: model.exposureBias)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ev = Double((value.location.x - slot.midX) / max(travel, 1)) * 2
                        model.setExposureBias((ev * 3).rounded() / 3)   // 1/3-stop clicks
                    }
            )
            .simultaneousGesture(TapGesture(count: 2).onEnded { model.setExposureBias(0) })
        }
        .accessibilityElement()
        .accessibilityLabel("Exposure compensation")
        .accessibilityValue(String(format: "%+.1f", model.exposureBias))
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? 1.0 / 3 : -1.0 / 3
            model.setExposureBias(((model.exposureBias + step) * 3).rounded() / 3)
        }
    }
}

/// One of the four rubber keys. Its face (a symbol or a figure over a short
/// name) turns to read upright where it is; lit while its function is on.
private struct UprightKey: View {
    @ObservedObject private var theme = BodyTheme.shared
    let index: Int
    let frame: CGRect
    let turn: Double
    let label: LocalizedStringKey
    let value: LocalizedStringKey
    let lit: Bool
    let symbol: String?
    let text: String?
    let caption: String
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        let h = frame.height
        let ink = lit ? theme.litInk : theme.keyInk
        Button(action: action) {
            ZStack {
                Image(uiImage: UprightCameraBody.part("key_\(index)")).resizable().interpolation(.high)
                    .brightness(pressed ? -0.06 : 0)
                    .scaleEffect(pressed ? 0.96 : 1)
                TurnInPlace(turn: turn) { sideways in
                    VStack(spacing: h * 0.04) {
                        if let symbol {
                            Image(systemName: symbol).font(.system(size: h * 0.34, weight: .semibold))
                        } else if let text {
                            Text(verbatim: text).font(.system(size: h * 0.34, weight: .bold, design: .rounded))
                        }
                        Text(verbatim: caption)
                            .font(.system(size: h * 0.20, weight: .semibold))
                            .kerning(h * 0.02)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .foregroundStyle(ink)
                    .shadow(color: lit && !theme.isLight ? ink.opacity(0.6) : .clear, radius: 3)
                    .padding(.horizontal, sideways ? 2 : 6)
                }
                .padding(.vertical, h * 0.08)
            }
            .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(KeyPress(pressed: $pressed))
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .uprightPlace(frame)
    }

    private struct KeyPress: ButtonStyle {
        @Binding var pressed: Bool
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.onChange(of: configuration.isPressed) { _, on in pressed = on }
        }
    }
}

/// The film door, with "FILM ▸" on it and the loaded roll's label in its
/// little window. A tap swings it open and the bag comes up.
private struct UprightDoor: View {
    @ObservedObject private var theme = BodyTheme.shared
    @EnvironmentObject private var model: CameraModel
    let open: Bool
    let turn: Double
    let action: () -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            // The window, measured on the door picture (341×375).
            let window = CGRect(x: w * 75 / 341, y: h * 231 / 375, width: w * 208 / 341, height: h * 92 / 375)
            Button(action: action) {
                ZStack(alignment: .topLeading) {
                    if open {
                        // The door has swung away: the chamber stands over the body (UprightCameraBody).
                        Color.clear
                    } else {
                        Image(uiImage: UprightCameraBody.part("door")).resizable().interpolation(.high)
                            .frame(width: w, height: h)
                        // Pressed into the leather above the window.
                        TurnInPlace(turn: turn) { _ in
                            HStack(spacing: h * 0.02) {
                                Text(verbatim: "FILM")
                                    .font(.system(size: h * 0.105, weight: .heavy).italic())
                                    .kerning(h * 0.01)
                                Image(systemName: turn == 0 ? "arrowtriangle.right.fill" : "arrowtriangle.up.fill")
                                    .font(.system(size: h * 0.06))
                            }
                            .foregroundStyle(Color(white: 0.30))
                            .shadow(color: .black.opacity(0.8), radius: 0, x: 0, y: -1)
                            .shadow(color: .white.opacity(0.10), radius: 0, x: 0, y: 1)
                            .fixedSize()
                        }
                        .frame(width: w * 0.62, height: h * 0.30)
                        .position(x: w * 0.52, y: h * 0.33)
                        RollLabel(turn: turn)
                            .frame(width: window.width, height: window.height)
                            .clipShape(RoundedRectangle(cornerRadius: window.height * 0.12))
                            .position(x: window.midX, y: window.midY)
                    }
                }
                .frame(width: w, height: h)
                .animation(.easeInOut(duration: 0.2), value: open)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change film")
            .accessibilityValue(Text(model.film?.name ?? ""))
        }
    }
}

/// The roll's own label, seen through the door's window: its name and speed.
private struct RollLabel: View {
    @EnvironmentObject private var model: CameraModel
    let turn: Double

    var body: some View {
        TurnInPlace(turn: turn) { sideways in
            GeometryReader { geo in
                let h = geo.size.height, w = geo.size.width
                let cream = Color(red: 0.95, green: 0.92, blue: 0.84)
                if let film = model.film {
                    VStack(alignment: .leading, spacing: h * 0.04) {
                        Text(verbatim: film.name.uppercased())
                            .font(.system(size: min(h * (sideways ? 0.18 : 0.30), w * (sideways ? 0.24 : 0.16)), weight: .bold))
                            .lineLimit(sideways ? 3 : 1)
                            .minimumScaleFactor(0.5)
                        Text(verbatim: "ISO \(film.iso)")
                            .font(.system(size: min(h * (sideways ? 0.12 : 0.22), w * (sideways ? 0.17 : 0.12)), weight: .semibold))
                            .foregroundStyle(cream.opacity(0.7))
                    }
                    .foregroundStyle(cream)
                    .padding(.horizontal, w * 0.08)
                    .frame(width: w, height: h, alignment: .leading)
                } else {
                    Text("No film")
                        .font(.system(size: h * 0.24, weight: .semibold))
                        .foregroundStyle(cream.opacity(0.6))
                        .frame(width: w, height: h)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// The shutter key. Pressed, the picture of it sunk in its well takes its
/// place; held, it keeps taking pictures.
private struct UprightShutter: View {
    @EnvironmentObject private var model: CameraModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var pressed = false
    @State private var burst: Task<Void, Never>?
    @State private var wentDown = Date.distantPast

    var body: some View {
        Image(uiImage: UprightCameraBody.part(pressed ? "shutter_down" : "shutter"))
            .resizable()
            .interpolation(.high)
            .contentShape(Rectangle().inset(by: -8))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in down() }
                    .onEnded { _ in up() }
            )
            .accessibilityLabel("Shutter")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.shoot() }
            // A hold cut short (Control Center, the Lock Screen, leaving the
            // camera) never ends its gesture: the burst stops here instead.
            .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
            .onChange(of: model.bag) { _, bag in if bag != nil { stop() } }
            .onDisappear { stop() }
    }

    private func stop() {
        burst?.cancel()
        burst = nil
        pressed = false
    }

    private func down() {
        guard !pressed else { return }
        pressed = true
        wentDown = Date()
        model.shoot()
        burst = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            while !Task.isCancelled {
                model.shoot(fast: true)   // ignored while the last exposure is still under way
                try? await Task.sleep(for: .milliseconds(40))
            }
        }
    }

    private func up() {
        burst?.cancel()
        burst = nil
        let shown = Date().timeIntervalSince(wentDown)
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, 0.14 - shown)) {
            if burst == nil { pressed = false }
        }
    }
}

/// The last picture, small, at the end of the nameplate's row. A tap shows it
/// in the finder (and the format key shares it); another goes back.
private struct UprightLastFrame: View {
    @EnvironmentObject private var model: CameraModel

    var body: some View {
        Button { model.toggleReview() } label: {
            GeometryReader { geo in
                let r = geo.size.height * 0.14
                ZStack {
                    RoundedRectangle(cornerRadius: r).fill(Color.black.opacity(0.55))
                    if let thumb = model.lastThumbnail {
                        Image(uiImage: thumb).resizable().scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .id(model.frameCount)
                            .transition(.asymmetric(insertion: .move(edge: .top), removal: .identity))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipShape(RoundedRectangle(cornerRadius: r))
                .overlay {
                    RoundedRectangle(cornerRadius: r)
                        .strokeBorder(model.isReviewing ? Color(red: 1.0, green: 0.74, blue: 0.24) : Color.white.opacity(0.12),
                                      lineWidth: model.isReviewing ? 2 : 1)
                }
                .animation(.easeOut(duration: 0.35), value: model.frameCount)
            }
            .contentShape(Rectangle().inset(by: -8))
        }
        .buttonStyle(.plain)
        .disabled(model.lastThumbnail == nil)
        .accessibilityLabel("Show the last picture")
    }
}
