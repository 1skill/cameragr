import Foundation

/// The app's side of the community API (project/community-api.md). The real
/// client talks to the Cloudflare Worker; `MockCommunityClient` stands in
/// until it is deployed, and in tests.
protocol CommunityClient: Sendable {
    var isSignedIn: Bool { get async }
    func signIn(_ apple: Community.AppleCredential) async throws -> Community.Me
    func signOut() async
    func me() async throws -> Community.Me
    func deleteAccount() async throws

    func themes(at: Date) async throws -> [Community.Theme]
    func posts(theme: String, cursor: String?) async throws -> (posts: [Community.Post], next: String?)

    /// Posts a picture (already prepared by `CommunityPhoto`) to an open theme.
    /// `clientID` is the app's own id for this post, the same on every retry,
    /// so a retry never posts it twice.
    func post(theme: String, photo: Data, thumb: Data, film: String, caption: String?, takenAt: Date?, clientID: String) async throws -> Community.Post
    func delete(post: String) async throws
    func setLike(_ liked: Bool, post: String) async throws -> (likeCount: Int, liked: Bool)
    func report(post: String, reason: Community.ReportReason, note: String?) async throws
    func setBlocked(_ blocked: Bool, user: String) async throws
    func claimReward(milestone: Int) async throws -> String
}
