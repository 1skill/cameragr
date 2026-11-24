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
        FilmStore.dailyFreeOn = false   // purchases and trials without the day's free roll
        FilmStore.today = Date.init
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
        for film in films where !film.isLimited { #expect(store.isUnlocked(film)) }
        for film in films where film.isLimited { #expect(!store.isUnlocked(film), "limited rolls are earned, not bought") }
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
        // (Films not offered yet may already have theirs.)
        #expect(films.allSatisfy { FilmNotes.all[$0.id] != nil })
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
        "ccd": ["grey": [0.5128, 0.5134, 0.5431], "skin": [0.7514, 0.5745, 0.4963], "sky": [0.454, 0.6127, 0.8491], "red": [0.8426, 0.1333, 0.0274]],
        "velvia50": ["grey": [0.5118, 0.5639, 0.5692], "skin": [0.7093, 0.6637, 0.5671], "sky": [0.5467, 0.6531, 0.8266], "red": [0.7761, 0.3149, 0.1968]],
        "fp100c": ["grey": [0.581, 0.5555, 0.5574], "skin": [0.7992, 0.671, 0.5592], "sky": [0.6038, 0.6648, 0.8358], "red": [0.7477, 0.1887, 0.135]],
        "doublex": ["grey": [0.5501, 0.5501, 0.5501], "skin": [0.5835, 0.5835, 0.5835], "sky": [0.7137, 0.7137, 0.7137], "red": [0.4211, 0.4211, 0.4211]],
        "vista100": ["grey": [0.5629, 0.5706, 0.574], "skin": [0.7794, 0.669, 0.5632], "sky": [0.5408, 0.6846, 0.8342], "red": [0.7864, 0.2168, 0.0913]],
        "ektachrome": ["grey": [0.4996, 0.5601, 0.5817], "skin": [0.7028, 0.6593, 0.574], "sky": [0.5173, 0.6408, 0.8244], "red": [0.7078, 0.227, 0.1911]],
        "natura1600": ["grey": [0.5375, 0.5441, 0.5437], "skin": [0.7717, 0.6732, 0.5415], "sky": [0.5484, 0.6804, 0.8701], "red": [0.7693, 0.1624, 0.1172]],
        "pro400h": ["grey": [0.5508, 0.5514, 0.5461], "skin": [0.7737, 0.653, 0.5434], "sky": [0.5325, 0.6668, 0.8016], "red": [0.7693, 0.1665, 0.1578]],
        // The limited rolls: Koco's own looks (tools/creative_looks.py).
        "dusk200": ["grey": [0.5097, 0.4935, 0.5162], "skin": [0.7002, 0.5177, 0.4842], "sky": [0.4731, 0.7632, 0.8071], "red": [0.9150, 0.1843, 0.1892]],
        "ember400": ["grey": [0.5313, 0.5021, 0.5128], "skin": [0.8333, 0.6997, 0.5390], "sky": [0.4927, 0.4522, 0.7296], "red": [1.0000, 0.8811, 0.1556]]
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
        FilmStore.dailyFreeOn = false   // purchases and trials without the day's free roll
        FilmStore.today = Date.init
        await store.resetDebugState()
        await store.refresh()
    }

    /// Not the community's first milestone roll (other tests may give it away).
    private func paidFilm() throws -> Film {
        try #require(store.paidFilms.first { $0.id != Community.Me.milestones.first?.film })
    }

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
        // What restore does after asking the App Store; the refund can take a
        // moment to reach the entitlements, so look again for up to 5 seconds.
        for _ in 0..<50 {
            await store.refresh()
            if !store.isUnlocked(film) { break }
            try await Task.sleep(for: .milliseconds(100))
        }
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

    @Test func productsFailingToLoadKeepPurchasesAndRecover() async throws {
        let film = try paidFilm()
        #expect(await store.buy(film))
        // The App Store out of reach while the app runs (not a cold start
        // offline, which needs the phone): products fail, the purchase stays.
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        store.forgetProductsForTesting()
        await store.refresh()
        #expect(store.productsUnavailable)
        #expect(store.isUnlocked(film))
        // Back online: the next try brings the prices back.
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        await store.loadProductsIfMissing(force: true)
        #expect(!store.productsUnavailable)
        #expect(store.products[FilmStore.productID(film)] != nil)
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

    @Test func aFailedPurchaseIsSaid() async throws {
        let film = try paidFilm()
        defer { session.failTransactionsEnabled = false; store.purchaseProblem = nil }
        store.purchaseProblem = nil
        session.failTransactionsEnabled = true
        session.failureError = .unknown
        #expect(await store.buy(film) == false)
        #expect(store.purchaseProblem != nil, "a failure is said")
        #expect(!store.isUnlocked(film))
    }

    /// Closing the sheet comes back as `.userCancelled` (no error); the
    /// cancel errors StoreKit can also throw are not failures either.
    /// (The test session reports a simulated cancel as `.unknown`, so these
    /// are checked directly.)
    @Test func cancelErrorsAreNotFailures() {
        #expect(FilmStore.isCancel(StoreKitError.userCancelled))
        #expect(FilmStore.isCancel(SKError(.paymentCancelled)))
        #expect(!FilmStore.isCancel(StoreKitError.unknown))
        #expect(!FilmStore.isCancel(StoreKitError.networkError(URLError(.notConnectedToInternet))))
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
    @Test func atLaunchTheFirstReadingIsTakenAtOnce() {
        // Opened flat: the library at once, no stop at the camera on the way.
        var t = FoldTracker(awaitingFirstReading: true)
        let changed = t.read(.full, at: 0)
        #expect(changed)
        #expect(t.mode == .flat)
        // After that the usual waits apply.
        t.read(.partial, at: 1)
        #expect(t.mode == .flat)
    }

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

    /// The Lock Screen camera's FILMS / SETUP: the app opens the bag at that
    /// pair of pages, looking at the roll asked for; nothing is loaded.
    @Test func theLockScreenOpensTheBagAtItsPages() throws {
        let before = model.film
        let roll = try other(than: before)
        model.openBag(fromLockScreen: ["bag": Spread.kit.rawValue])
        #expect(model.bag == CameraModel.BagOpening(spread: .kit, look: nil))
        model.openBag(fromLockScreen: ["bag": Spread.films.rawValue, "look": roll.id])
        #expect(model.bag == CameraModel.BagOpening(spread: .films, look: roll))
        model.openBag(fromLockScreen: nil)
        #expect(model.bag?.spread == .films)
        #expect(model.film == before)
        model.bag = nil
    }

    /// Closing the bag without choosing changes nothing.
    @Test func closingTheBagWithoutChoosingKeepsTheRoll() {
        let before = model.film
        model.openBag(.films)
        model.closeBag()
        #expect(model.bag == nil)
        #expect(model.film == before)
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
        // Closed: the door is already open on an empty chamber (the old roll
        // came out in the bag); the new one goes in once it is shut all the way.
        #expect(model.film != next)
        #expect(model.isBayOpen)
        #expect(model.bayWaiting)
        model.phoneShut()
        // It goes in through the chamber: the next picture is on it already.
        #expect(model.nextShotFilm == next)
        #expect(model.readyToLoad == nil)
        #expect(model.isBayOpen)
        model.completeArrival()                // the chamber's animation ends
        #expect(model.film == next)
        #expect(model.arrivingRoll == nil)
        #expect(!model.isBayOpen)
    }

    @Test func reopeningDuringTheLoadingKeepsTheNewChoice() throws {
        let a = try other(than: model.film)
        let b = try #require(model.films.first { $0 != model.film && $0 != a })
        model.chooseInLibrary(a)
        model.foldChanged(to: .closed)
        model.phoneShut()                       // A on its way in
        model.foldChanged(to: .flat)            // opened again: A is in
        #expect(model.film == a)
        model.chooseInLibrary(b)
        model.foldChanged(to: .closed)
        model.phoneShut()                       // B on its way in
        model.completeArrival()
        #expect(model.film == b)
        model.completeArrival()                 // any late callback changes nothing
        #expect(model.film == b)
    }

    @Test func passingThroughPartOpenWhileClosingLoadsNothingUnseen() throws {
        let before = model.film
        let next = try other(than: before)
        model.chooseInLibrary(next)
        model.foldChanged(to: .half)            // on the way to closed
        #expect(model.film == before)
        #expect(model.readyToLoad == next)      // still waiting to be seen going in
    }

    @Test func atWaistLevelTheFinderShowsTheChosenRoll() throws {
        let next = try other(than: model.film)
        model.chooseInLibrary(next)
        model.foldChanged(to: .half)
        #expect(model.frames.snapshot().film == next)    // seen in the finder…
        model.foldChanged(to: .closed)
        #expect(model.frames.snapshot().film == model.film)   // …and back when closed, until it goes in
    }

    @Test func choosingAgainKeepsTheChoice() throws {
        let next = try other(than: model.film)
        model.chooseInLibrary(next)
        model.chooseInLibrary(next)
        #expect(model.readyToLoad == next)
        if let loaded = model.film { model.chooseInLibrary(loaded) }   // keeping the loaded roll clears it
        #expect(model.readyToLoad == nil)
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

    @Test func closingFromTheLibraryDoesNotFlickToWaistLevel() {
        // Measured: closing from flat, "closed" comes at 83°, 70 ms before the outer screen.
        var t = FoldTracker(mode: .flat)
        t.read(.partial, at: 0)
        t.read(.closed, at: 0.22)
        #expect(t.shown(onInnerScreen: true, showing: .flat) == .flat)
        #expect(t.shown(onInnerScreen: false, showing: .flat) == .closed)
    }

    @Test func innerScreenFollowsTheHingeForHalfOrFlat() {
        #expect(FoldTracker(mode: .flat).shown(onInnerScreen: true) == .flat)
        #expect(FoldTracker(mode: .half).shown(onInnerScreen: true) == .half)
    }
}

import ImageIO
import UniformTypeIdentifiers

/// "Try my photo", and what the finder shows against what is saved.
@Suite("Photos in and out")
struct ImportAndFinderTests {
    let renderer = FilmRenderer.shared
    var film: Film { FilmLibrary.shared.films[0] }

    /// A 4:3 scene with a sky gradient, coloured blocks and a grey ramp: like a camera frame.
    static func scene(width: Int = 1600, height: Int = 1200) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: width, height: height)
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let sky = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: [UIColor(red: 0.25, green: 0.52, blue: 0.9, alpha: 1).cgColor,
                                          UIColor(red: 0.85, green: 0.9, blue: 0.98, alpha: 1).cgColor] as CFArray,
                                 locations: [0, 1])!
            cg.drawLinearGradient(sky, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            let colours: [UIColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemPurple, .brown, .gray]
            for (i, c) in colours.enumerated() {
                c.setFill()
                cg.fill(CGRect(x: CGFloat(i) * size.width / 8, y: size.height * 0.55, width: size.width / 8, height: size.height * 0.2))
            }
            for i in 0..<10 {
                UIColor(white: CGFloat(i) / 9, alpha: 1).setFill()
                cg.fill(CGRect(x: CGFloat(i) * size.width / 10, y: size.height * 0.8, width: size.width / 10, height: size.height * 0.2))
            }
        }.cgImage!
    }

    static func encode(_ image: CGImage, type: UTType, orientation: Int = 1) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImagePropertyOrientation: orientation,
                                                 kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }

    @Test func aPortraitPhotoStaysPortrait() throws {
        // Stored on its side with an orientation tag, as an iPhone stores a portrait.
        let data = try #require(Self.encode(Self.scene(width: 600, height: 400), type: .jpeg, orientation: 6))
        let pair = try #require(FilmRendering.ownPhoto(data, film: film))
        #expect(pair.before.size.height > pair.before.size.width)
        #expect(pair.after.size == pair.before.size)
    }

    @Test func aHugePhotoIsBroughtDownToSize() throws {
        let data = try #require(Self.encode(Self.scene(width: 6000, height: 4500), type: .jpeg))
        let pair = try #require(FilmRendering.ownPhoto(data, film: film))
        #expect(max(pair.before.size.width, pair.before.size.height) <= 2048)
    }

    @Test func heicOpens() throws {
        // HEIC encoding may be missing in a simulator; then there is nothing to test here.
        guard let data = Self.encode(Self.scene(width: 800, height: 600), type: .heic) else { return }
        #expect(FilmRendering.ownPhoto(data, film: film) != nil)
    }

    @Test func somethingThatIsNotAPictureFailsQuietly() {
        #expect(FilmRendering.ownPhoto(Data("not a picture".utf8), film: film) == nil)
        #expect(FilmRendering.ownPhoto(Data(), film: film) == nil)
    }

    /// Mean colour of each cell of a cols × rows grid, rendered at `size`.
    func cells(_ image: CIImage, size: CGSize, cols: Int = 8, rows: Int = 5) -> [[Float]] {
        let w = Int(size.width), h = Int(size.height)
        var px = [UInt8](repeating: 0, count: w * h * 4)
        renderer.context.render(image, toBitmap: &px, rowBytes: w * 4, bounds: CGRect(x: 0, y: 0, width: w, height: h),
                                format: .RGBA8, colorSpace: renderer.sRGB)
        var out: [[Float]] = []
        for r in 0..<rows { for c in 0..<cols {
            var sum: [Float] = [0, 0, 0]; var n: Float = 0
            for y in (r * h / rows)..<((r + 1) * h / rows) { for x in (c * w / cols)..<((c + 1) * w / cols) {
                let i = (y * w + x) * 4
                sum[0] += Float(px[i]); sum[1] += Float(px[i + 1]); sum[2] += Float(px[i + 2]); n += 1
            } }
            out.append(sum.map { $0 / n / 255 })
        } }
        return out
    }

    /// What you see is what you get: the finder and the saved picture of the
    /// same frame match, cell by cell, in colour, brightness, framing and vignette.
    @Test(arguments: FilmLibrary.shared.films)
    func finderMatchesThePicture(film: Film) {
        let frame = CIImage(cgImage: Self.scene(width: 2016, height: 1512))   // half a 12 MP frame
        let finder = CGSize(width: 707, height: 472)                          // the body's finder window
        let shown = PreviewMTKView.finderImage(frame, film: film, iso: 100, size: finder,
                                               showsFullHeight: false, renderer: renderer)
        let saved = renderer.filtered(CameraModel.cropToFrame(frame, aspect: CameraModel.frameAspect), film: film, iso: 100)
        let scale = finder.width / saved.extent.width
        let savedSmall = saved.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let a = cells(shown, size: finder), b = cells(savedSmall, size: finder)
        var worst: Float = 0
        for (x, y) in zip(a, b) { for c in 0..<3 { worst = max(worst, abs(x[c] - y[c])) } }
        #expect(worst < 0.03, "\(film.id): finder and picture differ by \(worst) in some cell")
        // And the frame really was drawn: its cells range from dark to light.
        let lights = a.map { $0.reduce(0, +) / 3 }
        #expect((lights.max() ?? 0) - (lights.min() ?? 0) > 0.3, "\(film.id): the finder came out flat")
    }
}


/// The shot log over time: damage, deleted pictures, updates.
@Suite("Shot log lifecycle")
@MainActor
struct ShotLogLifecycleTests {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("shots-\(UUID().uuidString).json")
    }

    @Test func anUnreadableRecordIsKeptAsideNotOverwritten() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("{not json".utf8).write(to: url)
        let log = ShotLog(url: url)
        #expect(log.shots.isEmpty)
        log.add(asset: "new", film: "ccd")
        let folder = url.deletingLastPathComponent()
        let aside = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0.hasPrefix(url.deletingPathExtension().lastPathComponent + ".unreadable-") }
        #expect(aside.count == 1)                                   // the old file survives
        for name in aside { try? FileManager.default.removeItem(at: folder.appendingPathComponent(name)) }
    }

    @Test func picturesAreNeverForgotten() {
        // A hidden picture, or one outside a limited selection, looks deleted to
        // the app: the record keeps it, so it is back on its roll when visible again.
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = ShotLog(url: url)
        log.add(asset: "a", film: "c200", date: Date(timeIntervalSince1970: 1))
        log.add(asset: "b", film: "c200", date: Date(timeIntervalSince1970: 2))
        #expect(ShotLog(url: url).assets(for: "c200") == ["b", "a"])
    }

    @Test func aRecordFromAnEarlierVersionStillReads() throws {
        // The format written since the first version: an array of {asset, film, date}.
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"[{"asset":"x","film":"trix400","date":700000000}]"#.utf8).write(to: url)
        #expect(ShotLog(url: url).assets(for: "trix400") == ["x"])
    }

    @Test func manyPicturesStayQuick() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = ShotLog(url: url)
        let start = Date()
        for i in 0..<2000 { log.add(asset: "p\(i)", film: i.isMultiple(of: 2) ? "ccd" : "c200") }
        #expect(log.assets(for: "ccd").count == 1000)
        #expect(Date().timeIntervalSince(start) < 20)               // 2000 saves, each the whole record
    }
}


/// Every language the app ships has every string, with the same placeholders.
@Suite("Languages")
struct LanguageTests {
    static let languages = ["zh-Hans", "zh-Hant", "ja", "ko"]
    static let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    static func catalog(_ name: String) throws -> [String: Any] {
        let data = try Data(contentsOf: repo.appendingPathComponent("Shared/\(name).xcstrings"))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(json["strings"] as? [String: Any])
    }

    /// %@, %lld, %1$lld… in order of appearance, positions ignored.
    static func placeholders(_ s: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"%(\d+\$)?(lld|ld|d|@|f)"#)
        return regex.matches(in: s, range: NSRange(s.startIndex..., in: s))
            .map { (s as NSString).substring(with: $0.range(at: 2)) }.sorted()
    }

    @Test(arguments: ["Localizable", "InfoPlist"])
    func everyStringIsInEveryLanguage(catalog name: String) throws {
        for (key, value) in try Self.catalog(name) {
            guard !key.trimmingCharacters(in: .whitespaces).isEmpty,
                  let entry = value as? [String: Any], entry["shouldTranslate"] as? Bool != false else { continue }
            let locs = entry["localizations"] as? [String: Any] ?? [:]
            let source = ((locs["en"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String ?? key
            for lang in Self.languages {
                let text = ((locs[lang] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
                #expect(text?.isEmpty == false, "\(name): \(lang) missing for “\(key)”")
                if let text { #expect(Self.placeholders(text) == Self.placeholders(source), "\(lang) placeholders differ for “\(key)”") }
            }
        }
    }

    @Test(arguments: ["zh-Hans", "zh-Hant", "ja", "ko"])
    func countsKeepTheirOrder(language: String) throws {
        // “1 of 6 paid films”: Japanese and Korean put the total first, by position.
        let bundle = try #require(Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)))
        let format = bundle.localizedString(forKey: "%lld of %lld paid films are yours", value: nil, table: nil)
        let text = String(format: format, locale: Locale(identifier: language), 1, 6)
        let one = try #require(text.firstIndex(of: "1")), six = try #require(text.firstIndex(of: "6"))
        if language == "ja" || language == "ko" { #expect(six < one, "\(text)") } else { #expect(one < six, "\(text)") }
    }

    @Test func everyFilmHasNotesInEveryLanguage() {
        for film in FilmLibrary.shared.films {
            for lang in ["en"] + Self.languages {
                #expect(FilmNotes.text(for: film.id, language: lang) != nil, "\(film.id): no \(lang) notes")
            }
        }
    }
}
