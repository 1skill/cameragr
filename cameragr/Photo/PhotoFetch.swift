import Photos
import UIKit
import UniformTypeIdentifiers

/// Pictures from Photos, for the app's own pages.
enum PhotoFetch {
    /// A picture's saved file, whole, and its file extension.
    static func original(_ id: String) async -> (Data, String)? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        return await withCheckedContinuation { done in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, _ in
                guard let data else { done.resume(returning: nil); return }
                let ext = uti.flatMap { UTType($0)?.preferredFilenameExtension } ?? "jpg"
                done.resume(returning: (data, ext))
            }
        }
    }

    /// One picture, at about `side` pixels.
    static func image(_ id: String, side: CGFloat) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { done in
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: side, height: side),
                                                  contentMode: .aspectFit, options: options) { picture, _ in
                done.resume(returning: picture)
            }
        }
    }
}
