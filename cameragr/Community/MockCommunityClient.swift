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
        if requiresRules { me.rulesAgreed = rulesAgreed; me.rulesCurrent = Self.rulesVersion }
        signedIn = me
        return me
    }

    func deleteAccount() async throws -> Community.AppleGrant {
        _ = try requireMe()
        allPosts.removeAll { $0.author.id == "me" }
        allComments.removeAll { $0.author.id == "me" }
        postDays = []
        account = nil
        isSignedIn = false
        return .none
    }

    /// Rules as the server keeps them: a version, agreed to once per version.
    private var rulesAgreed = 0
    static let rulesVersion = 1
    var requiresRules = false

    func agreeToRules(version: Int) async throws {
        _ = try requireMe()
        guard version == Self.rulesVersion else { throw Community.Failure.server(409) }
        rulesAgreed = version
    }

    func rename(_ name: String) async throws -> Community.Me {
        var me = try requireMe()
        let line = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        // As the server (S3): 2–12, house words kept, one to a person.
        guard (2...12).contains(line.count), !Self.blockedWords.contains(where: line.lowercased().contains) else { throw Community.Failure.words }
        let key = line.lowercased().filter { !$0.isWhitespace }
        if ["koco", "官方", "暗房", "管理员", "admin", "official"].contains(where: key.contains) { throw Community.Failure.nameReserved }
        if allPosts.contains(where: { $0.author.id != me.profile.id && $0.author.name.lowercased().filter { !$0.isWhitespace } == key }) { throw Community.Failure.nameTaken }
        me.profile.name = line
        signedIn = me
        return try await self.me()
    }

    func setRequiresRules(_ on: Bool) { requiresRules = on }

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

    private var follows: [String: Date] = [:]
    func follow(_ user: String, _ on: Bool) async throws {
        let me = try requireMe()
        guard user != me.profile.id else { throw Community.Failure.server(400) }
        follows[user] = on ? Date() : nil
    }
    func following() async throws -> [Community.Person] {
        _ = try requireMe()
        return follows.compactMap { id, since in
            allPosts.first { $0.author.id == id }.map { Community.Person(id: id, name: $0.author.name, since: since) }
        }.sorted { $0.since > $1.since }
    }
    func followers() async throws -> [Community.Person] { _ = try requireMe(); return [] }
    func followingFeed(cursor: String?) async throws -> (posts: [Community.Post], next: String?) {
        _ = try requireMe()
        let blocked = Set(signedIn?.blocked ?? [])
        return (allPosts.filter { follows[$0.author.id] != nil && $0.state != .pending && !hidden.contains($0.id) && !blocked.contains($0.author.id) }
                    .sorted { $0.createdAt > $1.createdAt }, nil)
    }

    func author(_ id: String) async throws -> Community.AuthorCard {
        _ = try requireMe()
        let theirs = allPosts.filter { $0.author.id == id && $0.state != .pending && !hidden.contains($0.id) }
        if id == signedIn?.profile.id, !allPosts.contains(where: { $0.author.id == id }), let me = signedIn {
            return .init(id: id, name: me.profile.name, topFilm: nil, films: 0, followed: false, bio: me.bio)
        }
        guard let any = allPosts.first(where: { $0.author.id == id }) else { throw Community.Failure.server(404) }
        let counts = Dictionary(grouping: theirs, by: \.filmId).mapValues(\.count)
        return .init(id: id, name: any.author.name, topFilm: counts.max { $0.value < $1.value }?.key, films: counts.count, followed: follows[id] != nil,
                     bio: id == signedIn?.profile.id ? signedIn?.bio : nil)
    }
    func authorPosts(_ id: String, cursor: String?) async throws -> (posts: [Community.Post], next: String?) {
        let me = try requireMe()
        return (allPosts.filter { $0.author.id == id && ($0.state != .pending || id == me.profile.id) && !hidden.contains($0.id) }
                    .sorted { $0.createdAt > $1.createdAt }, nil)
    }

    func posts(film: String?, cursor: String?) async throws -> (posts: [Community.Post], next: String?) {
        let blocked = Set(signedIn?.blocked ?? [])
        let list = allPosts.filter { (film == nil || $0.filmId == film) && !hidden.contains($0.id) && !blocked.contains($0.author.id)
                                     && !banned.contains($0.author.id) && ($0.state != .pending || $0.author.id == "me") }
            .sorted { $0.createdAt > $1.createdAt }
        return (list, nil)
    }

    func post(theme: String, photo: Data, thumb: Data, film: String, caption: String?, takenAt: Date?) async throws -> Community.Post {
        try await post(theme: theme, photo: photo, thumb: thumb, film: film, caption: caption, takenAt: takenAt, clientID: UUID().uuidString)
    }

    func post(theme: String, photo: Data, thumb: Data, film: String, caption: String?, takenAt: Date?, clientID: String) async throws -> Community.Post {
        let me = try requireMe()
        if requiresRules, rulesAgreed < Self.rulesVersion { throw Community.Failure.rulesNeeded }
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

    func redeem(milestone: Int, film: String) async throws -> String {
        var me = try requireMe()
        guard let i = me.rewards.firstIndex(where: { $0.milestone == milestone }) else { throw Community.Failure.server(409) }
        if me.rewards[i].filmId == film { return film }
        guard me.rewards[i].filmId == Community.voucher else { throw Community.Failure.server(409) }
        if film == Community.badge { me.rewards[i] = .init(milestone: milestone, filmId: film, claimedAt: now()); signedIn = me; return film }
        // As the server: only a regular paid roll; a refused one keeps the voucher.
        guard let roll = FilmLibrary.shared.films.first(where: { $0.id == film }),
              roll.free != true, !roll.isLimited, roll.upcoming != true else { throw Community.Failure.server(400) }
        me.rewards[i] = .init(milestone: milestone, filmId: film, claimedAt: now())
        signedIn = me
        return film
    }

    func claimReward(milestone: Int, as form: Community.RewardForm) async throws -> String {
        var me = try requireMe()
        guard let roll = Community.Me.milestones.first(where: { $0.days == milestone })?.film else { throw Community.Failure.server(400) }
        let film = milestone == 3 && form == .badge ? Community.badge : milestone == 3 && form == .voucher ? Community.voucher : roll
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
        // Public pictures, and one's own whatever its review (user 11/24: the review is never felt).
        guard allPosts.contains(where: { $0.id == post && (($0.state != .pending && $0.state != .hidden && !hidden.contains(post)) || $0.author.id == me.profile.id) }) else { return [] }
        return allComments.filter { $0.postId == post && ($0.state == .public || $0.author.id == me.profile.id)
                                    && !me.blocked.contains($0.author.id) }
    }

    func comment(post: String, text: String, clientID: String) async throws -> Community.Comment {
        let me = try requireMe()
        if requiresRules, rulesAgreed < Self.rulesVersion { throw Community.Failure.rulesNeeded }
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

    // S4 notices: comments on one's pictures as they come, plus any seeded for checks.
    private var noticeMarks: [String: (at: String, count: Int)] = [:]
    private var seededNotices: [Community.Notice] = []
    func seedNotices(_ notices: [Community.Notice]) { seededNotices = notices }
    private func isRead(_ m: (at: String, count: Int), _ n: Community.Notice) -> Bool {
        m.at > n.at || (m.at == n.at && m.count >= n.count)
    }
    func notices(cursor: String?) async throws -> Community.NoticePage {
        let me = try requireMe()
        let mine = Set(allPosts.filter { $0.author.id == me.profile.id && !hidden.contains($0.id) }.map(\.id))
        let iso = ISO8601DateFormatter()
        let fromComments = allComments.filter { mine.contains($0.postId) && $0.state == .public && $0.author.id != me.profile.id }
            .map { c in Community.Notice(key: "c:\(c.id)", kind: .comment, at: iso.string(from: approvedAt[c.id] ?? c.createdAt), count: 1,
                                         unread: true, postId: c.postId, text: String(c.text.prefix(60)),
                                         people: [.init(id: c.author.id, name: c.author.name)],
                                         thumbURL: allPosts.first { $0.id == c.postId }?.thumbURL) }
        var all: [Community.Notice] = fromComments + seededNotices
        for i in all.indices {
            if let m = noticeMarks[all[i].key], isRead(m, all[i]) { all[i].unread = false }
        }
        all.sort { a, b in a.at == b.at ? a.key > b.key : a.at > b.at }
        let unread = all.filter { $0.unread }.count
        return .init(notices: Array(all.prefix(30)), unread: min(99, unread), nextCursor: nil)
    }
    func noticesShown(_ shown: [Community.Notice]) async throws {
        for n in shown {
            if let m = noticeMarks[n.key], isRead(m, n) { continue }
            noticeMarks[n.key] = (n.at, n.count)
        }
    }

    func myPosts(ids: [String]) async throws -> [Community.Post] {
        let me = try requireMe()
        return allPosts.filter { ids.contains($0.id) && $0.author.id == me.profile.id }
            .map { p in var p = p; if hidden.contains(p.id) { p.state = .hidden }; return p }
    }

    func mine() async throws -> Community.Mine {
        let me = try requireMe()
        return .init(posts: allPosts.filter { $0.author.id == me.profile.id }.sorted { $0.createdAt > $1.createdAt }
                                    .map { p in var p = p; if hidden.contains(p.id) { p.state = .hidden }; return p },
                     comments: allComments.filter { $0.author.id == me.profile.id && $0.state != .public })
    }

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

    func adminNames() async throws -> [Community.NameRequest] { try requireAdmin(); return [] }
    func adminBios() async throws -> [Community.BioRequest] { try requireAdmin(); return [] }

    // Letters (S5), in memory: anyone one follows counts as following back here.
    private var letterBox: [String: [Community.Letter]] = [:]   // by the other's id, oldest first
    private var letterNames: [String: String] = [:]
    func seedLetters(with id: String, name: String, _ letters: [Community.Letter]) { letterBox[id] = letters; letterNames[id] = name }
    func letterThreads(cursor: String?) async throws -> Community.LetterThreads {
        _ = try requireMe()
        let threads = letterBox.compactMap { id, list -> Community.LetterThread? in
            guard let last = list.last else { return nil }
            return .init(with: .init(id: id, name: letterNames[id] ?? "?"), last: last, unread: list.filter { $0.unread == true }.count)
        }.sorted { $0.last.at > $1.last.at }
        return .init(threads: threads, unread: threads.reduce(0) { $0 + $1.unread }, next: nil)
    }
    func letters(with user: String, cursor: String?) async throws -> Community.LetterPage {
        _ = try requireMe()
        let list = letterBox[user] ?? []
        let mutual = follows[user] != nil || letterBox[user] != nil
        let answered = list.contains { !$0.mine }, mineSent = list.contains { $0.mine }
        let turn = answered || !mineSent
        return .init(messages: list.reversed(), canWrite: mutual && turn, mutual: mutual, waiting: mutual && !turn, next: nil)
    }
    func sendLetter(to user: String, text: String, clientID: String) async throws -> Community.Letter {
        _ = try requireMe()
        let page = try await letters(with: user, cursor: nil)
        guard page.mutual else { throw Community.Failure.server(403) }
        guard page.canWrite else { throw Community.Failure.server(409) }
        let low = text.lowercased()
        guard (1...Community.letterLimit).contains(text.count), !low.contains("http"), !low.contains("wechat"), !low.contains("微信") else { throw Community.Failure.words }
        let l = Community.Letter(id: clientID, mine: true, text: text, at: now())
        letterBox[user, default: []].append(l)
        return l
    }
    func lettersShown(from user: String, ids: [String]) async throws {
        letterBox[user] = letterBox[user]?.map { var l = $0; if ids.contains(l.id) { l.unread = false }; return l }
    }
    func reportLetters(with user: String, reason: Community.ReportReason, letter: String?) async throws { _ = try requireMe() }
    func adminLetterReports() async throws -> [Community.LetterReport] { try requireAdmin(); return [] }
    func letterReportHandled(_ id: Int) async throws { try requireAdmin() }
    func decideBio(user: String, version: String, approve: Bool) async throws { try requireAdmin() }
    func setBio(_ bio: String) async throws -> Community.Me {
        var me = try requireMe()
        let line = bio.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        // As the server: 40 letters, no links or ways to reach someone off Koco.
        let low = line.lowercased()
        guard line.count <= Community.bioLimit, !low.contains("http"), !low.contains("www."), !low.contains("@"),
              !["微信", "wechat", "vx", "qq", "ins", "instagram"].contains(where: low.contains) else { throw Community.Failure.words }
        me.bio = line.isEmpty ? nil : line
        signedIn = me
        return try await self.me()
    }
    func decideName(user: String, version: String, approve: Bool) async throws { try requireAdmin() }

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

    func adminFailedMail() async throws -> [Community.FailedMail] { try requireAdmin(); return [] }
    func retryMail(_ id: Int) async throws { try requireAdmin() }

    func adminStatus() async throws -> Community.AdminStatus {
        try requireAdmin()
        let waiting = allPosts.filter { $0.state == .pending }
        let comments = allComments.filter(\.isWaiting)
        return .init(pictures: .init(waiting: waiting.count, oldest: waiting.map(\.createdAt).min()),
                     comments: .init(waiting: comments.count, oldest: comments.map(\.createdAt).min()),
                     openReports: reportRows.filter { !$0.report.handled }.count,
                     mail: .init(pending: 0, failed: 0, lastSent: nil, configured: false))
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
