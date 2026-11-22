import Testing
import UIKit
@testable import cameragr

@MainActor
struct ShareLetterTests {
    @Test func letterIsAFourByFiveCardForAnyPicture() {
        for size in [CGSize(width: 1350, height: 900), CGSize(width: 900, height: 1350)] {
            let picture = UIGraphicsImageRenderer(size: size).image { ctx in
                UIColor.red.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            }
            let letter = ShareLetter.make(photo: picture, filmID: "gold200", filmName: "Golden 200", line: 1)
            #expect(letter.size == CGSize(width: 1080, height: 1350))
        }
    }

    @Test func everyLineIsThereAndAnOutOfRangeLineIsSafe() {
        #expect(ShareLetter.lines.count == 2)
        let picture = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in }
        let letter = ShareLetter.make(photo: picture, filmID: nil, filmName: "Koco", line: 9)
        #expect(letter.size.width == 1080)
    }
}

@MainActor
struct OwnPhotoTests {
    /// A photo tried on a film comes back whole when saved: the full size, not the preview's.
    @Test func savingKeepsTheFullSize() throws {
        let size = CGSize(width: 3000, height: 2000)
        let picture = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).image { ctx in
            UIColor.orange.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
        let data = try #require(picture.jpegData(compressionQuality: 0.9))
        let film = try #require(FilmLibrary.shared.films.first)
        let jpeg = try #require(FilmRendering.fullSize(data, film: film))
        let out = try #require(UIImage(data: jpeg))
        #expect(out.size.width * out.scale == 3000)
        #expect(out.size.height * out.scale == 2000)
    }
}
