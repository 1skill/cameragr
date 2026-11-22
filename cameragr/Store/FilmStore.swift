import Foundation
import StoreKit

/// Buying films: StoreKit 2 non-consumables, one per paid film plus "all
/// films" (which also covers films added later). Free films need nothing.
/// Every paid film can be tried for a few shots before it is bought.
///
/// Until the products exist in App Store Connect, debug builds show
/// reference prices and a purchase simply unlocks the film on this phone,
/// so the whole flow can be tried; release builds never do that.
@MainActor
final class FilmStore: ObservableObject {
    static let shared = FilmStore()

    static let allFilmsID = "com.oneskill.cameragr.allfilms"
    static func productID(_ film: Film) -> String { "com.oneskill.cameragr.film.\(film.id)" }
    /// Free shots on a paid film before it has to be bought.
    static let trialShots = 3

    @Published private(set) var products: [String: Product] = [:]
    /// Product ids this Apple ID owns.
    @Published private(set) var owned: Set<String>
    @Published private(set) var purchasing: String?
    /// Purchases waiting for someone's approval (Ask to Buy, or a payment
    /// the bank still has to confirm). They complete later, through `Transaction.updates`.
    @Published private(set) var awaitingApproval: Set<String> = []
    @Published private(set) var trialsUsed: [String: Int]

    private let defaults = UserDefaults.standard
    private var updates: Task<Void, Never>?

    private init() {
        owned = Set(defaults.stringArray(forKey: "store.owned") ?? [])
        trialsUsed = defaults.dictionary(forKey: "store.trials") as? [String: Int] ?? [:]
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    self?.awaitingApproval.remove(transaction.productID)
                    await self?.refreshEntitlements()
                }
            }
        }
        Task { await refresh() }
    }

    // MARK: State

    func isUnlocked(_ film: Film) -> Bool {
        film.free == true || ownsAll || owned.contains(Self.productID(film))
    }
    var ownsAll: Bool { owned.contains(Self.allFilmsID) }
    var paidFilms: [Film] { FilmLibrary.shared.films.filter { $0.free != true } }
    var ownedPaidCount: Int { paidFilms.filter(isUnlocked).count }

    func trialsLeft(_ film: Film) -> Int {
        isUnlocked(film) ? 0 : max(0, Self.trialShots - (trialsUsed[film.id] ?? 0))
    }

    /// Takes one trial shot; false if none are left.
    func useTrial(_ film: Film) -> Bool {
        guard trialsLeft(film) > 0 else { return false }
        // On the Lock Screen the shot is noted for the app first; if it
        // cannot be noted, it is not given (the app would never count it).
        if isLockScreen {
            guard let log = Self.lockScreenTrialLog else { return false }
            let line = Data((film.id + "\n").utf8)
            do {
                if let handle = try? FileHandle(forWritingTo: log) {
                    try handle.seekToEnd(); try handle.write(contentsOf: line); try handle.close()
                } else {
                    try line.write(to: log)
                }
            } catch { return false }
        }
        trialsUsed[film.id, default: 0] += 1
        defaults.set(trialsUsed, forKey: "store.trials")
        shareWithLockScreen()
        return true
    }

    /// Gives back a trial shot that never became a picture (the camera or
    /// the developing failed). In the app only: on the Lock Screen the shot
    /// is already in the log the app counts, and stays spent.
    func returnTrial(_ film: Film) {
        guard !isLockScreen, let used = trialsUsed[film.id], used > 0 else { return }
        trialsUsed[film.id] = used - 1
        defaults.set(trialsUsed, forKey: "store.trials")
        shareWithLockScreen()
    }

    func price(_ film: Film) -> String? { price(Self.productID(film)) }
    var allFilmsPrice: String? { price(Self.allFilmsID) }

    private func price(_ id: String) -> String? {
        if let product = products[id] { return product.displayPrice }
        #if DEBUG
        return id == Self.allFilmsID ? "¥68" : "¥12"   // reference prices until the products exist
        #else
        return nil
        #endif
    }

    // MARK: StoreKit

    func refresh() async {
        await loadProducts()
        // Works offline too: the system keeps the last known purchases.
        await refreshEntitlements()
    }

    /// The products (prices) could not be loaded: offline at launch, or the
    /// App Store out of reach. Bought films stay unlocked; buying waits.
    @Published private(set) var productsUnavailable = false
    private var lastProductLoad: Date?

    private var expectedProductIDs: [String] { [Self.allFilmsID] + paidFilms.map(Self.productID) }
    private var loadingProducts: Task<Void, Never>?

    /// One load at a time: a second call waits for the one under way.
    private func loadProducts() async {
        if let loadingProducts { return await loadingProducts.value }
        let task = Task { @MainActor in
            lastProductLoad = .now
            let missing = expectedProductIDs.filter { products[$0] == nil }
            if let list = try? await Product.products(for: missing) {
                for product in list { products[product.id] = product }   // kept, added to
            }
            // Any product still missing has no price: buying it waits for a retry.
            productsUnavailable = expectedProductIDs.contains { products[$0] == nil }
        }
        loadingProducts = task
        await task.value
        loadingProducts = nil
    }

    /// Tries again for any product still missing: when a page with prices
    /// opens, when the app comes back, or on a tap. At most every few seconds.
    func loadProductsIfMissing(force: Bool = false) async {
        guard productsUnavailable || products.isEmpty, !isLockScreen else { return }
        if !force, let last = lastProductLoad, Date.now.timeIntervalSince(last) < 5 { return }
        await loadProducts()
    }

    private func refreshEntitlements() async {
        if isLockScreen { await adoptAppContext(); return }
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                ids.insert(transaction.productID)
            }
        }
        #if DEBUG
        ids.formUnion(defaults.stringArray(forKey: "store.debugOwned") ?? [])
        #endif
        owned = ids
        defaults.set(Array(ids), forKey: "store.owned")
        shareWithLockScreen()
    }

    // MARK: Lock Screen camera

    /// In the Lock Screen camera: the file in its session folder where trial
    /// shots are noted for the app (`lockScreenTrialLogName`).
    static var lockScreenTrialLog: URL?
    static let lockScreenTrialLogName = "trials.txt"

    /// In the app: counts the trial shots a Lock Screen session noted, once per session.
    func addLockScreenTrials(from folder: URL) {
        let log = folder.appendingPathComponent(Self.lockScreenTrialLogName)
        var done = Set(defaults.stringArray(forKey: "store.trialSessions") ?? [])
        guard !done.contains(folder.lastPathComponent),
              let text = try? String(contentsOf: log, encoding: .utf8) else { return }
        for id in text.split(separator: "\n").map(String.init) where !id.isEmpty {
            trialsUsed[id, default: 0] += 1
        }
        done.insert(folder.lastPathComponent)
        defaults.set(Array(done), forKey: "store.trialSessions")
        defaults.set(trialsUsed, forKey: "store.trials")
        shareWithLockScreen()
    }

    /// Whether this is the Lock Screen camera extension rather than the app.
    private var isLockScreen: Bool { Bundle.main.bundleURL.pathExtension == "appex" }

    /// The app passes what it knows to the Lock Screen camera. One update at
    /// a time and always the newest state: several quick changes (a purchase
    /// and a trial shot) cannot arrive out of order and leave an older one in
    /// place. A failed update is tried again a few times.
    private func shareWithLockScreen() {
        guard !isLockScreen else { return }
        pendingContext = CaptureContext(owned: Array(owned).sorted(), trialsUsed: trialsUsed)
        guard sharing == nil else { return }
        sharing = Task { [weak self] in
            var failures = 0
            while let self, let context = self.pendingContext {
                self.pendingContext = nil
                do {
                    try await self.publishContext(context)
                    failures = 0
                } catch {
                    failures += 1
                    #if DEBUG
                    print("[store] Lock Screen context not updated (\(failures)): \(error)")
                    #endif
                    guard failures < 4 else {
                        // Give up for now but keep it: the next change or launch sends the newest.
                        if self.pendingContext == nil { self.pendingContext = context }
                        break
                    }
                    if self.pendingContext == nil { self.pendingContext = context }   // nothing newer: retry this one
                    try? await Task.sleep(for: .seconds(Double(failures)))
                }
            }
            self?.sharing = nil
        }
    }
    private var pendingContext: CaptureContext?
    /// How the context reaches the Lock Screen camera (replaced in tests).
    var publishContext: (CaptureContext) async throws -> Void = { try await PeliCaptureIntent.updateAppContext($0) }
    /// How purchases are fetched again from the App Store (replaced in tests,
    /// where there is no Apple ID to sign in with).
    var syncWithAppStore: () async throws -> Void = { try await AppStore.sync() }
    private var sharing: Task<Void, Never>?

    /// The Lock Screen camera takes over what the app last passed on: it can
    /// neither ask the App Store nor read the app's records itself. Trial
    /// shots taken here count on from the app's number but are not passed back.
    func adoptAppContext() async {
        guard isLockScreen, let context = try? await PeliCaptureIntent.appContext else { return }
        // The app's list replaces ours whole: a refund there takes the film away here too.
        owned = Set(context.owned)
        for (id, used) in context.trialsUsed where used > (trialsUsed[id] ?? 0) {
            trialsUsed[id] = used
        }
        defaults.set(Array(owned), forKey: "store.owned")
        defaults.set(trialsUsed, forKey: "store.trials")
    }

    /// Buys a film, or all films with `film` nil. True once it is owned.
    @discardableResult
    func buy(_ film: Film?) async -> Bool {
        let id = film.map(Self.productID) ?? Self.allFilmsID
        purchasing = id
        defer { purchasing = nil }
        guard let product = products[id] else {
            #if DEBUG
            var mock = Set(defaults.stringArray(forKey: "store.debugOwned") ?? [])
            mock.insert(id)
            defaults.set(Array(mock), forKey: "store.debugOwned")
            await refreshEntitlements()
            return true
            #else
            return false
            #endif
        }
        guard let result = try? await product.purchase() else { return false }
        switch result {
        case .success(.verified(let transaction)):
            await transaction.finish()
            awaitingApproval.remove(id)
            await refreshEntitlements()
            return true
        case .pending:
            awaitingApproval.insert(id)
            return false
        default:   // cancelled, or a transaction that failed verification
            return false
        }
    }

    /// Asks the App Store for this Apple ID's purchases again; false if the
    /// App Store could not be reached (or the sign-in was cancelled).
    @discardableResult
    func restore() async -> Bool {
        var reached = true
        do { try await syncWithAppStore() } catch { reached = false }
        await refreshEntitlements()
        return reached
    }

    #if DEBUG
    /// Tests: as if the products were never loaded.
    func forgetProductsForTesting() { products = [:]; lastProductLoad = nil }

    /// Clears the simulated purchases and trials (`-resetStore 1`).
    func resetDebugState() async {
        defaults.removeObject(forKey: "store.debugOwned")
        defaults.removeObject(forKey: "store.trials")
        defaults.removeObject(forKey: "store.trialSessions")
        trialsUsed = [:]
        owned = []
        awaitingApproval = []
        await refreshEntitlements()
    }
    #endif
}
