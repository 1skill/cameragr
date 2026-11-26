import Testing
@testable import cameragr

/// The bag's Camera entry (user 11/26).
@MainActor
struct FlatCameraTests {
    @Test func cameraEntryNeedsTheFlatPhone() {
        let posture = Posture.shared
        // The test host is not open flat: the Camera entry takes nothing.
        posture.setFlatCamera(true)
        #expect(!posture.flatCamera)
        #expect(posture.showsLibrary == (posture.mode == .flat))
    }

    @Test func cameraEntryLeavesTheBagWithoutLoading() {
        let model = CameraModel()
        model.lookedAt = model.films.last
        model.bag = CameraModel.BagOpening(spread: .films, look: nil)
        model.leaveBag()
        #expect(model.bag == nil)
        #expect(model.readyToLoad == nil)
    }

    @Test func bagShownFromFlatCameraNeedsNoLibraryStartElsewhere() {
        let model = CameraModel()
        model.libraryStart = nil
        model.showBag(.club)   // not in the flat camera: opens over the camera as before
        #expect(model.bag?.spread == .club)
        #expect(model.libraryStart == nil)
    }
}
