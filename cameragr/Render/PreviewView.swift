import CoreImage
import MetalKit
import SwiftUI

/// Live viewfinder: draws the latest frame through the film LUT, aspect-filled.
struct PreviewView: UIViewRepresentable {
    let store: FrameStore
    /// Shows the frame's whole short side instead of filling the view. The square
    /// format uses all of it, more than fits when the view is filled.
    var showsFullHeight = false

    func makeUIView(context: Context) -> PreviewMTKView { PreviewMTKView(store: store) }
    func updateUIView(_ uiView: PreviewMTKView, context: Context) { uiView.showsFullHeight = showsFullHeight }
}

final class PreviewMTKView: MTKView, MTKViewDelegate {
    private let store: FrameStore
    var showsFullHeight = false
    private let renderer = FilmRenderer.shared
    private let commandQueue: MTLCommandQueue?

    init(store: FrameStore) {
        self.store = store
        commandQueue = renderer.device.makeCommandQueue()
        super.init(frame: .zero, device: renderer.device)
        framebufferOnly = false
        colorPixelFormat = .bgra8Unorm
        preferredFramesPerSecond = 30
        backgroundColor = .black
        isOpaque = true
        delegate = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    #if DEBUG
    /// Finder speed, written to Diag every two seconds: frames drawn per
    /// second and the GPU's time per frame, for the film being shown.
    static let meter = FinderMeter()
    final class FinderMeter: @unchecked Sendable {
        private let lock = NSLock()
        private var frames = 0          // new camera frames shown
        private var repeats = 0         // redraws of a frame already shown
        private var lastSequence = -1
        private var lastNew = CACurrentMediaTime()
        private var longestGap = 0.0
        private var gpu: [Double] = []
        private var since = CACurrentMediaTime()
        func frame(film: String, sequence: Int, buffer: MTLCommandBuffer) {
            buffer.addCompletedHandler { [weak self] done in
                guard let self else { return }
                let ms = (done.gpuEndTime - done.gpuStartTime) * 1000
                self.lock.lock(); defer { self.lock.unlock() }
                let now = CACurrentMediaTime()
                if sequence != self.lastSequence {
                    self.frames += 1
                    self.longestGap = max(self.longestGap, now - self.lastNew)
                    self.lastNew = now
                    self.lastSequence = sequence
                } else {
                    self.repeats += 1
                }
                if ms > 0 { self.gpu.append(ms) }
                guard now - self.since >= 2 else { return }
                let sorted = self.gpu.sorted()
                let avg = sorted.isEmpty ? 0 : sorted.reduce(0, +) / Double(sorted.count)
                let p95 = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
                Diag.note(String(format: "perf finder %@ %.1f new fps, %d repeats, longest gap %.0f ms, gpu avg %.1f ms p95 %.1f ms",
                                 film, Double(self.frames) / (now - self.since), self.repeats,
                                 self.longestGap * 1000, avg, p95))
                self.frames = 0; self.repeats = 0; self.longestGap = 0; self.gpu = []; self.since = now
            }
        }
    }
    #endif

    /// What the finder shows of a camera frame at `size`: scaled first, so
    /// the film only runs on visible pixels, then through the film. The same
    /// `filtered` as the saved picture (tested against it in RenderTests).
    static func finderImage(_ source: CIImage, film: Film?, iso: Float, size: CGSize,
                            showsFullHeight: Bool, renderer: FilmRenderer) -> CIImage {
        let extent = source.extent
        // Square pictures use the whole of the frame's short side, whichever
        // way the frame lies: on a folding phone's inner screen it arrives upright.
        let scale = showsFullHeight ? size.height / min(extent.width, extent.height)
                                    : max(size.width / extent.width, size.height / extent.height)
        let fitted = source
            .transformed(by: CGAffineTransform(translationX: -extent.midX, y: -extent.midY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: size.width / 2, y: size.height / 2))
            .cropped(to: CGRect(origin: .zero, size: size))
        // Over black: where the frame does not reach, nothing of the last one may stay.
        let view = CGRect(origin: .zero, size: size)
        return renderer.filtered(fitted, film: film, iso: iso)
            .composited(over: CIImage(color: .black).cropped(to: view))
    }

    func draw(in view: MTKView) {
        let size = drawableSize
        guard size.width > 0, size.height > 0,
              let drawable = currentDrawable,
              let buffer = commandQueue?.makeCommandBuffer() else { return }

        let snapshot = store.snapshot()
        guard let source = snapshot.image else { return }
        let image = Self.finderImage(source, film: snapshot.film, iso: snapshot.iso,
                                     size: size, showsFullHeight: showsFullHeight, renderer: renderer)

        let destination = CIRenderDestination(width: Int(size.width),
                                              height: Int(size.height),
                                              pixelFormat: colorPixelFormat,
                                              commandBuffer: buffer) { drawable.texture }
        destination.colorSpace = renderer.sRGB
        _ = try? renderer.context.startTask(toRender: image,
                                            from: CGRect(origin: .zero, size: size),
                                            to: destination,
                                            at: .zero)
        #if DEBUG
        Self.meter.frame(film: snapshot.film?.id ?? "-", sequence: store.currentSequence(), buffer: buffer)
        #endif
        buffer.present(drawable)
        buffer.commit()
    }
}
