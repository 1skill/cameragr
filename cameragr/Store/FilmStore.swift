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
        trialsUsed[film.id, default: 0] += 1
        defaults.set(trialsUsed, forKey: "store.trials")
        return true
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
        let ids = [Self.allFilmsID] + paidFilms.map(Self.productID)
        if let list = try? await Product.products(for: ids) {
            products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        }
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
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
            await refreshEntitlements()
            return true
        default:
            return false
        }
    }

    /// Asks the App Store for this Apple ID's purchases again.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    #if DEBUG
    /// Clears the simulated purchases and trials (`-resetStore 1`).
    func resetDebugState() {
        defaults.removeObject(forKey: "store.debugOwned")
        defaults.removeObject(forKey: "store.trials")
        trialsUsed = [:]
        Task { await refreshEntitlements() }
    }
    #endif
}
