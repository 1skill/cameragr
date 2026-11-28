import Testing
import UIKit
@testable import cameragr

/// The upright films page: rolls standing on ledges by kind, four to a ledge.
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

    @Test func rollsSitOnLedgesByKind() {
        let rows = UprightFilms.rows(films)
        #expect(UprightFilms.columns == 4)
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
        // On a five-wide ledge three slides and two black-and-white rolls fit together.
        let rows = UprightFilms.rows(films, columns: 5)
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
        for name in ["cab_ledge", "shelf_clip_lit", "shelf_divider", "cab_tab_up", "cab_tab_down",
                     "cab_back", "cab_frame", "cab_sill", "cab_stile_l", "cab_stile_r", "cab_top", "cab_plinth",
                     "film_card", "compare_handle", "compare_handle_down", "allfilms_plate"] {
            #expect(UIImage(named: name) != nil, "\(name) missing")
        }
        #expect(UprightFilms.scenes.count == UprightFilms.sceneFiles.count)
    }

    @Test func shelvesFitEveryUprightPhone() {
        // Narrowest upright phone: each roll's touch area stays at least 44 pt.
        for width in [375.0, 402, 440] {
            let slot = (width - 32) / Double(UprightFilms.columns)
            #expect(slot >= 44)
        }
    }
}
