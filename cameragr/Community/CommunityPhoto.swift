import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A picture made ready to post: a JPEG at most 1600 px on its long side and
/// a 400 px thumbnail, both without GPS or any other metadata
/// (project/community-api.md, “照片”).
enum CommunityPhoto {
    static let long: CGFloat = 1600
    static let thumbLong: CGFloat = 400

    /// Returns (photo, thumb), or nil if the data is not a picture.
    static func prepare(_ data: Data) -> (photo: Data, thumb: Data)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let photo = jpeg(source, long: long, quality: 0.82),
              let thumb = jpeg(source, long: thumbLong, quality: 0.75) else { return nil }
        return (photo, thumb)
    }

    private static func jpeg(_ source: CGImageSource, long: CGFloat, quality: CGFloat) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // upright, so no orientation tag is needed
            kCGImageSourceThumbnailMaxPixelSize: long,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        // Only the pixels: no GPS, no EXIF, no maker notes.
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
