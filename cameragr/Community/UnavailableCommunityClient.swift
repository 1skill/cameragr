import Foundation

/// The community when no server is set in a release build: nothing made up,
/// every call says the community isn't reachable (retro 7).
struct UnavailableCommunityClient: CommunityClient {
    private var no: Community.Failure { .server(503) }
    var isSignedIn: Bool { false }
    func signIn(_ apple: Community.AppleCredential) async throws -> Community.Me { throw no }
    func signOut() async {}
    func me() async throws -> Community.Me { throw no }
    func deleteAccount() async throws -> Community.AppleGrant { throw no }
    func agreeToRules(version: Int) async throws { throw no }
    func rename(_ name: String) async throws -> Community.Me { throw no }
    func themes(at: Date) async throws -> [Community.Theme] { throw no }
    func posts(theme: String, cursor: String?) async throws -> (posts: [Community.Post], next: String?) { throw no }
    func post(theme: String, photo: Data, thumb: Data, film: String, caption: String?, takenAt: Date?, clientID: String) async throws -> Community.Post { throw no }
    func delete(post: String) async throws { throw no }
    func setLike(_ liked: Bool, post: String) async throws -> (likeCount: Int, liked: Bool) { throw no }
    func report(post: String, reason: Community.ReportReason, note: String?) async throws { throw no }
    func setBlocked(_ blocked: Bool, user: String) async throws { throw no }
    func claimReward(milestone: Int, voucher: Bool) async throws -> String { throw no }
    func redeem(milestone: Int, film: String) async throws -> String { throw no }
    func adminQueue() async throws -> [Community.Post] { throw no }
    func adminReports() async throws -> [Community.ReportedPost] { throw no }
    func adminHidden() async throws -> [Community.Post] { throw no }
    func adminAlerts() async throws -> [Community.Alert] { throw no }
    func moderate(post: String, _ action: Community.ModAction, reason: String?) async throws { throw no }
    func setBanned(_ banned: Bool, user: String, reason: String?) async throws { throw no }
    func markHandled(report: Int) async throws { throw no }
    func comments(post: String) async throws -> [Community.Comment] { throw no }
    func post(id: String) async throws -> Community.Post { throw no }
    func comment(post: String, text: String, clientID: String) async throws -> Community.Comment { throw no }
    func delete(comment: String) async throws { throw no }
    func report(comment: String, reason: Community.ReportReason) async throws { throw no }
    func news() async throws -> Community.News { throw no }
    func markNewsSeen() async throws { throw no }
    func adminComments(_ which: String) async throws -> [Community.Comment] { throw no }
    func moderate(comment: String, _ action: Community.ModAction) async throws { throw no }
}
