import CoreImage
import CoreImage.CIFilterBuiltins
import Metal

/// Applies a film. The viewfinder and the saved photo both go through
/// `filtered(_:film:)`, so what you see is what you get.
///
/// Stocks with grain data go photo -> negative -> + grain -> print, as in
/// Spectral Film LUT's own grain workflow; the grain's strength follows the
/// stock's datasheet granularity at each density and the picture's size
/// (a 36 mm frame across its long side). Other looks are a single cube.
final class FilmRenderer: @unchecked Sendable {   // mutable state is guarded by `lock`
    static let shared = FilmRenderer()

    let device: MTLDevice
    let context: CIContext
    let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    private var filters: [String: CIFilter] = [:]
    /// Films with filters made, latest last; older ones let go (their cubes too).
    private var filterFilms: [String] = []
    private let lock = NSLock()

    /// Film frame width across the picture's long side, mm.
    private static let frameMM: CGFloat = 36

    private static func kernel(_ name: String) -> CIColorKernel? {
        guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? CIColorKernel(functionName: name, fromMetalLibraryData: data)
    }
    private static let grainKernel = kernel("filmGrain")
    private static let falloffKernel = kernel("lensFalloff")
    private static let encodeKernel = kernel("toEncoded")
    private static let ccdKernel = kernel("ccdTexture")

    /// A tile of unit Gaussian noise, one value per channel; tiled across the
    /// picture from a random point each time. (At the library's 6 um grain
    /// size a grain is smaller than a pixel here, and the library then uses
    /// plain per-pixel Gaussian noise.)
    private static let noiseTile: CIImage = {
        let side = 512
        var values = [Float](repeating: 1, count: side * side * 4)
        var rng = SystemRandomNumberGenerator()
        for i in 0..<(side * side) {
            for c in 0..<3 {
                // Box–Muller
                let u1 = max(Float.random(in: 0..<1, using: &rng), 1e-7)
                let u2 = Float.random(in: 0..<1, using: &rng)
                values[i * 4 + c] = sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
            }
        }
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        return CIImage(bitmapData: data, bytesPerRow: side * 16,
                       size: CGSize(width: side, height: side), format: .RGBAf, colorSpace: nil)
    }()

    private init() {
        device = MTLCreateSystemDefaultDevice()!
        context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
    }

    func filtered(_ input: CIImage, film: Film?, iso: Float = 100) -> CIImage {
        guard let film else { return input }
        let image = falloff(input, film: film)
        if film.texture == "ccd", let cube = filter(for: film, stage: nil) {
            return ccd(apply(cube, to: image), iso: iso)
        }
        if film.grain == true, let kernel = Self.grainKernel,
           let negative = filter(for: film, stage: "neg"),
           let intensity = filter(for: film, stage: "grain"),
           let print = filter(for: film, stage: "print") {
            let neg = apply(negative, to: image)
            let strength = apply(intensity, to: neg)
            let extent = image.extent
            let pixelsPerMM = max(extent.width, extent.height) / Self.frameMM
            let noise = noiseField(extent)
            if let grained = kernel.apply(extent: extent,
                                          arguments: [neg, strength, noise, Float(pixelsPerMM * 0.001)]) {
                return apply(print, to: grained)
            }
        }
        guard let single = filter(for: film, stage: nil) else { return image }
        return apply(single, to: image)
    }

    /// The lens's natural vignetting (cos^4 law), in linear light before the
    /// film, on a 36 mm frame across the long side. The phone's own lens
    /// shading is already corrected, so this puts back what a film camera's
    /// lens would have given; a 35 mm lens darkens the corners by ~0.9 stop.
    private func falloff(_ image: CIImage, film: Film) -> CIImage {
        guard let focal = film.lens, let kernel = Self.falloffKernel else { return image }
        let extent = image.extent
        let center = CIVector(x: extent.midX, y: extent.midY)
        let mmPerPixel = Float(Self.frameMM / max(extent.width, extent.height))
        return kernel.apply(extent: extent, arguments: [image, center, mmPerPixel, Float(focal)]) ?? image
    }

    // MARK: - CCD

    /// Sony DSC-T10 (2006, 7 MP, 3072 px across), measured on Imaging
    /// Resource's samples, in its own pixels:
    /// - Sharpening, from a slanted-edge profile on the test chart: a 1.0 px
    ///   blur, then an unsharp mask of amount 6 at 0.71 px and -0.24 at 3.75 px
    ///   (fit within 2.9/255; white overshoots 227 -> 248, black dips 37 -> 14).
    /// - Noise, from 100 % crops of skin at ISO 80-1000: luma stays ~1.8/255
    ///   (noise reduction), colour blotches grow from 0.7 to 2.7/255; grain is
    ///   about 0.76 px (lag-1 correlation 0.65), blotches about 2 px.
    /// Scaled to the picture by its long side. The phone's ISO is turned into
    /// the T10's for the same scene: its f/3.5 lens gets ~4x less light than
    /// the phone's f/1.78.
    private static let t10Width: CGFloat = 3072
    private static let chromaByISO: [(iso: Float, std: Float)] = [(80, 0.74), (200, 1.65), (400, 1.85), (1000, 2.7)]

    private func ccd(_ image: CIImage, iso: Float) -> CIImage {
        guard let encode = Self.encodeKernel, let kernel = Self.ccdKernel,
              let encoded = encode.apply(extent: image.extent, arguments: [image]) else { return image }
        let extent = image.extent
        let scale = max(extent.width, extent.height) / Self.t10Width
        func blur(_ img: CIImage, _ sigma: CGFloat) -> CIImage {
            img.clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: sigma * scale])
                .cropped(to: extent)
        }
        let base = blur(encoded, 1.0)
        let near = blur(encoded, hypot(1.0, 0.706))
        let wide = blur(encoded, hypot(1.0, 3.75))

        let t10ISO = min(max(iso * 4, 80), 1000)
        let table = Self.chromaByISO
        var chroma = table.last!.std
        for (a, b) in zip(table, table.dropFirst()) where t10ISO <= b.iso {
            chroma = a.std + (b.std - a.std) * (t10ISO - a.iso) / (b.iso - a.iso); break
        }
        // Unit white noise blurred by sigma keeps 1 / (2 sqrt(pi) sigma) of its spread.
        func noise(_ sigma: CGFloat) -> (CIImage, Float) {
            let s = max(sigma * scale, 0.5)
            return (blur(noiseField(extent), sigma), Float(2 * sqrt(CGFloat.pi) * s))
        }
        let (luma, lumaGain) = noise(0.76)
        let (blotch, chromaGain) = noise(2.0)
        return kernel.apply(extent: extent, arguments: [
            base, near, wide, luma, blotch, Float(6.0), Float(-0.243),
            Float(1.8 / 255) * lumaGain, chroma / 255 * chromaGain,
        ]) ?? image
    }

    /// The noise tile spread over `extent` from a random point.
    private func noiseField(_ extent: CGRect) -> CIImage {
        let tile = Self.noiseTile
        return tile
            .applyingFilter("CIAffineTile", parameters: [kCIInputTransformKey: CGAffineTransform.identity])
            .transformed(by: CGAffineTransform(translationX: extent.minX - .random(in: 0..<tile.extent.width),
                                               y: extent.minY - .random(in: 0..<tile.extent.height)))
            .cropped(to: extent)
    }

    private func apply(_ filter: CIFilter, to image: CIImage) -> CIImage {
        lock.lock()
        defer { lock.unlock() }
        filter.setValue(image, forKey: kCIInputImageKey)
        let output = filter.outputImage ?? image
        filter.setValue(nil, forKey: kCIInputImageKey)
        return output
    }

    private func filter(for film: Film, stage: String?) -> CIFilter? {
        let key = stage.map { "\(film.id)_\($0)" } ?? film.id
        lock.lock()
        defer { lock.unlock() }
        if let cached = filters[key] { return cached }
        guard let cube = FilmLibrary.shared.cube(for: film, stage: stage) else { return nil }
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.cubeDimension = Float(film.lutSize)
        filter.cubeData = cube
        filter.colorSpace = sRGB
        filters[key] = filter
        filterFilms.removeAll { $0 == film.id }
        filterFilms.append(film.id)
        while filterFilms.count > FilmLibrary.cubeFilmsKept {
            let old = filterFilms.removeFirst()
            filters = filters.filter { $0.key != old && !$0.key.hasPrefix(old + "_") }
        }
        return filter
    }
}

/// Latest camera frame and selected film, shared between the capture queue and the view.
final class FrameStore {
    private let lock = NSLock()
    private var image: CIImage?
    private var iso: Float = 100
    private var film: Film?
    /// Counts camera frames, so a redraw of the same frame can be told apart.
    private(set) var sequence = 0

    func set(image: CIImage, iso: Float) {
        lock.lock(); self.image = image; self.iso = iso; sequence &+= 1; lock.unlock()
    }

    func currentSequence() -> Int {
        lock.lock(); defer { lock.unlock() }
        return sequence
    }

    func set(film: Film?) {
        lock.lock(); self.film = film; lock.unlock()
    }

    func snapshot() -> (image: CIImage?, film: Film?, iso: Float) {
        lock.lock()
        defer { lock.unlock() }
        return (image, film, iso)
    }
}
