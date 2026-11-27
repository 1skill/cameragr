import Testing
import UIKit
@testable import cameragr

/// The upright films page: rolls on shelves by kind, all on one screen.
@MainActor
struct FilmShelfTests {
    let films = FilmLibrary.shared.films

    @Test func everyFilmSaysItsShelf() {
        for film in films {
            #expect(film.shelf.flatMap(Film.Shelf.init(rawValue:)) != nil, "\(film.id) needs a shelf in films.json")
        }
        #expect(films.first { $0.id == "trix400" }?.shelfKind == .bw)
        #expect(films.first { $0.id == "velvia50" }?.shelfKind == .slide)
        #expect(films.first { $0.id == "ccd" }?.shelfKind == .instant)
        #expect(films.first { $0.id == "portra400" }?.shelfKind == .neg)
    }

    @Test func rollsFitOnFourShelves() {
        let rows = UprightFilms.rows(films)
        #expect(rows.count <= 4)
        #expect(rows.allSatisfy { $0.films.count <= UprightFilms.columns })
        // Every roll once, kinds in order, each kind labelled where it starts.
        #expect(rows.flatMap(\.films).map(\.id).sorted() == films.map(\.id).sorted())
        let kinds = rows.flatMap { row in row.starts.keys.sorted().compactMap { row.starts[$0] } }
        #expect(kinds == Film.Shelf.allCases.filter { kind in films.contains { $0.shelfKind == kind } })
        for row in rows {
            for (i, roll) in row.films.enumerated() {
                let kindStart = row.starts.keys.filter { $0 <= i }.max()
                #expect(kindStart.flatMap { row.starts[$0] } == roll.shelfKind || kindStart == nil)
            }
        }
    }

    @Test func aKindThatFitsSharesAShelf() {
        let rows = UprightFilms.rows(films)
        let shared = rows.first { $0.starts.count > 1 }
        #expect(shared != nil)
        #expect(Set(shared?.starts.values.map(\.self) ?? []) == [.slide, .bw])
    }

    @Test func nameLineCarriesTheSpeed() {
        for film in films {
            #expect(UprightFilms.nameLine(film).contains(String(film.iso)))
        }
    }

    @Test func shelfArtIsBundled() {
        for name in ["shelf_lip", "shelf_cradle", "shelf_cradle_lit", "shelf_divider", "shelf_tab", "shelf_label",
                     "film_card", "compare_handle", "compare_handle_down", "allfilms_plate"] {
            #expect(UIImage(named: name) != nil, "\(name) missing")
        }
        #expect(UprightFilms.scenes.count == UprightFilms.sceneFiles.count)
    }

    @Test func shelvesFitEveryUprightPhone() {
        // Narrowest upright phone: each roll's touch area stays at least 44 pt.
        for width in [375.0, 402, 440] {
            let slot = (width - 24) / Double(UprightFilms.columns)
            #expect(slot >= 44)
        }
    }
}
