import SwiftUI

/// The camera body. Landscape only: a metal top plate with the viewfinder on the
/// left two thirds, a leather grip on the right third that doubles as the film bay.
struct CameraScreen: View {
    @EnvironmentObject private var model: CameraModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                TopPlate()
                    .frame(width: geo.size.width * 0.70)
                Rectangle()
                    .fill(LinearGradient(colors: [.black, Color(white: 0.28), .black],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 5)
                ZStack {
                    Grip()
                    if model.isBayOpen {
                        FilmBay()
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .clipped()
            }
        }
        .background(Color.black)
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

// MARK: - Top plate

private struct TopPlate: View {
    @EnvironmentObject private var model: CameraModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                LCDPanel()
                    .frame(width: 168)
                KeyButton(symbol: flashSymbol, isLit: model.flash != .off) { model.cycleFlash() }
                KeyButton(symbol: "arrow.triangle.2.circlepath", isLit: false) { model.flipCamera() }
                KeyButton(symbol: "grid", isLit: model.showsGrid) { model.showsGrid.toggle() }
                ExposureWheel()
            }
            .frame(height: 40)

            Viewfinder()
        }
        .padding(.leading, 58)   // clear the Dynamic Island
        .padding(.trailing, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(
            LinearGradient(colors: [Color(white: 0.30), Color(white: 0.17), Color(white: 0.22)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private var flashSymbol: String {
        switch model.flash {
        case .off: return "bolt.slash.fill"
        case .auto: return "bolt.badge.automatic.fill"
        case .on: return "bolt.fill"
        }
    }
}

private struct LCDPanel: View {
    @EnvironmentObject private var model: CameraModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10))
            Text(model.flash.rawValue.uppercased())
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 0)
            Text(String(format: "%+.1f", model.exposureBias))
                .lineLimit(1)
                .fixedSize()
            VStack(alignment: .trailing, spacing: -2) {
                Text("ISO").font(.system(size: 7, weight: .bold, design: .monospaced))
                Text("\(model.film?.iso ?? 0)")
            }
        }
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .foregroundStyle(Color(red: 0.10, green: 0.14, blue: 0.10))
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(red: 0.72, green: 0.78, blue: 0.70),
                                              Color(red: 0.60, green: 0.67, blue: 0.59)],
                                     startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.7), lineWidth: 1.5))
    }
}

private struct KeyButton: View {
    let symbol: String
    let isLit: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Circle()
                    .fill(isLit ? Color(red: 1.0, green: 0.25, blue: 0.2) : Color(white: 0.35))
                    .frame(width: 4, height: 4)
                    .shadow(color: isLit ? .red : .clear, radius: 3)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(white: 0.88))
                    .frame(width: 32, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [Color(white: 0.34), Color(white: 0.12)],
                                                 startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
    }
}

/// Knurled wheel: drag sideways for exposure compensation, double-tap to reset.
private struct ExposureWheel: View {
    @EnvironmentObject private var model: CameraModel
    @State private var dragStart: Double?

    var body: some View {
        GeometryReader { geo in
            let offset = CGFloat(model.exposureBias) * 18
            Capsule()
                .fill(LinearGradient(colors: [Color(white: 0.06), Color(white: 0.20), Color(white: 0.06)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay {
                    // Knurling: more ridges than fit, clipped to the wheel, sliding with the value.
                    HStack(spacing: 3) {
                        ForEach(0..<80, id: \.self) { _ in
                            Rectangle()
                                .fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.45)],
                                                     startPoint: .top, endPoint: .bottom))
                                .frame(width: 2)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: offset.truncatingRemainder(dividingBy: 5))
                    .padding(.vertical, 6)
                }
                .clipShape(Capsule().inset(by: 3))
                .overlay {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white)
                        .frame(width: 3)
                        .padding(.vertical, 5)
                }
            .frame(width: geo.size.width, height: geo.size.height * 0.72)
            .position(x: geo.size.width / 2, y: geo.size.height * 0.58)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        let start = dragStart ?? model.exposureBias
                        dragStart = start
                        let ev = start + Double(value.translation.width) / 60
                        model.setExposureBias((ev * 3).rounded() / 3)   // 1/3-stop clicks
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .onTapGesture(count: 2) { model.setExposureBias(0) }
        }
    }
}

private struct Viewfinder: View {
    @EnvironmentObject private var model: CameraModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [Color(white: 0.42), Color(white: 0.26)],
                                     startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.8), lineWidth: 2)

            PreviewView(store: model.frames)
                .aspectRatio(CameraModel.frameAspect, contentMode: .fit)
                .overlay { if model.showsGrid { GridLines() } }
                .overlay(alignment: .top) { ExposureScale().padding(.top, 5) }
                .overlay {
                    // Darkened edges, like looking into a real finder.
                    RadialGradient(colors: [.clear, .black.opacity(0.35)],
                                   center: .center, startRadius: 120, endRadius: 330)
                        .allowsHitTesting(false)
                }
                .overlay {
                    if model.isDeveloping { Color.black.opacity(0.85) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 3))
                .padding(10)
                .animation(.easeOut(duration: 0.12), value: model.isDeveloping)
        }
        .overlay(alignment: .topLeading) { Screw().padding(5) }
        .overlay(alignment: .topTrailing) { Screw().padding(5) }
        .overlay(alignment: .bottomLeading) { Screw().padding(5) }
        .overlay(alignment: .bottomTrailing) { Screw().padding(5) }
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

private struct ExposureScale: View {
    @EnvironmentObject private var model: CameraModel

    var body: some View {
        ZStack {
            HStack(spacing: 7) {
                ForEach(-6...6, id: \.self) { tick in
                    Rectangle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 1, height: tick % 3 == 0 ? 8 : 4)
                }
            }
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 6))
                .foregroundStyle(.white)
                .offset(x: CGFloat(model.exposureBias) * 24, y: 9)
        }
        .shadow(color: .black, radius: 1)
        .allowsHitTesting(false)
    }
}

private struct Screw: View {
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(white: 0.45), Color(white: 0.08)],
                                 center: .topLeading, startRadius: 0, endRadius: 7))
            .frame(width: 7, height: 7)
    }
}

// MARK: - Grip

private struct Grip: View {
    @EnvironmentObject private var model: CameraModel

    var body: some View {
        VStack(spacing: 0) {
            // Last frame.
            Group {
                if let thumb = model.lastThumbnail {
                    Image(uiImage: thumb).resizable().scaledToFill()
                } else {
                    Color(white: 0.08)
                }
            }
            .frame(width: 56, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(white: 0.45), lineWidth: 2))
            .padding(.top, 22)

            Spacer(minLength: 8)
            ShutterButton { model.shoot() }
            Spacer(minLength: 8)

            // Film window: shows the loaded roll; tap to open the back.
            Button { model.toggleBay() } label: {
                VStack(spacing: 4) {
                    if let film = model.film {
                        Canister(film: film)
                            .frame(width: 34, height: 50)
                    }
                    Text(String(format: "%02d", model.frameCount))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.1))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.75)))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(white: 0.5), lineWidth: 2))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Leather())
    }
}

private struct ShutterButton: View {
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.05))
                .frame(width: 92, height: 92)
            Circle()
                .fill(AngularGradient(colors: [Color(white: 0.9), Color(white: 0.5), Color(white: 0.95),
                                               Color(white: 0.45), Color(white: 0.9)],
                                      center: .center))
                .frame(width: 70, height: 70)
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.25), Color(white: 0.75)],
                                     center: .center, startRadius: 2, endRadius: 22))
                .frame(width: 34, height: 34)
                .scaleEffect(pressed ? 0.88 : 1)
        }
        .scaleEffect(pressed ? 0.96 : 1)
        .animation(.easeOut(duration: 0.08), value: pressed)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in
                    pressed = false
                    action()
                }
        )
        .accessibilityLabel("快门")
    }
}

/// Pebbled black leatherette, drawn once.
private struct Leather: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.07)))
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat((seed >> 33) % 10_000) / 10_000
            }
            for _ in 0..<2600 {
                let rect = CGRect(x: next() * size.width, y: next() * size.height,
                                  width: 1.5 + next() * 2.5, height: 1.5 + next() * 2.5)
                let shade = 0.10 + next() * 0.12
                context.fill(Path(ellipseIn: rect), with: .color(Color(white: shade).opacity(0.55)))
            }
        }
        .drawingGroup()
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
        .background(
            LinearGradient(colors: [Color(white: 0.11), Color(white: 0.03)], startPoint: .top, endPoint: .bottom)
        )
    }
}

/// A 35mm cartridge drawn in code: spool caps, body, colour band, label.
struct Canister: View {
    let film: Film

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Spool nub on top.
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(white: 0.12))
                    .frame(width: w * 0.30, height: h * 0.10)
                    .position(x: w / 2, y: h * 0.05)
                // Body.
                RoundedRectangle(cornerRadius: w * 0.10)
                    .fill(film.bodyColor)
                    .frame(width: w, height: h * 0.86)
                    .position(x: w / 2, y: h * 0.55)
                // Colour band with the stock's short name.
                Rectangle()
                    .fill(film.bandColor)
                    .frame(width: w, height: h * 0.30)
                    .position(x: w / 2, y: h * 0.60)
                Text(film.label)
                    .font(.system(size: max(5, w * 0.24), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(width: w * 0.92)
                    .position(x: w / 2, y: h * 0.60)
                // Caps.
                Rectangle().fill(Color(white: 0.12)).frame(width: w, height: h * 0.07).position(x: w / 2, y: h * 0.155)
                Rectangle().fill(Color(white: 0.12)).frame(width: w, height: h * 0.07).position(x: w / 2, y: h * 0.945)
                // Cylinder shading.
                LinearGradient(colors: [.black.opacity(0.45), .white.opacity(0.22), .clear, .black.opacity(0.5)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: w, height: h * 0.86)
                    .position(x: w / 2, y: h * 0.55)
                    .clipShape(RoundedRectangle(cornerRadius: w * 0.10))
            }
        }
    }
}
