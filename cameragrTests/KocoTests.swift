import CoreImage
import Foundation
import Testing
@testable import cameragr

/// The safety net for unattended work: purchases, the film catalogue and its
/// data, rendering and localisation. Run with `tools/test.sh`.

@MainActor
@Suite("Purchases and trial shots", .serialized)
struct StoreTests {
    let store = FilmStore.shared
    let films = FilmLibrary.shared.films

    /// Every test starts from no purchases and no trials used.
    init() async { await store.resetDebugState() }

    @Test func freeFilmsAreAlwaysUnlocked() {
        let free = films.filter { $0.free == true }
        #expect(!free.isEmpty)
        for film in free {
            #expect(store.isUnlocked(film))
            #expect(store.trialsLeft(film) == 0)
        }
    }

    @Test func paidFilmsStartLockedWithThreeTrials() {
        for film in store.paidFilms {
            #expect(!store.isUnlocked(film), "\(film.id) should start locked")
            #expect(store.trialsLeft(film) == FilmStore.trialShots)
        }
    }

    @Test func trialsRunOutAfterThree() throws {
        let film = try #require(store.paidFilms.first)
        for _ in 0..<FilmStore.trialShots { #expect(store.useTrial(film)) }
        #expect(store.trialsLeft(film) == 0)
        #expect(!store.useTrial(film))
        // Other films keep their own trials.
        let other = try #require(store.paidFilms.dropFirst().first)
        #expect(store.trialsLeft(other) == FilmStore.trialShots)
    }

    @Test func buyingAFilmUnlocksOnlyThatFilm() async throws {
        let film = try #require(store.paidFilms.first)
        let other = try #require(store.paidFilms.dropFirst().first)
        #expect(await store.buy(film))
        #expect(store.isUnlocked(film))
        #expect(!store.isUnlocked(other))
        #expect(store.trialsLeft(film) == 0)
    }

    @Test func lockScreenTrialsCountOncePerSession() throws {
        let film = try #require(store.paidFilms.first)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("session-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try "\(film.id)\n\(film.id)\n".write(to: folder.appendingPathComponent(FilmStore.lockScreenTrialLogName),
                                                  atomically: true, encoding: .utf8)
        store.addLockScreenTrials(from: folder)
        #expect(store.trialsLeft(film) == FilmStore.trialShots - 2)
        // The same session read again (e.g. the photos could not be filed yet) counts nothing more.
        store.addLockScreenTrials(from: folder)
        #expect(store.trialsLeft(film) == FilmStore.trialShots - 2)
    }

    @Test func allFilmsUnlocksEverything() async {
        #expect(await store.buy(nil))
        #expect(store.ownsAll)
        for film in films { #expect(store.isUnlocked(film)) }
        #expect(store.ownedPaidCount == store.paidFilms.count)
    }
}

@MainActor
@Suite("Film catalogue and its data")
struct CatalogueTests {
    let films = FilmLibrary.shared.films

    @Test func catalogueLoads() {
        #expect(films.count >= 9)
        #expect(Set(films.map(\.id)).count == films.count, "ids must be unique")
    }

    @Test func everyFilmHasItsCube() {
        for film in films {
            #expect(FilmLibrary.shared.cube(for: film) != nil, "\(film.id).lut missing or wrong size")
        }
    }

    @Test func grainFilmsHaveTheirThreeStages() {
        for film in films where film.grain == true {
            for stage in ["neg", "grain", "print"] {
                #expect(FilmLibrary.shared.cube(for: film, stage: stage) != nil, "\(film.id)_\(stage).lut")
            }
        }
    }

    @Test func everyFilmHasNotesAndSamples() throws {
        for film in films {
            let note = try #require(FilmNotes.all[film.id], "no notes for \(film.id)")
            #expect(!note.tagline.isEmpty && !note.about.isEmpty && !note.suits.isEmpty)
            #expect(!note.samples.isEmpty, "\(film.id) has no samples")
            for sample in note.samples {
                #expect(Bundle.main.url(forResource: sample.file, withExtension: "jpg") != nil, "\(sample.file).jpg")
                #expect((0...1).contains(sample.split))
            }
        }
    }

    @Test func notesDecodeForTheAppLanguage() {
        // FilmNotes.all decoded every film (in the app's language, English as fallback).
        #expect(FilmNotes.all.count == films.count)
    }

    @Test func notesExistInEnglishAndChinese() throws {
        let url = try #require(Bundle.main.url(forResource: "film_notes", withExtension: "json"))
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [String: Any]])
        for film in films {
            let text = try #require(json[film.id]?["text"] as? [String: Any])
            #expect(text["en"] != nil && text["zh-Hans"] != nil, "\(film.id) needs en and zh-Hans")
        }
    }

    @Test func storeProductIdsAreStable() {
        // These are what App Store Connect will hold: changing one strands buyers.
        #expect(FilmStore.allFilmsID == "com.oneskill.cameragr.allfilms")
        let portra = films.first { $0.id == "portra400" }!
        #expect(FilmStore.productID(portra) == "com.oneskill.cameragr.film.portra400")
    }
}

@Suite("Rendering")
struct RenderTests {
    /// Each film's colour at four fixed points of its cube (grey, skin, sky,
    /// red), read when the films were exported. A change here means a film's
    /// look changed: deliberate (re-export, update these) or a mistake.
    static let golden: [String: [String: [Float]]] = [
        "portra400": ["grey": [0.5526, 0.5594, 0.5671], "skin": [0.7273, 0.6353, 0.5554], "sky": [0.5658, 0.6901, 0.8342], "red": [0.7707, 0.2565, 0.1079]],
        "gold200": ["grey": [0.5518, 0.5608, 0.5683], "skin": [0.726, 0.6427, 0.5645], "sky": [0.5959, 0.6874, 0.7978], "red": [0.7817, 0.2519, 0.1023]],
        "c200": ["grey": [0.5789, 0.5838, 0.5796], "skin": [0.8088, 0.6921, 0.5758], "sky": [0.5784, 0.7096, 0.8565], "red": [0.7802, 0.1587, 0.1088]],
        "cine500t": ["grey": [0.5301, 0.5316, 0.5245], "skin": [0.6737, 0.6079, 0.5281], "sky": [0.5593, 0.6356, 0.7107], "red": [0.6926, 0.282, 0.1529]],
        "kodachrome64": ["grey": [0.5129, 0.5363, 0.5679], "skin": [0.6946, 0.6319, 0.5794], "sky": [0.5528, 0.6355, 0.7734], "red": [0.6643, 0.1866, 0.1895]],
        "trix400": ["grey": [0.404, 0.404, 0.404], "skin": [0.4508, 0.4508, 0.4508], "sky": [0.6092, 0.6092, 0.6092], "red": [0.3228, 0.3228, 0.3228]],
        "instax": ["grey": [0.5521, 0.5261, 0.5303], "skin": [0.8096, 0.6687, 0.5303], "sky": [0.5646, 0.6419, 0.8202], "red": [0.7842, 0.2355, 0.1166]],
        "grneg": ["grey": [0.5837, 0.5887, 0.5865], "skin": [0.7116, 0.6312, 0.5652], "sky": [0.5549, 0.6286, 0.7421], "red": [0.8008, 0.3998, 0.286]],
        "ccd": ["grey": [0.5128, 0.5134, 0.5431], "skin": [0.7514, 0.5745, 0.4963], "sky": [0.454, 0.6127, 0.8491], "red": [0.8426, 0.1333, 0.0274]]
    ]

    @Test func cubesMatchTheirGoldenValues() throws {
        let points: [String: (r: Int, g: Int, b: Int)] = ["grey": (16, 16, 16), "skin": (22, 18, 15),
                                                          "sky": (14, 18, 26), "red": (28, 6, 6)]
        for film in FilmLibrary.shared.films {
            let expected = try #require(Self.golden[film.id], "no golden values for \(film.id)")
            let data = try #require(FilmLibrary.shared.cube(for: film))
            let n = film.lutSize
            let values = data.withUnsafeBytes { Array($0.bindMemory(to: Float32.self)) }
            for (name, p) in points {
                let i = ((p.b * n + p.g) * n + p.r) * 4
                let got = Array(values[i..<i + 3])
                let want = try #require(expected[name])
                for c in 0..<3 {
                    #expect(abs(got[c] - want[c]) < 0.002, "\(film.id) \(name) channel \(c): \(got[c]) vs \(want[c])")
                }
            }
        }
    }

    /// Every film turns a mid-grey frame into something sensible: not black,
    /// not blown out, and black-and-white films stay neutral.
    @Test func everyFilmRendersMidGrey() throws {
        let renderer = FilmRenderer.shared
        let grey = CIImage(color: CIColor(red: 0.46, green: 0.46, blue: 0.46))
            .cropped(to: CGRect(x: 0, y: 0, width: 300, height: 200))
        for film in FilmLibrary.shared.films {
            let out = renderer.filtered(grey, film: film, iso: 100)
            var pixel = [Float](repeating: 0, count: 4)
            renderer.context.render(out.cropped(to: CGRect(x: 150, y: 100, width: 1, height: 1)),
                                    toBitmap: &pixel, rowBytes: 16,
                                    bounds: CGRect(x: 150, y: 100, width: 1, height: 1),
                                    format: .RGBAf, colorSpace: renderer.sRGB)
            let mean = (pixel[0] + pixel[1] + pixel[2]) / 3
            #expect((0.2...0.85).contains(mean), "\(film.id) mid-grey came out \(mean)")
            if film.kind == "bw" {
                #expect(abs(pixel[0] - pixel[2]) < 0.02, "\(film.id) should stay neutral")
            }
        }
    }
}

@Suite("Localisation")
struct LocalisationTests {
    @Test func chineseIsBundled() {
        #expect(Bundle.main.localizations.contains("zh-Hans"))
        let zh = Bundle.main.path(forResource: "zh-Hans", ofType: "lproj").flatMap(Bundle.init(path:))
        #expect(zh?.localizedString(forKey: "Films", value: nil, table: nil) == "胶卷")
        #expect(zh?.localizedString(forKey: "Restore purchases", value: nil, table: nil) == "恢复购买")
    }
}
