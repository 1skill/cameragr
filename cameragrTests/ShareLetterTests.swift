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

/// The widgets (blueprint 1.16): four pockets on the medium, nine on the
/// large; picks in order, no roll twice, gaps stay gaps; every roll opens its film.
@MainActor
struct WidgetTests {
    let all = FilmLibrary.shared.films

    @Test func picksKeepTheirOrderAndNoRollTwice() throws {
        let a = all[3].id, b = all[0].id
        let picked = try #require(ShelfProvider.picked([a, b, a, "gone"], from: all))
        #expect(picked.map(\.id) == [a, b])
        #expect(ShelfProvider.picked([], from: all) == nil)
        #expect(ShelfProvider.picked(["gone"], from: all) == nil)
    }

    @Test func pocketsAreFourAndNineWithGapsKept() {
        #expect(WidgetArt.medium.pockets.count == 4)
        #expect(WidgetArt.large.pockets.count == 9)
        #expect(WidgetArt.medium.labels.count == 4 && WidgetArt.large.labels.count == 9)
        let two = FilmShelfView.places(Array(all.prefix(2)), pockets: 4)
        #expect(two.count == 4 && two[2] == nil && two[3] == nil)
        let many = FilmShelfView.places(all, pockets: 9)
        #expect(many.compactMap { $0 }.count == 9)
    }

    /// A roll chosen in the bag, then another tapped on a widget: the widget's wins.
    @Test func aWidgetRollReplacesOneWaitingToLoad() throws {
        let model = CameraModel()
        let a = try #require(all.first { $0 != model.film }), b = try #require(all.first { $0 != model.film && $0 != a })
        model.chooseInLibrary(a)
        #expect(model.readyToLoad == a)
        model.open(link(to: b))
        #expect(model.readyToLoad == nil)
        #expect(model.film == b)
    }

    @Test func everyRollOpensItsFilm() {
        let model = CameraModel()
        model.openBag(.films)
        for film in all {
            let url = link(to: film)
            #expect(url.absoluteString == "peli://film/\(film.id)")
            model.open(url)
            #expect(model.bag == nil, "the bag closes: back to the camera")
            #expect(model.film == film, "a roll on a widget loads that roll (trial shots apply when shooting)")
        }
    }
}
