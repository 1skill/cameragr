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
    private(set) var isSignedIn = false
    private var allThemes: [Community.Theme]
    private var allPosts: [Community.Post] = []
    private var byClientID: [String: String] = [:]
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

    func signIn(_ apple: Community.AppleCredential) async throws -> Community.Me {
        try await signIn(appleIdentityToken: apple.identityToken, name: apple.name)
    }

    func signOut() async { isSignedIn = false }

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
        try await post(theme: theme, photo: photo, thumb: thumb, film: film, caption: caption, takenAt: takenAt, clientID: UUID().uuidString)
    }

    func post(theme: String, photo: Data, thumb: Data, film: String, caption: String?, takenAt: Date?, clientID: String) async throws -> Community.Post {
        let me = try requireMe()
        // A retry of a post already made returns it (the server does the same).
        if let made = byClientID[clientID], let p = allPosts.first(where: { $0.id == made }) { return p }
        guard let t = allThemes.first(where: { $0.id == theme }), t.isOpen(at: now()) else { throw Community.Failure.themeClosed }
        if let caption {
            guard caption.count <= Community.captionLimit else { throw Community.Failure.words }
            let lower = caption.lowercased()
            if Self.blockedWords.contains(where: lower.contains) { throw Community.Failure.words }
        }
        let id = UUID().uuidString
        // The pictures kept where the app can show them again (the server keeps them in R2).
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mock-community", isDirectory: true)
        let photoURL = dir.appendingPathComponent("\(id).jpg"), thumbURL = dir.appendingPathComponent("\(id)-thumb.jpg")
        // Both pictures stored, or the post is not made (and nothing is left behind).
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try photo.write(to: photoURL)
            try thumb.write(to: thumbURL)
        } catch {
            try? FileManager.default.removeItem(at: photoURL)
            try? FileManager.default.removeItem(at: thumbURL)
            throw Community.Failure.network
        }
        let p = Community.Post(id: id, author: .init(id: me.profile.id, name: me.profile.name), themeId: theme,
                               photoURL: photoURL, thumbURL: thumbURL,
                               filmId: film, caption: caption, takenAt: takenAt, createdAt: now(), likeCount: 0, likedByMe: false)
        allPosts.append(p)
        byClientID[clientID] = id
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

    /// Others' posts, to fill the community before the server is there.
    func seed(_ posts: [Community.Post]) { allPosts.append(contentsOf: posts) }

    /// The app's sample pictures as other people's posts (bundled; none in the Lock Screen camera).
    static func samplePosts(theme: String) -> [Community.Post] {
        let names = ["Momo", "小川", "Lena", "竹子", "阿木", "Kai", "青山", "Ren", "Yuki", "老陈", "Mia", "琦"]
        let samples: [(file: String, film: String)] = [
            ("portra400_1", "portra400"), ("c200_2", "c200"), ("cine500t_1", "cine500t"), ("trix400_3", "trix400"),
            ("gold200_2", "gold200"), ("ccd_1", "ccd"), ("instax_2", "instax"), ("grneg_1", "grneg"),
            ("kodachrome64_3", "kodachrome64"), ("portra400_3", "portra400"), ("c200_4", "c200"), ("cine500t_3", "cine500t"),
        ]
        let now = Date()
        return samples.enumerated().compactMap { i, sample in
            guard let url = Bundle.main.url(forResource: sample.file, withExtension: "jpg") else { return nil }
            return Community.Post(id: "\(theme)-sample-\(i)", author: .init(id: "u\(i)", name: names[i % names.count]),
                                  themeId: theme, photoURL: url, thumbURL: url, filmId: sample.film,
                                  caption: nil, takenAt: nil, createdAt: now.addingTimeInterval(-Double(i) * 1_700),
                                  likeCount: [215, 362, 97, 289, 184, 76, 301, 268, 119, 54, 140, 33][i % 12], likedByMe: false)
        }
    }

    static func sampleThemes() -> [Community.Theme] {
        let now = Date()
        return [
            .init(id: "daily-sample", kind: .daily, startsAt: now.addingTimeInterval(-3_600), endsAt: now.addingTimeInterval(20 * 3_600),
                  title: ["en": "Asleep", "zh-Hans": "它睡着了"],
                  prompt: ["en": "I can't stop looking at my dog asleep.", "zh-Hans": "我总是忍不住看我睡着的狗狗，太治愈！"],
                  coverURL: nil, suggestedFilm: "portra400", limitedFilm: nil),
            .init(id: "weekly-sample", kind: .weekly, startsAt: now.addingTimeInterval(-2 * 86_400), endsAt: now.addingTimeInterval(5 * 86_400),
                  title: ["en": "Windows", "zh-Hans": "窗边"],
                  prompt: ["en": "Whatever your window holds this week.", "zh-Hans": "这周你的窗边有什么？"],
                  coverURL: nil, suggestedFilm: "c200", limitedFilm: nil),
        ]
    }
}
