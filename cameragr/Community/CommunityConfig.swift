import Foundation

/// Where Koco's community lives: a Cloudflare Worker (user 11/24: the whole
/// backend on Cloudflare). Not deployed yet, so the app uses
/// `MockCommunityClient` until this is set. Nothing secret is ever here.
enum CommunityConfig {
    static let apiBase: URL? = nil
}
