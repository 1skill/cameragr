import Foundation

/// The app's side of the community API (project/community-api.md). The real
/// client talks to the Cloudflare Worker; `MockCommunityClient` stands in
/// until it is deployed, and in tests.
extension CommunityClient {
    func claimReward(milestone: Int) async throws -> String { try await claimReward(milestone: milestone, as: .roll) }
    func claimReward(milestone: Int, voucher: Bool) async throws -> String { try await claimReward(milestone: milestone, as: voucher ? .voucher : .roll) }
}

protocol CommunityClient: Sendable {
    var isSignedIn: Bool { get async }
    func signIn(_ apple: Community.AppleCredential) async throws -> Community.Me
    func signOut() async
    func me() async throws -> Community.Me
    /// Deletes the account and everything in it; says what became of the Apple grant.
    func deleteAccount() async throws -> Community.AppleGrant
    func agreeToRules(version: Int) async throws
    func rename(_ name: String) async throws -> Community.Me
    /// S2b: one's line (empty takes it away at once); and the admins' list of them.
    func setBio(_ bio: String) async throws -> Community.Me
    func adminBios() async throws -> [Community.BioRequest]
    func decideBio(user: String, version: String, approve: Bool) async throws
    /// S5 letters.
    func letterThreads(cursor: String?) async throws -> Community.LetterThreads
    func letters(with user: String, cursor: String?) async throws -> Community.LetterPage
    func sendLetter(to user: String, text: String, clientID: String) async throws -> Community.Letter
    func lettersShown(from user: String, ids: [String]) async throws
    func reportLetters(with user: String, reason: Community.ReportReason, letter: String?) async throws
    func adminLetterReports() async throws -> [Community.LetterReport]
    func letterReportHandled(_ id: Int) async throws

    func themes(at: Date) async throws -> [Community.Theme]
    func posts(theme: String, cursor: String?) async throws -> (posts: [Community.Post], next: String?)
    /// Every theme's pictures, newest first; one film's when given (C18).
    func posts(film: String?, cursor: String?) async throws -> (posts: [Community.Post], next: String?)
    /// Following (S1): one way; the lists are one's own only.
    func follow(_ user: String, _ on: Bool) async throws
    func following() async throws -> [Community.Person]
    func followers() async throws -> [Community.Person]
    func followingFeed(cursor: String?) async throws -> (posts: [Community.Post], next: String?)
    /// Someone's page and pictures (S2).
    func author(_ id: String) async throws -> Community.AuthorCard
    func authorPosts(_ id: String, cursor: String?) async throws -> (posts: [Community.Post], next: String?)

    /// Posts a picture (already prepared by `CommunityPhoto`) to an open theme.
    /// `clientID` is the app's own id for this post, the same on every retry,
    /// so a retry never posts it twice.
    func post(theme: String, photo: Data, thumb: Data, film: String, caption: String?, takenAt: Date?, clientID: String) async throws -> Community.Post
    func delete(post: String) async throws
    func setLike(_ liked: Bool, post: String) async throws -> (likeCount: Int, liked: Bool)
    func report(post: String, reason: Community.ReportReason, note: String?) async throws
    func setBlocked(_ blocked: Bool, user: String) async throws
    /// A milestone's roll; `voucher`: the roll is had already, so a voucher
    /// (`Community.voucher`) for another one instead.
    func claimReward(milestone: Int, as form: Community.RewardForm) async throws -> String
    /// A voucher turned into a roll not had yet.
    func redeem(milestone: Int, film: String) async throws -> String

    // Comments (C7).
    func comments(post: String) async throws -> [Community.Comment]
    /// One post by id (one's news can point to any theme's).
    func post(id: String) async throws -> Community.Post
    func comment(post: String, text: String, clientID: String) async throws -> Community.Comment
    func delete(comment: String) async throws
    func report(comment: String, reason: Community.ReportReason) async throws
    func news() async throws -> Community.News
    func mine() async throws -> Community.Mine
    /// Some of one's own posts by id, any age; ids not returned are gone (≤ 20).
    func myPosts(ids: [String]) async throws -> [Community.Post]
    func markNewsSeen() async throws
    /// S4: notices, 30 a page; and the ones actually shown, to mark them read.
    func notices(cursor: String?) async throws -> Community.NoticePage
    func noticesShown(_ shown: [Community.Notice]) async throws

    // Moderation (admins only; the server checks).
    func adminQueue() async throws -> [Community.Post]
    /// Names asked for, and deciding them (S3).
    func adminNames() async throws -> [Community.NameRequest]
    func decideName(user: String, version: String, approve: Bool) async throws
    func adminReports() async throws -> [Community.ReportedPost]
    /// Hidden posts (turned down, hidden after reports, a banned person's), to restore.
    func adminHidden() async throws -> [Community.Post]
    func adminAlerts() async throws -> [Community.Alert]
    func adminStatus() async throws -> Community.AdminStatus
    func adminFailedMail() async throws -> [Community.FailedMail]
    func retryMail(_ id: Int) async throws
    func moderate(post: String, _ action: Community.ModAction, reason: String?) async throws
    func setBanned(_ banned: Bool, user: String, reason: String?) async throws
    func markHandled(report: Int) async throws
    /// Comments waiting, reported or hidden.
    func adminComments(_ which: String) async throws -> [Community.Comment]
    func moderate(comment: String, _ action: Community.ModAction) async throws
}
