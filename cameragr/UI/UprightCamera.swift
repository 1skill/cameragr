import SwiftUI

/// Where everything on the upright body goes, for one screen size (points).
/// The plate picture (`upright_plate.jpg`, GPT, 804×1748 = 2 px a point on a
/// 402-point screen; design/upright_body_v3, in the Duo body's matte plastic)
/// is cut into five bands across: the top with the window's upper edge, the
/// window's sides (stretched to the window's height), the window's lower
/// edge, the plain body (stretched or squeezed to fill), and the bottom edge
/// with the stripes. The body runs to the screen's top edge; on a phone with
/// a Dynamic Island a ring in the body goes round it (user 11/28).
struct UprightLayout: Equatable {
    /// The plate picture's size and its bands, in its own pixels.
    static let plate = CGSize(width: 804, height: 1748)
    static let topBand: ClosedRange<CGFloat> = 0...240         // from the top edge, with the window's upper edge
    static let shortTopBand: ClosedRange<CGFloat> = 110...240  // a short phone (status bar, no island): the window higher up
    static let sideBand: ClosedRange<CGFloat> = 240...840      // the window's straight sides
    static let lowerBand: ClosedRange<CGFloat> = 840...930     // the window's lower edge
    static let leatherBand: ClosedRange<CGFloat> = 930...1640  // plain body
    static let bottomBand: ClosedRange<CGFloat> = 1640...1748  // the stripes and the body's lower edge
    static let shortBottomBand: ClosedRange<CGFloat> = 1640...1706  // a phone without a home indicator: the stripes at the very foot
    /// The window's glass, edge to edge, and where the stripes start.
    static let glassPx = CGRect(x: 41, y: 162, width: 722, height: 737)
    static let stripePx: CGFloat = 1668
    static let glassRadiusPx: CGFloat = 40
    /// The Dynamic Island (points): the same on every iPhone that has one.
    static let island = CGSize(width: 126, height: 37.33)
    static let islandTop: CGFloat = 11.33
    /// The ring art's opening, as fractions of it (upright_island.png).
    static let ringOpening = CGRect(x: 0.0498, y: 0.1384, width: 0.9005, height: 0.7233)
    /// The last picture's bezel art's opening (upright_review.png, 294 × 225).
    static let reviewOpening = CGRect(x: 0.0850, y: 0.1111, width: 0.8265, height: 0.7778)
    /// The door's window, as fractions of the door art (upright_bigdoor.png, GPT,
    /// design/big_door; measured on its alpha, dark and light the same to a pixel).
    static let doorWindow = CGRect(x: 0.1447, y: 0.1665, width: 0.1979, height: 0.6705)

    let size: CGSize
    /// Plate pixels to points, across.
    let s: CGFloat
    /// The controls' scale (1 on a 402-point-wide screen).
    let k: CGFloat
    let glass: CGRect
    /// Where each band of the plate is drawn.
    let bands: [(source: ClosedRange<CGFloat>, frame: CGRect)]
    /// The ring round the Dynamic Island, if the phone has one.
    let islandRing: CGRect?
    let nameplate: CGRect
    let lastFrame: CGRect   // the last picture's bezel, at the end of the nameplate's row
    /// The film chamber behind the door: the door's own size and place (the whole bottom row).
    let chamber: CGRect
    let switchRect: CGRect  // the body colour switch, between the nameplate and the last picture
    let lcd: CGRect
    let ev: CGRect          // the track, with its scale printed above it
    let keys: [CGRect]      // flash, flip, lens, format
    let door: CGRect
    let shutter: CGRect
    let ribs: CGRect        // the grip ribs under the shutter
    let bodyEnd: CGFloat

    static func == (a: UprightLayout, b: UprightLayout) -> Bool { a.size == b.size }

    /// The screens (points, upright) of the iPhones with a Dynamic Island:
    /// 14 Pro / 15 / 16 (393 × 852), 16 Pro / 17 / 17 Pro (402 × 874),
    /// Air (420 × 912), 14 Pro Max / 15 Plus / 16 Plus (430 × 932), 16 Pro
    /// Max / 17 Pro Max (440 × 956). Notched phones (375 × 812, 414 × 896,
    /// 390 × 844, 428 × 926) and the SE get no ring.
    static let islandScreens: [CGSize] = [CGSize(width: 393, height: 852), CGSize(width: 402, height: 874),
                                          CGSize(width: 420, height: 912), CGSize(width: 430, height: 932),
                                          CGSize(width: 440, height: 956)]
    static func hasIsland(_ size: CGSize) -> Bool {
        islandScreens.contains { abs($0.width - size.width) < 1 && abs($0.height - size.height) < 1 }
    }

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
        let top = tall ? Self.topBand : Self.shortTopBand
        let bottom = tall ? Self.bottomBand : Self.shortBottomBand
        let glassTop = (Self.glassPx.minY - top.lowerBound) * s
        // The controls end above the stripes.
        let bodyEnd = h - (bottom.upperBound - Self.stripePx) * s
        self.bodyEnd = bodyEnd
        let glassW = Self.glassPx.width * s
        let glassX = Self.glassPx.minX * s

        if Self.hasIsland(size) {
            let opening = CGSize(width: Self.island.width + 6, height: Self.island.height + 5)
            let ringW = opening.width / Self.ringOpening.width, ringH = opening.height / Self.ringOpening.height
            let midY = Self.islandTop + Self.island.height / 2
            islandRing = CGRect(x: (w - ringW) / 2, y: midY - ringH / 2, width: ringW, height: ringH)
        } else {
            islandRing = nil
        }

        // Fixed heights below the window, and the door, which may give way on a short screen.
        let bezel = (Self.lowerBand.upperBound - Self.glassPx.maxY) * s
        // The rows' spacing, closer on a short phone.
        let sp: CGFloat = tall ? 1 : 0.6
        let rowH = (tall ? 64 : 50) * k
        let fixed = (60 + 44) * k + (8 + 6 + 12 + 12 + 4) * k * sp + rowH
        // The door no shorter than three 44-point keys in its chamber.
        let doorMin = max(130 * k, 132)
        var doorH = 187 * k
        var g = bodyEnd - glassTop - bezel - fixed - doorH
        let gMin = glassW * 0.85
        if g < gMin {
            let give = min(gMin - g, doorH - doorMin)
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
        let topH = (top.upperBound - top.lowerBound) * s
        let lowerH = (Self.lowerBand.upperBound - Self.lowerBand.lowerBound) * s
        let lowerY = glass.maxY - (Self.glassPx.maxY - Self.lowerBand.lowerBound) * s
        let bottomH = (bottom.upperBound - bottom.lowerBound) * s
        // The body runs to the screen's bottom edge.
        let bottomY = h - bottomH
        bands = [
            (top, CGRect(x: 0, y: 0, width: w, height: topH)),
            (Self.sideBand, CGRect(x: 0, y: topH, width: w, height: max(0, lowerY - topH))),
            (Self.lowerBand, CGRect(x: 0, y: lowerY, width: w, height: lowerH)),
            (Self.leatherBand, CGRect(x: 0, y: lowerY + lowerH, width: w, height: max(0, bottomY - lowerY - lowerH))),
            (bottom, CGRect(x: 0, y: bottomY, width: w, height: bottomH)),
        ]

        // The controls, top down from the window.
        let gap = spare / 4
        let left = glass.minX, right = glass.maxX, width = right - left
        var y = glass.maxY + bezel + 8 * k * sp + gap
        // The last picture, big enough to see (user 11/28), at the row's end.
        let reviewW = rowH * 294 / 225
        lastFrame = CGRect(x: right - reviewW, y: y, width: reviewW, height: rowH)
        nameplate = CGRect(x: left + 4 * k, y: y + (rowH - 22 * k) / 2, width: 96 * k, height: 22 * k)
        let switchW = 84 * k
        switchRect = CGRect(x: (left + 100 * k + lastFrame.minX - switchW) / 2, y: y + (rowH - switchW * 82 / 214) / 2,
                            width: switchW, height: switchW * 82 / 214)
        y += rowH + 6 * k * sp + gap
        let lcdW = 60 * k * 454 / 166
        lcd = CGRect(x: left, y: y, width: lcdW, height: 60 * k)
        ev = CGRect(x: left + lcdW + 14 * k, y: y, width: width - lcdW - 14 * k, height: 60 * k)
        y += 60 * k + 12 * k * sp + gap
        let keyGap = 10 * k
        let keyW = (width - 3 * keyGap) / 4
        keys = (0..<4).map { CGRect(x: left + CGFloat($0) * (keyW + keyGap), y: y, width: keyW, height: 44 * k) }
        y += 44 * k + 12 * k * sp + gap
        // The door is the whole bottom row, shutter and all (user 11/28): one
        // lid over the chamber, with the shutter and its grip ribs on it.
        door = CGRect(x: left, y: y, width: width, height: doorH)
        let shutterSide = min(132 * k, doorH * 0.7)
        let shutterTop = door.minY + 8 * k * sp
        shutter = CGRect(x: right - shutterSide - 14 * k, y: shutterTop, width: shutterSide, height: shutterSide)
        let ribsH = min(36 * k, door.maxY - shutter.maxY - 14 * k)
        let ribsW = ribsH * 391 / 159
        ribs = CGRect(x: shutter.midX - ribsW / 2, y: shutter.maxY + 6 * k, width: ribsW, height: max(0, ribsH))
        // The film chamber is exactly what the door covers.
        chamber = door
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
            if let ring = layout.islandRing {
                // The body gives way round the Dynamic Island: a ring moulded in it.
                Image(uiImage: Self.part("island")).resizable().interpolation(.high)
                    .uprightPlace(ring)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
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
            // The small chamber, under its door: always there (so the arriving
            // roll's change plays), seen as the door swings away.
            // Shut, it is drawn a little smaller than its door so none of its
            // dark edge shows round the door's rounded corners.
            let chamberShape = RoundedRectangle(cornerRadius: 10 * layout.k, style: .continuous)
                .inset(by: 8 * layout.k * (1 - doorOpenness))
            FilmChamber(compact: true, rollWindow: Self.rollWindow(layout, light: BodyTheme.shared.isLight),
                        closedness: 1 - doorOpenness)
                .frame(width: layout.chamber.width, height: layout.chamber.height)
                // In the door's shadow while it is shut, lit as it swings open.
                .overlay(Color.black.opacity(0.3 * (1 - doorOpenness)).allowsHitTesting(false))
                .clipShape(chamberShape)
                .overlay(chamberShape.strokeBorder(Color.black.opacity(0.6), lineWidth: 2))
                .shadow(color: .black.opacity(0.5 * doorOpenness), radius: 8, y: 3)
                .position(x: layout.chamber.midX, y: layout.chamber.midY)
                .animation(.easeInOut(duration: Self.doorSwing), value: model.isBayOpen)
                .allowsHitTesting(model.isBayOpen && model.bag == nil)
                .accessibilityHidden(!model.isBayOpen)

            // The chamber door: one lid over the whole bottom row, shutter
            // and all, hinged along its left edge (user 11/28).
            // A tap swings it towards you, about the hinge, to show the
            // chamber; closing swings it back. Made the way iPhone Duo's
            // outer door is (CameraScreen).
            // Its thickness: the door's own picture, in shadow, a few points
            // behind it, showing past its free edge as it turns.
            ZStack(alignment: .topLeading) {
                Image(uiImage: Self.part("bigdoor")).resizable().interpolation(.high)
                    .uprightPlace(layout.door)
            }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .overlay(Color.black.opacity(0.7))
                .mask { doorWindowMask(layout) }
                .clipShape(DoorOutline(rect: layout.chamber, radius: 10 * layout.k))
                .offset(x: Self.doorThickness * layout.k * sin(doorAngle * .pi / 180))
                // Only there once it has swung a little: shut, its edge would
                // show dark round the lid's soft edges.
                .opacity(min(1, doorOpenness * 6))
                .rotation3DEffect(.degrees(-doorAngle), axis: (x: 0, y: 1, z: 0),
                                  anchor: UnitPoint(x: layout.chamber.minX / size.width, y: layout.chamber.midY / size.height),
                                  perspective: 0.35)
                .animation(.easeInOut(duration: Self.doorSwing), value: model.isBayOpen)
                .opacity(model.isBayOpen && frozenDoor == nil ? 0 : 1)
                .animation(.linear(duration: 0.1).delay(model.isBayOpen ? Self.doorSwing - 0.1 : 0), value: model.isBayOpen)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            ZStack(alignment: .topLeading) {
                UprightDoor(turn: model.labelTurn, labelX: Self.doorLabelX(layout)) {
                    if !model.isBayOpen { model.toggleBay() }
                }
                .uprightPlace(layout.door)
                // The shutter is on the lid and swings with it; the grip ribs under it.
                Image(uiImage: Self.part("ribs")).resizable().interpolation(.high)
                    .uprightPlace(layout.ribs)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                UprightShutter().uprightPlace(layout.shutter)
            }
            .frame(width: size.width, height: size.height)
            // The window is a hole: the roll lying in the chamber shows through it.
            .mask { doorWindowMask(layout) }
            .overlay { doorWindowPane(layout) }
            // Turning from the light as it opens.
            .overlay(Color.black.opacity(0.35 * doorOpenness).allowsHitTesting(false))
            .clipShape(DoorOutline(rect: layout.chamber, radius: 10 * layout.k))
            .contentShape(DoorOutline(rect: layout.chamber, radius: 10 * layout.k))
            .rotation3DEffect(.degrees(-doorAngle), axis: (x: 0, y: 1, z: 0),
                              anchor: UnitPoint(x: layout.chamber.minX / size.width, y: layout.chamber.midY / size.height),
                              perspective: 0.35)
            .animation(.easeInOut(duration: Self.doorSwing), value: model.isBayOpen)
            // Gone once it is edge-on, so its mirrored back never shows.
            .opacity(model.isBayOpen && frozenDoor == nil ? 0 : 1)
            .animation(.linear(duration: 0.1).delay(model.isBayOpen ? Self.doorSwing - 0.1 : 0), value: model.isBayOpen)
            .allowsHitTesting(!model.isBayOpen && model.bag == nil)

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

    /// How long the door takes to swing open or shut, and how far it swings
    /// (just short of edge-on): both as on iPhone Duo's outer door.
    static let doorSwing = 0.4
    static let doorOpenAngle: Double = 86
    /// How thick the door is (points on a 402-point-wide phone).
    static let doorThickness: CGFloat = 5

    /// A fixed door angle for UI checks (`-door <degrees>`), debug builds only.
    private var frozenDoor: Double? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "door").flatMap(Double.init)
        #else
        nil
        #endif
    }

    /// The door's angle about its hinge (0 shut, as far as iPhone Duo's door opens).
    private var doorAngle: Double { frozenDoor ?? (model.isBayOpen ? Self.doorOpenAngle : 0) }
    /// 0 shut … 1 open.
    private var doorOpenness: Double { min(max(doorAngle / Self.doorOpenAngle, 0), 1) }

    /// The door window's opening on the screen: the hole in the door picture
    /// (GPT, upright_bigdoor*.png, design/big_door), measured on its
    /// alpha, a little inside the lip; over the roll lying in the chamber.
    static func doorWindow(_ layout: UprightLayout, light _: Bool = false) -> (rect: CGRect, radius: CGFloat) {
        let f = UprightLayout.doorWindow.insetBy(dx: 0.004, dy: 0.004)
        let d = layout.door
        let r = CGRect(x: d.minX + f.minX * d.width, y: d.minY + f.minY * d.height, width: f.width * d.width, height: f.height * d.height)
        return (r, 0.025 * d.width)
    }
    private func doorWindow(_ layout: UprightLayout) -> (rect: CGRect, radius: CGFloat) {
        Self.doorWindow(layout)
    }

    /// Where the FILM label goes on the door (a fraction of its width): in the
    /// plain stretch between the window and the shutter.
    static func doorLabelX(_ layout: UprightLayout) -> CGFloat {
        let windowRight = UprightLayout.doorWindow.maxX
        let shutterLeft = (layout.shutter.minX - layout.door.minX) / layout.door.width
        return (windowRight + shutterLeft) / 2
    }

    /// The door window in the chamber's frame: the roll is laid under it.
    static func rollWindow(_ layout: UprightLayout, light: Bool) -> CGRect {
        doorWindow(layout, light: light).rect.offsetBy(dx: -layout.chamber.minX, dy: -layout.chamber.minY)
    }

    /// The door's picture and body bands with the window cut out.
    private func doorWindowMask(_ layout: UprightLayout) -> some View {
        let w = doorWindow(layout)
        return Rectangle().fill(Color.black)
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: w.radius, style: .continuous)
                    .frame(width: w.rect.width, height: w.rect.height)
                    .offset(x: w.rect.minX, y: w.rect.minY)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }

    /// A pane in the opening: the roll seen through glass, in the shade of its edge.
    private func doorWindowPane(_ layout: UprightLayout) -> some View {
        let w = doorWindow(layout)
        let shape = RoundedRectangle(cornerRadius: w.radius, style: .continuous)
        return ZStack {
            shape.fill(Color.black.opacity(0.12))
            shape.stroke(Color.black.opacity(0.9), lineWidth: 8 * layout.k).blur(radius: 4 * layout.k).offset(y: 2 * layout.k).clipShape(shape)
        }
        .frame(width: w.rect.width, height: w.rect.height)
        .position(x: w.rect.midX, y: w.rect.midY)
        .allowsHitTesting(false)
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

/// The chamber door's outline: the chamber's rounded rectangle, in the body's frame.
private struct DoorOutline: Shape {
    let rect: CGRect
    let radius: CGFloat
    func path(in _: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
    }
}

/// The film door, with "FILM ▸" on it and a window over the roll in the chamber. A tap swings it open and the bag comes up.
private struct UprightDoor: View {
    @ObservedObject private var theme = BodyTheme.shared
    @EnvironmentObject private var model: CameraModel
    let turn: Double
    let labelX: CGFloat
    let action: () -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Button(action: action) {
                ZStack(alignment: .topLeading) {
                    Image(uiImage: UprightCameraBody.part("bigdoor")).resizable().interpolation(.high)
                        .frame(width: w, height: h)
                    // Pressed into the leather above the window.
                    TurnInPlace(turn: turn) { _ in
                        HStack(spacing: h * 0.02) {
                            Text(verbatim: "FILM")
                                .font(.system(size: h * 0.085, weight: .heavy).italic())
                                .kerning(h * 0.01)
                            Image(systemName: turn == 0 ? "arrowtriangle.right.fill" : "arrowtriangle.up.fill")
                                .font(.system(size: h * 0.06))
                        }
                        .foregroundStyle(Color(white: 0.30))
                        .shadow(color: .black.opacity(0.8), radius: 0, x: 0, y: -1)
                        .shadow(color: .white.opacity(0.10), radius: 0, x: 0, y: 1)
                        .fixedSize()
                    }
                    .frame(width: w * 0.22, height: h * 0.30)
                    .position(x: w * labelX, y: h * 0.50)
                }
                .frame(width: w, height: h)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change film")
            .accessibilityValue(Text(model.film?.name ?? ""))
        }
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
                let o = UprightLayout.reviewOpening
                let inner = CGRect(x: o.minX * geo.size.width, y: o.minY * geo.size.height,
                                   width: o.width * geo.size.width, height: o.height * geo.size.height)
                    .insetBy(dx: -1, dy: -1)
                let r = inner.height * 0.12
                ZStack(alignment: .topLeading) {
                    // The little screen, under its bezel (GPT, upright_review*.png).
                    ZStack {
                        Color.black
                        if let thumb = model.lastThumbnail {
                            Image(uiImage: thumb).resizable().scaledToFill()
                                .frame(width: inner.width, height: inner.height)
                                .id(model.frameCount)
                                .transition(.asymmetric(insertion: .move(edge: .top), removal: .identity))
                        }
                    }
                    .frame(width: inner.width, height: inner.height)
                    .clipShape(RoundedRectangle(cornerRadius: r))
                    .overlay {
                        if model.isReviewing {
                            RoundedRectangle(cornerRadius: r)
                                .strokeBorder(Color(red: 1.0, green: 0.74, blue: 0.24), lineWidth: 2)
                        }
                    }
                    .offset(x: inner.minX, y: inner.minY)
                    .animation(.easeOut(duration: 0.35), value: model.frameCount)
                    Image(uiImage: UprightCameraBody.part("review")).resizable().interpolation(.high)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(false)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Not `.disabled`: that would dim the bezel too. Nothing to show, nothing to tap.
        .allowsHitTesting(model.lastThumbnail != nil)
        .accessibilityHidden(model.lastThumbnail == nil)
        .accessibilityLabel("Show the last picture")
    }
}
