import AVFoundation
import CoreImage
import SwiftUI
import UIKit

/// App state: the loaded film, camera controls, and the capture → develop → save flow.
@MainActor
final class CameraModel: ObservableObject {
    enum Flash: String, CaseIterable {
        case off, auto, on

        var mode: AVCaptureDevice.FlashMode {
            switch self {
            case .off: return .off
            case .auto: return .auto
            case .on: return .on
            }
        }

        var next: Flash {
            let all = Flash.allCases
            return all[(all.firstIndex(of: self)! + 1) % all.count]
        }
    }

    /// Frame aspect of the loaded film (135 film is 3:2).
    nonisolated static let frameAspect: CGFloat = 3.0 / 2.0

    let films: [Film] = FilmLibrary.shared.films
    let frames = FrameStore()

    @Published var film: Film?
    @Published var isBayOpen = false
    @Published var flash: Flash = .off
    @Published var showsGrid = true
    @Published var exposureBias: Double = 0
    @Published var zoom: CGFloat = 1
    @Published var lastThumbnail: UIImage?
    @Published var frameCount = 0
    /// True from the shutter press until the camera hands over the exposure:
    /// the finder blinks dark and a second press is ignored. Developing and
    /// saving happen afterwards in the background and don't hold up the next shot.
    @Published var isExposing = false
    @Published var message: String?

    private let service = CameraService()
    private let renderer = FilmRenderer.shared
    private let developQueue = DispatchQueue(label: "cameragr.develop", qos: .userInitiated)

    init() {
        film = films.first
        #if DEBUG
        // Launch arguments for automated UI checks: -film <id>  -bay 1  -shoot 1  -url <link>
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: "film"), let match = films.first(where: { $0.id == id }) {
            film = match
        }
        isBayOpen = defaults.bool(forKey: "bay")
        if let link = defaults.string(forKey: "url").flatMap(URL.init(string:)) { open(link) }
        if defaults.bool(forKey: "shoot") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.shoot() }
        }
        #endif
        frames.set(film: film)
        let frames = frames
        service.onFrame = { frames.set(image: $0) }
        service.onPhoto = { [weak self] image in
            // Read the film on the main actor, then develop off it.
            Task { @MainActor in self?.develop(image) }
        }
    }

    func start() {
        service.start { [weak self] granted in
            if !granted { self?.message = "没有相机权限，请在系统设置里允许 Peli 使用相机。" }
        }
    }

    func stop() { service.stop() }

    func load(_ film: Film) {
        self.film = film
        frames.set(film: film)
        frameCount = 0
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    /// Handles peli://film/<id>, the link a widget's roll opens.
    func open(_ url: URL) {
        guard url.scheme == "peli", url.host == "film",
              let match = films.first(where: { $0.id == url.lastPathComponent }) else { return }
        isBayOpen = false
        if match != film { load(match) }
    }

    func toggleBay() {
        isBayOpen.toggle()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func cycleFlash() { flash = flash.next }

    func flipCamera() {
        zoom = 1
        service.flip()
    }

    /// Switches between the plain view and a 2× crop.
    func toggleLens() {
        zoom = zoom > 1 ? 1 : 2
        service.setZoom(zoom)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func setExposureBias(_ ev: Double) {
        let clamped = min(max(ev, -2), 2)
        exposureBias = clamped
        service.setExposureBias(Float(clamped))
    }

    func shoot() {
        guard !isExposing else { return }
        isExposing = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        service.capture(flash: flash.mode)
    }

    // MARK: - Develop

    private func develop(_ image: CIImage?) {
        isExposing = false
        guard let image else {
            message = "拍摄失败，请再试一次。"
            return
        }
        let film = film
        let renderer = renderer
        developQueue.async { [weak self] in
            let cropped = Self.cropToFrame(image)
            let developed = renderer.filtered(cropped, film: film)
            let data = renderer.context.heifRepresentation(of: developed,
                                                           format: .RGBA8,
                                                           colorSpace: renderer.sRGB,
                                                           options: [:])
            let thumbnail = Self.thumbnail(of: developed, context: renderer.context)

            guard let data else {
                Task { @MainActor in
                    self?.message = "照片处理失败。"
                }
                return
            }
            PhotoSaver.save(data) { result in
                Task { @MainActor in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.lastThumbnail = thumbnail
                        self.frameCount += 1
                    case .failure(PhotoSaver.SaveError.denied):
                        self.lastThumbnail = thumbnail
                        self.message = "没有相册权限，照片未保存。请在系统设置里允许访问照片。"
                    case .failure:
                        self.message = "保存到相册失败。"
                    }
                }
            }
        }
    }

    /// Centre-crops to the film's frame aspect and moves the origin to zero.
    nonisolated private static func cropToFrame(_ image: CIImage) -> CIImage {
        let extent = image.extent
        var width = extent.width
        var height = width / frameAspect
        if height > extent.height {
            height = extent.height
            width = height * frameAspect
        }
        let rect = CGRect(x: extent.midX - width / 2, y: extent.midY - height / 2, width: width, height: height).integral
        return image.cropped(to: rect).transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
    }

    nonisolated private static func thumbnail(of image: CIImage, context: CIContext) -> UIImage? {
        let scale = 240 / max(image.extent.width, 1)
        let small = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(small, from: small.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
