import CoreImage
import CoreImage.CIFilterBuiltins
import Metal

/// Applies a film's LUT. The viewfinder and the saved photo both go through
/// `filtered(_:film:)`, so what you see is what you get.
final class FilmRenderer: @unchecked Sendable {   // mutable state is guarded by `lock`
    static let shared = FilmRenderer()

    let device: MTLDevice
    let context: CIContext
    let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    private var filters: [String: CIFilter] = [:]
    private let lock = NSLock()

    private init() {
        device = MTLCreateSystemDefaultDevice()!
        context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
    }

    func filtered(_ image: CIImage, film: Film?) -> CIImage {
        guard let film, let filter = filter(for: film) else { return image }
        lock.lock()
        defer { lock.unlock() }
        filter.setValue(image, forKey: kCIInputImageKey)
        let output = filter.outputImage ?? image
        filter.setValue(nil, forKey: kCIInputImageKey)
        return output
    }

    private func filter(for film: Film) -> CIFilter? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = filters[film.id] { return cached }
        guard let cube = FilmLibrary.shared.cube(for: film) else { return nil }
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.cubeDimension = Float(film.lutSize)
        filter.cubeData = cube
        filter.colorSpace = sRGB
        filters[film.id] = filter
        return filter
    }
}

/// Latest camera frame and selected film, shared between the capture queue and the view.
final class FrameStore {
    private let lock = NSLock()
    private var image: CIImage?
    private var film: Film?

    func set(image: CIImage) {
        lock.lock(); self.image = image; lock.unlock()
    }

    func set(film: Film?) {
        lock.lock(); self.film = film; lock.unlock()
    }

    func snapshot() -> (image: CIImage?, film: Film?) {
        lock.lock()
        defer { lock.unlock() }
        return (image, film)
    }
}
