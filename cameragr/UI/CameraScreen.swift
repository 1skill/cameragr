import CoreMotion
import AVKit
import SwiftUI
import CoreText

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
    @State private var innerHintWake = Date.distantPast
    /// When the closed body's way home last said so in words (the bar alone
    /// comes back on any touch).
    @State private var exitLabelWake = Date()

    /// Shows the way home on its own only where the system's bottom is not
    /// the bottom as seen (user 11/24: the bag held upright landscape needs
    /// no hint). The bag follows the interface unless held the other way up;
    /// the camera is fixed to the phone, so turned whenever the layout is.
    private func wakeInnerHintIfAskew() {
        DispatchQueue.main.async {
            let askew = posture.mode == .flat ? posture.heldFlipped : posture.contentTurn != 0
            if posture.isOpen, askew { innerHintWake = Date() }
        }
    }
    @State private var pressBegan = false
    @ObservedObject private var posture = Posture.shared

    var body: some View {
        // The plate deliberately covers the full screen, safe area included: its
        // eyepiece is drawn where the front camera sits, so it has to line up with
        // the physical display rather than with the safe region.
        GeometryReader { geo in
            let _ = Diag.note("layout \(geo.size) mode \(posture.mode.rawValue)")
            let _ = Posture.shared.noteWindow(geo.size)
            if posture.awaitingHinge {
                // Opened on the inner screen: black for the instant until the
                // hinge says flat or part way, rather than a flash of the camera.
                Color.black
            } else if posture.mode == .flat {
                // Open flat: the film library, one half the rolls, the other
                // the chosen roll's pictures. Fixed to the phone like the halves below.
                // Held like a book, the library follows the interface's own
                // orientation (it is not a camera: nothing ties it to the glass).
                #if DEBUG
                if Self.debugInner {
                    // `-inner 1`: the library at the Duo's real inner screen
                    // (951×669 pt, 55 pt corners), shrunk onto the simulator's
                    // screen, so corners and edges can be checked.
                    let inner = CGSize(width: 951, height: 669)
                    let k = min(geo.size.width / inner.height, geo.size.height / inner.width)
                    RollLibrary()
                        .environmentObject(model)
                        .frame(width: inner.width, height: inner.height)
                        .clipShape(RoundedRectangle(cornerRadius: 55, style: .continuous))
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(k)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .background(Color.white)
                        .ignoresSafeArea()
                } else {
                    RollLibrary()
                        .rotationEffect(.degrees(posture.heldFlipped ? 180 : 0))
                        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: posture.heldFlipped)
                        .ignoresSafeArea()
                        .environmentObject(model)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
                #else
                RollLibrary()
                    .rotationEffect(.degrees(posture.heldFlipped ? 180 : 0))
                    .animation(.spring(response: 0.5, dampingFraction: 0.86), value: posture.heldFlipped)
                    .ignoresSafeArea()
                    .environmentObject(model)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                #endif
            } else if posture.isOpen {
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
                        // The roll just loaded by turning the phone upright, said plainly.
                        .overlay(alignment: .center) { LoadedNotice(film: model.loadedNotice) }
                    }
                    .ignoresSafeArea()
                    .environmentObject(model)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
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
                        #if DEBUG
                        if let half = Self.debugHalf {
                            // `-half WxH`: the body as on one half of the open
                            // inner screen, shrunk to fit, for layout checks.
                            // With `-finder 1`, the waist-level finder half instead,
                            // its two corners away from the hinge rounded as on the phone.
                            Group {
                                if UserDefaults.standard.bool(forKey: "finder") {
                                    WaistFinder()
                                        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 55, bottomTrailingRadius: 55, style: .continuous))
                                        .background(Color.white)
                                } else {
                                    cameraBody(size: half, folded: true)
                                }
                            }
                                .frame(width: half.width, height: half.height)
                                .scaleEffect(min(canvas.size.width / half.width, canvas.size.height / half.height))
                                .frame(width: canvas.size.width, height: canvas.size.height)
                        } else {
                            cameraBody(size: canvas.size, folded: false)
                        }
                        #else
                        cameraBody(size: canvas.size, folded: false)
                        #endif
                    }
                    .ignoresSafeArea()
                    .environmentObject(model)
                }
            }
        }
        // Between the bag and the camera (turning the open phone): a soft
        // cross-fade rather than a cut (user 11/24).
        .animation(.easeInOut(duration: 0.35), value: posture.mode)
        // Open, the interface is held still while the phone turns (the
        // content keeps itself upright), so where the swipe home starts is
        // often not the edge that looks like the bottom (user 11/24). Said
        // plainly at that edge: on opening, on every change of hold, and when
        // a swipe from any other edge finds nothing to do.
        .overlay {
            if posture.isOpen, !posture.awaitingHinge {
                InnerExitHint(wake: innerHintWake, flat: posture.mode == .flat) {
                    innerHintWake = Date()
                }
            }
        }
        .onChange(of: posture.awaitingHinge) { _, waiting in if !waiting { wakeInnerHintIfAskew() } }
        .onChange(of: posture.mode) { _, _ in wakeInnerHintIfAskew() }
        .onChange(of: posture.heldFlipped) { _, _ in wakeInnerHintIfAskew() }
        .onChange(of: posture.contentTurn) { _, _ in wakeInnerHintIfAskew() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { wakeInnerHintIfAskew(); exitLabelWake = Date() }
        }
        .onChange(of: posture.mode) { _, mode in if mode == .closed { exitLabelWake = Date() } }
        .onChange(of: posture.lockScreenWantsBag) { _, wants in if wants { model.showBag(.films) } }
        .background(HingeReader().frame(width: 0, height: 0))
        .ignoresSafeArea()
        .statusBarHidden()
        // The phone's Camera Control button and the volume buttons release the shutter.
        .onCameraCaptureEvent { event in
            Diag.note("capture event \(event.phase)")
            // Only a press that began here releases the shutter. The press
            // that opened the camera from the Lock Screen ends here too, and
            // would otherwise take a picture (and blink the finder) at once.
            // Like the key on the body, it fires as it goes down.
            switch event.phase {
            case .began:
                pressBegan = true
                model.shoot()
            default: pressBegan = false
            }
        }
        // The capture-event modifier puts the screen inside a view of its own,
        // as large as the safe area only: touches beyond it (along the outer
        // screen's edges) never reached what lies there, such as the first row
        // of rolls in the bag. It must cover the whole screen too.
        .ignoresSafeArea()
        .onChange(of: scenePhase) { _, phase in Diag.note("scene \(phase)") }
        .sheet(item: $model.shareVideo, onDismiss: {
            // What was made only for sharing is gone once the sheet closes.
            let made = FileManager.default.temporaryDirectory
            for file in (try? FileManager.default.contentsOfDirectory(at: made, includingPropertiesForKeys: nil)) ?? []
            where file.lastPathComponent.hasPrefix("Koco-") && ["mp4", "jpg", "heic", "jpeg"].contains(file.pathExtension) {
                try? FileManager.default.removeItem(at: file)
            }
        }) { file in
            ActivitySheet(items: [file.url]).ignoresSafeArea()
        }
        // Shut all the way, and a moment to turn the phone over and look: then
        // a roll chosen in the library goes in.
        .onChange(of: posture.isShut) { _, shut in
            guard shut else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if Posture.shared.isShut { model.phoneShut() }
            }
        }
        .onChange(of: posture.mode) { old, mode in
            model.foldChanged(to: mode)
            // Turned from the bag to the camera: the chosen roll goes in now.
            if old == .flat, mode == .half, posture.hingeLevel { model.turnedToCamera() }
            // The camera rests while the library is up (no camera light while
            // only looking at rolls), and comes back for shooting.
            // The bag always stops it, whatever the scene's state: launched
            // straight into the bag, the change came before the app was active
            // and the camera ran on, so Camera Control still offered its
            // exposure slider over the bag (user 11/24).
            if mode == .flat { model.stop(); return }
            guard scenePhase == .active else { return }
            model.start()
        }
        .onChange(of: posture.awaitingHinge) { _, waiting in
            if !waiting, posture.mode != .flat, scenePhase == .active { model.start() }
        }
        .onChange(of: model.isExposing) { _, on in Diag.note("exposing \(on)") }
        .onAppear {
            // On the inner screen before the hold is known the mode is not
            // decided yet: the camera starts once it is (the change above).
            if posture.mode != .flat, !posture.awaitingHinge { model.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if posture.mode != .flat, !posture.awaitingHinge { model.start() }
                posture.askAgain()
            } else if phase == .background {
                model.stop()
            }
        }
        .alert("Notice", isPresented: Binding(get: { model.message != nil },
                                          set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.message ?? "")
        }
    }
}

#if DEBUG
extension CameraScreen {
    static let debugInner = UserDefaults.standard.bool(forKey: "inner")
    static let debugHalf: CGSize? = UserDefaults.standard.string(forKey: "half").flatMap { text in
        let parts = text.split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2, parts.allSatisfy({ $0.isFinite && $0 > 0 }) else { return nil }
        return CGSize(width: parts[0], height: parts[1])
    }
}
#endif

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

            // The body's window is live again after a look at the last picture
            // (user 11/24); the small window beside it keeps the last shot.
            Viewfinder(showsLastShot: false).place(plate.rect(Plate.viewfinder))
            if model.isShareTrayOpen && !folded {
                ShareTray().place(plate.rect(Plate.viewfinder))
                    .transition(.opacity)
            }
            LCDReadout().place(plate.rect(Plate.lcd))
            ExposureSlider(plate: plate)
                .allowsHitTesting(model.bag == nil)

            PlateKey(plate: plate, region: Plate.flashKey, label: "Flash", value: LocalizedStringKey(model.flash.title),
                     lit: model.flash != .off, latched: model.flash == .on) {
                model.cycleFlash()
            } face: {
                switch model.flash {
                case .off: KeyFace(symbol: "bolt.slash.fill")
                case .auto: KeyFace(symbol: "bolt.fill", caption: "AUTO")
                case .on: KeyFace(symbol: "bolt.fill", caption: "ON")
                }
            }
            PlateKey(plate: plate, region: Plate.flipKey, label: "Switch camera",
                     value: model.isFrontCamera ? "Front" : "Rear",
                     lit: model.isFrontCamera, latched: model.isFrontCamera) {
                model.flipCamera()
            } face: {
                KeyFace(symbol: "arrow.triangle.2.circlepath.camera.fill",
                        caption: model.isFrontCamera ? "FRONT" : "REAR")
            }
            PlateKey(plate: plate, region: Plate.lensKey, label: "Zoom", value: LocalizedStringKey(Plate.zoomText(model.zoom)),
                     lit: false, latched: false) {
                model.toggleLens()
            } face: {
                KeyFace(text: Plate.zoomText(model.zoom))
            }
            if model.isReviewing {
                // Looking at the last picture, the format key shares it: the
                // first press opens the share tray, the next sends.
                PlateKey(plate: plate, region: Plate.formatKey, label: "Share", value: LocalizedStringKey(model.shareKind.title),
                         lit: model.isShareTrayOpen || model.isMakingShare, latched: model.isMakingShare) {
                    model.pressShare()
                } face: {
                    KeyFace(symbol: model.isMakingShare ? "hourglass" : "square.and.arrow.up", caption: "SHARE")
                }
            } else {
                PlateKey(plate: plate, region: Plate.formatKey, label: "Format", value: model.isSquare ? "Square" : "3 to 2",
                         lit: model.isSquare, latched: model.isSquare) {
                    model.toggleFormat()
                } face: {
                    KeyFace(symbol: model.isSquare ? "square" : "rectangle", caption: model.isSquare ? "1:1" : "3:2")
                }
            }
            ForEach(Array(zip([Plate.flashKey, Plate.flipKey, Plate.lensKey, Plate.formatKey],
                              ["FLASH", "FLIP", "LENS", model.isReviewing ? "SHARE" : "FORMAT"])), id: \.0.minX) { key, name in
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
                    // The film window is a hole: the chamber shows through it.
                    .mask {
                        Path { path in
                            path.addRect(CGRect(origin: .zero, size: size))
                            path.addRoundedRect(in: plate.rect(Plate.filmWindow),
                                                cornerSize: CGSize(width: 16 * plate.scaleY, height: 16 * plate.scaleY))
                        }
                        .fill(style: FillStyle(eoFill: true))
                    }
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
            .allowsHitTesting(!model.isBayOpen && model.bag == nil)

            // The detail page or the settings, over the whole body.
            PanelHost().frame(width: size.width, height: size.height)

            // The camera bag, over the whole body, done up with its clasp.
            if let bag = model.bag {
                RollLibrary(start: bag, showsClasp: true)
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity)
                    .zIndex(100)   // over every part of the body, which has its own layers
            }

            if !folded {
                // The swipe home starts from the interface's bottom edge:
                // whichever edge of the body the interface has down just now
                // (from the Lock Screen, always the body's right-hand side).
                // The system's own bar is absent or does not come back on a
                // touch, so this one stands in for it.
                // Laid out upright in the interface's frame (bottom aligned),
                // then turned with it, so it reads as the system has it.
                let turn = posture.contentTurn
                let side = turn == 90 || turn == 270
                ExitHint(wake: exitHintWake, labelWake: exitLabelWake)
                    .frame(width: side ? size.height : size.width, height: side ? size.width : size.height,
                           alignment: .bottom)
                    .rotationEffect(.degrees(-turn))
                    .position(x: size.width / 2, y: size.height / 2)
                    .allowsHitTesting(false)
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
    /// Changes whenever the words above it should show again.
    var labelWake = Date.distantPast

    var body: some View {
        // Decided from the clock on every tick, not from a one-off timer, so
        // nothing that restarts the view can leave the bar up for good.
        TimelineView(.periodic(from: .now, by: 0.5)) { tick in
            let bar = tick.date.timeIntervalSince(wake) < 4
            let label = tick.date.timeIntervalSince(labelWake) < 4.5
            VStack(spacing: 8) {
                Label("Swipe up from this edge to leave", systemImage: "chevron.compact.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.72)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                    .opacity(label ? 1 : 0)
                    .animation(.easeOut(duration: 0.5), value: label)
                Capsule()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 134, height: 5)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .opacity(bar || label ? 1 : 0)
                    .animation(.easeOut(duration: 0.6), value: bar || label)
            }
            .padding(.bottom, 6)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The open phone's way home: a bright bar on the interface's bottom edge,
/// where the system's swipe home starts, with a word above it saying so.
/// Laid out in the interface's own frame (not the content's), so its bottom
/// is the system's bottom however the phone is held. Thin strips along the
/// other edges hear a swipe that tried to leave from there, and bring it back.
private struct InnerExitHint: View {
    let wake: Date
    /// The bag: its left and right edges turn the pages, so only the top
    /// edge listens there.
    let flat: Bool
    let tried: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.periodic(from: .now, by: 0.5)) { tick in
                    let on = tick.date.timeIntervalSince(wake) < 4.5
                    VStack(spacing: 8) {
                        Label("Swipe up from this edge to leave", systemImage: "chevron.compact.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Capsule().fill(Color.black.opacity(0.72)))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: 150, height: 6)
                            .shadow(color: .black.opacity(0.7), radius: 3)
                    }
                    .padding(.bottom, 10)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                    .opacity(on ? 1 : 0)
                    .offset(y: on ? 0 : 12)
                    .animation(.easeOut(duration: 0.5), value: on)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                // The edges that are not the way home.
                edge(.top, geo.size)
                if !flat {
                    edge(.leading, geo.size)
                    edge(.trailing, geo.size)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func edge(_ side: Edge, _ size: CGSize) -> some View {
        let across = side == .top
        return Color.clear
            .contentShape(Rectangle())
            .frame(width: across ? size.width : 18, height: across ? 18 : size.height)
            .gesture(DragGesture(minimumDistance: 12).onEnded { drag in
                let inward = side == .top ? drag.translation.height
                    : side == .leading ? drag.translation.width : -drag.translation.width
                if inward > 30 { tried() }
            })
            .frame(width: size.width, height: size.height,
                   alignment: side == .top ? .top : side == .leading ? .leading : .trailing)
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

/// The lower half: the waist-level finder deck, looked down into (GPT art,
/// `finder_deck.jpg`, from design/finder/finder_template.png). A big 3:2
/// window carries the live view; on the right, the shutter key (the body's
/// own red key) above and a bubble level below.
struct WaistFinder: View {
    @EnvironmentObject private var model: CameraModel

    /// The deck picture, and rectangles measured on it, in its pixels.
    static let art = CGSize(width: 1442, height: 1024)
    static let deck = UIImage(named: "finder_deck.jpg") ?? UIImage()
    static let window = CGRect(x: 55, y: 165, width: 1092, height: 718)
    /// The bubble level, low on the right (user: shutter above, level below).
    static let vial = CGRect(x: 1236, y: 800, width: 136, height: 44)
    /// The shutter key's well, high on the right under the thumb.
    static let key = CGRect(x: 1226, y: 186, width: 158, height: 158)

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / Self.art.width, geo.size.height / Self.art.height)
            let shift = CGSize(width: (geo.size.width - Self.art.width * s) / 2,
                               height: (geo.size.height - Self.art.height * s) / 2)
            let window = Self.window.scaled(s)
            // Exactly the picture's shape inside the window (the window itself
            // is a hair squarer than 3:2), the rest black.
            let glass = model.isSquare ? CGSize(width: window.height, height: window.height)
                : CGSize(width: min(window.width, window.height * CameraModel.frameAspect),
                         height: min(window.height, window.width / CameraModel.frameAspect))
            ZStack(alignment: .topLeading) {
                Image(uiImage: Self.deck).resizable()
                    .frame(width: Self.art.width * s, height: Self.art.height * s)
                PreviewView(store: model.frames, showsFullHeight: model.isSquare)
                    .overlay { if model.showsGrid { GridLines() } }
                    .overlay { ShutterBlades() }
                    .overlay { UsedUpNote() }
                    .frame(width: glass.width, height: glass.height)
                    .clipShape(RoundedRectangle(cornerRadius: 10 * s))
                    .frame(width: window.width, height: window.height)
                    .background(Color.black)
                    .contentShape(Rectangle())
                    .onTapGesture { model.toggleGrid() }
                    .offset(x: window.minX, y: window.minY)
                    .accessibilityLabel("Viewfinder")
                LevelBubble(vial: Self.vial.scaled(s))
                ShutterKeyButton(rect: Self.key.scaled(s))
            }
            .offset(shift)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background(Color.black)
            .animation(.easeInOut(duration: 0.25), value: model.isSquare)
        }
    }
}

/// The bubble in the deck's level vial: it shows how far the hinge, and with
/// it the picture's horizon, leans left or right. Only that one axis: the
/// fold's own angle and how far the phone is tipped toward the user don't move it.
private struct LevelBubble: View {
    let vial: CGRect
    static let picture = UIImage(named: "finder_bubble") ?? UIImage()
    @StateObject private var tilt = HingeTilt()

    var body: some View {
        let h = vial.height * 0.62
        let w = h * Self.picture.size.width / max(Self.picture.size.height, 1) * 0.55
        let travel = (vial.width - w) / 2
        // Roughly ±10° fills the vial, like a real one.
        let x = vial.midX - w / 2 + travel * CGFloat(max(-1, min(1, tilt.lean / 0.17)))
        Image(uiImage: Self.picture).resizable()
            .frame(width: w, height: h)
            .offset(x: x, y: vial.midY - h / 2)
            .animation(.interpolatingSpring(stiffness: 120, damping: 14), value: tilt.lean)
            .allowsHitTesting(false)
            .onAppear { tilt.start() }
            .onDisappear { tilt.stop() }
            .accessibilityHidden(true)
    }
}

/// How far the hinge leans from level, in radians (the gravity along the hinge).
@MainActor
final class HingeTilt: ObservableObject {
    @Published var lean: Double = 0
    private let motion = CMMotionManager()

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let g = data?.gravity else { return }
            // The fold runs along the phone's long side (its y axis).
            let lean = asin(max(-1, min(1, g.y)))
            Task { @MainActor in
                guard let self, abs(lean - self.lean) > 0.004 else { return }
                self.lean = lean
            }
        }
    }

    func stop() { motion.stopDeviceMotionUpdates() }
}

/// The red shutter key on the finder deck (GPT, finder_shutter.png, the
/// body's own key). Pressed, it sinks into its well and the picture is taken
/// at once; held, pictures go on being taken one after another.
private struct ShutterKeyButton: View {
    @EnvironmentObject private var model: CameraModel
    @Environment(\.scenePhase) private var scenePhase
    let rect: CGRect
    static let picture = UIImage(named: "finder_shutter") ?? UIImage()
    @State private var pressed = false
    @State private var burst: Task<Void, Never>?
    @State private var wentDown = Date.distantPast

    var body: some View {
        Image(uiImage: Self.picture).resizable()
            .frame(width: rect.width, height: rect.height)
            .scaleEffect(pressed ? 0.93 : 1)
            .brightness(pressed ? -0.1 : 0)
            .shadow(color: .black.opacity(0.6), radius: rect.width * (pressed ? 0.02 : 0.05), y: rect.width * (pressed ? 0.01 : 0.03))
            .animation(pressed ? .easeIn(duration: 0.05) : .easeOut(duration: 0.14), value: pressed)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in down() }
                .onEnded { _ in up() })
            .offset(x: rect.minX, y: rect.minY)
            .accessibilityLabel("Shutter")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.shoot() }
            // A held key never goes on shooting once the finder is gone
            // (folded or opened flat) or the app leaves the screen.
            .onDisappear(perform: stop)
            .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
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
                model.shoot(fast: true)
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
    /// The shutter key held down, with the well around it (shutter_down.jpg).
    static let shutterDown = UIImage(named: "shutter_down.jpg")
    /// The glass of the two door windows, cut from the plate: reflections on black.
    static let filmGlass = UIImage(named: "glass_film.png")
    static let lastGlass: UIImage? = nil
    static let shutterDownRegion = CGRect(x: 1293, y: 271, width: 222, height: 224)

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
    /// The LCD glass, measured on the body picture.
    static let lcd = CGRect(x: 880, y: 131, width: 542, height: 69)
    static let slot = CGRect(x: 361, y: 183, width: 431, height: 31)
    /// Centre tick of the EV scale and the distance of one stop along it.
    static let scaleZero: CGFloat = 582
    static let scaleStop: CGFloat = 71
    static let sliderTouch = CGRect(x: 345, y: 95, width: 465, height: 140)
    static let filmWindow = CGRect(x: 1149, y: 819, width: 305, height: 95)
    static let lastFrame = CGRect(x: 1040, y: 299, width: 202, height: 158)
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
    /// The left end wall of the cassette well, cut from the chamber picture
    /// (transparent elsewhere, the size of `bay`): drawn over the roll, so its
    /// spool hub goes into the wall's socket, onto the fork.
    static let bayWallImage = UIImage(named: "bay_wall_front.png")

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
        if showsLastShot || model.isReviewing, let shot = model.lastThumbnail {
            GeometryReader { geo in
                ZStack {
                    Color.black
                    Image(uiImage: shot).resizable().scaledToFit()
                }
                .clipShape(RoundedRectangle(cornerRadius: Plate.viewfinderRadius * geo.size.width / Plate.viewfinder.width))
                .contentShape(Rectangle())
                // Reviewing: a tap goes back to the scene.
                .onTapGesture { if model.isReviewing { model.toggleReview() } }
            }
            .accessibilityLabel("Last picture")
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
                .overlay(alignment: .bottom) { UsedUpNote() }
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
                .overlay { ShutterBlades() }
                .clipShape(RoundedRectangle(cornerRadius: Plate.viewfinderRadius * geo.size.width / Plate.viewfinder.width))
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .onTapGesture { model.toggleGrid() }
        }
    }
}

/// The shutter, seen in the finder as in a real SLR's: the mirror flips up
/// and the finder goes black for an instant, then the view comes back. Makers
/// give 55–115 ms for that blackout (Canon 7D 55 ms, Nikon D3 74 ms, D300
/// 86–90 ms, Canon 20D 115 ms); this one is about 100 ms, and it stays dark
/// for as long as a longer exposure lasts.
private struct ShutterBlades: View {
    @EnvironmentObject private var model: CameraModel
    @State private var shut = false
    /// A fixed blackout for UI checks (`-iris <0…1>`, 1 clear, 0 black), debug builds only.
    private static let frozen: CGFloat? = {
        #if DEBUG
        UserDefaults.standard.string(forKey: "iris").flatMap(Double.init).map { CGFloat($0) }
        #else
        nil
        #endif
    }()
    /// How long the finder is held black after the mirror is up.
    private static let hold: Double = 0.07

    var body: some View {
        let closed = shut || model.isExposing
        let open: CGFloat = Self.frozen ?? (closed ? 0 : 1)
        Color.black
            .opacity(Double(1 - open))
            // The mirror snaps up in a few milliseconds and settles back a
            // little slower.
            .animation(closed ? .easeIn(duration: 0.015) : .easeOut(duration: 0.03), value: closed)
            .allowsHitTesting(false)
            .onChange(of: model.releases) { _, _ in
                shut = true
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.hold) { shut = false }
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

/// The grey-green LCD strip, drawn like the panels on 1990s cameras: the
/// figures in segment type (DSEG, SIL OFL), every unlit segment faintly
/// there, each lit one throwing a soft shadow onto the reflector behind the
/// glass, and the fixed legends (the EV scale, the flash mark) printed into
/// the panel and only darkened when in use.
private struct LCDReadout: View {
    @EnvironmentObject private var model: CameraModel

    static let ink = Color(red: 0.07, green: 0.09, blue: 0.07)
    /// The bundled segment faces, registered once for this process.
    static let fonts: Bool = {
        for name in ["DSEG7Classic-Italic", "DSEG14Classic-Italic"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        return true
    }()

    var body: some View {
        _ = Self.fonts
        return GeometryReader { geo in
            let h = geo.size.height
            HStack(alignment: .center, spacing: h * 0.20) {
                // The film by its short code, or what the finder is showing.
                // ("!" is DSEG's blank the width of a character; a space is narrower.)
                Segments(text: (model.isReviewing ? "PLAY" : model.usedUp != nil ? "END" : (model.film.map { $0.lcd ?? $0.name } ?? "----"))
                            .uppercased().replacingOccurrences(of: " ", with: "!"),
                         ghost: "~~~~~", face: "DSEG14Classic-Italic", size: h * 0.44, h: h)
                // Which camera, and the frame's shape.
                VStack(alignment: .leading, spacing: h * 0.08) {
                    Segments(text: model.isFrontCamera ? "SELF" : "REAR", ghost: "~~~~",
                             face: "DSEG14Classic-Italic", size: h * 0.19, h: h)
                    Segments(text: model.isSquare ? "1:1" : "3:2", ghost: "~:~",
                             face: "DSEG14Classic-Italic", size: h * 0.19, h: h)
                }
                Spacer(minLength: 0)
                EVScale(bias: model.exposureBias, h: h)
                Spacer(minLength: 0)
                Lit(on: model.showsGrid, h: h) { GridMark() }
                    .frame(width: h * 0.30, height: h * 0.30)
                FlashMark(mode: model.flash, h: h)
                HStack(alignment: .lastTextBaseline, spacing: h * 0.03) {
                    Segments(text: String(format: "%.1f", model.zoom), ghost: "8.8",
                             face: "DSEG7Classic-Italic", size: h * 0.34, h: h)
                    Segments(text: "X", ghost: "X", face: "DSEG14Classic-Italic", size: h * 0.18, h: h)
                }
            }
            .padding(.horizontal, h * 0.26)
            .frame(width: geo.size.width, height: h)
        }
        .allowsHitTesting(false)
    }

    /// Lit segments over their own faint ghost, with the shadow they cast.
    struct Segments: View {
        let text: String
        let ghost: String
        let face: String
        let size: CGFloat
        let h: CGFloat

        var body: some View {
            let font = Font.custom(face, fixedSize: size)
            ZStack(alignment: .leading) {
                Text(ghost).font(font).foregroundStyle(LCDReadout.ink.opacity(0.06))
                Text(text).font(font).foregroundStyle(Color.black.opacity(0.22))
                    .offset(x: h * 0.035, y: h * 0.05).blur(radius: h * 0.012)
                Text(text).font(font).foregroundStyle(LCDReadout.ink.opacity(0.86))
            }
            .lineLimit(1)
            .fixedSize()
        }
    }

    /// The printed −2·1·0·1·2+ scale, a pointer segment under each third of a
    /// stop, the one at the current setting dark.
    struct EVScale: View {
        let bias: Double
        let h: CGFloat

        var body: some View {
            let step = h * 0.14
            let width = step * 12
            let lit = Int((bias * 3).rounded()) + 6
            VStack(spacing: h * 0.07) {
                ZStack {
                    ForEach(0..<13, id: \.self) { i in
                        let x = CGFloat(i) * step - width / 2
                        if i % 3 == 0 {
                            Segments(text: "\(abs(i / 3 - 2))", ghost: "\(abs(i / 3 - 2))",
                                     face: "DSEG7Classic-Italic", size: h * 0.22, h: h)
                                .offset(x: x)
                        } else {
                            Rectangle().fill(LCDReadout.ink.opacity(0.75))
                                .frame(width: h * 0.04, height: h * 0.04)
                                .offset(x: x, y: h * 0.07)
                        }
                    }
                    Segments(text: "-", ghost: "-", face: "DSEG14Classic-Italic", size: h * 0.18, h: h)
                        .offset(x: -width / 2 - step * 0.85)
                    Segments(text: "+", ghost: "+", face: "DSEG14Classic-Italic", size: h * 0.18, h: h)
                        .offset(x: width / 2 + step * 0.85)
                }
                ZStack {
                    ForEach(0..<13, id: \.self) { i in
                        let on = i == lit
                        Rectangle()
                            .fill(LCDReadout.ink.opacity(on ? 0.86 : 0.06))
                            .frame(width: h * 0.09, height: h * (i == 6 ? 0.20 : 0.14))
                            .background(alignment: .topLeading) {
                                if on {
                                    Rectangle().fill(Color.black.opacity(0.22))
                                        .offset(x: h * 0.035, y: h * 0.05).blur(radius: h * 0.012)
                                }
                            }
                            .offset(x: CGFloat(i) * step - width / 2)
                    }
                }
                .frame(height: h * 0.20)
            }
            .frame(width: width + step * 2.4)
        }
    }

    /// The printed flash marks, as on such panels: the bolt, a small A beside
    /// it for auto, a barred circle over it when the flash is off.
    struct FlashMark: View {
        let mode: CameraModel.Flash
        let h: CGFloat

        var body: some View {
            HStack(alignment: .bottom, spacing: h * 0.02) {
                ZStack {
                    Lit(on: true, h: h) { Bolt() }
                        .frame(width: h * 0.20, height: h * 0.36)
                    Lit(on: mode == .off, h: h) { NoMark() }
                        .frame(width: h * 0.44, height: h * 0.44)
                }
                .frame(width: h * 0.44, height: h * 0.44)
                Segments(text: mode == .auto ? "A" : "!", ghost: "A",
                         face: "DSEG14Classic-Italic", size: h * 0.20, h: h)
            }
        }
    }

    /// A printed mark: faint always, dark with its shadow when lit.
    struct Lit<S: Shape>: View {
        let on: Bool
        let h: CGFloat
        @ViewBuilder let shape: () -> S

        var body: some View {
            ZStack {
                shape().fill(LCDReadout.ink.opacity(0.06))
                if on {
                    shape().fill(Color.black.opacity(0.22))
                        .offset(x: h * 0.035, y: h * 0.05).blur(radius: h * 0.012)
                    shape().fill(LCDReadout.ink.opacity(0.86))
                }
            }
        }
    }

    /// The finder grid mark: a square in thirds.
    struct GridMark: Shape {
        func path(in r: CGRect) -> Path {
            let w = r.width * 0.10
            let style = StrokeStyle(lineWidth: w)
            var p = Path(r.insetBy(dx: w / 2, dy: w / 2))
            for i in 1...2 {
                let f = CGFloat(i) / 3
                p.move(to: CGPoint(x: r.minX + r.width * f, y: r.minY))
                p.addLine(to: CGPoint(x: r.minX + r.width * f, y: r.maxY))
                p.move(to: CGPoint(x: r.minX, y: r.minY + r.height * f))
                p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * f))
            }
            return p.strokedPath(style)
        }
    }

    /// A circle with a bar across it, the "off" mark.
    struct NoMark: Shape {
        func path(in r: CGRect) -> Path {
            let w = r.width * 0.11
            let style = StrokeStyle(lineWidth: w)
            var mark = Path(ellipseIn: r.insetBy(dx: w / 2, dy: w / 2)).strokedPath(style)
            let d = (r.width / 2 - w / 2) * 0.7071
            var bar = Path()
            bar.move(to: CGPoint(x: r.midX - d, y: r.midY - d))
            bar.addLine(to: CGPoint(x: r.midX + d, y: r.midY + d))
            mark.addPath(bar.strokedPath(style))
            return mark
        }
    }

    /// The flash mark as printed on such panels: a slanted zigzag bolt.
    struct Bolt: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            let w = r.width, h = r.height
            p.move(to: CGPoint(x: r.minX + w * 0.62, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX + w * 0.05, y: r.minY + h * 0.58))
            p.addLine(to: CGPoint(x: r.minX + w * 0.45, y: r.minY + h * 0.58))
            p.addLine(to: CGPoint(x: r.minX + w * 0.30, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + w * 0.95, y: r.minY + h * 0.40))
            p.addLine(to: CGPoint(x: r.minX + w * 0.55, y: r.minY + h * 0.40))
            p.closeSubpath()
            return p
        }
    }
}

/// The thumb in the slot under the EV scale. Drag anywhere on the scale;
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
                .accessibilityLabel("Exposure compensation")
                .accessibilityValue(String(format: "%+.1f", model.exposureBias))

            // The slide's thumb (GPT, ev_knob.png): body-black ribbed plastic,
            // a little narrower than one half-stop step so its white line
            // points at one tick, standing proud of the slot above and below.
            Image(uiImage: Self.thumb).resizable()
                .interpolation(.high)
                // The slot as drawn is about 57 px deep (Plate.slot is its groove).
                .frame(width: slot.height * 2.0 * Self.thumb.size.width / max(Self.thumb.size.height, 1),
                       height: slot.height * 2.0)
                .shadow(color: .black.opacity(0.55), radius: slot.height * 0.08, y: slot.height * 0.06)
                .position(x: knobX, y: slot.midY + slot.height * 0.18)
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.08), value: model.exposureBias)
        }
    }

    static let thumb = UIImage(named: "ev_knob") ?? UIImage()
}

/// The film window in the door: a hole onto the roll lying in its cradle
/// behind it. What shows is the chamber itself, in its own place and size.
private struct LoadedRoll: View {
    @EnvironmentObject private var model: CameraModel

    var body: some View {
        GeometryReader { geo in
            let sy = geo.size.height / Plate.filmWindow.height
            Button { model.toggleBay() } label: {
                // The window is a hole in the door with a pane in it: what shows
                // through is the chamber itself, under the door (see the mask on
                // the door), so nothing of the roll is painted on the door and
                // moves with it as it swings.
                ZStack(alignment: .topLeading) {
                    // Seen through the door: the roll lies below the surface, in
                    // the shade of the opening's edge, behind a pane of glass.
                    Color.black.opacity(0.22)
                    RoundedRectangle(cornerRadius: 16 * sy)
                        .stroke(Color.black.opacity(0.95), lineWidth: 16 * sy)
                        .blur(radius: 7 * sy)
                        .offset(y: 5 * sy)      // the top edge throws the deeper shadow
                    // The ends of the opening are deep in shade: nothing of the
                    // roll shows a hard line right at the frame.
                    LinearGradient(stops: [.init(color: .black, location: 0),
                                           .init(color: .black.opacity(0.85), location: 0.035),
                                           .init(color: .clear, location: 0.10),
                                           .init(color: .clear, location: 0.92),
                                           .init(color: .black.opacity(0.8), location: 0.98),
                                           .init(color: .black, location: 1)],
                                   startPoint: .leading, endPoint: .trailing)
                    // The pane's own reflections, from the plate picture: black
                    // there is clear glass, so only the light is laid over the roll.
                    if let glass = Plate.filmGlass {
                        Image(uiImage: glass).resizable().interpolation(.high)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .blendMode(.screen)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 16 * sy))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change film")
        }
    }
}

/// The last picture, in its window on the door. A new one drops in from the
/// top. Tap it to look at the picture in the finder; tap again to go back.
private struct LastFrame: View {
    @EnvironmentObject private var model: CameraModel

    var body: some View {
        GeometryReader { geo in
            Button { model.toggleReview() } label: {
                ZStack {
                    Color.clear
                    if let thumb = model.lastThumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .id(model.frameCount)
                            .transition(.asymmetric(insertion: .move(edge: .top), removal: .identity))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipShape(RoundedRectangle(cornerRadius: geo.size.height * 0.08))
                .overlay {
                    if let glass = Plate.lastGlass, model.lastThumbnail != nil {
                        Image(uiImage: glass).resizable().interpolation(.high).blendMode(.screen)
                            .clipShape(RoundedRectangle(cornerRadius: geo.size.height * 0.08))
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    // Lit while the finder is showing this picture.
                    RoundedRectangle(cornerRadius: geo.size.height * 0.08)
                        .strokeBorder(Color(red: 1.0, green: 0.74, blue: 0.24), lineWidth: max(2, geo.size.height * 0.04))
                        .opacity(model.isReviewing ? 1 : 0)
                }
                .animation(.easeOut(duration: 0.35), value: model.frameCount)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.lastThumbnail == nil)
            .accessibilityLabel("Show the last picture")
        }
    }
}

/// A rubber key. Its top is cut out of the plate picture so that it can sink
/// into its well when pressed; what is printed on it is drawn here, and glows
/// while the key's function is on. A latched key stays down.
private struct PlateKey<Face: View>: View {
    let plate: Plate
    let region: CGRect
    let label: LocalizedStringKey
    let value: LocalizedStringKey
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
                    if !pressed { Haptic.tap() }
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

/// A key on the control column beside the open chamber, in the manner of the
/// keys under the finder: a face on the key, its name printed below, the
/// face sinking and the key darkening while pressed. The target reaches
/// past the key, which is small on the outer screen.
private struct ChamberKey: View {
    let key: CGRect
    let symbol: String
    let name: String
    let label: LocalizedStringKey
    let sx: CGFloat
    let sy: CGFloat
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        let rect = CGRect(x: key.minX * sx, y: key.minY * sy, width: key.width * sx, height: key.height * sy)
        ZStack {
            RoundedRectangle(cornerRadius: rect.height * 0.32)
                .fill(Color.black.opacity(pressed ? 0.35 : 0))
                .frame(width: rect.width, height: rect.height)
            Image(systemName: symbol)
                .font(.system(size: rect.height * 0.42, weight: .bold))
                .foregroundStyle(Color(red: 0.86, green: 0.82, blue: 0.72))
                .scaleEffect(pressed ? 0.93 : 1)
                .offset(y: pressed ? rect.height * 0.02 : 0)
            Text(verbatim: name)
                .font(.system(size: 13 * sy, weight: .medium))
                .kerning(1.2 * sy)
                .foregroundStyle(Color(red: 0.80, green: 0.78, blue: 0.72))
                .fixedSize()
                .offset(y: rect.height * 0.5 + 16 * sy)
        }
        .frame(width: rect.width, height: rect.height)
        .animation(.spring(response: 0.16, dampingFraction: 0.6), value: pressed)
        // A target bigger than the key: around it and down over its name.
        .padding(.top, 12 * sy)
        .frame(width: rect.width + 24 * sx, height: rect.height + 70 * sy, alignment: .top)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed { Haptic.tap() }
                    pressed = true
                }
                .onEnded { _ in
                    pressed = false
                    action()
                }
        )
        .position(x: rect.midX, y: rect.minY - 12 * sy + (rect.height + 70 * sy) / 2)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }
}

/// The shutter release. The picture is taken the moment the cap goes down;
/// held down, it goes on taking pictures one after another until let go.
private struct ShutterKey: View {
    @EnvironmentObject private var model: CameraModel
    let plate: Plate
    @State private var pressed = false
    /// Takes the further pictures while the key stays held.
    @State private var burst: Task<Void, Never>?
    @State private var wentDown = Date.distantPast

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
        // Stays down a moment, so that even a quick tap is seen.
        let shown = Date().timeIntervalSince(wentDown)
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, 0.14 - shown)) {
            if burst == nil { pressed = false }
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Pressed, the picture of the key at the bottom of its well takes
            // the place of the plate's own: the cap keeps its size and sinks
            // into shadow, as a real key does.
            if let down = Plate.shutterDown {
                let region = plate.rect(Plate.shutterDownRegion)
                Image(uiImage: down)
                    .resizable()
                    .interpolation(.high)
                    // Only the key and its well: the edge fades out, so the
                    // body around it stays the plate's own.
                    .mask {
                        RoundedRectangle(cornerRadius: region.width * 0.24)
                            .padding(region.width * 0.035)
                            .blur(radius: region.width * 0.015)
                    }
                    .place(region)
                    .opacity(pressed ? 1 : 0)
                    .animation(pressed ? .easeIn(duration: 0.05) : .easeOut(duration: 0.14), value: pressed)
                    .allowsHitTesting(false)
            }
            Color.clear
                .contentShape(Rectangle())
                .place(plate.rect(Plate.shutterTouch))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in down() }
                        .onEnded { _ in up() }
                )
                .accessibilityLabel("Shutter")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { model.shoot() }
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
    /// What is bought: the shelf marks films not bought yet, and updates when that changes.
    @ObservedObject private var store = FilmStore.shared

    private enum Stage { case loaded, shelf }
    @State private var stage = Stage.loaded
    /// How much of the film is drawn out of the roll, 0...1.
    @State private var drawn: CGFloat = 1
    /// Whether the leader is out at all (it is laid across by hand, so it shows at once).
    @State private var leader: Double = 1
    // Putting a roll in, as in a real compact: it comes in from in front of
    // the camera with its far end tipped up, its spool hub is pushed along its
    // axis onto the rewind fork, then the far end is pressed down onto its seat.
    // Taking it out runs the other way. Each is 0 once the roll is seated.
    /// How far the roll is out in front of the chamber, towards you.
    @State private var away: CGFloat = 0
    /// How far the hub is clear of the fork, along the roll's axis.
    @State private var slide: CGFloat = 0
    /// How far the far end is tipped up, towards you.
    @State private var tilt: CGFloat = 0
    /// Whether the roll is out in front of the camera, above the end wall.
    /// Switched at the moment it leaves or reaches the chamber, not from
    /// `away`, which takes its final value as soon as an animation is set up.
    @State private var inFront = false
    /// Chamber pixels the hub moves to come off the fork's prongs.
    private static let slideOff: CGFloat = 40
    /// Degrees the far end is tipped up by.
    /// Perspective of the tip, for a view the size of the whole chamber.
    private static let tiltPerspective: CGFloat = 0.6
    private static let tiltUp: Double = -18    // negative: the far end comes towards you
    @State private var busy = false

    // Regions, in chamber pixels (532×802, the size of `Plate.bay`).
    private static let size = CGSize(width: 532, height: 802)
    private static let handle = CGRect(x: 0, y: 0, width: 100, height: 802)
    private static let spool = CGRect(x: 125, y: 38, width: 338, height: 80)
    private static let gate = CGRect(x: 172, y: 140, width: 244, height: 404)
    /// Where the roll lies, as in a real chamber: its spool hub goes into the
    /// socket in the left end wall (face at x 133 of the chamber picture),
    /// onto the fork inside, and the far end cap sits over the round seat on
    /// the right (centre x 462).
    static let cradle = CGRect(x: 108, y: 569.9, width: 345, height: 181.1)
    /// The front of the take-up spool's drum, and the band its turning ribs
    /// are drawn in (`drum_frames.png`, 12 frames of 204×63).
    static let drum = CGRect(x: 178, y: 61, width: 204, height: 64)
    static let ribs = CGRect(x: 178, y: 62, width: 204, height: 63)
    /// How far below the top of the roll the film comes out of its felt lip.
    static let lipDepth: CGFloat = 4
    /// Film out of the roll, in chamber pixels along it, with the leader wound
    /// on: lip to drum, round the drum's front, and the tongue beyond it, so
    /// all that shows is full width.
    static let filmOut: CGFloat = straightRun + 32 * .pi / 2 + FilmStrip.fullWidthAt + 6
    /// From the roll's lip to the middle of the drum, where the film leaves
    /// the plane of the gate.
    static let straightRun: CGFloat = (569.9 + 4) - 93
    /// The leader laid across onto the spool before winding: its tip half way
    /// over the top of the drum. A roll comes in like this, pulled out ready.
    static let leaderLaid: CGFloat = (straightRun + 32 * .pi / 4) / filmOut
    /// Rewound just off the spool: the tip a little below the drum. The roll
    /// is taken out from here, its leader still out.
    static let offSpool: CGFloat = (straightRun - 12) / filmOut

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
                    loadedRoll(gate: rect(Self.gate), cradle: rect(Self.cradle), drum: rect(Self.drum), ribs: rect(Self.ribs), unit: sy,
                               size: geo.size)
                        .transition(.opacity)
                } else {
                    shelf(unit: sy)
                        .padding(.leading, rect(Self.handle).width)
                        .transition(.opacity)
                }

                // The control column beside the open chamber, only there with
                // the door open: the film store, shutting the door, the
                // settings. Shut, the camera is bare. The column is GPT art
                // (`bay_strip.png`): blank keys like the ones under the
                // finder, faces and names drawn on them as on those keys.
                ZStack(alignment: .topLeading) {
                    if let strip = Self.stripImage {
                        Image(uiImage: strip).resizable().interpolation(.high)
                    } else {
                        LinearGradient(colors: [Color(white: 0.22), Color(white: 0.12)],
                                       startPoint: .leading, endPoint: .trailing)
                    }
                    ChamberKey(key: Self.storeKey, symbol: "film", name: "FILMS", label: "Films", sx: sx, sy: sy) {
                        model.showBag(.films)
                    }
                    ChamberKey(key: Self.latchKey, symbol: "chevron.right", name: "CLOSE", label: "Close the film chamber",
                               sx: sx, sy: sy) {
                        close()
                    }
                    ChamberKey(key: Self.settingsKey, symbol: "gearshape.fill", name: "SETUP", label: "Settings", sx: sx, sy: sy) {
                        model.showBag(.kit)
                    }
                }
                .place(rect(Self.handle))
                .zIndex(3)    // over the chamber's front wall, which covers its lower end
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .onChange(of: model.isBayOpen) { _, open in
            if open {
                reset()
                // Waiting for a roll chosen in the bag: the chamber is empty.
                if model.bayWaiting { away = 1; leader = 0; inFront = true }
            }
        }
        // The phone was closed on a roll chosen in the film library: the door
        // has opened by itself; the old roll is wound back and taken out, the
        // new one goes in and the door shuts, as when changing by hand.
        .onChange(of: model.arrivingRoll) { _, next in
            guard let next else { return }
            let empty = model.bayWaiting
            if !empty { after(0.35) { rewind() } }
            after(empty ? 0.1 : 1.0) {
                guard model.arrivingRoll == next else { return }   // already loaded another way
                model.arrivingRoll = nil
                model.bayWaiting = false
                load(next)
            }
        }
        .onAppear {
            #if DEBUG
            if UserDefaults.standard.string(forKey: "stage") == "shelf" { stage = .shelf; drawn = 0 }
            // `-demo <film id>`: rewind the loaded roll, then load that one, for
            // recording the whole change in the simulator.
            if let id = UserDefaults.standard.string(forKey: "demo"),
               let next = model.films.first(where: { $0.id == id }) {
                after(1.5) { rewind() }
                after(3.0) { load(next) }
            }
            #endif
        }
    }

    /// The control column, the size of `handle`.
    private static let stripImage = UIImage(named: "bay_strip.png")
    /// Its keys, in chamber pixels (measured on `bay_strip.png`).
    private static let storeKey = CGRect(x: 0, y: 85, width: 86, height: 70)
    private static let latchKey = CGRect(x: 0, y: 283, width: 86, height: 70)
    private static let settingsKey = CGRect(x: 0, y: 480, width: 86, height: 70)

    // MARK: Loaded roll

    @ViewBuilder
    private func loadedRoll(gate: CGRect, cradle: CGRect, drum: CGRect, ribs: CGRect, unit: CGFloat,
                            size: CGSize) -> some View {
        // The take-up spool's ribs, turning with the film.
        DrawnFilm(out: drawn * Self.filmOut, gate: gate, drum: drum, ribs: ribs,
                  lip: cradle.minY + Self.lipDepth * unit, unit: unit, part: .ribs)
            .allowsHitTesting(false)

        // The roll and the leader out of it, moved as one piece: brought in
        // and taken out together, tipped about the roll's hub end, slid along
        // its axis, and nearer you looking bigger.
        ZStack(alignment: .topLeading) {
            if let film = model.film {
                // The roll lies on its side in the cradle, its lip towards the gate.
                Button { rewind() } label: {
                    Canister(film: film)
                        .frame(width: cradle.height, height: cradle.width)
                        .rotationEffect(.degrees(-90))
                        .frame(width: cradle.width, height: cradle.height)
                        .shadow(color: .black.opacity(0.8), radius: (5 + 20 * away) * unit, y: (5 + 20 * away) * unit)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .allowsHitTesting(!busy)    // not .disabled: that greys the roll out
                .position(x: cradle.midX, y: cradle.midY)
                .accessibilityLabel("Change film")
                .accessibilityValue(film.name)
            }
            // The film, over the roll's lip so it is seen to come out of the felt.
            DrawnFilm(out: drawn * Self.filmOut, gate: gate, drum: drum, ribs: ribs,
                      lip: cradle.minY + Self.lipDepth * unit, unit: unit, part: .film)
                .opacity(leader)
                .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height)
        // The far end tipped up towards you, about the hub end.
        .rotation3DEffect(.degrees(Double(tilt) * Self.tiltUp), axis: (x: 0, y: 1, z: 0),
                          anchor: UnitPoint(x: cradle.minX / size.width, y: cradle.midY / size.height),
                          perspective: Self.tiltPerspective)
        .scaleEffect(1 + away * 0.35, anchor: UnitPoint(x: cradle.midX / size.width, y: cradle.midY / size.height))
        .offset(x: slide * Self.slideOff * unit)
        .opacity(Double(1 - away))
        // Out in front of the camera it is above everything; down in the
        // chamber the end wall covers its hub.
        .zIndex(inFront ? 2 : 0)

        if let wall = Plate.bayWallImage {
            Image(uiImage: wall).resizable().interpolation(.high)
                .allowsHitTesting(false)
                .zIndex(1)
        }
    }

    // MARK: Shelf

    private func shelf(unit: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text("Films")
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
                        Button {
                            // A limited roll not earned yet has no trials: its way is the Book.
                            if film.isLimited, !store.isUnlocked(film) { model.showBag(.book) } else { load(film) }
                        } label: {
                            HStack(spacing: 16 * unit) {
                                Canister(film: film)
                                    .frame(width: 76 * unit, height: 150 * unit)
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 150 * unit, height: 76 * unit)
                                VStack(alignment: .leading, spacing: 4 * unit) {
                                    Text(film.name)
                                        .font(.system(size: 28 * unit, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                    HStack(spacing: 8 * unit) {
                                        Text(verbatim: "ISO \(film.iso)")
                                            .font(.system(size: 21 * unit, design: .monospaced))
                                            .foregroundStyle(loaded ? Color(red: 1.0, green: 0.62, blue: 0.15)
                                                                    : Color(white: 0.55))
                                        // Not bought yet: a lock.
                                        if !store.isUnlocked(film) {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 17 * unit))
                                                .foregroundStyle(Color(white: 0.55))
                                                .accessibilityLabel("Not bought yet")
                                        }
                                    }
                                    .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 26 * unit)
                            .padding(.vertical, 12 * unit)
                            .background(loaded ? Color.white.opacity(0.08) : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .allowsHitTesting(!busy)
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
        leader = 1
        away = 0; slide = 0; tilt = 0
        inFront = false
        busy = false
    }

    private func close() {
        model.isBayOpen = false
        Haptic.tap()
    }

    /// Winds the film back into the roll, then offers every roll.
    private func rewind() {
        guard !busy else { return }
        busy = true
        Haptic.tap()
        // Rewound only until the film is off the take-up spool, the spool
        // turning back; then the roll is taken out, its leader with it.
        withAnimation(.easeIn(duration: 0.35)) { drawn = Self.offSpool }
        // The far end is lifted off its seat, the hub drawn off the fork, and
        // the roll taken out towards you; the shelf comes up.
        withAnimation(.easeOut(duration: 0.12).delay(0.4)) { tilt = 1 }
        withAnimation(.easeOut(duration: 0.12).delay(0.52)) { slide = 1 }
        after(0.64) { inFront = true }   // lifted clear of the wall
        withAnimation(.easeIn(duration: 0.18).delay(0.64)) { away = 1; leader = 0 }   // leader and all
        after(0.8) {
            withAnimation(.easeOut(duration: 0.2)) { stage = .shelf }
            busy = false
        }
    }

    /// Puts the picked roll in, draws its leader out and shuts the door.
    /// About two thirds of the first version's time (user 11/24: too slow).
    private func load(_ film: Film) {
        guard !busy else { return }
        busy = true
        if film != model.film { model.load(film) }
        // It comes in with its leader pulled out and laid across to the spool.
        drawn = Self.leaderLaid
        leader = 0
        away = 1; slide = 1; tilt = 1
        inFront = true
        withAnimation(.easeOut(duration: 0.12)) { stage = .loaded }
        // Brought in to the chamber, tipped, its hub clear of the fork…
        withAnimation(.easeOut(duration: 0.16)) { away = 0; leader = 1 }
        after(0.16) { inFront = false }   // down in the chamber, beside the wall
        // …the hub pushed along onto the fork's prongs…
        withAnimation(.easeIn(duration: 0.1).delay(0.16)) { slide = 0 }
        after(0.26) { Haptic.tap() }
        // …and the far end pressed down onto its seat.
        withAnimation(.easeIn(duration: 0.1).delay(0.28)) { tilt = 0 }
        after(0.38) { Haptic.stop() }
        // Seated: the take-up spool turns, winding the leader on; the rest
        // follows out of the roll.
        after(0.4) {
            withAnimation(.easeInOut(duration: 0.38)) { drawn = 1 }
        }
        after(0.82) {
            busy = false
            model.isBayOpen = false
            Haptic.tap()
        }
    }

    private func after(_ seconds: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}

/// The film between the roll and the take-up spool, as one strip: out of the
/// felt lip of the roll, straight up over the gate, round the front of the
/// take-up spool and away behind it. The spool's front is drawn from slices
/// of the same strip, squeezed as a cylinder shows them, so the holes run on
/// round it, and the spool's ribs turn with it (frames made from the chamber
/// picture itself). Winding on, everything moves up and over the spool;
/// rewinding, back down into the roll.
private struct DrawnFilm: View, Animatable {
    /// How much film is out of the roll, in chamber pixels along it.
    var out: CGFloat
    /// The film's width and place across the chamber, in view points.
    let gate: CGRect
    /// The front of the spool drum, in view points.
    let drum: CGRect
    /// Where the turning-rib frames go, in view points.
    let ribs: CGRect
    /// Where the film comes out of the roll's lip, in view points.
    let lip: CGFloat
    /// View points per chamber pixel.
    let unit: CGFloat
    /// The drum's turning ribs belong to the camera, the film to the roll:
    /// they are drawn by separate copies, so the film can move with the roll.
    enum Part { case ribs, film }
    let part: Part

    var animatableData: CGFloat {
        get { out }
        set { out = newValue }
    }

    /// 12 frames over one rib pitch, then a 13th: all of them averaged, the
    /// blur of a spool turning too fast for its ribs to be seen.
    static let ribFrames = UIImage(named: "drum_frames.png")
    static let ribFrameCount = 12
    /// Remembers the last drawn position, to tell how fast the spool turns.
    final class Pace { var lastOut: CGFloat = 0 }
    let pace = Pace()
    /// Chamber pixels of drum surface from one rib to the next.
    static let ribPitch: CGFloat = 10.5

    var body: some View {
        Canvas { context, _ in
            let travel = out * unit
            // The drum's ribs, turning as far as the film has moved.
            if part == .ribs, let sheet = Self.ribFrames {
                let phase = (out.truncatingRemainder(dividingBy: Self.ribPitch) + Self.ribPitch)
                    .truncatingRemainder(dividingBy: Self.ribPitch) / Self.ribPitch
                // Moving more than a third of a rib between frames, sharp ribs
                // would seem to creep backwards: show the blur instead.
                let step = abs(out - pace.lastOut)
                pace.lastOut = out
                let frame = step > Self.ribPitch / 3 ? Self.ribFrameCount
                    : min(Self.ribFrameCount - 1, Int(phase * CGFloat(Self.ribFrameCount)))
                context.drawLayer { layer in
                    layer.clip(to: Path(ribs))
                    layer.draw(Image(uiImage: sheet),
                               in: CGRect(x: ribs.minX, y: ribs.minY - CGFloat(frame) * ribs.height,
                                          width: ribs.width, height: ribs.height * CGFloat(Self.ribFrameCount + 1)))
                }
            }
            guard part == .film, travel > 0, let picture = FilmStrip.picture else { return }
            let strip = Image(uiImage: picture)
            let stripHeight = FilmStrip.length * unit
            // The film lies flat in the plane of the gate, and the front of the
            // drum touches that plane along its middle: flat up to there, then
            // it bends away round the top of the drum and out of sight.
            let r = drum.height / 2, yc = drum.midY
            let straight = lip - yc
            // The straight run: the tip is `travel` up from the lip.
            context.drawLayer { layer in
                layer.clip(to: Path(CGRect(x: gate.minX, y: yc, width: gate.width, height: max(0, straight))))
                layer.draw(strip, in: CGRect(x: gate.minX, y: lip - travel, width: gate.width, height: stripHeight))
            }
            // The quarter turn over the top of the drum, in slices.
            let slices = 16
            for i in 0..<slices {
                let a0 = CGFloat(i) / CGFloat(slices) * .pi / 2
                let a1 = CGFloat(i + 1) / CGFloat(slices) * .pi / 2
                let yBottom = yc - r * sin(a0), yTop = yc - r * sin(a1)
                // Distance from the tip along the film at each edge of the slice.
                let uHigh = travel - straight - r * a0
                let uLow = travel - straight - r * a1
                if uHigh <= 0 { break }
                let k = (yBottom - yTop) / (uHigh - uLow)
                let slice = CGRect(x: gate.minX, y: yTop, width: gate.width, height: yBottom - yTop + 0.5)
                context.drawLayer { layer in
                    layer.clip(to: Path(slice))
                    layer.translateBy(x: 0, y: yTop - uLow * k)
                    layer.scaleBy(x: 1, y: k)
                    layer.draw(strip, in: CGRect(x: gate.minX, y: 0, width: gate.width, height: stripHeight))
                    // Darker as it turns away from you.
                    let turned = 1 - cos((a0 + a1) / 2)
                    layer.blendMode = .sourceAtop
                    layer.fill(Path(CGRect(x: gate.minX, y: uLow - 1, width: gate.width, height: uHigh - uLow + 2)),
                               with: .color(.black.opacity(Double(0.7 * turned))))
                }
            }
        }
    }
}

/// A length of colour negative: the reddish-brown base with a row of
/// perforations down each side, cut through so the chamber shows in them.
/// The picture is a GPT render of a flat dark-brown leader as on everyday
/// colour film: the tongue (half width, one row of holes, rounded tip), a
/// smooth curve out to full width, holes fully inside the film.
private struct FilmStrip: View {
    static let picture = UIImage(named: "film_strip.png")
    /// Height over width of the strip picture (482×1982: the GPT strip, its
    /// full-width part lengthened by whole runs of perforations).
    static let aspect: CGFloat = picture.map { $0.size.height / $0.size.width } ?? 4.1
    /// The strip's length in chamber pixels, laid 244 wide across the gate.
    static let length: CGFloat = 244 * aspect
    /// How far from the tip, in chamber pixels, the tongue has widened to the
    /// full film (600 of the picture's 482-wide pixels).
    static let fullWidthAt: CGFloat = 600 * 244 / 482

    var body: some View {
        if let picture = Self.picture {
            Image(uiImage: picture)
                .resizable()
                .interpolation(.high)
        } else {
            drawn
        }
    }

    private var drawn: some View {
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

/// The system share sheet.
private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// In the finder, after a press with the loaded roll's free shots used up:
/// why nothing was taken, and the two ways on — buy this roll here, or choose
/// another — on kraft slips like the bag's (GPT art kraft_slip.png).
struct UsedUpNote: View {
    @EnvironmentObject private var model: CameraModel
    @ObservedObject private var store = FilmStore.shared

    var body: some View {
        GeometryReader { geo in
            if let film = model.usedUp {
                let h = geo.size.height
                VStack(spacing: h * 0.035) {
                    Group {
                        if film.isLimited { Text("\(film.name): earned in the Book only") }
                        else { Text("\(film.name): free shots used up") }
                    }
                        .font(.system(size: max(h * 0.065, 12), weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    HStack(spacing: h * 0.05) {
                        if film.isLimited {
                            slip(Text("Open the Book"), h: h) { model.usedUp = nil; model.showBag(.book) }
                        } else {
                            slip(buyTitle(film), h: h) { model.buyUsedUp() }
                                .disabled(store.purchasing != nil || waiting(film))
                        }
                        slip(Text("Choose another roll"), h: h) { model.changeRollFromUsedUp() }
                    }
                }
                .padding(.horizontal, h * 0.05).padding(.vertical, h * 0.04)
                .background(RoundedRectangle(cornerRadius: h * 0.03).fill(Color.black.opacity(0.7)))
                .padding(h * 0.04)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.usedUp)
        // Bought (or approved) later, by any way: END and the slips go.
        .onChange(of: model.usedUp.map { store.isUnlocked($0) } ?? false) { _, unlocked in
            if unlocked { model.usedUp = nil }
        }
    }

    private func waiting(_ film: Film) -> Bool {
        store.awaitingApproval.contains(FilmStore.productID(film)) || store.awaitingApproval.contains(FilmStore.allFilmsID)
    }

    private func buyTitle(_ film: Film) -> Text {
        if waiting(film) { return Text("Purchase waiting for approval") }
        if store.purchasing != nil { return Text("Buying…") }
        if let price = store.price(film) { return Text("Buy it · \(price)") }
        return Text("Prices unavailable · try again")
    }

    private func slip(_ title: Text, h: CGFloat, action: @escaping () -> Void) -> some View {
        let w = h * 0.62, sh = w * 53 / 210
        return Button(action: { Haptic.click(); action() }) {
            Image(uiImage: TryMyPhotoSlip.picture).resizable()
                .frame(width: w, height: sh)
                .overlay {
                    title.font(.custom("Marker Felt", size: sh * 0.42))
                        .foregroundStyle(BookArt.ink)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .padding(.leading, w * 0.13).padding(.trailing, w * 0.08)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A slip laid over the finder for a moment: the roll that just went in.
struct LoadedNotice: View {
    let film: Film?
    var body: some View {
        if let film {
            HStack(spacing: 12) {
                Canister(film: film, fill: true).frame(width: 34, height: 52)
                Text("Loaded · \(film.name)")
                    .font(.custom("Marker Felt", size: 26))
                    .foregroundStyle(Color(red: 0.24, green: 0.15, blue: 0.08))
            }
            .padding(.horizontal, 22).padding(.vertical, 12)
            .background(Image("kraft_slip").resizable())
            .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
            .allowsHitTesting(false)
        }
    }
}
