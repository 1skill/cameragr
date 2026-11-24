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
    private var reportRows: [Community.ReportedPost] = []
    private var alerts: [Community.Alert] = []
    private var banned: Set<String> = []
    /// Posts wait for approval, as on the server (user 11/24); the one person
    /// here is then an admin, to try the whole round. Off in older tests.
    private let approveFirst: Bool
    private var hidden: Set<String> = []
    private var postDays: Set<String> = []             // yyyy-MM-dd with a post of mine
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    /// Words a caption may not hold (the server keeps the real list).
    static let blockedWords = ["fuck", "porn"]

    init(themes: [Community.Theme] = MockCommunityClient.sampleThemes(), timeZone: TimeZone = .current,
         approveFirst: Bool = false, now: @escaping @Sendable () -> Date = { Date() }) {
        self.approveFirst = approveFirst
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
                                   streak: 0, rewards: [], blocked: [], isAdmin: approveFirst)
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
        let list = allPosts.filter { $0.themeId == theme && !hidden.contains($0.id) && !blocked.contains($0.author.id)
                                     && !banned.contains($0.author.id) && ($0.state != .pending || $0.author.id == "me") }
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
                               filmId: film, caption: caption, takenAt: takenAt, createdAt: now(), likeCount: 0, likedByMe: false,
                               state: approveFirst ? .pending : nil)
        allPosts.append(p)
        byClientID[clientID] = id
        if !approveFirst { postDays.insert(day(now())) }   // else counted on approval
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
        if let p = allPosts.first(where: { $0.id == post }), !reports[post, default: []].contains(me.profile.id) {
            reportRows.insert(.init(report: .init(id: reportRows.count + 1, reason: reason, note: note,
                                                  reporter: .init(id: me.profile.id, name: me.profile.name),
                                                  createdAt: now(), handled: false), post: p), at: 0)
            alerts.insert(.init(kind: "report:\(p.id)", text: reason.rawValue, createdAt: now()), at: 0)
        }
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

    // MARK: Comments

    private var allComments: [Community.Comment] = []
    private var commentReports: [String: Set<String>] = [:]
    private var commentByClient: [String: String] = [:]
    private var newsSeen = Date.distantPast
    private var approvedAt: [String: Date] = [:]

    func post(id: String) async throws -> Community.Post {
        _ = try requireMe()
        guard let p = allPosts.first(where: { $0.id == id }), !hidden.contains(id) else { throw Community.Failure.server(404) }
        return p
    }

    func comments(post: String) async throws -> [Community.Comment] {
        let me = try requireMe()
        guard allPosts.contains(where: { $0.id == post && $0.state != .pending && $0.state != .hidden && !hidden.contains(post) }) else { return [] }
        return allComments.filter { $0.postId == post && ($0.state == .public || ($0.isWaiting && $0.author.id == me.profile.id))
                                    && !me.blocked.contains($0.author.id) }
    }

    func comment(post: String, text: String, clientID: String) async throws -> Community.Comment {
        let me = try requireMe()
        if let id = commentByClient[clientID], let c = allComments.first(where: { $0.id == id }) { return c }
        let line = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !line.isEmpty, line.count <= Community.commentLimit, !line.lowercased().contains("http"),
              !Self.blockedWords.contains(where: line.lowercased().contains) else { throw Community.Failure.words }
        let c = Community.Comment(id: UUID().uuidString, postId: post, author: .init(id: me.profile.id, name: me.profile.name),
                                  text: line, createdAt: now(), state: .pending, mine: true)
        allComments.append(c)
        commentByClient[clientID] = c.id
        return c
    }

    func delete(comment: String) async throws {
        let me = try requireMe()
        guard let c = allComments.first(where: { $0.id == comment }) else { return }
        let postAuthor = allPosts.first { $0.id == c.postId }?.author.id
        guard c.author.id == me.profile.id || postAuthor == me.profile.id || me.isAdmin else { throw Community.Failure.server(404) }
        allComments.removeAll { $0.id == comment }
    }

    func report(comment: String, reason: Community.ReportReason) async throws {
        let me = try requireMe()
        commentReports[comment, default: []].insert(me.profile.id)
        if commentReports[comment]!.count >= 3, let i = allComments.firstIndex(where: { $0.id == comment }) { allComments[i].state = .hidden }
    }

    func news() async throws -> Community.News {
        let me = try requireMe()
        let mine = Set(allPosts.filter { $0.author.id == me.profile.id }.map(\.id))
        let fresh = allComments.filter { mine.contains($0.postId) && $0.state == .public && $0.author.id != me.profile.id
                                         && (approvedAt[$0.id] ?? .distantPast) > newsSeen }
        return .init(comments: fresh, postsApproved: 0, count: fresh.count)
    }

    func markNewsSeen() async throws { newsSeen = now() }

    func adminComments(_ which: String) async throws -> [Community.Comment] {
        try requireAdmin()
        switch which {
        case "reported": return allComments.filter { (commentReports[$0.id]?.count ?? 0) > 0 }
        case "hidden": return allComments.filter { $0.state == .hidden }
        default: return allComments.filter(\.isWaiting)
        }
    }

    func moderate(comment: String, _ action: Community.ModAction) async throws {
        try requireAdmin()
        guard let i = allComments.firstIndex(where: { $0.id == comment }) else { throw Community.Failure.server(404) }
        allComments[i].state = action == .hide ? .hidden : .public
        if action != .hide, approvedAt[comment] == nil { approvedAt[comment] = now() }
        commentReports[comment] = nil
    }

    /// For checks: a comment by someone else, approved.
    func seedComment(post: String, by name: String, text: String) {
        let c = Community.Comment(id: UUID().uuidString, postId: post, author: .init(id: "seed-\(name)", name: name),
                                  text: text, createdAt: now(), state: .public)
        allComments.append(c)
        approvedAt[c.id] = now()
    }

    // MARK: Moderation

    private func requireAdmin() throws {
        guard try requireMe().isAdmin else { throw Community.Failure.server(403) }
    }

    func adminQueue() async throws -> [Community.Post] {
        try requireAdmin()
        return allPosts.filter { $0.state == .pending }.sorted { $0.createdAt < $1.createdAt }
    }

    func adminReports() async throws -> [Community.ReportedPost] {
        try requireAdmin()
        return reportRows.filter { !$0.report.handled }
    }

    func adminHidden() async throws -> [Community.Post] {
        try requireAdmin()
        return allPosts.filter { hidden.contains($0.id) || $0.state == .hidden }
    }

    func adminAlerts() async throws -> [Community.Alert] {
        try requireAdmin()
        return alerts
    }

    func moderate(post: String, _ action: Community.ModAction, reason: String?) async throws {
        try requireAdmin()
        guard let i = allPosts.firstIndex(where: { $0.id == post }) else { throw Community.Failure.server(404) }
        switch action {
        case .approve:
            if allPosts[i].state == .pending, allPosts[i].author.id == "me" { postDays.insert(day(now())) }   // the day it's approved
            allPosts[i].state = nil
            hidden.remove(post)
        case .hide:
            allPosts[i].state = .hidden
            hidden.insert(post)
        case .restore:
            allPosts[i].state = nil
            hidden.remove(post)
        }
    }

    func setBanned(_ on: Bool, user: String, reason: String?) async throws {
        try requireAdmin()
        guard user != "me" else { throw Community.Failure.server(409) }
        if on { banned.insert(user) } else { banned.remove(user) }
    }

    func markHandled(report: Int) async throws {
        try requireAdmin()
        if let i = reportRows.firstIndex(where: { $0.report.id == report }) {
            reportRows[i] = .init(report: { var r = reportRows[i].report; r.handled = true; return r }(), post: reportRows[i].post)
        }
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
