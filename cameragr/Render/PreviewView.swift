import CoreImage
import MetalKit
import SwiftUI

/// Live viewfinder: draws the latest frame through the film LUT, aspect-filled.
struct PreviewView: UIViewRepresentable {
    let store: FrameStore

    func makeUIView(context: Context) -> PreviewMTKView { PreviewMTKView(store: store) }
    func updateUIView(_ uiView: PreviewMTKView, context: Context) {}
}

final class PreviewMTKView: MTKView, MTKViewDelegate {
    private let store: FrameStore
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

    func draw(in view: MTKView) {
        let size = drawableSize
        guard size.width > 0, size.height > 0,
              let drawable = currentDrawable,
              let buffer = commandQueue?.makeCommandBuffer() else { return }

        let snapshot = store.snapshot()
        guard let source = snapshot.image else { return }

        // Scale to aspect-fill first so the LUT only runs on visible pixels.
        let extent = source.extent
        let scale = max(size.width / extent.width, size.height / extent.height)
        let fitted = source
            .transformed(by: CGAffineTransform(translationX: -extent.midX, y: -extent.midY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: size.width / 2, y: size.height / 2))
            .cropped(to: CGRect(origin: .zero, size: size))
        let image = renderer.filtered(fitted, film: snapshot.film)

        let destination = CIRenderDestination(width: Int(size.width),
                                              height: Int(size.height),
                                              pixelFormat: colorPixelFormat,
                                              commandBuffer: buffer) { drawable.texture }
        destination.colorSpace = renderer.sRGB
        _ = try? renderer.context.startTask(toRender: image,
                                            from: CGRect(origin: .zero, size: size),
                                            to: destination,
                                            at: .zero)
        buffer.present(drawable)
        buffer.commit()
    }
}
