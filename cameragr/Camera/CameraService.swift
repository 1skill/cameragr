import AVFoundation
import CoreImage
import UIKit

/// Owns the capture session. Frames and photos are delivered as CIImages in the
/// app's fixed landscape orientation; all colour work happens downstream.
final class CameraService: NSObject {
    /// Called on a background queue for every preview frame.
    var onFrame: ((CIImage) -> Void)?
    /// Called on a background queue with the full-resolution photo (nil on failure).
    var onPhoto: ((CIImage?) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "cameragr.session")
    private let videoQueue = DispatchQueue(label: "cameragr.video", qos: .userInteractive)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private var configured = false
    private(set) var position: AVCaptureDevice.Position = .back

    /// Asks for camera access, then starts the session. Completion runs on the main queue.
    func start(completion: @escaping (Bool) -> Void) {
        #if targetEnvironment(simulator)
        // The simulator has no camera: feed one synthetic frame so the UI and LUTs can be checked.
        let frame = TestPattern.image()
        videoQueue.async { self.onFrame?(frame) }
        DispatchQueue.main.async { completion(true) }
        #else
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            self.sessionQueue.async {
                if !self.configured { self.configure() }
                if !self.session.isRunning { self.session.startRunning() }
                DispatchQueue.main.async { completion(true) }
            }
        }
        #endif
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func flip() {
        sessionQueue.async {
            self.position = self.position == .back ? .front : .back
            guard self.configured else { return }
            self.session.beginConfiguration()
            self.attachInput()
            self.applyConnectionSettings()
            self.session.commitConfiguration()
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

    /// Zoom factor on the current lens, clamped to what the device supports.
    func setZoom(_ factor: CGFloat) {
        sessionQueue.async {
            guard let device = self.input?.device, (try? device.lockForConfiguration()) != nil else { return }
            device.videoZoomFactor = min(max(factor, device.minAvailableVideoZoomFactor),
                                         device.maxAvailableVideoZoomFactor)
            device.unlockForConfiguration()
        }
    }

    func capture(flash: AVCaptureDevice.FlashMode) {
        #if targetEnvironment(simulator)
        let frame = TestPattern.image()
        videoQueue.async { self.onPhoto?(frame) }
        #else
        sessionQueue.async {
            guard self.configured, self.session.isRunning else {
                self.onPhoto?(nil)
                return
            }
            let settings = AVCapturePhotoSettings()
            if self.photoOutput.supportedFlashModes.contains(flash) { settings.flashMode = flash }
            settings.photoQualityPrioritization = self.photoOutput.maxPhotoQualityPrioritization
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
        photoOutput.maxPhotoQualityPrioritization = .quality

        applyConnectionSettings()
        session.commitConfiguration()
        configured = true
    }

    private func attachInput() {
        if let input { session.removeInput(input) }
        input = nil
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let newInput = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(newInput) else { return }
        session.addInput(newInput)
        input = newInput
    }

    /// The UI is locked to landscape-right, which is the back sensor's native
    /// orientation (0°). The front sensor is mounted the other way round.
    private func applyConnectionSettings() {
        let angle: CGFloat = position == .back ? 0 : 180
        for output in [videoOutput, photoOutput] as [AVCaptureOutput] {
            guard let connection = output.connection(with: .video) else { continue }
            if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = position == .front
            }
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(CIImage(cvPixelBuffer: buffer))
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            onPhoto?(nil)
            return
        }
        onPhoto?(image)
    }
}

/// Synthetic frame for the simulator: sky, foliage, skin and saturated patches,
/// a grey ramp, and a "TOP" marker to catch orientation mistakes.
enum TestPattern {
    static func image() -> CIImage {
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
