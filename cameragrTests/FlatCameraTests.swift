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

/// Open flat but held like a camera, then the bag's key (user 11/28: only
/// half the screen changed, turned the wrong way).
@MainActor
struct FlatHeldCameraTests {
    @Test func flatHingeHeldLikeACameraShowsTheCamera() {
        let posture = Posture(testingHinge: .flat, hingeLevel: true)
        #expect(posture.mode == .half)
        #expect(posture.hingeFlat)
        #expect(!posture.showsLibrary)
    }

    @Test func bagKeyReturnsTheWholeScreenBag() {
        let posture = Posture(testingHinge: .flat, hingeLevel: true)
        let model = CameraModel()
        model.showBag(.club, posture: posture)
        #expect(posture.mode == .flat)
        #expect(posture.showsLibrary)
        #expect(model.libraryStart?.spread == .club)
        #expect(model.bag == nil)   // not drawn over the half layout
    }

    @Test func realHalfFoldStillOpensTheBagOverTheCamera() {
        let posture = Posture(testingHinge: .half, hingeLevel: true)
        let model = CameraModel()
        model.showBag(.club, posture: posture)
        #expect(posture.mode == .half)
        #expect(model.bag?.spread == .club)
    }

    @Test func cameraEntryUnpinsTheBag() {
        let posture = Posture(testingHinge: .flat, hingeLevel: true)
        #expect(posture.pinBag())
        #expect(posture.bagPinned)
        posture.unpinBag()   // the camera entry: the hold decides again
        #expect(!posture.bagPinned)
        #expect(posture.mode == .half)
    }
}
