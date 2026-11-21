import StoreKitTest
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

    /// Purchases go to the local StoreKit configuration, with no dialogs.
    let session: SKTestSession

    /// Every test starts from no purchases and no trials used.
    init() async throws {
        session = try SKTestSession(configurationFileNamed: "Koco")
        session.disableDialogs = true
        session.clearTransactions()
        await store.resetDebugState()
        await store.refresh()
    }

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

    @Test func failedTrialShotIsGivenBack() throws {
        let film = try #require(store.paidFilms.first)
        #expect(store.useTrial(film))
        store.returnTrial(film)
        #expect(store.trialsLeft(film) == FilmStore.trialShots)
        store.returnTrial(film)   // nothing to give back: never above the allowance
        #expect(store.trialsLeft(film) == FilmStore.trialShots)
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

/// Purchases against the local StoreKit configuration (Config/Koco.storekit):
/// real `Product.purchase()` calls, with refunds and Ask to Buy simulated.
@Suite("StoreKit", .serialized)
@MainActor
struct StoreKitTests {
    let store = FilmStore.shared
    let session: SKTestSession

    init() async throws {
        session = try SKTestSession(configurationFileNamed: "Koco")
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.clearTransactions()
        await store.resetDebugState()
        await store.refresh()
    }

    private func paidFilm() throws -> Film { try #require(store.paidFilms.first) }

    @Test func everyPaidFilmHasAProduct() {
        for film in store.paidFilms { #expect(store.products[FilmStore.productID(film)] != nil, "\(film.id)") }
        #expect(store.products[FilmStore.allFilmsID] != nil)
        #expect(store.products.count == store.paidFilms.count + 1)
    }

    @Test func buyingUnlocksAndRefundTakesItBack() async throws {
        let film = try paidFilm()
        #expect(await store.buy(film))
        #expect(store.isUnlocked(film))
        let transaction = try #require(session.allTransactions().first { $0.productIdentifier == FilmStore.productID(film) })
        try session.refundTransaction(identifier: UInt(transaction.identifier))
        await store.refresh()   // what restore does after asking the App Store
        #expect(!store.isUnlocked(film))
    }

    @Test func askToBuyWaitsForApproval() async throws {
        let film = try paidFilm()
        session.askToBuyEnabled = true
        #expect(await store.buy(film) == false)
        #expect(store.awaitingApproval.contains(FilmStore.productID(film)))
        #expect(!store.isUnlocked(film))
        let pending = try #require(session.allTransactions().first { $0.productIdentifier == FilmStore.productID(film) })
        try session.approveAskToBuyTransaction(identifier: UInt(pending.identifier))
        // The approved purchase arrives through Transaction.updates.
        for _ in 0..<50 where !store.isUnlocked(film) { try await Task.sleep(for: .milliseconds(100)) }
        #expect(store.isUnlocked(film))
        #expect(!store.awaitingApproval.contains(FilmStore.productID(film)))
    }

    @Test func allFilmsUnlocksEveryPaidFilm() async {
        #expect(await store.buy(nil))
        #expect(store.paidFilms.allSatisfy(store.isUnlocked))
    }

    @Test func restoreBringsBackWhatWasBought() async throws {
        let film = try paidFilm()
        #expect(await store.buy(film))
        #expect(await store.buy(nil))
        // A fresh install: the purchases are with the App Store, not on the phone.
        UserDefaults.standard.removeObject(forKey: "store.owned")
        var synced = false
        store.syncWithAppStore = { synced = true }
        defer { store.syncWithAppStore = { try await AppStore.sync() } }
        await store.restore()
        #expect(synced)
        #expect(store.isUnlocked(film))
        #expect(store.ownsAll)
    }

    @Test func cancelledPurchaseChangesNothing() async throws {
        let film = try paidFilm()
        session.failTransactionsEnabled = true
        session.failureError = .paymentCancelled
        defer { session.failTransactionsEnabled = false }
        #expect(await store.buy(film) == false)
        #expect(!store.isUnlocked(film))
        #expect(store.trialsLeft(film) == FilmStore.trialShots)
        #expect(store.awaitingApproval.isEmpty)
    }

    @Test func refundArrivesWithoutAsking() async throws {
        let film = try paidFilm()
        #expect(await store.buy(film))
        let transaction = try #require(session.allTransactions().first { $0.productIdentifier == FilmStore.productID(film) })
        try session.refundTransaction(identifier: UInt(transaction.identifier))
        // No refresh here: the refund has to come in through Transaction.updates.
        for _ in 0..<50 where store.isUnlocked(film) { try await Task.sleep(for: .milliseconds(100)) }
        #expect(!store.isUnlocked(film))
    }

    @Test func lockScreenGetsTheNewestStateAfterAFailure() async throws {
        let film = try paidFilm()
        var sent: [CaptureContext] = []
        var calls = 0
        store.publishContext = { context in
            calls += 1
            if calls == 1 { throw CocoaError(.fileWriteUnknown) }   // the first update fails
            sent.append(context)
        }
        defer { store.publishContext = { try await PeliCaptureIntent.updateAppContext($0) } }
        #expect(store.useTrial(film))
        #expect(store.useTrial(film))
        #expect(await store.buy(film))
        for _ in 0..<60 where sent.last?.owned.contains(FilmStore.productID(film)) != true {
            try await Task.sleep(for: .milliseconds(100))
        }
        let last = try #require(sent.last)
        #expect(last.owned.contains(FilmStore.productID(film)))
        #expect(last.trialsUsed[film.id] == 2)
    }
}

/// The fold rules: closing acts at once, everything else must hold first,
/// and the waist-level finder is hard to leave by accident.
@Suite("Folding")
struct FoldTests {
    @Test func closingActsAtOnce() {
        var t = FoldTracker(mode: .flat)
        let changed = t.read(.closed, at: 0)
        #expect(changed)
        #expect(t.mode == .closed)
    }

    @Test func openingFlatPassesThroughHalfWithoutStopping() {
        // Opening a closed phone flat goes through "partially open" briefly.
        var t = FoldTracker(mode: .closed)
        t.read(.partial, at: 0)
        t.read(.full, at: 0.3)          // before half would have taken effect
        #expect(t.mode == .closed)
        t.tick(at: 0.6)
        #expect(t.mode == .closed)      // flat needs 0.4 s of its own
        t.tick(at: 0.71)
        #expect(t.mode == .flat)
    }

    @Test func waistLevelSurvivesWobbles() {
        var t = FoldTracker(mode: .half)
        // The hinge brushes fully open for a moment, several times over a minute.
        for second in stride(from: 0.0, to: 60, by: 2) {
            t.read(.full, at: second)
            t.tick(at: second + 0.5)
            t.read(.partial, at: second + 0.6)
            t.tick(at: second + 1.9)
        }
        #expect(t.mode == .half)
    }

    @Test func waistLevelLeavesForTheLibraryWhenHeldOpen() {
        var t = FoldTracker(mode: .half)
        t.read(.full, at: 10)
        t.tick(at: 10.9)
        #expect(t.mode == .half)
        t.tick(at: 11.0)
        #expect(t.mode == .flat)
    }

    @Test func libraryIsNotLeftForASlightClosing() {
        var t = FoldTracker(mode: .flat)
        t.read(.partial, at: 0)
        t.read(.full, at: 0.5)
        t.tick(at: 2)
        #expect(t.mode == .flat)
    }

    @Test func nothingButClosingChangesTheModeDuringAShot() {
        var t = FoldTracker(mode: .half)
        t.holdForShot = true
        t.read(.full, at: 0)
        t.tick(at: 5)
        #expect(t.mode == .half)
        t.holdForShot = false
        t.tick(at: 5.01)
        #expect(t.mode == .flat)         // held long enough meanwhile
        t.holdForShot = true
        let closed = t.read(.closed, at: 6)
        #expect(closed)                  // closing still acts
    }

    @Test func unknownReadingsChangeNothing() {
        var t = FoldTracker(mode: .half)
        let changed = t.read(.unknown, at: 0)
        #expect(!changed)
        t.tick(at: 10)
        #expect(t.mode == .half)
        #expect(t.nextDeadline == nil)
    }
}

/// The library's promise: looking changes nothing, choosing loads on closing.
@Suite("Film library", .serialized)
@MainActor
struct RollLibraryTests {
    let model = CameraModel()

    private func other(than film: Film?) throws -> Film {
        try #require(model.films.first { $0 != film })
    }

    @Test func closingWithoutChoosingKeepsTheRoll() {
        let before = model.film
        model.foldChanged(to: .flat)
        model.foldChanged(to: .closed)
        #expect(model.film == before)
        #expect(model.readyToLoad == nil)
    }

    @Test func aChosenRollGoesInOnClosing() throws {
        let next = try other(than: model.film)
        model.foldChanged(to: .flat)
        model.chooseInLibrary(next)
        #expect(model.readyToLoad == next)
        #expect(model.film != next)            // not yet: still in the library
        model.foldChanged(to: .closed)
        #expect(model.film == next)
        #expect(model.readyToLoad == nil)
    }

    @Test func aChosenRollGoesInForTheWaistLevelFinderToo() throws {
        let next = try other(than: model.film)
        model.chooseInLibrary(next)
        model.foldChanged(to: .half)
        #expect(model.film == next)
    }

    @Test func choosingAgainTakesTheChoiceBack() throws {
        let before = model.film
        let next = try other(than: before)
        model.chooseInLibrary(next)
        model.chooseInLibrary(next)
        model.foldChanged(to: .closed)
        #expect(model.film == before)
    }

    @Test func choosingTheLoadedRollChangesNothing() throws {
        let loaded = try #require(model.film)
        model.chooseInLibrary(loaded)
        #expect(model.readyToLoad == nil)
    }
}

@Suite("Shot log")
@MainActor
struct ShotLogTests {
    @Test func remembersEachPicturesFilmAcrossLaunches() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shots-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let log = ShotLog(url: url)
        log.add(asset: "a", film: "portra400", date: Date(timeIntervalSince1970: 1))
        log.add(asset: "b", film: "ccd", date: Date(timeIntervalSince1970: 2))
        log.add(asset: "c", film: "portra400", date: Date(timeIntervalSince1970: 3))
        let again = ShotLog(url: url)
        #expect(again.assets(for: "portra400") == ["c", "a"])   // newest first
        #expect(again.assets(for: "ccd") == ["b"])
    }
}

@Suite("Shot log from the Lock Screen")
@MainActor
struct LockScreenShotLogTests {
    @Test func lockScreenShotsComeInOnce() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shots-\(UUID().uuidString).json")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("session-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: folder) }
        try "x1\tccd\t100\nx2\tgrneg\t200\n".write(to: folder.appendingPathComponent(ShotLog.lockScreenLogName),
                                                  atomically: true, encoding: .utf8)
        let log = ShotLog(url: url)
        log.addLockScreenShots(from: folder)
        log.addLockScreenShots(from: folder)   // read again: nothing doubles
        #expect(log.assets(for: "ccd") == ["x1"])
        #expect(log.assets(for: "grneg") == ["x2"])
    }
}

/// Measured on the phone: the hinge can read "closed" at 84° while the
/// interface is already on the inner screen. The screen decides open or closed.
@Suite("Folding: screen decides")
struct FoldScreenTests {
    @Test func innerScreenIsNeverTheClosedBody() {
        let t = FoldTracker(mode: .closed)
        #expect(t.shown(onInnerScreen: true) == .half)
        #expect(t.shown(onInnerScreen: false) == .closed)
    }

    @Test func outerScreenIsAlwaysTheBody() {
        #expect(FoldTracker(mode: .flat).shown(onInnerScreen: false) == .closed)
        #expect(FoldTracker(mode: .half).shown(onInnerScreen: false) == .closed)
    }

    @Test func innerScreenFollowsTheHingeForHalfOrFlat() {
        #expect(FoldTracker(mode: .flat).shown(onInnerScreen: true) == .flat)
        #expect(FoldTracker(mode: .half).shown(onInnerScreen: true) == .half)
    }
}
