import AVKit
import SwiftUI

/// The camera body. The body itself is a rendered picture (`body_plate.jpg`,
/// 1536×1024) that fills the whole screen; everything that changes — the live
/// view, the LCD text, the exposure knob, the loaded roll, the last frame and
/// the pressed states — is drawn on top at coordinates measured on that picture.
struct CameraScreen: View {
    @EnvironmentObject private var model: CameraModel
    @Environment(\.scenePhase) private var scenePhase
    /// Draws a bar where a swipe leaves the camera. The Lock Screen camera needs
    /// it: the system shows no home indicator there.
    var showsExitHint = false
    @State private var exitHintWake = Date()
    @State private var pressBegan = false
    @ObservedObject private var posture = Posture.shared

    var body: some View {
        // The plate deliberately covers the full screen, safe area included: its
        // eyepiece is drawn where the front camera sits, so it has to line up with
        // the physical display rather than with the safe region.
        GeometryReader { geo in
            let _ = Diag.note("layout \(geo.size) open \(posture.isOpen)")
            if posture.isOpen {
                // A folding phone, open. Its inner screen is laid out as two
                // halves either side of the hinge: the half with the cameras
                // carries the body, the other is a waist-level finder. Folded
                // to a right angle, the body stands facing the scene and the
                // finder lies in the hands.
                //
                // The halves are fixed to the phone, not to the interface:
                // the layout is drawn upright as the phone is held with the
                // hinge level, then turned against whichever way the system
                // has the interface (see FixedToPhone). Rotation lock and the
                // way the phone is held make no difference to where things are.
                FixedToPhone(turnOnGlass: FoldLayout.turnOnGlass) {
                    GeometryReader { canvas in
                        let half = CGSize(width: canvas.size.width, height: canvas.size.height / 2)
                        VStack(spacing: 0) {
                            if FoldLayout.camerasAbove {
                                cameraBody(size: half, folded: true)
                                WaistFinder().frame(width: half.width, height: half.height)
                            } else {
                                WaistFinder().frame(width: half.width, height: half.height)
                                cameraBody(size: half, folded: true)
                            }
                        }
                    }
                    .ignoresSafeArea()
                    .environmentObject(model)
                }
            } else {
                // Closed. The body has one place on the outer screen, with its
                // eyepiece over the front camera. The app takes the interface
                // whichever way the system has it and never asks for a turn, so
                // there is none at launch; the body is simply drawn in its
                // place on the glass (see FixedToPhone). The Lock Screen camera
                // does the same: its window changes shape twice in its first
                // moments, and a layout that followed it would flash.
                FixedToPhone(wide: true, turnOnGlass: FoldLayout.bodyTurnOnGlass) {
                    GeometryReader { canvas in
                        cameraBody(size: canvas.size, folded: false)
                    }
                    .ignoresSafeArea()
                    .environmentObject(model)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        // The phone's Camera Control button and the volume buttons release the shutter.
        .onCameraCaptureEvent { event in
            Diag.note("capture event \(event.phase)")
            // Only a press that began here releases the shutter. The press
            // that opened the camera from the Lock Screen ends here too, and
            // would otherwise take a picture (and blink the finder) at once.
            switch event.phase {
            case .began: pressBegan = true
            case .ended:
                if pressBegan { model.shoot() }
                pressBegan = false
            default: pressBegan = false
            }
        }
        .onChange(of: scenePhase) { _, phase in Diag.note("scene \(phase)") }
        .onChange(of: posture.isOpen) { _, open in Diag.note("hinge open \(open)") }
        .onChange(of: model.isExposing) { _, on in Diag.note("exposing \(on)") }
        .onAppear {
            model.start()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.start()
                posture.askAgain()
            } else if phase == .background {
                model.stop()
            }
        }
        .alert("提示", isPresented: Binding(get: { model.message != nil },
                                          set: { if !$0 { model.message = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(model.message ?? "")
        }
    }
}

private extension CameraScreen {
    /// The camera body, laid out to fill `size`.
    func cameraBody(size: CGSize, folded: Bool) -> some View {
        let plate = Plate(container: size)
        return ZStack(alignment: .topLeading) {
            Color.black
            Image(uiImage: Plate.image)
                .resizable()
                .interpolation(.high)
                .place(plate.frame)
                .accessibilityHidden(true)

            Viewfinder(showsLastShot: folded).place(plate.rect(Plate.viewfinder))
            LCDReadout().place(plate.rect(Plate.lcd))
            ExposureSlider(plate: plate)

            PlateKey(plate: plate, region: Plate.flashKey, label: "闪光灯", value: model.flash.rawValue,
                     lit: model.flash != .off, latched: model.flash == .on) {
                model.cycleFlash()
            } face: {
                switch model.flash {
                case .off: KeyFace(symbol: "bolt.slash.fill")
                case .auto: KeyFace(symbol: "bolt.fill", caption: "AUTO")
                case .on: KeyFace(symbol: "bolt.fill", caption: "ON")
                }
            }
            PlateKey(plate: plate, region: Plate.flipKey, label: "切换前后镜头",
                     value: model.isFrontCamera ? "前置" : "后置",
                     lit: model.isFrontCamera, latched: model.isFrontCamera) {
                model.flipCamera()
            } face: {
                KeyFace(symbol: "arrow.triangle.2.circlepath.camera.fill",
                        caption: model.isFrontCamera ? "FRONT" : "REAR")
            }
            PlateKey(plate: plate, region: Plate.lensKey, label: "变焦", value: Plate.zoomText(model.zoom),
                     lit: false, latched: false) {
                model.toggleLens()
            } face: {
                KeyFace(text: Plate.zoomText(model.zoom))
            }
            PlateKey(plate: plate, region: Plate.formatKey, label: "画幅", value: model.isSquare ? "正方形" : "3 比 2",
                     lit: model.isSquare, latched: model.isSquare) {
                model.toggleFormat()
            } face: {
                KeyFace(symbol: model.isSquare ? "square" : "rectangle", caption: model.isSquare ? "1:1" : "3:2")
            }
            ForEach(Array(zip([Plate.flashKey, Plate.flipKey, Plate.lensKey, Plate.formatKey],
                              ["FLASH", "FLIP", "LENS", "FORMAT"])), id: \.1) { key, name in
                Text(name)
                    .font(.system(size: 13 * plate.scaleY, weight: .medium))
                    .kerning(1.2 * plate.scaleY)
                    .foregroundStyle(Color(red: 0.80, green: 0.78, blue: 0.72))
                    .fixedSize()
                    .position(x: plate.rect(key).midX, y: plate.rect(key).minY + Plate.keyNameY * plate.scaleY)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            // The film chamber, behind its door on the right of the body.
            FilmChamber().place(plate.rect(Plate.bay))

            // The chamber door: the right-hand part of the body, with the film
            // window and the shutter on it. Hinged along its right edge, it
            // swings towards you to show the film inside.
            ZStack(alignment: .topLeading) {
                Image(uiImage: Plate.image)
                    .resizable()
                    .interpolation(.high)
                    .place(plate.frame)
                    .allowsHitTesting(false)   // or it would cover the keys beside the door
                    .accessibilityHidden(true)
                LoadedRoll().place(plate.rect(Plate.filmWindow))
                LastFrame().place(plate.rect(Plate.lastFrame))
                ShutterKey(plate: plate)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(Path(plate.rect(Plate.bay)))
            .rotation3DEffect(.degrees(doorAngle), axis: (x: 0, y: 1, z: 0),
                              anchor: .trailing, perspective: 0.35)
            .animation(.easeInOut(duration: 0.4), value: model.isBayOpen)
            // Gone once it is edge-on, so its mirrored back never shows.
            .opacity(model.isBayOpen && frozenDoor == nil ? 0 : 1)
            .animation(.linear(duration: 0.1).delay(model.isBayOpen ? 0.3 : 0), value: model.isBayOpen)
            .allowsHitTesting(!model.isBayOpen)

            if !folded {
                // The swipe home starts from the interface's bottom edge:
                // whichever edge of the body the interface has down just now
                // (from the Lock Screen, always the body's right-hand side).
                // The system's own bar is absent or does not come back on a
                // touch, so this one stands in for it.
                let turn = posture.contentTurn
                ExitHint(wake: exitHintWake)
                    .rotationEffect(.degrees(turn == 90 || turn == 270 ? 90 : 0))
                    .position(turn == 90 ? CGPoint(x: size.width - 8, y: size.height / 2)
                              : turn == 180 ? CGPoint(x: size.width / 2, y: 8)
                              : turn == 270 ? CGPoint(x: 8, y: size.height / 2)
                              : CGPoint(x: size.width / 2, y: size.height - 8))
            }
        }
        .simultaneousGesture(
            // Any touch on the body brings the bar back for a moment.
            DragGesture(minimumDistance: 0).onChanged { _ in
                if Date().timeIntervalSince(exitHintWake) > 1 { exitHintWake = Date() }
            }
        )
        .coordinateSpace(name: Plate.space)
        .frame(width: size.width, height: size.height)
    }

    /// A fixed door angle for UI checks (`-door <degrees>`), debug builds only.
    var frozenDoor: Double? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "door").flatMap(Double.init)
        #else
        nil
        #endif
    }

    var doorAngle: Double { frozenDoor ?? (model.isBayOpen ? Plate.doorOpenAngle : 0) }

}

/// A stand-in for the home indicator: shows, then fades after a few seconds.
private struct ExitHint: View {
    /// Changes whenever the bar should show again.
    let wake: Date

    var body: some View {
        // Decided from the clock on every tick, not from a one-off timer, so
        // nothing that restarts the view can leave the bar up for good.
        TimelineView(.periodic(from: .now, by: 0.5)) { tick in
            Capsule()
                .fill(Color.white.opacity(0.75))
                .frame(width: 134, height: 5)
                .shadow(color: .black.opacity(0.6), radius: 2)
                .opacity(tick.date.timeIntervalSince(wake) < 4 ? 1 : 0)
                .animation(.easeOut(duration: 0.6), value: tick.date.timeIntervalSince(wake) < 4)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Folded layout

/// The two-half layout of a folding phone's inner screen.
enum FoldLayout {
    /// Which half carries the cameras when the layout is upright. Not known
    /// from any interface; set from the phone itself.
    static let camerasAbove = true

    /// The layout's place on the glass: how far, in degrees clockwise, its own
    /// upright frame is turned from the screen's fixed coordinate space. On an
    /// iPhone Duo that space is the inner screen upright, 669×951, the hinge
    /// across the middle: the layout's own shape, so this is 0 or 180. Its
    /// frame is the one the back camera's picture is upright in, with the half
    /// that carries the cameras above.
    static let turnOnGlass: Double = 0
    /// The closed body's place on the outer screen, in the same terms
    /// (measured: that screen's fixed space is upright, 466×678).
    static let bodyTurnOnGlass: Double = 90
}

/// The lower half: a waist-level finder, looked down into. A hood shades a
/// ground glass that carries the live view; a bright frame marks the picture.
/// Drawn in code until its rendered picture exists.
private struct WaistFinder: View {
    @EnvironmentObject private var model: CameraModel

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            // Clear of the hinge above and of the rounded screen edge below.
            let glassHeight = h * 0.84
            let glass = CGSize(width: glassHeight * (model.isSquare ? 1 : CameraModel.frameAspect), height: glassHeight)
            ZStack {
                // The hood: four walls sloping down to the glass.
                LinearGradient(colors: [Color(white: 0.10), Color(white: 0.03)], startPoint: .top, endPoint: .bottom)
                RoundedRectangle(cornerRadius: h * 0.05)
                    .fill(Color.black)
                    .frame(width: glass.width + h * 0.07, height: glass.height + h * 0.07)
                    .shadow(color: .black, radius: h * 0.03)

                PreviewView(store: model.frames, showsFullHeight: model.isSquare)
                    .overlay { if model.showsGrid { GridLines() } }
                    .overlay {
                        // A ground glass is brightest in the middle.
                        EllipticalGradient(colors: [.clear, .black.opacity(0.45)],
                                           center: .center, startRadiusFraction: 0.28, endRadiusFraction: 0.80)
                    }
                    .overlay { if model.isExposing { Color.black.opacity(0.85) } }
                    .frame(width: glass.width, height: glass.height)
                    .clipShape(RoundedRectangle(cornerRadius: h * 0.025))
                    .overlay {
                        RoundedRectangle(cornerRadius: h * 0.025)
                            .strokeBorder(Color(red: 1.0, green: 0.96, blue: 0.84).opacity(0.55),
                                          lineWidth: max(1, h * 0.004))
                    }
                    .animation(.easeOut(duration: 0.12), value: model.isExposing)
                    .contentShape(Rectangle())
                    .onTapGesture { model.showsGrid.toggle() }
            }
            .frame(width: geo.size.width, height: h)
            .animation(.easeInOut(duration: 0.25), value: model.isSquare)
        }
        .accessibilityLabel("取景器")
    }
}

// MARK: - Plate geometry

/// Maps rectangles measured on the plate picture (in its pixels) to the screen.
/// Screens close to the picture's 3:2 shape get it stretched edge to edge, which
/// keeps the eyepiece over the front camera; other shapes get it fitted whole.
private struct Plate {
    static let image = UIImage(named: "body_plate.jpg") ?? UIImage()

    /// A piece of the plate picture, so a key can move on its own.
    static func sprite(_ region: CGRect) -> UIImage {
        guard let whole = image.cgImage else { return UIImage() }
        let k = CGFloat(whole.width) / size.width
        let px = CGRect(x: region.minX * k, y: region.minY * k, width: region.width * k, height: region.height * k)
        return whole.cropping(to: px).map { UIImage(cgImage: $0) } ?? UIImage()
    }

    /// How far a key's well reaches beyond the key itself.
    static let keyWell = CGSize(width: 18, height: 14)
    private static let keySprites = [flashKey, flipKey, lensKey, formatKey].map {
        ($0, sprite($0.insetBy(dx: -keyWell.width, dy: -keyWell.height)))
    }
    static let shutterSprite = sprite(shutter)

    static func sprite(for key: CGRect) -> UIImage {
        keySprites.first { $0.0 == key }?.1 ?? sprite(key.insetBy(dx: -keyWell.width, dy: -keyWell.height))
    }

    static func zoomText(_ zoom: CGFloat) -> String {
        String(format: zoom == zoom.rounded() ? "%.0f×" : "%.1f×", zoom)
    }
    static let size = CGSize(width: 1536, height: 1024)
    /// Coordinate space of the laid-out body, whichever way the host turns it.
    static let space = "plate"
    /// Largest stretch that still reads as undistorted.
    static let maxStretch: CGFloat = 1.08

    // Regions, in plate pixels.
    /// The glass of the finder window, edge to edge.
    static let viewfinder = CGRect(x: 257, y: 304, width: 707, height: 472)
    static let viewfinderRadius: CGFloat = 22
    static let lcd = CGRect(x: 888, y: 137, width: 534, height: 62)
    static let slot = CGRect(x: 361, y: 183, width: 431, height: 31)
    /// Centre tick of the EV scale and the distance of one stop along it.
    static let scaleZero: CGFloat = 582
    static let scaleStop: CGFloat = 71
    static let sliderTouch = CGRect(x: 345, y: 95, width: 465, height: 140)
    static let filmWindow = CGRect(x: 1046, y: 290, width: 194, height: 424)
    static let lastFrame = CGRect(x: 1058, y: 768, width: 170, height: 134)
    static let flashKey = CGRect(x: 276, y: 818, width: 153, height: 88)
    static let flipKey = CGRect(x: 460, y: 818, width: 153, height: 88)
    static let lensKey = CGRect(x: 643, y: 818, width: 153, height: 88)
    static let formatKey = CGRect(x: 825, y: 818, width: 153, height: 88)
    /// Where a key's name is printed, measured down from the key's top.
    static let keyNameY: CGFloat = 95
    static let shutter = CGRect(x: 1307, y: 285, width: 194, height: 196)
    /// The red cap with a little slack around it; the ribbed grip below is not a button.
    static let shutterTouch = CGRect(x: 1287, y: 265, width: 234, height: 236)
    /// How far the back swings; just short of edge-on.
    static let doorOpenAngle: Double = 86

    /// The film chamber and its door: the right-hand part of the body, below the LCD.
    static let bay = CGRect(x: 1004, y: 222, width: 532, height: 802)
    /// The chamber picture, the size of `bay`. Drawn in code until it exists.
    static let bayImage = UIImage(named: "bay_plate.jpg")

    let frame: CGRect

    init(container: CGSize) {
        let sx = container.width / Self.size.width
        let sy = container.height / Self.size.height
        if max(sx, sy) / max(min(sx, sy), 0.0001) <= Self.maxStretch {
            frame = CGRect(origin: .zero, size: container)
        } else {
            let s = min(sx, sy)
            let fitted = CGSize(width: Self.size.width * s, height: Self.size.height * s)
            frame = CGRect(x: (container.width - fitted.width) / 2, y: (container.height - fitted.height) / 2,
                           width: fitted.width, height: fitted.height)
        }
    }

    var scaleX: CGFloat { frame.width / Self.size.width }
    var scaleY: CGFloat { frame.height / Self.size.height }

    func rect(_ r: CGRect) -> CGRect {
        CGRect(x: frame.minX + r.minX * scaleX, y: frame.minY + r.minY * scaleY,
               width: r.width * scaleX, height: r.height * scaleY)
    }

    func x(_ px: CGFloat) -> CGFloat { frame.minX + px * scaleX }
}

private extension View {
    /// Sizes and positions a view at a rectangle of the enclosing top-leading ZStack.
    func place(_ rect: CGRect) -> some View {
        frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
    }
}

// MARK: - Dynamic parts

private struct Viewfinder: View {
    @EnvironmentObject private var model: CameraModel
    /// With a separate finder in use, this window shows the last picture
    /// taken instead, once there is one: a look up from the finder checks the shot.
    var showsLastShot = false

    var body: some View {
        if showsLastShot, let shot = model.lastThumbnail {
            GeometryReader { geo in
                ZStack {
                    Color.black
                    Image(uiImage: shot).resizable().scaledToFit()
                }
                .clipShape(RoundedRectangle(cornerRadius: Plate.viewfinderRadius * geo.size.width / Plate.viewfinder.width))
            }
            .accessibilityLabel("上一张照片")
        } else {
            live
        }
    }

    private var live: some View {
        GeometryReader { geo in
            // The live view fills the whole window. The window is a little
            // taller than 3:2, so it shows a sliver more above and below than
            // the picture will hold; the grid marks the picture itself.
            PreviewView(store: model.frames, showsFullHeight: model.isSquare)
                .overlay {
                    // Square format, the way a rangefinder shows a frame: the
                    // scene stays visible, dimmed, outside a bright frame line.
                    ZStack {
                        Rectangle().fill(Color.black.opacity(0.62))
                            .mask {
                                Rectangle().overlay {
                                    RoundedRectangle(cornerRadius: geo.size.height * 0.02)
                                        .aspectRatio(1, contentMode: .fit)
                                        .blendMode(.destinationOut)
                                }
                                .compositingGroup()
                            }
                        RoundedRectangle(cornerRadius: geo.size.height * 0.02)
                            .strokeBorder(Color(red: 1.0, green: 0.96, blue: 0.84).opacity(0.9),
                                          lineWidth: max(1, geo.size.height * 0.006))
                            .aspectRatio(1, contentMode: .fit)
                            .shadow(color: .black.opacity(0.5), radius: 1)
                    }
                    .opacity(model.isSquare ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: model.isSquare)
                    .allowsHitTesting(false)
                }
                .overlay {
                    if model.showsGrid {
                        GridLines().aspectRatio(model.isSquare ? 1 : CameraModel.frameAspect, contentMode: .fit)
                    }
                }
                .overlay {
                    // Darkened edges, like looking into a real finder.
                    EllipticalGradient(colors: [.clear, .black.opacity(0.35)],
                                       center: .center, startRadiusFraction: 0.30, endRadiusFraction: 0.78)
                        .allowsHitTesting(false)
                }
                .overlay { if model.isExposing { Color.black.opacity(0.85) } }
                .clipShape(RoundedRectangle(cornerRadius: Plate.viewfinderRadius * geo.size.width / Plate.viewfinder.width))
                .frame(width: geo.size.width, height: geo.size.height)
                .animation(.easeOut(duration: 0.12), value: model.isExposing)
                .contentShape(Rectangle())
                .onTapGesture { model.showsGrid.toggle() }
        }
    }
}

private struct GridLines: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                for i in 1..<3 {
                    let x = geo.size.width * CGFloat(i) / 3
                    let y = geo.size.height * CGFloat(i) / 3
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
    }
}

/// Segment-style text on the grey-green LCD strip.
private struct LCDReadout: View {
    @EnvironmentObject private var model: CameraModel

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: geo.size.height * 0.32) {
                Text(model.film?.name.uppercased() ?? "NO FILM")
                    .layoutPriority(1)
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill").font(.system(size: geo.size.height * 0.36))
                    Text(model.flash.rawValue.uppercased())
                }
                Text(String(format: "%+.1f", model.exposureBias))
                Text(Plate.zoomText(model.zoom))
            }
            .font(.system(size: geo.size.height * 0.42, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(Color(red: 0.10, green: 0.13, blue: 0.09).opacity(0.88))
            .padding(.horizontal, geo.size.height * 0.28)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }
}

/// The yellow knob in the slot under the EV scale. Drag anywhere on the scale;
/// double-tap to return to zero.
private struct ExposureSlider: View {
    @EnvironmentObject private var model: CameraModel
    let plate: Plate

    var body: some View {
        let slot = plate.rect(Plate.slot)
        let touch = plate.rect(Plate.sliderTouch)
        let knobX = plate.x(Plate.scaleZero + CGFloat(model.exposureBias) * Plate.scaleStop)
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .place(touch)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(Plate.space))
                        .onChanged { value in
                            let ev = Double((value.location.x - plate.x(Plate.scaleZero)) / (Plate.scaleStop * plate.scaleX))
                            model.setExposureBias((ev * 3).rounded() / 3)   // 1/3-stop clicks
                        }
                )
                .simultaneousGesture(TapGesture(count: 2).onEnded { model.setExposureBias(0) })
                .accessibilityLabel("曝光补偿")
                .accessibilityValue(String(format: "%+.1f", model.exposureBias))

            Knob()
                .frame(width: slot.height * 1.5, height: slot.height * 1.25)
                .position(x: knobX, y: slot.midY)
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.08), value: model.exposureBias)
        }
    }

    private struct Knob: View {
        var body: some View {
            GeometryReader { geo in
                let r = geo.size.height * 0.22
                ZStack {
                    RoundedRectangle(cornerRadius: r)
                        .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.80, blue: 0.20),
                                                      Color(red: 0.86, green: 0.58, blue: 0.05)],
                                             startPoint: .top, endPoint: .bottom))
                    HStack(spacing: geo.size.width * 0.12) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule().fill(Color.black.opacity(0.35)).frame(width: geo.size.width * 0.08)
                        }
                    }
                    .padding(.vertical, geo.size.height * 0.2)
                    RoundedRectangle(cornerRadius: r).stroke(Color.black.opacity(0.6), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.7), radius: 1.5, y: 1)
            }
        }
    }
}

/// The roll seen through the film window. Tap to open the back.
private struct LoadedRoll: View {
    @EnvironmentObject private var model: CameraModel

    var body: some View {
        GeometryReader { geo in
            Button { model.toggleBay() } label: {
                ZStack {
                    Color.clear
                    if let film = model.film {
                        Canister(film: film)
                            .frame(width: geo.size.width * 0.80, height: geo.size.height * 0.74)
                            .overlay {
                                // The window's glass: the roll sits a little in the dark.
                                LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.45)],
                                               startPoint: .top, endPoint: .bottom)
                            }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("更换胶卷")
        }
    }
}

private struct LastFrame: View {
    @EnvironmentObject private var model: CameraModel

    var body: some View {
        GeometryReader { geo in
            if let thumb = model.lastThumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: geo.size.height * 0.12))
            }
        }
        .allowsHitTesting(false)
    }
}

/// A rubber key. Its top is cut out of the plate picture so that it can sink
/// into its well when pressed; what is printed on it is drawn here, and glows
/// while the key's function is on. A latched key stays down.
private struct PlateKey<Face: View>: View {
    let plate: Plate
    let region: CGRect
    let label: String
    let value: String
    let lit: Bool
    let latched: Bool
    let action: () -> Void
    @ViewBuilder let face: () -> Face
    @State private var pressed = false

    var body: some View {
        let rect = plate.rect(region)
        let down = pressed || latched
        // The key and the well around it, as one piece of the picture.
        let well = plate.rect(region.insetBy(dx: -Plate.keyWell.width, dy: -Plate.keyWell.height))
        let sink: CGFloat = pressed ? 0.93 : (latched ? 0.96 : 1)
        ZStack {
            // At rest the plate's own key shows, untouched. Held or latched, a
            // copy of it is drawn a little smaller and darker on top, its
            // edge faded out so that no outline has to match the picture's.
            Image(uiImage: Plate.sprite(for: region))
                .resizable()
                .interpolation(.high)
                .frame(width: well.width, height: well.height)
                .brightness(pressed ? -0.09 : -0.05)
                .scaleEffect(sink)
                .mask {
                    RoundedRectangle(cornerRadius: well.height * 0.42)
                        .padding(well.height * 0.07)
                        .blur(radius: well.height * 0.05)
                }
                .opacity(down ? 1 : 0)
                .allowsHitTesting(false)
            face()
                .foregroundStyle(lit ? Color(red: 1.0, green: 0.74, blue: 0.24)
                                     : Color(red: 0.86, green: 0.82, blue: 0.72))
                .shadow(color: lit ? Color(red: 1.0, green: 0.55, blue: 0.1).opacity(0.9) : .clear,
                        radius: rect.height * 0.12)
                .environment(\.keyHeight, rect.height)
                .scaleEffect(sink)
                .offset(y: down ? rect.height * 0.02 : 0)
        }
        .frame(width: rect.width, height: rect.height)
        .animation(.spring(response: 0.16, dampingFraction: 0.6), value: pressed)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: latched)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    pressed = true
                }
                .onEnded { _ in
                    pressed = false
                    action()
                }
        )
        .place(rect)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }
}

private struct KeyHeight: EnvironmentKey {
    static let defaultValue: CGFloat = 40
}

private extension EnvironmentValues {
    var keyHeight: CGFloat {
        get { self[KeyHeight.self] }
        set { self[KeyHeight.self] = newValue }
    }
}

/// What is printed on a key: a symbol with an optional word under it, or a word alone.
private struct KeyFace: View {
    var symbol: String?
    var text: String?
    var caption: String?
    @Environment(\.keyHeight) private var h

    var body: some View {
        VStack(spacing: h * 0.03) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: h * (caption == nil ? 0.46 : 0.36), weight: .bold))
            }
            if let text {
                Text(text).font(.system(size: h * 0.46, weight: .heavy, design: .rounded))
            }
            if let caption {
                Text(caption).font(.system(size: h * 0.17, weight: .heavy, design: .rounded)).kerning(h * 0.02)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// The shutter release: the red cap sinks into its well while it is held, and
/// the picture is taken as it comes back up.
private struct ShutterKey: View {
    @EnvironmentObject private var model: CameraModel
    let plate: Plate
    @State private var pressed = false

    var body: some View {
        let cap = plate.rect(Plate.shutter)
        ZStack(alignment: .topLeading) {
            ZStack {
                RoundedRectangle(cornerRadius: cap.width * 0.2).fill(Color.black)
                Image(uiImage: Plate.shutterSprite)
                    .resizable()
                    .interpolation(.high)
                    .clipShape(RoundedRectangle(cornerRadius: cap.width * 0.2))
                    .brightness(pressed ? -0.16 : 0)
                    .scaleEffect(pressed ? 0.88 : 1)
            }
            .place(cap)
            .animation(.spring(response: 0.18, dampingFraction: 0.5), value: pressed)
            Color.clear
                .contentShape(Rectangle())
                .place(plate.rect(Plate.shutterTouch))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !pressed { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                            pressed = true
                        }
                        .onEnded { _ in
                            pressed = false
                            model.shoot()
                        }
                )
                .accessibilityLabel("快门")
                .accessibilityAddTraits(.isButton)
        }
    }
}

// MARK: - Film chamber

/// Inside the chamber door. It opens on the loaded roll, its film drawn across
/// the gate to the take-up spool. Tap the roll and the film winds back in, then
/// every roll is offered; pick one and it drops in, the leader is drawn out and
/// the door shuts.
private struct FilmChamber: View {
    @EnvironmentObject private var model: CameraModel

    private enum Stage { case loaded, shelf }
    @State private var stage = Stage.loaded
    /// How much of the film is drawn out of the roll, 0...1.
    @State private var drawn: CGFloat = 1
    /// The roll's height above its cradle while it drops in, 0 once seated.
    @State private var lift: CGFloat = 0
    @State private var busy = false

    // Regions, in chamber pixels (532×802, the size of `Plate.bay`).
    private static let size = CGSize(width: 532, height: 802)
    private static let handle = CGRect(x: 0, y: 0, width: 54, height: 802)
    private static let spool = CGRect(x: 124, y: 44, width: 338, height: 116)
    private static let gate = CGRect(x: 166, y: 160, width: 254, height: 384)
    private static let cradle = CGRect(x: 76, y: 544, width: 434, height: 214)

    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / Self.size.width
            let sy = geo.size.height / Self.size.height
            let rect = { (r: CGRect) in
                CGRect(x: r.minX * sx, y: r.minY * sy, width: r.width * sx, height: r.height * sy)
            }
            ZStack(alignment: .topLeading) {
                if let picture = Plate.bayImage {
                    Image(uiImage: picture).resizable().interpolation(.high)
                } else {
                    DrawnChamber(spool: rect(Self.spool), gate: rect(Self.gate), cradle: rect(Self.cradle))
                }

                if stage == .loaded {
                    loadedRoll(spool: rect(Self.spool), gate: rect(Self.gate), cradle: rect(Self.cradle), unit: sy)
                        .transition(.opacity)
                } else {
                    shelf(unit: sy)
                        .padding(.leading, rect(Self.handle).width)
                        .transition(.opacity)
                }

                // The edge of the door frame: tap it to shut the door.
                Button { close() } label: {
                    ZStack {
                        LinearGradient(colors: [Color(white: 0.22), Color(white: 0.12)],
                                       startPoint: .leading, endPoint: .trailing)
                        Image(systemName: "chevron.compact.right")
                            .font(.system(size: 44 * sy, weight: .semibold))
                            .foregroundStyle(Color(white: 0.6))
                    }
                }
                .buttonStyle(.plain)
                .place(rect(Self.handle))
                .accessibilityLabel("关上胶卷仓")
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .onChange(of: model.isBayOpen) { _, open in
            if open { reset() }
        }
        .onAppear {
            #if DEBUG
            if UserDefaults.standard.string(forKey: "stage") == "shelf" { stage = .shelf; drawn = 0 }
            #endif
        }
    }

    // MARK: Loaded roll

    @ViewBuilder
    private func loadedRoll(spool: CGRect, gate: CGRect, cradle: CGRect, unit: CGFloat) -> some View {
        // Film wound on the take-up spool: there once the leader has reached it.
        RoundedRectangle(cornerRadius: spool.height * 0.2)
            .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.20, blue: 0.12),
                                          Color(red: 0.62, green: 0.38, blue: 0.22),
                                          Color(red: 0.30, green: 0.16, blue: 0.10)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: gate.width, height: spool.height * 0.86)
            .position(x: spool.midX, y: spool.midY)
            .opacity(drawn > 0.97 ? 1 : 0)
            .allowsHitTesting(false)

        // The film itself, drawn up out of the roll across the gate.
        FilmStrip()
            .frame(width: gate.width, height: gate.height + spool.height * 0.4)
            .mask(alignment: .bottom) {
                Rectangle().frame(height: (gate.height + spool.height * 0.4) * drawn)
            }
            .position(x: gate.midX, y: gate.midY - spool.height * 0.2)
            .allowsHitTesting(false)

        if let film = model.film {
            // The roll lies on its side in the cradle, its lip towards the gate.
            Button { rewind() } label: {
                Canister(film: film)
                    .frame(width: cradle.height, height: cradle.width)
                    .rotationEffect(.degrees(-90))
                    .frame(width: cradle.width, height: cradle.height)
                    .shadow(color: .black.opacity(0.8), radius: 5 * unit, y: 5 * unit)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .position(x: cradle.midX, y: cradle.midY - lift * cradle.minY)
            .opacity(Double(1 - lift))
            .accessibilityLabel("更换胶卷")
            .accessibilityValue(film.name)
        }
    }

    // MARK: Shelf

    private func shelf(unit: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text("胶卷")
                .font(.system(size: 30 * unit, weight: .semibold))
                .foregroundStyle(Color(white: 0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30 * unit)
                .padding(.top, 26 * unit)
                .padding(.bottom, 14 * unit)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10 * unit) {
                    ForEach(model.films) { film in
                        let loaded = film == model.film
                        Button { load(film) } label: {
                            HStack(spacing: 22 * unit) {
                                Canister(film: film)
                                    .frame(width: 96 * unit, height: 190 * unit)
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 190 * unit, height: 96 * unit)
                                VStack(alignment: .leading, spacing: 4 * unit) {
                                    Text(film.name)
                                        .font(.system(size: 30 * unit, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("ISO \(film.iso) · \(film.kind == "bw" ? "黑白" : "彩色")")
                                        .font(.system(size: 21 * unit, design: .monospaced))
                                        .foregroundStyle(loaded ? Color(red: 1.0, green: 0.62, blue: 0.15)
                                                                : Color(white: 0.55))
                                }
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 26 * unit)
                            .padding(.vertical, 12 * unit)
                            .background(loaded ? Color.white.opacity(0.08) : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(busy)
                        .accessibilityLabel(film.name)
                        .accessibilityAddTraits(loaded ? .isSelected : [])
                    }
                }
                .padding(.bottom, 40 * unit)
            }
        }
        .background(Color(white: 0.04))
    }

    // MARK: Steps

    private func reset() {
        stage = .loaded
        drawn = 1
        lift = 0
        busy = false
    }

    private func close() {
        model.isBayOpen = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Winds the film back into the roll, then offers every roll.
    private func rewind() {
        guard !busy else { return }
        busy = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeIn(duration: 0.45)) { drawn = 0 }
        after(0.5) {
            withAnimation(.easeOut(duration: 0.2)) { stage = .shelf }
            busy = false
        }
    }

    /// Drops the picked roll into the cradle, draws its leader out and shuts the door.
    private func load(_ film: Film) {
        guard !busy else { return }
        busy = true
        if film != model.film { model.load(film) }
        drawn = 0
        lift = 1
        withAnimation(.easeOut(duration: 0.15)) { stage = .loaded }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75).delay(0.1)) { lift = 0 }
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) { drawn = 1 }
        after(1.05) {
            busy = false
            model.isBayOpen = false
        }
    }

    private func after(_ seconds: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}

/// A length of colour negative: the orange base with a row of perforations down each side.
private struct FilmStrip: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let hole = CGSize(width: w * 0.075, height: w * 0.055)
            let pitch = w * 0.135
            ZStack {
                LinearGradient(colors: [Color(red: 0.33, green: 0.17, blue: 0.10),
                                        Color(red: 0.52, green: 0.29, blue: 0.17),
                                        Color(red: 0.33, green: 0.17, blue: 0.10)],
                               startPoint: .leading, endPoint: .trailing)
                Path { path in
                    var y = pitch / 2
                    while y < geo.size.height {
                        for x in [w * 0.075, w * 0.925] {
                            path.addRoundedRect(in: CGRect(x: x - hole.width / 2, y: y - hole.height / 2,
                                                           width: hole.width, height: hole.height),
                                                cornerSize: CGSize(width: 1.5, height: 1.5))
                        }
                        y += pitch
                    }
                }
                .fill(Color.black.opacity(0.85))
                // The sheen of the film base.
                LinearGradient(colors: [.clear, .white.opacity(0.10), .clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}

/// Stand-in for the chamber picture until the rendered one is in the bundle.
private struct DrawnChamber: View {
    let spool: CGRect
    let gate: CGRect
    let cradle: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(white: 0.09), Color(white: 0.04)], startPoint: .top, endPoint: .bottom)
            // Take-up spool.
            RoundedRectangle(cornerRadius: spool.height * 0.22)
                .fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.42), Color(white: 0.14)],
                                     startPoint: .top, endPoint: .bottom))
                .place(spool)
            // Film gate with its rails.
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black)
                .overlay { RoundedRectangle(cornerRadius: 3).stroke(Color(white: 0.3), lineWidth: 1.5) }
                .place(gate.insetBy(dx: gate.width * 0.10, dy: gate.height * 0.12))
            // Cradle for the roll.
            RoundedRectangle(cornerRadius: cradle.height * 0.2)
                .fill(LinearGradient(colors: [Color(white: 0.02), Color(white: 0.10)],
                                     startPoint: .top, endPoint: .bottom))
                .place(cradle.insetBy(dx: -6, dy: -6))
        }
    }
}
