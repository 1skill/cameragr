import Synchronization
import AVFoundation
import CoreImage
import UIKit

/// Owns the capture session. Frames and photos are delivered as CIImages in the
/// app's fixed landscape orientation; all colour work happens downstream.
final class CameraService: NSObject {
    /// Called on a background queue for every preview frame, with the
    /// camera's ISO at the time (looks that model a sensor's noise use it).
    var onFrame: ((CIImage, Float) -> Void)?
    /// Called on a background queue with the full-resolution photo (nil on
    /// failure) and the ISO it was taken at.
    /// The picture, its ISO, and how many stops the film should bring it up to
    /// match the finder (the picture itself is the camera's own).
    var onPhoto: ((CIImage?, Float, Double) -> Void)?
    /// The exposure itself is over and the camera can take the next one; the
    /// picture follows through `onPhoto` once it has been processed.
    var onShutter: (() -> Void)?

    /// A change the user made with the phone's Camera Control button.
    enum ControlChange {
        case film(Int), flash(Int), zoom(CGFloat), exposure(Float)
    }
    /// Called on a background queue when a Camera Control setting changes.
    var onControl: ((ControlChange) -> Void)?
    /// Names offered by the Camera Control film picker. Set before `start`.
    var filmTitles: [String] = []
    static let flashTitles = [String(ui: "Off"), String(ui: "Auto"), String(ui: "On")]

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "cameragr.session")
    private let videoQueue = DispatchQueue(label: "cameragr.video", qos: .userInteractive)
    private let videoOutput = AVCaptureVideoDataOutput()
    /// The finder's exposure (seconds × ISO) at each press, by photo.
    private let finderExposures = Mutex<[Int64: Double]>([:])
    private let photoOutput = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?

    private var configured = false
    /// Started and not stopped by the app (session queue).
    private var wantsRunning = false
    /// The bag is up: the session runs on (see `rest`), offering nothing on
    /// Camera Control and passing no frames on.
    private var resting = false
    /// Finder frames may be 1/15 s long (video queue; see `checkDarkFrames`).
    private var darkFramesOn = false
    private var lastFrameCheck = 0.0
    private var runtimeErrorObserver: NSObjectProtocol?

    deinit {
        if let runtimeErrorObserver { NotificationCenter.default.removeObserver(runtimeErrorObserver) }
    }
    private var filmPicker: AVCaptureIndexPicker?
    private var flashPicker: AVCaptureIndexPicker?
    private var selectedFilm = 0
    private var selectedFlash = 0
    private(set) var position: AVCaptureDevice.Position = .back

    /// Asks for camera access, then starts the session. Completion runs on
    /// the main queue: true once a camera is attached and running.
    func start(completion: @escaping (Bool) -> Void) {
        #if targetEnvironment(simulator)
        // The simulator has no camera: feed one synthetic frame so the UI and LUTs can be checked.
        let frame = TestPattern.image()
        videoQueue.async { self.onFrame?(frame, 100) }
        DispatchQueue.main.async { completion(true) }
        #else
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            self.sessionQueue.async {
                if !self.configured { self.configure() }
                self.wantsRunning = true
                if !self.session.isRunning { self.session.startRunning() }
                // Ready only with a lens attached: access alone is not enough.
                let ready = self.input != nil
                DispatchQueue.main.async { completion(ready) }
            }
        }
        #endif
    }

    /// The bag is up. The session keeps running: an app the system opened
    /// from Camera Control has to keep a camera running, or the system ends
    /// it about ten seconds on (seen three times, 11/24, each launched straight
    /// into the bag). But Camera Control offers nothing over the bag (user
    /// 11/24) and no frames are rendered. `start` undoes it.
    func rest(_ on: Bool) {
        sessionQueue.async {
            guard self.resting != on else { return }
            self.resting = on
            guard self.configured, self.session.supportsControls else { return }
            self.session.beginConfiguration()
            if on { self.session.controls.forEach { self.session.removeControl($0) } } else { self.installControls() }
            self.session.commitConfiguration()
        }
    }

    func stop() {
        sessionQueue.async {
            self.wantsRunning = false
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func flip() {
        sessionQueue.async {
            self.position = self.position == .back ? .front : .back
            guard self.configured else { return }
            self.session.beginConfiguration()
            self.attachInput()
            self.installControls()
            self.applyConnectionSettings()
            self.session.commitConfiguration()
            self.allowDarkFrames()
        }
    }

    /// Keeps the Camera Control pickers in step with changes made on screen.
    func select(film index: Int) {
        sessionQueue.async {
            self.selectedFilm = index
            guard let picker = self.filmPicker, index < picker.numberOfIndexes else { return }
            picker.selectedIndex = index   // only on the picker's action queue, which is this one
        }
    }

    func select(flash index: Int) {
        sessionQueue.async {
            self.selectedFlash = index
            guard let picker = self.flashPicker, index < picker.numberOfIndexes else { return }
            picker.selectedIndex = index   // only on the picker's action queue, which is this one
        }
    }

    /// Exposure compensation in EV, clamped to what the device supports.
    func setExposureBias(_ ev: Float) {
        sessionQueue.async {
            guard let device = self.input?.device, (try? device.lockForConfiguration()) != nil else { return }
            let clamped = min(max(ev, device.minExposureTargetBias), device.maxExposureTargetBias)
            device.setExposureTargetBias(clamped)
            device.unlockForConfiguration()
        }
    }

    /// The device's own zoom factor at which the main lens is in use: 1, or more
    /// when the camera also has an ultra-wide lens below it.
    private(set) var wideFactor: CGFloat = 1
    /// Whether 0.5× exists. Zooming only crops, so it takes a wider lens.
    var hasUltraWide: Bool { wideFactor > 1 }

    /// Zoom as printed on a camera (1× is the main lens), clamped to what the
    /// device supports. Beyond the lenses it has, the device crops.
    func setZoom(_ factor: CGFloat) {
        sessionQueue.async {
            guard let device = self.input?.device, (try? device.lockForConfiguration()) != nil else { return }
            device.videoZoomFactor = min(max(factor * self.wideFactor, device.minAvailableVideoZoomFactor),
                                         device.maxAvailableVideoZoomFactor)
            device.unlockForConfiguration()
        }
    }

    /// Takes a picture. `fast` trades some of the camera's processing for
    /// speed: used for the pictures of a burst after the first.
    func capture(flash: AVCaptureDevice.FlashMode, fast: Bool = false) {
        #if targetEnvironment(simulator)
        let frame = TestPattern.image()
        videoQueue.async {
            self.onShutter?()
            self.onPhoto?(frame, 100, 0)
        }
        #else
        sessionQueue.async {
            guard self.configured, self.session.isRunning else {
                self.onPhoto?(nil, 0, 0)
                return
            }
            let settings = AVCapturePhotoSettings()
            if self.photoOutput.supportedFlashModes.contains(flash) { settings.flashMode = flash }
            // Balanced, not quality: the film look hides what the slow multi-frame
            // processing would add, and it costs seconds per shot.
            settings.photoQualityPrioritization = fast ? .speed : .balanced
            // Settings: no shutter sound, where the law allows it (the system decides).
            if !Preferences.shutterSound, self.photoOutput.isShutterSoundSuppressionSupported {
                settings.isShutterSoundSuppressionEnabled = true
            }
            // What the finder was exposed with at the press: the picture is
            // brought up to it if the camera took it shorter (see below).
            if let device = self.input?.device {
                self.finderExposures.withLock {
                    $0[settings.uniqueID] = CMTimeGetSeconds(device.exposureDuration) * Double(device.iso)
                }
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
        #endif
    }

    // MARK: - Configuration (session queue)

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        attachInput()

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        photoOutput.maxPhotoQualityPrioritization = .balanced

        installControls()
        applyConnectionSettings()
        session.commitConfiguration()
        allowDarkFrames()
        configured = true
        watchSession()
    }

    /// The session can stop on its own: the media services restarting, or
    /// an error. Started again here; an interruption (a call, another app
    /// using the camera) ends by itself and needs nothing.
    private func watchSession() {
        guard runtimeErrorObserver == nil else { return }
        runtimeErrorObserver = NotificationCenter.default.addObserver(forName: AVCaptureSession.runtimeErrorNotification,
                                               object: session, queue: nil) { [weak self] note in
            let error = note.userInfo?[AVCaptureSessionErrorKey] as? AVError
            #if DEBUG
            print("[camera] runtime error: \(error?.localizedDescription ?? "unknown")")
            #endif
            self?.sessionQueue.asyncAfter(deadline: .now() + 0.5) {
                guard let self, !self.session.isRunning, self.wantsRunning else { return }
                self.session.startRunning()
            }
        }
    }

    private func attachInput() {
        if let input { session.removeInput(input) }
        input = nil
        // On the back, prefer the camera that also has the ultra-wide lens: one
        // zoom range then runs from 0.5× through the main lens and on.
        let types: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera]
            : [.builtInWideAngleCamera]
        guard let device = types.lazy.compactMap({
                  AVCaptureDevice.default($0, for: .video, position: self.position)
              }).first,
              let newInput = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(newInput) else { return }
        session.addInput(newInput)
        input = newInput

        let widest = device.constituentDevices.first?.deviceType
        let switchOver = device.virtualDeviceSwitchOverVideoZoomFactors.first.map { CGFloat(truncating: $0) }
        wideFactor = widest == .builtInUltraWideCamera ? (switchOver ?? 1) : 1
        // Start on the main lens, not on the widest one.
        if (try? device.lockForConfiguration()) != nil {
            device.videoZoomFactor = min(max(wideFactor, device.minAvailableVideoZoomFactor),
                                         device.maxAvailableVideoZoomFactor)
            device.unlockForConfiguration()
        }
    }

    /// The finder runs at 30 fps. Only when it is really dark, with the ISO
    /// near the top of its range, may auto exposure stretch each frame to
    /// 1/15 s (and use the lens's low-light boost where it has one), so the
    /// finder stays bright enough to frame in. Allowing 1/15 s all the time
    /// made AE take ~1/40 s frames indoors at a fifth of the ISO range, and
    /// the finder ran at 26–28 fps (perf log 11/25, build 93).
    /// Set after a configuration is committed (a new format resets it).
    private func allowDarkFrames() {
        // Synchronously, so no check queued before the reset can undo it (the
        // video queue never waits on the session queue).
        videoQueue.sync { self.darkFramesOn = false; self.lastFrameCheck = 0 }
        setFrameLimit(dark: false)
        guard let device = input?.device, (try? device.lockForConfiguration()) != nil else { return }
        if device.isLowLightBoostSupported { device.automaticallyEnablesLowLightBoostWhenAvailable = true }
        device.unlockForConfiguration()
    }

    /// Longest finder frame: 1/15 s in the dark, else 1/30 s (session queue).
    @discardableResult
    private func setFrameLimit(dark: Bool) -> Bool {
        guard let device = input?.device, (try? device.lockForConfiguration()) != nil else { return false }
        let longest = CMTime(value: 1, timescale: dark ? 15 : 30)
        if device.activeFormat.videoSupportedFrameRateRanges.contains(where: {
            CMTimeCompare($0.maxFrameDuration, longest) >= 0 && CMTimeCompare($0.minFrameDuration, longest) <= 0
        }) {
            device.activeVideoMaxFrameDuration = longest
        }
        device.unlockForConfiguration()
        Diag.note(String(format: "dark frames %@: max frame %.3fs, ISO %.0f/%.0f",
                         dark ? "on" : "off", CMTimeGetSeconds(device.activeVideoMaxFrameDuration),
                         device.iso, device.activeFormat.maxISO))
        return true
    }

    /// Whether the finder should allow 1/15 s frames, given whether it does
    /// now and how far up its range the ISO is (0…1). Wide gap between the
    /// two thresholds: once frames are longer the ISO drops, and the finder
    /// must not flip back and forth.
    static func wantsDarkFrames(now: Bool, isoFraction: Double) -> Bool {
        now ? isoFraction > 0.2 : isoFraction >= 0.75
    }

    /// Once a second, from the video queue: switch the frame limit when the light changes.
    fileprivate func checkDarkFrames(at time: Double) {
        guard time - lastFrameCheck >= 1, let device = input?.device else { return }
        lastFrameCheck = time
        let maxISO = Double(device.activeFormat.maxISO), minISO = Double(device.activeFormat.minISO)
        guard maxISO > minISO else { return }
        let fraction = (Double(device.iso) - minISO) / (maxISO - minISO)
        let dark = Self.wantsDarkFrames(now: darkFramesOn, isoFraction: fraction)
        guard dark != darkFramesOn else { return }
        darkFramesOn = dark
        sessionQueue.async {
            // A reset (new lens or format) since this check wins.
            guard self.videoQueue.sync(execute: { self.darkFramesOn == dark }) else { return }
            // Not applied (the lens was busy): forget the switch, so the next check tries again.
            if !self.setFrameLimit(dark: dark) {
                self.videoQueue.async { if self.darkFramesOn == dark { self.darkFramesOn = !dark } }
            }
        }
    }

    /// The Camera Control button's overlay: film, exposure, zoom and flash.
    /// Rebuilt for every input, because the system sliders belong to one lens.
    private func installControls() {
        guard session.supportsControls else { return }
        session.controls.forEach { session.removeControl($0) }
        guard !resting else { return }
        filmPicker = nil
        flashPicker = nil
        guard let device = input?.device else { return }

        var controls: [AVCaptureControl] = []
        if !filmTitles.isEmpty {
            let picker = AVCaptureIndexPicker(String(ui: "Film"), symbolName: "film", localizedIndexTitles: filmTitles)
            picker.selectedIndex = min(selectedFilm, filmTitles.count - 1)
            picker.setActionQueue(sessionQueue) { [weak self] index in
                self?.selectedFilm = index
                self?.onControl?(.film(index))
            }
            filmPicker = picker
            controls.append(picker)
        }
        controls.append(AVCaptureSystemExposureBiasSlider(device: device) { [weak self] bias in
            self?.onControl?(.exposure(Float(bias)))
        })
        controls.append(AVCaptureSystemZoomSlider(device: device) { [weak self] factor in
            guard let self else { return }
            self.onControl?(.zoom(CGFloat(factor) / self.wideFactor))
        })
        if device.hasFlash {
            let picker = AVCaptureIndexPicker(String(ui: "Flash"), symbolName: "bolt.fill", localizedIndexTitles: Self.flashTitles)
            picker.selectedIndex = min(selectedFlash, Self.flashTitles.count - 1)
            picker.setActionQueue(sessionQueue) { [weak self] index in
                self?.selectedFlash = index
                self?.onControl?(.flash(index))
            }
            flashPicker = picker
            controls.append(picker)
        }
        for control in controls.prefix(session.maxControlsCount) where session.canAddControl(control) {
            session.addControl(control)
        }
        session.setControlsDelegate(self, queue: sessionQueue)
    }

    /// The UI is locked to landscape-right, which is the back sensor's native
    /// orientation. Both outputs deliver the sensor's own picture, untouched;
    /// the front one is mirrored in `upright(_:)` instead, because rotating and
    /// mirroring it on the connection came out upside down on a real phone.
    private func applyConnectionSettings() {
        // Take the frame from the moment of the press and let shots overlap,
        // where the current camera supports it.
        if photoOutput.isZeroShutterLagSupported { photoOutput.isZeroShutterLagEnabled = true }
        if photoOutput.isResponsiveCaptureSupported { photoOutput.isResponsiveCaptureEnabled = true }
        if photoOutput.isFastCapturePrioritizationSupported { photoOutput.isFastCapturePrioritizationEnabled = true }

        // Both outputs deliver the sensor's own picture, unturned. The body is
        // drawn fixed to the phone (see CameraScreen), in the frame the back
        // sensor lies in, so nothing here depends on how the interface is turned.
        let angle: CGFloat = 0
        for output in [videoOutput, photoOutput] as [AVCaptureOutput] {
            guard let connection = output.connection(with: .video) else { continue }
            if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
    }
}

extension CameraService {
    /// The front sensor's picture arrives the right way up in this interface
    /// (checked on an iPhone Duo's outer screen). Flipping it left to right
    /// makes the finder behave like a mirror, the way a selfie finder should.
    fileprivate func upright(_ image: CIImage) -> CIImage {
        guard position == .front else { return image }
        let flipped = image.oriented(.upMirrored)
        return flipped.transformed(by: CGAffineTransform(translationX: -flipped.extent.minX,
                                                         y: -flipped.extent.minY))
    }
}

#if DEBUG
/// Every two seconds: how the finder is exposed (for tuning the dark finder
/// on the phone; read off with devicectl).
private var exposureLog = (last: CMTime.zero, frames: 0)
extension CameraService {
    func noteExposure(_ sample: CMSampleBuffer) {
        let now = CMSampleBufferGetPresentationTimeStamp(sample)
        exposureLog.frames += 1
        let span = CMTimeGetSeconds(CMTimeSubtract(now, exposureLog.last))
        guard span >= 2, let device = input?.device else { return }
        Diag.note(String(format: "finder exposure %.4fs ISO %.0f/%.0f %.1f fps boost %@",
                         CMTimeGetSeconds(device.exposureDuration), device.iso, device.activeFormat.maxISO,
                         Double(exposureLog.frames) / span,
                         device.isLowLightBoostEnabled ? "on" : "off"))
        exposureLog = (now, 0)
    }
}
#endif

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        #if DEBUG
        noteExposure(sampleBuffer)
        #endif
        guard !resting else { return }
        checkDarkFrames(at: CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)))
        onFrame?(upright(CIImage(cvPixelBuffer: buffer)), input?.device.iso ?? 100)
    }
}

/// Adopting this is what switches the Camera Control overlay on; the app has
/// nothing of its own to hide or show while the overlay is up.
extension CameraService: AVCaptureSessionControlsDelegate {
    func sessionControlsDidBecomeActive(_ session: AVCaptureSession) { Self.trace("DidBecomeActive") }
    func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) { Self.trace("WillEnterFullscreenAppearance") }
    func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) { Self.trace("WillExitFullscreenAppearance") }
    func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) { Self.trace("DidBecomeInactive") }
}

extension CameraService {
    /// Temporary: timestamps Camera Control overlay events while a light-press problem is tracked down.
    fileprivate static func trace(_ event: String) {
        #if DEBUG
        print(String(format: "[controls] %.2f %@", CACurrentMediaTime(), event))
        #endif
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        onShutter?()
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            onPhoto?(nil, 0, 0)
            return
        }
        let exif = photo.metadata[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let iso = (exif?[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber])?.first?.floatValue
        let time = (exif?[kCGImagePropertyExifExposureTime as String] as? NSNumber)?.doubleValue
        let finder = finderExposures.withLock { $0.removeValue(forKey: photo.resolvedSettings.uniqueID) }
        // What you see is what you get, in the dark too: the finder may expose
        // each frame up to 1/15 s, while the camera can take the picture
        // shorter. Brought up by the difference (at most two stops), before
        // the film. Not with the flash, which lights the picture itself.
        var lift = 0.0
        if let finder, let time, let iso, time > 0, iso > 0, !photo.resolvedSettings.isFlashEnabled {
            let stops = min(max(log2(finder / (time * Double(iso))), 0), 2)
            if stops > 0.15 { lift = stops }
            Diag.note(String(format: "photo %.4fs ISO %.0f, finder %.4f, lift %.2f EV", time, iso, finder, stops))
        }
        onPhoto?(upright(image), iso ?? input?.device.iso ?? 100, lift)
    }
}

/// Synthetic frame for the simulator: sky, foliage, skin and saturated patches,
/// a grey ramp, and a "TOP" marker to catch orientation mistakes.
enum TestPattern {
    static func image() -> CIImage {
        #if DEBUG
        // `-feed <sample>` (e.g. portra400_2): a bundled sample picture as the
        // camera's view, for App Store screenshots in the simulator.
        if let name = UserDefaults.standard.string(forKey: "feed"),
           let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
           let picture = CIImage(contentsOf: url) {
            return picture.transformed(by: CGAffineTransform(translationX: -picture.extent.minX, y: -picture.extent.minY))
        }
        #endif
        return chart()
    }

    private static func chart() -> CIImage {
        let size = CGSize(width: 1500, height: 1000)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let sky = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: [UIColor(red: 0.25, green: 0.52, blue: 0.90, alpha: 1).cgColor,
                                          UIColor(red: 0.80, green: 0.90, blue: 0.98, alpha: 1).cgColor] as CFArray,
                                 locations: [0, 1])!
            cg.drawLinearGradient(sky, start: .zero, end: CGPoint(x: 0, y: 560), options: [])
            UIColor(red: 0.20, green: 0.45, blue: 0.18, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 560, width: size.width, height: 440))

            let patches: [UIColor] = [
                UIColor(red: 0.86, green: 0.65, blue: 0.54, alpha: 1), // light skin
                UIColor(red: 0.62, green: 0.42, blue: 0.32, alpha: 1), // tan skin
                UIColor(red: 0.90, green: 0.15, blue: 0.12, alpha: 1),
                UIColor(red: 0.98, green: 0.55, blue: 0.10, alpha: 1),
                UIColor(red: 0.98, green: 0.85, blue: 0.15, alpha: 1),
                UIColor(red: 0.15, green: 0.65, blue: 0.30, alpha: 1),
                UIColor(red: 0.10, green: 0.35, blue: 0.80, alpha: 1),
                UIColor(red: 0.55, green: 0.20, blue: 0.65, alpha: 1),
            ]
            for (i, color) in patches.enumerated() {
                color.setFill()
                cg.fill(CGRect(x: 90 + CGFloat(i) * 165, y: 420, width: 150, height: 220))
            }
            for i in 0..<12 {
                UIColor(white: CGFloat(i) / 11, alpha: 1).setFill()
                cg.fill(CGRect(x: 90 + CGFloat(i) * 110, y: 720, width: 110, height: 160))
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 120),
                .foregroundColor: UIColor.white,
            ]
            ("TOP" as NSString).draw(at: CGPoint(x: 90, y: 60), withAttributes: attributes)
        }
        return CIImage(image: rendered) ?? CIImage(color: .gray).cropped(to: CGRect(origin: .zero, size: size))
    }
}
