import AVFoundation
import UIKit

/// A short video for sharing: the picture with a white line sweeping across
/// it, the iPhone original on one side and the film on the other, as on a
/// film's page. 4:5 portrait (the shape that fills the feed on Xiaohongshu
/// and Instagram), H.264, about five seconds.
enum ComparisonVideo {
    static let size = CGSize(width: 1080, height: 1350)
    static let fps: Int32 = 30

    /// Where the line is over time (0 = all film, 1 = all iPhone): the
    /// iPhone picture first, the line sweeps across to show the film, rests,
    /// then comes back to the middle so both are seen side by side.
    private static let keys: [(t: Double, split: Double)] = [
        (0, 1), (0.6, 1), (2.2, 0), (3.2, 0), (4.3, 0.5), (5.2, 0.5),
    ]

    private static func split(at t: Double) -> Double {
        guard let i = keys.lastIndex(where: { $0.t <= t }), i + 1 < keys.count else { return keys.last!.split }
        let a = keys[i], b = keys[i + 1]
        let u = (t - a.t) / (b.t - a.t)
        let eased = u * u * (3 - 2 * u)
        return a.split + (b.split - a.split) * eased
    }

    /// Writes the video to a temporary file and returns its address.
    static func make(before: UIImage, after: UIImage, filmName: String) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Koco-\(filmName.replacingOccurrences(of: " ", with: "-"))-\(UUID().uuidString.prefix(6)).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)

        // Any failure or cancellation: stop, and leave no half-written file behind.
        func fail(_ error: Error) -> Error {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            return error
        }
        let frames = Int(keys.last!.t * Double(fps))
        for frame in 0..<frames {
            do { try Task.checkCancellation() } catch { throw fail(error) }
            while !input.isReadyForMoreMediaData {
                if writer.status == .failed { throw fail(writer.error ?? CocoaError(.fileWriteUnknown)) }
                do { try await Task.sleep(for: .milliseconds(5)) } catch { throw fail(error) }
            }
            var buffer: CVPixelBuffer?
            if let pool = adaptor.pixelBufferPool { CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) }
            guard let buffer else { throw fail(CocoaError(.fileWriteOutOfSpace)) }
            draw(into: buffer, before: before, after: after, filmName: filmName,
                 split: split(at: Double(frame) / Double(fps)))
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps)) else {
                throw fail(writer.error ?? CocoaError(.fileWriteUnknown))
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed { throw fail(writer.error ?? CocoaError(.fileWriteUnknown)) }
        return url
    }

    // MARK: Drawing

    private static func draw(into buffer: CVPixelBuffer, before: UIImage, after: UIImage, filmName: String, split: Double) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                      width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return }
        // UIKit drawing, top-left origin.
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        UIColor(red: 0.071, green: 0.067, blue: 0.063, alpha: 1).setFill()
        context.fill(CGRect(origin: .zero, size: size))

        // The picture, fitted into the middle with a margin.
        let margin: CGFloat = 60
        let box = CGRect(x: margin, y: 230, width: size.width - 2 * margin, height: size.height - 230 - 330)
        let aspect = before.size.width / max(before.size.height, 1)
        var frame = CGRect(x: 0, y: 0, width: box.width, height: box.width / aspect)
        if frame.height > box.height { frame.size = CGSize(width: box.height * aspect, height: box.height) }
        frame.origin = CGPoint(x: box.midX - frame.width / 2, y: box.midY - frame.height / 2)

        let rounded = UIBezierPath(roundedRect: frame, cornerRadius: 18)
        context.saveGState()
        rounded.addClip()
        before.draw(in: frame)
        let x = frame.minX + frame.width * split
        context.clip(to: CGRect(x: x, y: frame.minY, width: frame.maxX - x, height: frame.height))
        after.draw(in: frame)
        context.restoreGState()

        // The line and its knob.
        context.setShadow(offset: .zero, blur: 8, color: UIColor.black.withAlphaComponent(0.45).cgColor)
        UIColor.white.setFill()
        context.fill(CGRect(x: x - 2, y: frame.minY, width: 4, height: frame.height))
        let knob = CGRect(x: x - 34, y: frame.midY - 34, width: 68, height: 68)
        UIColor(white: 1, alpha: 0.94).setFill()
        context.fillEllipse(in: knob)
        context.setShadow(offset: .zero, blur: 0, color: nil)
        if let arrows = UIImage(systemName: "arrow.left.and.right",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .bold))?
            .withTintColor(UIColor(white: 0.12, alpha: 1), renderingMode: .alwaysOriginal) {
            arrows.draw(in: CGRect(x: knob.midX - arrows.size.width / 2, y: knob.midY - arrows.size.height / 2,
                                   width: arrows.size.width, height: arrows.size.height))
        }

        // Tags over the picture, as on the film's page.
        tag("iPhone", at: CGPoint(x: frame.minX + 18, y: frame.minY + 18), alignRight: false)
        tag("Koco " + filmName, at: CGPoint(x: frame.maxX - 18, y: frame.minY + 18), alignRight: true)

        // The film's name under the picture, and the app's name at the top.
        let accent = UIColor(red: 0.94, green: 0.64, blue: 0.28, alpha: 1)
        text("KOCO", size: 30, weight: .bold, color: accent, kern: 9, centreAt: CGPoint(x: size.width / 2, y: 130))
        text(filmName, size: 64, weight: .bold, color: UIColor(white: 0.93, alpha: 1), kern: 0,
             centreAt: CGPoint(x: size.width / 2, y: frame.maxY + 110))
        text("iPhone  →  Koco", size: 28, weight: .medium, color: UIColor(white: 0.6, alpha: 1), kern: 2,
             centreAt: CGPoint(x: size.width / 2, y: frame.maxY + 175))
    }

    private static func tag(_ string: String, at point: CGPoint, alignRight: Bool) {
        let font = UIFont.systemFont(ofSize: 26, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        let textSize = (string as NSString).size(withAttributes: attrs)
        let pill = CGRect(x: alignRight ? point.x - textSize.width - 32 : point.x, y: point.y,
                          width: textSize.width + 32, height: textSize.height + 14)
        let path = UIBezierPath(roundedRect: pill, cornerRadius: pill.height / 2)
        UIColor.black.withAlphaComponent(0.55).setFill(); path.fill()
        UIColor.white.withAlphaComponent(0.5).setStroke(); path.lineWidth = 2; path.stroke()
        (string as NSString).draw(at: CGPoint(x: pill.minX + 16, y: pill.minY + 7), withAttributes: attrs)
    }

    private static func text(_ string: String, size: CGFloat, weight: UIFont.Weight, color: UIColor, kern: CGFloat,
                             centreAt point: CGPoint) {
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size, weight: weight),
                                                    .foregroundColor: color, .kern: kern]
        let s = (string as NSString).size(withAttributes: attrs)
        (string as NSString).draw(at: CGPoint(x: point.x - s.width / 2, y: point.y - s.height / 2), withAttributes: attrs)
    }
}
