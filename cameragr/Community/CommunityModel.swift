import Foundation

/// The community's data as the app sees it (project/community-api.md).
enum Community {
    struct Theme: Codable, Identifiable, Hashable, Sendable {
        enum Kind: String, Codable, Sendable { case daily, weekly, festival }
        let id: String
        let kind: Kind
        let startsAt: Date
        let endsAt: Date
        /// Per language (`en`, `zh-Hans`…); `text(_:)` picks one.
        let title: [String: String]
        let prompt: [String: String]
        var coverURL: URL?
        var suggestedFilm: String?
        var limitedFilm: String?

        func isOpen(at now: Date) -> Bool { startsAt <= now && now < endsAt }

        /// The text in the interface's language, else English, else any.
        static func text(_ table: [String: String], language: String) -> String {
            table[language] ?? table["en"] ?? table.values.first ?? ""
        }
    }

    struct Author: Codable, Hashable, Sendable {
        let id: String
        let name: String
    }

    struct Post: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let author: Author
        let themeId: String
        let photoURL: URL
        let thumbURL: URL
        let filmId: String
        var caption: String?
        var takenAt: Date?
        let createdAt: Date
        var likeCount: Int
        var likedByMe: Bool
        /// Waiting for approval (shown to its author only) until a moderator
        /// lets it out (user 11/24: approved before public). Nil: public.
        var state: State? = nil
        enum State: String, Codable, Sendable { case pending, `public`, hidden }
        var isWaiting: Bool { state == .pending }
    }

    /// A report, as admins see it (C2c).
    struct Report: Codable, Identifiable, Hashable, Sendable {
        let id: Int
        let reason: ReportReason
        var note: String?
        let reporter: Author
        let createdAt: Date
        var handled: Bool
    }
    struct ReportedPost: Codable, Hashable, Sendable, Identifiable {
        let report: Report
        let post: Post
        var id: Int { report.id }
    }
    enum ModAction: String, Sendable { case approve, hide, restore }
    /// Something admins should know: a new report, a long queue, usage nearing the free plan.
    struct Alert: Codable, Hashable, Sendable {
        let kind: String
        let text: String
        let createdAt: Date
    }

    /// What Sign in with Apple hands the app, for the server to check.
    struct AppleCredential: Sendable {
        let identityToken: String
        let authorizationCode: String
        /// The raw nonce; Apple's token carries its SHA-256.
        let nonce: String
        let name: String?
    }

    struct Profile: Codable, Hashable, Sendable {
        let id: String
        var name: String
        let tz: String
    }

    struct Reward: Codable, Hashable, Sendable {
        let milestone: Int
        let filmId: String
        let claimedAt: Date
    }

    struct Me: Codable, Hashable, Sendable {
        var profile: Profile
        /// Days in a row with a post, counted by the server in the person's own day.
        var streak: Int
        var rewards: [Reward]
        var blocked: [String]
        var isAdmin: Bool

        /// The milestones and their rolls (decided 11/23–24): 3 → Porto 400, 7 → Dusk 200, 14 → Ember 400.
        static let milestones: [(days: Int, film: String)] = [(3, "portra400"), (7, "dusk200"), (14, "ember400")]

        /// The next milestone this streak can claim now, if any.
        var claimable: Int? {
            Self.milestones.first { m in m.days <= streak && !rewards.contains { $0.milestone == m.days } }?.days
        }
    }

    enum ReportReason: String, Codable, CaseIterable, Sendable {
        case nudity, violence, hate, spam, notKoco = "not-koco", other
    }

    /// What can go wrong, as the app shows it.
    enum Failure: Error, Equatable, Sendable {
        case signedOut
        case themeClosed
        /// The words of the caption are not allowed.
        case words
        case notYet
        case network
        case server(Int)
    }

    /// Caption limit, as the server checks it.
    static let captionLimit = 80
}
