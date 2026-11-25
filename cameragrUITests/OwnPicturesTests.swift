import XCTest

final class OwnPicturesTests: XCTestCase {
    func testTappingAPictureOpensItLarge() {
        let app = XCUIApplication()
        app.launchArguments = ["-fold", "flat", "-look", "portra400", "-AppleLanguages", "(en)", "-dailyFree", "off"]
        app.launch()
        let photo = app.descendants(matching: .any).matching(identifier: "album-photo").element(boundBy: 4)
        XCTAssertTrue(photo.waitForExistence(timeout: 15), "a picture in the album")
        photo.tap()
        XCTAssertTrue(app.buttons["Full Screen"].waitForExistence(timeout: 5), "the viewer opened")
    }
}
