import SwiftUI

/// The camera body. The body itself is a rendered picture (`body_plate.jpg`,
/// 1536×1024) that fills the whole screen; everything that changes — the live
/// view, the LCD text, the exposure knob, the loaded roll, the last frame and
/// the pressed states — is drawn on top at coordinates measured on that picture.
struct CameraScreen: View {
    @EnvironmentObject private var model: CameraModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // The plate deliberately covers the full screen, safe area included: its
        // eyepiece is drawn where the front camera sits, so it has to line up with
        // the physical display rather than with the safe region.
        GeometryReader { geo in
            let plate = Plate(container: geo.size)
            ZStack(alignment: .topLeading) {
                Color.black
                Image(uiImage: Plate.image)
                    .resizable()
                    .interpolation(.high)
                    .place(plate.frame)
                    .accessibilityHidden(true)

                Viewfinder().place(plate.rect(Plate.viewfinder))
                Nameplate().place(plate.rect(Plate.nameplate))
                LCDReadout().place(plate.rect(Plate.lcd))
                ExposureSlider(plate: plate)
                LoadedRoll().place(plate.rect(Plate.filmWindow))
                LastFrame().place(plate.rect(Plate.lastFrame))

                PlateKey(shape: Capsule(), label: "闪光灯") { model.cycleFlash() }
                    .place(plate.rect(Plate.flashKey))
                PlateKey(shape: Capsule(), label: "切换前后镜头") { model.flipCamera() }
                    .place(plate.rect(Plate.flipKey))
                PlateKey(shape: Capsule(), label: "变焦") { model.toggleLens() }
                    .place(plate.rect(Plate.lensKey))
                ShutterKey(plate: plate)

                if model.isBayOpen {
                    FilmBay()
                        .padding(.trailing, geo.safeAreaInsets.trailing)
                        .place(plate.rect(Plate.bay))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: model.isBayOpen)
        .onAppear { model.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.start() } else if phase == .background { model.stop() }
        }
        .alert("提示", isPresented: Binding(get: { model.message != nil },
                                          set: { if !$0 { model.message = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(model.message ?? "")
        }
    }
}

// MARK: - Plate geometry

/// Maps rectangles measured on the plate picture (in its pixels) to the screen.
/// Screens close to the picture's 3:2 shape get it stretched edge to edge, which
/// keeps the eyepiece over the front camera; other shapes get it fitted whole.
private struct Plate {
    static let image = UIImage(named: "body_plate.jpg") ?? UIImage()
    static let size = CGSize(width: 1536, height: 1024)
    /// Largest stretch that still reads as undistorted.
    static let maxStretch: CGFloat = 1.08

    // Regions, in plate pixels.
    static let viewfinder = CGRect(x: 259, y: 306, width: 702, height: 467)
    static let viewfinderRadius: CGFloat = 22
    /// Larger than the blank plate in the picture, which it covers.
    static let nameplate = CGRect(x: 460, y: 34, width: 242, height: 54)
    static let lcd = CGRect(x: 888, y: 137, width: 534, height: 62)
    static let slot = CGRect(x: 361, y: 183, width: 431, height: 31)
    /// Centre tick of the EV scale and the distance of one stop along it.
    static let scaleZero: CGFloat = 582
    static let scaleStop: CGFloat = 71
    static let sliderTouch = CGRect(x: 345, y: 95, width: 465, height: 140)
    static let filmWindow = CGRect(x: 1046, y: 290, width: 194, height: 424)
    static let lastFrame = CGRect(x: 1058, y: 768, width: 170, height: 134)
    static let flashKey = CGRect(x: 333, y: 818, width: 153, height: 88)
    static let flipKey = CGRect(x: 538, y: 818, width: 153, height: 88)
    static let lensKey = CGRect(x: 745, y: 818, width: 153, height: 88)
    static let shutter = CGRect(x: 1307, y: 285, width: 194, height: 196)
    /// The shutter answers on the whole upper grip, not just the red cap.
    static let shutterTouch = CGRect(x: 1285, y: 262, width: 251, height: 440)
    static let bay = CGRect(x: 1010, y: 0, width: 526, height: 1024)

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

    var body: some View {
        GeometryReader { geo in
            PreviewView(store: model.frames)
                .overlay { if model.showsGrid { GridLines() } }
                .overlay {
                    // Darkened edges, like looking into a real finder.
                    EllipticalGradient(colors: [.clear, .black.opacity(0.35)],
                                       center: .center, startRadiusFraction: 0.30, endRadiusFraction: 0.78)
                        .allowsHitTesting(false)
                }
                .overlay { if model.isDeveloping { Color.black.opacity(0.85) } }
                .aspectRatio(CameraModel.frameAspect, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Plate.viewfinderRadius * geo.size.width / Plate.viewfinder.width))
                .frame(width: geo.size.width, height: geo.size.height)
                .animation(.easeOut(duration: 0.12), value: model.isDeveloping)
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

/// The brand plate above the EV scale: brushed metal with the name engraved.
private struct Nameplate: View {
    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let shape = RoundedRectangle(cornerRadius: h * 0.30)
            ZStack {
                shape.fill(LinearGradient(colors: [Color(white: 0.80), Color(white: 0.52), Color(white: 0.66),
                                                   Color(white: 0.40)],
                                          startPoint: .top, endPoint: .bottom))
                // Brushing: a soft band of light across the middle.
                shape.fill(LinearGradient(colors: [.clear, .white.opacity(0.28), .clear],
                                          startPoint: .leading, endPoint: .trailing))
                shape.strokeBorder(Color.black.opacity(0.75), lineWidth: max(1, h * 0.06))
                Text("PELI")
                    .font(.system(size: h * 0.60, weight: .black, design: .rounded))
                    .kerning(h * 0.20)
                    .foregroundStyle(Color(white: 0.10).opacity(0.9))
                    .shadow(color: .white.opacity(0.6), radius: 0, y: 0.6)
                    .padding(.leading, h * 0.20)   // balance the trailing kerning
            }
            .shadow(color: .black.opacity(0.6), radius: 1.5, y: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
                Text(model.zoom > 1 ? "2×" : "1×")
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
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
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

/// An invisible button over a key that is part of the plate picture; it only
/// draws the pressed state.
private struct PlateKey<S: Shape>: View {
    let shape: S
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { Color.clear.contentShape(Rectangle()) }
            .buttonStyle(PressedShade(shape: shape))
            .accessibilityLabel(label)
    }
}

private struct PressedShade<S: Shape>: ButtonStyle {
    let shape: S

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay { shape.fill(Color.black.opacity(configuration.isPressed ? 0.35 : 0)) }
            .animation(.easeOut(duration: 0.06), value: configuration.isPressed)
    }
}

private struct ShutterKey: View {
    @EnvironmentObject private var model: CameraModel
    let plate: Plate
    @State private var pressed = false

    var body: some View {
        let cap = plate.rect(Plate.shutter)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cap.width * 0.2)
                .fill(Color.black.opacity(pressed ? 0.3 : 0))
                .place(cap)
                .animation(.easeOut(duration: 0.06), value: pressed)
            Color.clear
                .contentShape(Rectangle())
                .place(plate.rect(Plate.shutterTouch))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in pressed = true }
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

// MARK: - Film bay

/// The opened back: every roll on a shelf. Tap one to load it.
private struct FilmBay: View {
    @EnvironmentObject private var model: CameraModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("胶卷")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.85))
                Spacer()
                Button { model.toggleBay() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(white: 0.85))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(model.films) { film in
                        Button {
                            model.load(film)
                            model.isBayOpen = false
                        } label: {
                            HStack(spacing: 12) {
                                Canister(film: film)
                                    .frame(width: 30, height: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(film.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("ISO \(film.iso) · \(film.kind == "bw" ? "黑白" : "彩色")")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(Color(white: 0.6))
                                }
                                Spacer(minLength: 0)
                                if film == model.film {
                                    Circle().fill(Color(red: 1.0, green: 0.55, blue: 0.1)).frame(width: 6, height: 6)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(film == model.film ? Color.white.opacity(0.08) : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(white: 0.11), Color(white: 0.03)],
                                   startPoint: .top, endPoint: .bottom))
    }
}
