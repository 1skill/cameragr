import Foundation

/// A community kept in memory, behaving as the server is meant to (rules in
/// project/community-api.md): for the screens until the Worker is deployed,
/// and for tests. Nothing leaves the phone.
actor MockCommunityClient: CommunityClient {
    /// The account, kept across signing out and in (one person here).
    private var account: Community.Me?
    private var signedIn: Community.Me? {
        get { isSignedIn ? account : nil }
        set { if let newValue { account = newValue } }
    }
    private var isSignedIn = false
    private var allThemes: [Community.Theme]
    private var allPosts: [Community.Post] = []
    private var reports: [String: Set<String>] = [:]   // post → reporters
    private var hidden: Set<String> = []
    private var postDays: Set<String> = []             // yyyy-MM-dd with a post of mine
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    /// Words a caption may not hold (the server keeps the real list).
    static let blockedWords = ["fuck", "porn"]

    init(themes: [Community.Theme] = MockCommunityClient.sampleThemes(), timeZone: TimeZone = .current,
         now: @escaping @Sendable () -> Date = { Date() }) {
        allThemes = themes
        var c = Calendar(identifier: .gregorian); c.timeZone = timeZone
        calendar = c
        self.now = now
    }

    private func requireMe() throws -> Community.Me {
        guard let signedIn else { throw Community.Failure.signedOut }
        return signedIn
    }

    func signIn(appleIdentityToken: String, name: String?) async throws -> Community.Me {
        // The same person signing in again finds their account as it was.
        if account == nil {
            account = Community.Me(profile: .init(id: "me", name: name ?? "Koco", tz: calendar.timeZone.identifier),
                                   streak: 0, rewards: [], blocked: [], isAdmin: false)
        }
        isSignedIn = true
        return try await me()
    }

    func me() async throws -> Community.Me {
        var me = try requireMe()
        me.streak = streak()
        signedIn = me
        return me
    }

    func deleteAccount() async throws {
        _ = try requireMe()
        allPosts.removeAll { $0.author.id == "me" }
        postDays = []
        account = nil
        isSignedIn = false
    }

    func themes(at date: Date) async throws -> [Community.Theme] {
        allThemes.filter { $0.isOpen(at: date) || ($0.endsAt <= date && date.timeIntervalSince($0.endsAt) < 7 * 86_400) }
    }

    func posts(theme: String, cursor: String?) async throws -> (posts: [Community.Post], next: String?) {
        let blocked = Set(signedIn?.blocked ?? [])
        let list = allPosts.filter { $0.themeId == theme && !hidden.contains($0.id) && !blocked.contains($0.author.id) }
            .sorted { $0.createdAt > $1.createdAt }
        return (list, nil)
    }

    func post(theme: String, photo: Data, thumb: Data, film: String, caption: String?, takenAt: Date?) async throws -> Community.Post {
        let me = try requireMe()
        guard let t = allThemes.first(where: { $0.id == theme }), t.isOpen(at: now()) else { throw Community.Failure.themeClosed }
        if let caption {
            guard caption.count <= Community.captionLimit else { throw Community.Failure.words }
            let lower = caption.lowercased()
            if Self.blockedWords.contains(where: lower.contains) { throw Community.Failure.words }
        }
        let id = UUID().uuidString
        let p = Community.Post(id: id, author: .init(id: me.profile.id, name: me.profile.name), themeId: theme,
                               photoURL: URL(string: "mock://photo/\(id)")!, thumbURL: URL(string: "mock://thumb/\(id)")!,
                               filmId: film, caption: caption, takenAt: takenAt, createdAt: now(), likeCount: 0, likedByMe: false)
        allPosts.append(p)
        postDays.insert(day(now()))
        return p
    }

    /// A deleted post's day still counts: a check-in once made stays made
    /// (project/community-api.md), or deleting an old picture would break a streak.
    func delete(post: String) async throws {
        _ = try requireMe()
        allPosts.removeAll { $0.id == post && $0.author.id == "me" }
    }

    func setLike(_ liked: Bool, post: String) async throws -> (likeCount: Int, liked: Bool) {
        _ = try requireMe()
        guard let i = allPosts.firstIndex(where: { $0.id == post }) else { throw Community.Failure.server(404) }
        if allPosts[i].likedByMe != liked {
            allPosts[i].likedByMe = liked
            allPosts[i].likeCount += liked ? 1 : -1
        }
        return (allPosts[i].likeCount, allPosts[i].likedByMe)
    }

    func report(post: String, reason: Community.ReportReason, note: String?) async throws {
        let me = try requireMe()
        reports[post, default: []].insert(me.profile.id)
        if reports[post]!.count >= 3 { hidden.insert(post) }
    }

    /// For tests: a report from someone else.
    func report(post: String, by reporter: String) {
        reports[post, default: []].insert(reporter)
        if reports[post]!.count >= 3 { hidden.insert(post) }
    }

    func setBlocked(_ blocked: Bool, user: String) async throws {
        var me = try requireMe()
        if blocked { if !me.blocked.contains(user) { me.blocked.append(user) } } else { me.blocked.removeAll { $0 == user } }
        signedIn = me
    }

    func claimReward(milestone: Int) async throws -> String {
        var me = try requireMe()
        guard let film = Community.Me.milestones.first(where: { $0.days == milestone })?.film else { throw Community.Failure.server(400) }
        if let had = me.rewards.first(where: { $0.milestone == milestone }) { return had.filmId }
        guard streak() >= milestone else { throw Community.Failure.notYet }
        me.rewards.append(.init(milestone: milestone, filmId: film, claimedAt: now()))
        signedIn = me
        return film
    }

    /// For tests: a post of mine on an earlier day.
    func backdatePost(daysAgo: Int) {
        postDays.insert(day(calendar.date(byAdding: .day, value: -daysAgo, to: now())!))
    }

    // MARK: Streak, as the server counts it

    private func day(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// Days in a row with a post, ending today or yesterday.
    func streak() -> Int {
        let today = now()
        var start = 0
        if !postDays.contains(day(today)) {
            guard postDays.contains(day(calendar.date(byAdding: .day, value: -1, to: today)!)) else { return 0 }
            start = 1
        }
        var n = 0
        while postDays.contains(day(calendar.date(byAdding: .day, value: -(start + n), to: today)!)) { n += 1 }
        return n
    }

    static func sampleThemes() -> [Community.Theme] {
        let now = Date()
        return [
            .init(id: "daily-sample", kind: .daily, startsAt: now.addingTimeInterval(-3_600), endsAt: now.addingTimeInterval(20 * 3_600),
                  title: ["en": "Asleep", "zh-Hans": "它睡着了"],
                  prompt: ["en": "I can't stop looking at my dog asleep.", "zh-Hans": "我总是忍不住看我睡着的狗狗，太治愈！"],
                  coverURL: nil, suggestedFilm: "porto400", limitedFilm: nil),
        ]
    }
}
