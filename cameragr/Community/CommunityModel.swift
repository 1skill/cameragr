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

    /// A comment on the back of a picture (C7): plain text, approved before it shows.
    struct Comment: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let postId: String
        let author: Author
        let text: String
        let createdAt: Date
        var state: Post.State?
        /// Written by the person looking.
        var mine: Bool?
        /// Admins' view: why it was reported.
        var reasons: [ReportReason]?
        var isWaiting: Bool { state == .pending }
    }
    static let commentLimit = 120
    /// A reward kept as a voucher for a roll, not yet chosen (user 11/24).
    static let voucher = "voucher"
    /// The 3-day keepsake for someone who owns every roll (user 11/24).
    static let badge = "badge"
    /// What a milestone gives: its roll, a voucher (the roll is had), or the badge (every roll is had).
    enum RewardForm: String, Sendable { case roll, voucher, badge }

    /// One's own pictures and comments, whatever their state (C10).
    struct Mine: Codable, Hashable, Sendable {
        var posts: [Post]
        var comments: [Comment]
        static let none = Mine(posts: [], comments: [])
    }

    /// What's new for someone since they last looked.
    struct News: Codable, Hashable, Sendable {
        var comments: [Comment]
        var postsApproved: Int
        var count: Int
        static let none = News(comments: [], postsApproved: 0, count: 0)
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
    /// A mail to the admins that gave up after eight tries (C15): sent again by hand.
    struct FailedMail: Codable, Hashable, Sendable, Identifiable {
        let id: Int
        let kind: String
        let count: Int
        let attempts: Int
        var lastError: String?
        let createdAt: Date
    }
    /// At a glance for admins (C6a): what waits and since when, and the mail.
    struct AdminStatus: Codable, Hashable, Sendable {
        struct Waiting: Codable, Hashable, Sendable { var waiting: Int; var oldest: Date? }
        struct Mail: Codable, Hashable, Sendable { var pending: Int; var failed: Int; var lastSent: Date?; var configured: Bool }
        var pictures: Waiting
        var comments: Waiting
        var openReports: Int
        var mail: Mail
    }
    /// Something admins should know: a new report, a long queue, usage nearing the free plan.
    struct Alert: Codable, Hashable, Sendable {
        let kind: String
        let text: String
        let createdAt: Date
    }

    /// What became of the Apple sign-in grant when an account was deleted.
    enum AppleGrant: String, Sendable { case revoked, pending, none = "no-grant-kept" }

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
        /// Milestones reached for good (the server keeps them after a run
        /// breaks). Nil from the in-memory community: there, the run decides.
        var eligible: [Int]? = nil
        /// The community rules agreed to, and the current version (C4a).
        var rulesAgreed: Int? = nil
        var rulesCurrent: Int? = nil
        /// One's line about oneself, as one sees it (asked for, or approved; S2b).
        var bio: String? = nil
        var needsRules: Bool { (rulesAgreed ?? 0) < (rulesCurrent ?? 0) }
        /// An earlier account holds this name: asked to choose another (S3).
        var needsRename: Bool? = nil
        /// The next change of name is possible from then (30 days after the last).
        var renameAfter: Date? = nil

        /// The milestones and their rolls (decided 11/23–24): 3 → Porto 400, 7 → Dusk 200, 14 → Ember 400.
        static let milestones: [(days: Int, film: String)] = [(3, "portra400"), (7, "dusk200"), (14, "ember400")]

        func reached(_ days: Int) -> Bool { eligible?.contains(days) ?? (streak >= days) }
        func claimed(_ days: Int) -> Bool { rewards.contains { $0.milestone == days } }

        /// The next milestone that can be claimed now, if any.
        var claimable: Int? {
            Self.milestones.first { m in reached(m.days) && !claimed(m.days) }?.days
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
        /// The community rules (this version) aren't agreed to yet.
        case rulesNeeded
        /// Names (S3): someone has it; a word kept for the house; too soon after the last change.
        case nameTaken
        case nameReserved
        case tooSoon
        case network
        case server(Int)
    }

    /// Someone's page (S2): their films from public pictures only; no counts of people.
    struct AuthorCard: Codable, Hashable, Sendable {
        let id: String
        let name: String
        let topFilm: String?
        let films: Int
        var followed: Bool
        /// Their approved line (one's own as one sees it); nil: none.
        var bio: String? = nil
    }

    /// Someone followed, or following (S1): only ever shown to oneself.
    struct Person: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let since: Date
    }

    /// A notice in "Mine" (S4): others' comments on my pictures, likes merged
    /// per picture, new followers per day. `at` stays the server's own text,
    /// sent back as is when it was shown ("read" = shown, key + at + count).
    struct Notice: Codable, Identifiable, Hashable, Sendable {
        enum Kind: String, Codable, Sendable { case comment, likes, follows }
        struct Who: Codable, Hashable, Sendable { let id: String; let name: String }
        let key: String
        let kind: Kind
        let at: String
        let count: Int
        var unread: Bool
        let postId: String?
        let text: String?
        let people: [Who]
        let thumbURL: URL?
        var id: String { key }
    }
    struct NoticePage: Codable, Hashable, Sendable {
        let notices: [Notice]
        let unread: Int
        let nextCursor: String?
    }

    /// A name asked for, waiting for an admin (S3).
    struct NameRequest: Codable, Identifiable, Hashable, Sendable {
        let userId: String
        let name: String
        let requested: String
        let requestedAt: Date
        /// Which request this is: a decision is on this one only.
        let version: String
        var id: String { userId }
    }

    /// A line about oneself waiting for an admin (S2b).
    struct BioRequest: Codable, Identifiable, Hashable, Sendable {
        let userId: String
        let name: String
        let bio: String?
        let requested: String
        let version: String
        var id: String { userId }
    }
    static let bioLimit = 40

    /// Caption limit, as the server checks it.
    static let captionLimit = 80
}
