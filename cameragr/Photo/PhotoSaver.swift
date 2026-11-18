import Photos

/// Saves finished photos into the system library, inside an album named after the app.
enum PhotoSaver {
    static let albumTitle = "Peli"

    enum SaveError: Error { case denied, failed }

    static func save(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                completion(.failure(SaveError.denied))
                return
            }
            let existing = album()
            PHPhotoLibrary.shared().performChanges({
                let creation = PHAssetCreationRequest.forAsset()
                creation.addResource(with: .photo, data: data, options: nil)
                guard let placeholder = creation.placeholderForCreatedAsset else { return }
                let albumRequest: PHAssetCollectionChangeRequest?
                if let existing {
                    albumRequest = PHAssetCollectionChangeRequest(for: existing)
                } else {
                    albumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumTitle)
                }
                albumRequest?.addAssets([placeholder] as NSArray)
            }, completionHandler: { success, error in
                completion(success ? .success(()) : .failure(error ?? SaveError.failed))
            })
        }
    }

    private static func album() -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", albumTitle)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options).firstObject
    }
}
