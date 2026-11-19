import Photos

/// Saves finished photos into the system library, inside an album named after the app.
enum PhotoSaver {
    static let albumTitle = "Koco"

    enum SaveError: Error { case denied, failed }

    /// Where to note pictures that were saved but couldn't be put in the album.
    /// The Lock Screen camera sets this to a file in its session folder; the app
    /// reads it once the phone is unlocked and files them (`fileLater(from:)`).
    static var unfiledLog: URL?
    static let unfiledLogName = "unfiled.txt"
    private static let logLock = NSLock()

    static func save(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                completion(.failure(SaveError.denied))
                return
            }
            write(data, intoAlbum: true) { success, error, _ in
                if success {
                    completion(.success(()))
                    return
                }
                // The album can be out of reach (the Lock Screen camera on a locked
                // phone): the picture matters more than where it is filed.
                write(data, intoAlbum: false) { success, retryError, identifier in
                    if success, let identifier { noteUnfiled(identifier) }
                    completion(success ? .success(()) : .failure(retryError ?? error ?? SaveError.failed))
                }
            }
        }
    }

    /// Puts pictures noted in a Lock Screen session's log into the album.
    /// Returns false if the library couldn't be changed, so the log can be kept.
    static func fileLater(from log: URL, completion: @escaping (Bool) -> Void) {
        guard let text = try? String(contentsOf: log, encoding: .utf8) else {
            completion(true)
            return
        }
        let identifiers = text.split(separator: "\n").map(String.init)
        guard !identifiers.isEmpty else {
            completion(true)
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                completion(false)
                return
            }
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            guard assets.count > 0 else {
                completion(true)
                return
            }
            let existing = album()
            PHPhotoLibrary.shared().performChanges({
                let request = existing.map { PHAssetCollectionChangeRequest(for: $0) }
                    ?? PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumTitle)
                request?.addAssets(assets)
            }, completionHandler: { success, _ in completion(success) })
        }
    }

    private static func noteUnfiled(_ identifier: String) {
        guard let log = unfiledLog else { return }
        logLock.lock()
        defer { logLock.unlock() }
        let existing = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        try? (existing + identifier + "\n").write(to: log, atomically: true, encoding: .utf8)
    }

    private static func write(_ data: Data, intoAlbum: Bool,
                              completion: @escaping (Bool, Error?, String?) -> Void) {
        let existing = intoAlbum ? album() : nil
        var identifier: String?
        PHPhotoLibrary.shared().performChanges({
            let creation = PHAssetCreationRequest.forAsset()
            creation.addResource(with: .photo, data: data, options: nil)
            identifier = creation.placeholderForCreatedAsset?.localIdentifier
            guard intoAlbum, let placeholder = creation.placeholderForCreatedAsset else { return }
            let albumRequest: PHAssetCollectionChangeRequest?
            if let existing {
                albumRequest = PHAssetCollectionChangeRequest(for: existing)
            } else {
                albumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumTitle)
            }
            albumRequest?.addAssets([placeholder] as NSArray)
        }, completionHandler: { success, error in completion(success, error, identifier) })
    }

    private static func album() -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", albumTitle)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options).firstObject
    }
}
