import Foundation

/// Where Koco's community lives: a Cloudflare Worker (user 11/24: the whole
/// backend on Cloudflare). Nothing secret is ever here.
enum CommunityConfig {
    static let apiBase: URL? = URL(string: "https://koco-community.sybbzb.workers.dev")

    /// The in-memory community instead of the server: on the simulator (its
    /// snapshots and tests), or on a phone launched with `-mockClub 1`.
    static var usesMock: Bool {
        #if DEBUG
        #if targetEnvironment(simulator)
        return !UserDefaults.standard.bool(forKey: "realClub")
        #else
        return UserDefaults.standard.bool(forKey: "mockClub")
        #endif
        #else
        return false
        #endif
    }
}
