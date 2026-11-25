import AuthenticationServices
import CryptoKit
import Photos
import SwiftUI
import UIKit

/// The community's pair of pages in the bag (user 11/24: the community is in
/// v1, in place of the Book). Right: a long clear three-pocket sleeve threaded
/// on brass rings, one picture per pocket with a kraft slip under it (author ·
/// film · hearts); it slides and rests on whole rows. Left: the theme.
/// Art is GPT's (design/community/parts, v6/rings): the spread (its rail and
/// rings taken out), one tileable sleeve row, a length of rail and one ring
/// per row that scroll with it.
enum ClubArt {
    /// The 3-day keepsake badge (GPT, cut out of its white ground).
    static let badge = UIImage(named: "badge_3day") ?? UIImage()
    static let spread = UIImage(named: "club_spread.jpg") ?? UIImage()
    static let row = UIImage(named: "sleeve_row.jpg") ?? UIImage()
    static let slip = UIImage(named: "kraft_slip") ?? UIImage()

    /// Bag pixels (community_v4, as agreed): the rail and rings on the left
    /// page near the spine; the sleeve threaded on them runs across the spine
    /// to the right page's edge, most of the bag (user 11/24).
    static let sleeveX: CGFloat = 470
    static let sleeveRight: CGFloat = 1430
    static var sleeveWidth: CGFloat { sleeveRight - sleeveX }
    static var rowHeight: CGFloat { sleeveWidth * row.size.height / max(row.size.width, 1) }
    /// The rail and a ring per row ride with the sleeve (user 11/24–25): the
    /// scrolling starts here, left of the rail (bag units).
    static let scrollX: CGFloat = 384
    /// The brass rail's place across the page, and the ring seat's middle on it.
    static let railX: CGFloat = 397
    static let railWidth: CGFloat = 48
    static var seatX: CGFloat { railX + railWidth / 2 }
    /// The punched hole on a sleeve row, as a fraction of the row (sleeve_row.jpg).
    static let hole = CGPoint(x: 40.0 / 1300, y: 150.0 / 299)
    static let railMid = UIImage(named: "rail_mid") ?? UIImage()
    static let railTop = UIImage(named: "rail_top") ?? UIImage()
    static let railBottom = UIImage(named: "rail_bottom") ?? UIImage()
    static let ring = UIImage(named: "club_ring") ?? UIImage()
    /// On the ring picture: the seat's middle and the hole's (its pixels, set when cut).
    static let ringSeat = CGPoint(x: 66.2, y: 94.9)
    static let ringHole = CGPoint(x: 332.0, y: 93.1)
    /// The left page's narrow column left of the rail, for the themes.
    static let navWidth: CGFloat = 330
    static let navX: CGFloat = 50
    /// The three pockets of a row, as fractions of the row (measured on sleeve_row).
    static let pockets: [CGRect] = [
        CGRect(x: 0.0591, y: 0.0255, width: 0.3105, height: 0.9430),
        CGRect(x: 0.3732, y: 0.0255, width: 0.3123, height: 0.9430),
        CGRect(x: 0.6877, y: 0.0255, width: 0.3091, height: 0.9430),
    ]
}

/// The community as the bag shows it: themes and the posts of the open one.
@MainActor
final class ClubModel: ObservableObject {
    static let shared = ClubModel()
    let client: CommunityClient
    /// A server to talk to (or, in debug builds, the in-memory one).
    var isOpen: Bool { !(client is UnavailableCommunityClient) }
    @Published private(set) var themes: [Community.Theme] = []
    @Published private(set) var theme: Community.Theme?
    @Published private(set) var posts: [Community.Post] = []
    /// Signed in to the community (posting, liking and reading need it).
    @Published private(set) var signedIn = false
    /// What is being posted (the picture and its words), kept until it goes
    /// in: through a lost connection, an expired sign-in or a relaunch.
    @Published var draftAsset: String? { didSet { saveDraft() } }
    @Published var draftCaption = "" { didSet { saveDraft() } }
    /// One's own account (name, days in a row, admin or not).
    @Published private(set) var me: Community.Me?
    /// The "Mine" panel is open (and, for admins, moderation in it).
    @Published var mineOpen = false
    @Published private(set) var queue: [Community.Post] = []
    @Published private(set) var reported: [Community.ReportedPost] = []
    @Published private(set) var alerts: [Community.Alert] = []
    @Published private(set) var hiddenPosts: [Community.Post] = []
    @Published private(set) var adminStatus: Community.AdminStatus?
    /// Names waiting for an admin (S3).
    @Published private(set) var nameRequests: [Community.NameRequest] = []
    @Published private(set) var bioRequests: [Community.BioRequest] = []
    @Published private(set) var failedMail: [Community.FailedMail] = []
    /// The comments on the picture looked at, its own waiting ones included.
    @Published private(set) var thread: [Community.Comment] = []
    @Published var commentDraft = ""
    @Published private(set) var commenting = false
    /// The comments couldn't be read (shown, with a way to try again).
    @Published private(set) var threadFailed = false
    /// What's new since one last looked (comments on one's pictures).
    @Published private(set) var news = Community.News.none
    /// One's own pictures and comments with their states (C10).
    @Published private(set) var mineList = Community.Mine.none
    /// The last post didn't go: its draft stays, and the same button retries it.
    @Published private(set) var postFailed = false
    /// When each picture's links were last fetched again (one ran out).
    private var relinkedAt: [String: Date] = [:]
    /// What was new when "Mine" opened (shown there; the count is cleared).
    @Published private(set) var newsShown = Community.News.none
    /// S4 notices: the list as shown in "Mine", how many unread, the next page.
    @Published private(set) var notices: [Community.Notice] = []
    @Published private(set) var noticeUnread = 0
    @Published private(set) var noticeNext: String?
    @Published private(set) var noticesFailed = false
    @Published private(set) var moreNoticesFailed = false
    /// The notice a follower's page was opened from: "Mine" comes back to it (retro 13).
    var mineReturnTo: String?
    /// Bumped by each first-page load: a later page from before it is dropped.
    private var noticeListGen = 0
    private var loadingMoreNotices = false
    /// Shown, waiting to be told to the server as read (sent in a batch).
    private var shownPending: [String: Community.Notice] = [:]
    private var shownFlush: Task<Void, Never>?
    @Published private(set) var modComments: [Community.Comment] = []
    /// The community rules are shown, to agree to before posting or commenting.
    @Published var rulesOpen = false
    /// What was being sent when the rules came up: sent once they're agreed to.
    private var afterRules: (() async -> Void)?
    /// An account step on its way (agreeing, deleting): its button waits.
    @Published private(set) var accountBusy = false
    /// Moves on when the account changes (signed out, deleted): an answer to
    /// a request made before is dropped, never shown for the next account.
    private var generation = 0
    /// The theme's pictures couldn't be read: shown, with a way to try again.
    @Published private(set) var failed = false
    /// The next page of this theme's posts, if there is one.
    private var nextPage: String?
    private var loadingMore = false
    /// The picture drawn out of its pocket to look at.
    @Published var viewing: Community.Post?
    /// The folder of one's own Koco pictures is open, to post one.
    @Published var posting = false
    @Published private(set) var sending = false
    /// A line to show for a moment (reported, blocked…); each new one restarts its time.
    @Published var note: Text? { didSet { if note != nil { noteID += 1 } } }
    @Published private(set) var noteID = 0

    private func saveDraft() {
        UserDefaults.standard.set(draftAsset, forKey: "communityDraftAsset")
        UserDefaults.standard.set(draftCaption, forKey: "communityDraftCaption")
    }

    init(client: CommunityClient? = nil) {
        draftAsset = UserDefaults.standard.string(forKey: "communityDraftAsset")
        draftCaption = UserDefaults.standard.string(forKey: "communityDraftCaption") ?? ""
        if let client { self.client = client } else if !CommunityConfig.usesMock, let base = CommunityConfig.apiBase {
            self.client = RemoteCommunityClient(base: base)
        } else {
            #if DEBUG
            // Debug only, for snapshots and tests (CommunityConfig.usesMock):
            // the in-memory community, with the app's sample pictures as others' posts.
            let mock = MockCommunityClient(approveFirst: true)
            Task { await mock.setRequiresRules(true) }
            self.client = mock
            Task {
                await mock.seed(MockCommunityClient.samplePosts(theme: "daily-sample"))
                await mock.seed(Array(MockCommunityClient.samplePosts(theme: "weekly-sample").suffix(5)))
            }
            #else
            // A release build never makes up a community (retro 7): no server
            // set means the community isn't open yet.
            self.client = UnavailableCommunityClient()
            #endif
        }
    }

    func load() async {
        // The in-memory community (Debug snapshots and tests) signs in by itself.
        if let mock = client as? MockCommunityClient, !UserDefaults.standard.bool(forKey: "clubSignedOut") {   // `-clubSignedOut 1`, for checks
            _ = try? await mock.signIn(appleIdentityToken: "mock", name: nil)
        }
        signedIn = await client.isSignedIn
        if signedIn { me = try? await client.me(); keepRewards(); await refreshNews(); await refreshFollows() }
        failed = false
        do {
            themes = try await client.themes(at: Date())
        } catch {
            Diag.note("club themes failed: \(error)")
            themes = []
            failed = true
        }
        // The one chosen before if it is still there, else the first open one.
        let keep = theme.flatMap { t in themes.first { $0.id == t.id } }
        await choose(keep ?? themes.first { $0.isOpen(at: Date()) } ?? themes.first)
        #if DEBUG
        if let room = UserDefaults.standard.string(forKey: "clubRoom") { await chooseRoom(room) }   // `-clubRoom <film id|*>`, for checks
        if UserDefaults.standard.bool(forKey: "clubBio") { _ = await setBio("Rainy streets, mostly at dusk") }   // `-clubBio 1`
        if UserDefaults.standard.bool(forKey: "clubAuthorSelf"), let me { await openAuthor(.init(id: me.profile.id, name: me.profile.name)) }   // `-clubAuthorSelf 1`
        if UserDefaults.standard.bool(forKey: "clubAuthor"), let first = posts.first { await openAuthor(first.author) }   // `-clubAuthor 1`
        if UserDefaults.standard.bool(forKey: "clubView") {   // `-clubView 1`, for checks
            if let mock = client as? MockCommunityClient, let first = posts.first {
                await mock.seedComment(post: first.id, by: "小川", text: "光线好温柔，窗框的影子太好看了")
                await mock.seedComment(post: first.id, by: "Lena", text: "Love the light on the wall.")
            }
            viewing = posts.first
        }
        if UserDefaults.standard.bool(forKey: "clubPost") { posting = true }   // `-clubPost 1`, for checks
        if UserDefaults.standard.bool(forKey: "clubRules") { if let mock = client as? MockCommunityClient { await mock.setRequiresRules(true) }; me = try? await client.me(); rulesOpen = true }   // `-clubRules 1`
        if UserDefaults.standard.bool(forKey: "clubBadge"), let mock = client as? MockCommunityClient {   // `-clubBadge 1`
            for d in 0..<3 { await mock.backdatePost(daysAgo: d) }
            _ = try? await mock.claimReward(milestone: 3, as: .badge)
        }
        if UserDefaults.standard.bool(forKey: "clubNotices"), let mock = client as? MockCommunityClient, let first = posts.first {   // `-clubNotices 1`
            let iso = ISO8601DateFormatter(), t = Date()
            await mock.seedNotices([
                .init(key: "l:\(first.id)", kind: .likes, at: iso.string(from: t), count: 4, unread: true, postId: first.id, text: nil,
                      people: [.init(id: "u-aki", name: "Aki"), .init(id: "u-momo", name: "Momo")], thumbURL: first.thumbURL),
                .init(key: "f:today", kind: .follows, at: iso.string(from: t.addingTimeInterval(-600)), count: 2, unread: true, postId: nil, text: nil,
                      people: [.init(id: "u-lin", name: "小林"), .init(id: "u-aki", name: "Aki")], thumbURL: nil),
                .init(key: "c:n1", kind: .comment, at: iso.string(from: t.addingTimeInterval(-3600)), count: 1, unread: false, postId: first.id,
                      text: "The light on the wall is lovely.", people: [.init(id: "u-momo", name: "Momo")], thumbURL: first.thumbURL),
            ])
            await refreshNotices()
        }
        if UserDefaults.standard.bool(forKey: "clubMine"), let mock = client as? MockCommunityClient, let first = posts.first {   // `-clubMine 1`
            await mock.seed(MockCommunityClient.samplePosts(theme: theme?.id ?? "").prefix(2).map {
                var p = $0; p.state = .pending
                return Community.Post(id: "wait-" + p.id, author: p.author, themeId: p.themeId, photoURL: p.photoURL, thumbURL: p.thumbURL,
                                      filmId: p.filmId, caption: p.caption, takenAt: p.takenAt, createdAt: p.createdAt,
                                      likeCount: 0, likedByMe: false, state: .pending)
            })
            try? await client.report(post: first.id, reason: .spam, note: nil)
            await openMine()
        }
        #endif
    }

    func toggleLike(_ post: Community.Post) async {
        // A like that didn't go through says so (never looks done when it isn't).
        guard let r = try? await client.setLike(!post.likedByMe, post: post.id) else { note = Text("That didn't go through. Try again."); return }
        update(post.id) { $0.likeCount = r.likeCount; $0.likedByMe = r.liked }
    }

    func report(_ post: Community.Post, reason: Community.ReportReason) async {
        do {
            try await client.report(post: post.id, reason: reason, note: nil)
            note = Text("Reported. Thank you — it will be looked at.")
        } catch { note = Text("The report didn't go through. Try again.") }
    }

    /// Blocks the author: none of their pictures show again.
    func block(_ post: Community.Post) async {
        do {
            try await client.setBlocked(true, user: post.author.id)
            posts.removeAll { $0.author.id == post.author.id }
            followingIDs.remove(post.author.id)   // blocking ends following both ways (S1)
            followingPeople.removeAll { $0.id == post.author.id }; followerPeople.removeAll { $0.id == post.author.id }
            covers = covers.filter { $0.value.author.id != post.author.id }   // nor on a poster
            viewing = nil
            note = Text("You won’t see \(post.author.name)’s pictures.")
        } catch { note = Text("That didn't go through. Try again.") }
    }

    /// Signs in with what Sign in with Apple gave; then the theme is read again.
    func signIn(_ apple: Community.AppleCredential) async {
        do {
            me = try await client.signIn(apple)
            signedIn = true
            keepRewards()
            await refreshFollows()   // whom this account follows, before any label is touched
            await reloadAlbum()   // the same album, read again
        } catch {
            Diag.note("club sign-in failed: \(error)")
            note = Text("Couldn’t sign in. Try again.")
        }
    }

    /// Rolls this account has claimed, kept on this phone too (a new phone,
    /// or reinstalled): the store gives them, the Lock Screen and widgets follow.
    private func keepRewards() {
        for r in me?.rewards ?? [] where r.filmId != Community.voucher && r.filmId != Community.badge
                                          && !FilmStore.shared.gifted.contains(r.filmId) {
            FilmStore.shared.grant(r.filmId)
        }
    }

    /// A claim on its way (its slip waits, no second request).
    @Published private(set) var claiming: Int?

    /// Claims a milestone's roll and gives it here.
    func claim(_ days: Int) async {
        guard claiming == nil else { return }
        claiming = days
        defer { claiming = nil }
        do {
            // Had already (bought, or all films): a voucher for another roll instead (user 11/24).
            let roll = FilmLibrary.shared.films.first { $0.id == Community.Me.milestones.first { $0.days == days }?.film }
            // Every roll had (all films): the keepsake badge (user 11/24); this one had: a voucher.
            let had = roll.map { !$0.isLimited && FilmStore.shared.owns($0) } ?? false
            let form: Community.RewardForm = had ? (Self.hasEveryRoll ? .badge : .voucher) : .roll
            let gen = generation
            let film = try await client.claimReward(milestone: days, as: form)
            // Signed out (or deleted) meanwhile: nothing given to whoever is here now (retro 8).
            guard gen == generation else { return }
            if film == Community.badge {
                Haptic.stop()
                let fresh = try? await client.me()
                guard gen == generation else { return }
                if let fresh { me = fresh }
                note = Text("A keepsake badge is yours: you have every roll already.")
                return
            }
            if film == Community.voucher {
                Haptic.stop()
                if let fresh = try? await client.me(), gen == generation { me = fresh }
                note = Text("A voucher for a roll is yours: choose one in Mine.")
                return
            }
            guard FilmStore.shared.grant(film) else { note = Text("That didn't go through. Try again."); return }
            Haptic.stop()
            if let fresh = try? await client.me(), gen == generation { me = fresh }   // kept as it was if this fails
            let name = FilmLibrary.shared.films.first { $0.id == film }?.name ?? film
            note = Text("\(name) is yours. It’s in the bag.")
        } catch Community.Failure.notYet {
            note = Text("Not yet: keep going.")
        } catch Community.Failure.server(409) {
            note = Text("This Apple account has had this roll before.")
        } catch {
            note = Text("That didn't go through. Try again.")
        }
    }

    func refreshNews() async {
        await refreshNotices()
    }

    /// The first page again; a failure keeps the list there was (retro 12).
    func refreshNotices() async {
        let gen = generation
        // Numbered when sent: only the latest load lands (out-of-order replies dropped).
        noticeListGen += 1
        let mine = noticeListGen
        do {
            let page = try await client.notices(cursor: nil)
            guard gen == generation, mine == noticeListGen else { return }
            notices = page.notices; noticeUnread = page.unread; noticeNext = page.nextCursor
            noticesFailed = false; moreNoticesFailed = false
        } catch {
            if gen == generation, mine == noticeListGen { noticesFailed = true }
        }
    }

    /// The next page: one at a time, and only onto the list it was asked for.
    func moreNotices() async {
        guard let cursor = noticeNext, !loadingMoreNotices else { return }
        loadingMoreNotices = true
        defer { loadingMoreNotices = false }
        let gen = generation, list = noticeListGen
        do {
            let page = try await client.notices(cursor: cursor)
            guard gen == generation, list == noticeListGen, noticeNext == cursor else { return }
            let have = Set(notices.map(\.key))
            notices += page.notices.filter { !have.contains($0.key) }
            noticeNext = page.nextCursor
            moreNoticesFailed = false
        } catch {
            if gen == generation, list == noticeListGen { moreNoticesFailed = true }
        }
    }

    /// A notice came into view: read ("read" = shown). Told in a batch a
    /// moment later; only what was actually shown is ever marked.
    func noticeShown(_ n: Community.Notice) {
        guard n.unread, shownPending[n.key] == nil else { return }
        shownPending[n.key] = n
        shownFlush?.cancel()
        shownFlush = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await self?.flushShown()
        }
    }

    private func flushShown() async {
        let batch = Array(shownPending.values.prefix(30))
        guard !batch.isEmpty else { return }
        let gen = generation
        do {
            try await client.noticesShown(batch)
            guard gen == generation else { return }
            // Only the versions that were sent and are still the ones listed
            // turn read; a group that grew meanwhile stays unread.
            for n in batch {
                shownPending[n.key] = nil
                if let i = notices.firstIndex(where: { $0.key == n.key && $0.at == n.at && $0.count == n.count }) { notices[i].unread = false }
            }
            // The count from the server, not counted down here (it caps what it reports).
            let list = noticeListGen
            if let page = try? await client.notices(cursor: nil), gen == generation, list == noticeListGen { noticeUnread = page.unread }
            if !shownPending.isEmpty { await flushShown() }
        } catch {
            // Not told: they stay unread, tried again next time they show.
            if gen == generation { for n in batch { shownPending[n.key] = nil } }
        }
    }

    /// A notice opened: a picture in the viewer, a follower's page.
    func openNotice(_ n: Community.Notice) async {
        switch n.kind {
        case .comment, .likes:
            if let id = n.postId { await open(postID: id) }
        case .follows:
            guard let who = n.people.first else { return }
            mineReturnTo = n.key
            mineOpen = false
            await openAuthor(.init(id: who.id, name: who.name))
        }
    }

    // MARK: Comments (C7)

    /// The comments of the picture now looked at.
    func loadThread(_ post: Community.Post) async {
        thread = []
        threadFailed = false
        guard signedIn else { return }
        let gen = generation
        do {
            let list = try await client.comments(post: post.id)
            if gen == generation, viewing?.id == post.id {
                thread = list
                // Already in (the answer was lost before): no need to send it again.
                if let pending = commentClientID, pending.key.hasPrefix(post.id + "|"),
                   list.contains(where: { $0.mine == true && pending.key == post.id + "|" + $0.text }) {
                    commentClientID = nil
                } else { restoreCommentDraft(for: post) }
            }
        } catch {
            if viewing?.id == post.id { threadFailed = true }
        }
    }

    /// Picture links last an hour: one that ran out has the theme's pictures
    /// fetched again with fresh links (at most once a minute), kept in place.
    /// The picture of one post, fetched again with fresh links (at most once a
    /// minute each), and put back wherever that post is shown.
    func relink(postID: String) async {
        guard signedIn, Date().timeIntervalSince(relinkedAt[postID] ?? .distantPast) > 60 else { return }
        relinkedAt[postID] = Date()
        let gen = generation
        guard let f = try? await client.post(id: postID), gen == generation else { relinkedAt[postID] = nil; return }
        func swap(_ list: inout [Community.Post]) { if let i = list.firstIndex(where: { $0.id == f.id }) { list[i] = f } }
        swap(&posts); swap(&mineList.posts); swap(&queue); swap(&hiddenPosts)
        if viewing?.id == f.id { viewing = f }
    }

    /// Opens the picture a piece of news is about, whichever theme it's in.
    func open(postID: String) async {
        if let p = posts.first(where: { $0.id == postID }) { viewing = p; return }
        let gen = generation
        let p = try? await client.post(id: postID)
        guard gen == generation else { return }   // another account by now (retro 9)
        if let p { viewing = p } else { note = Text("That picture isn't there any more.") }
    }

    /// The comment on its way, and its id, kept on this phone until it goes
    /// in: a retry, even after a relaunch, sends the same one (C10).
    private var commentClientID: (key: String, id: String)? {
        get {
            guard let d = UserDefaults.standard.dictionary(forKey: "communityCommentPending") as? [String: String],
                  let k = d["key"], let i = d["id"] else { return nil }
            return (k, i)
        }
        set {
            if let newValue { UserDefaults.standard.set(["key": newValue.key, "id": newValue.id], forKey: "communityCommentPending") }
            else { UserDefaults.standard.removeObject(forKey: "communityCommentPending") }
        }
    }

    /// A comment left unsent on this picture comes back into the line.
    func restoreCommentDraft(for post: Community.Post) {
        guard commentDraft.isEmpty, let pending = commentClientID, pending.key.hasPrefix(post.id + "|") else { return }
        commentDraft = String(pending.key.dropFirst(post.id.count + 1))
    }

    func sendComment(on post: Community.Post) async {
        let text = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !commenting else { return }
        if me?.needsRules == true {
            afterRules = { [weak self] in await self?.sendComment(on: post) }
            rulesOpen = true
            return
        }
        commenting = true
        defer { commenting = false }
        let gen = generation
        let key = post.id + "|" + text
        if commentClientID?.key != key { commentClientID = (key, UUID().uuidString) }
        do {
            let c = try await client.comment(post: post.id, text: text, clientID: commentClientID!.id)
            guard gen == generation else { return }   // another account by now: nothing of this one shown
            commentClientID = nil
            if commentDraft.trimmingCharacters(in: .whitespacesAndNewlines) == text { commentDraft = "" }
            thread.removeAll { $0.id == c.id }
            thread.append(c)
            note = Text("Posted.")
        } catch Community.Failure.words {
            guard gen == generation else { return }
            note = Text("Those words can’t be posted. Try other ones.")
        } catch Community.Failure.rulesNeeded {
            guard gen == generation else { return }
            let fresh = try? await client.me()
            guard gen == generation else { return }
            if let fresh { me = fresh } else { me?.rulesAgreed = 0 }
            afterRules = { [weak self] in await self?.sendComment(on: post) }
            rulesOpen = true
        } catch Community.Failure.signedOut {
            guard gen == generation else { return }
            signedIn = false
            note = Text("Sign in to post.")
        } catch {
            guard gen == generation else { return }
            note = Text("Couldn’t post. Check the connection and try again.")
        }
    }

    // MARK: Account (C4a)

    /// Agrees to the rules shown, then sends what was waiting for them.
    func agreeToRules() async {
        guard !accountBusy else { return }
        accountBusy = true
        defer { accountBusy = false }
        let gen = generation
        do {
            try await client.agreeToRules(version: me?.rulesCurrent ?? 1)
            let fresh = try? await client.me()
            guard gen == generation else { return }   // signed out meanwhile: this account's state is left alone
            if let fresh { me = fresh } else { me?.rulesAgreed = me?.rulesCurrent }
            rulesOpen = false
            let next = afterRules
            afterRules = nil
            await next?()
        } catch {
            // A newer version (409): read it again, the sheet stays to be read.
            guard gen == generation else { return }
            if let fresh = try? await client.me(), gen == generation { me = fresh }
            note = Text("That didn't go through. Try again.")
        }
    }

    func declineRules() { rulesOpen = false; afterRules = nil }

    func rename(_ name: String) async -> Bool {
        let gen = generation
        do {
            let fresh = try await client.rename(name)
            guard gen == generation else { return false }
            me = fresh; return true
        } catch {
            guard gen == generation else { return false }
            switch error as? Community.Failure {
            case .words?: note = Text("Names are 2 to 12 letters, without links or rude words.")
            case .nameReserved?: note = Text("That name is kept for Koco. Try another one.")
            case .nameTaken?: note = Text("Someone already has that name. Try another one.")
            case .tooSoon?:
                if let after = me?.renameAfter { note = Text("A name can be changed once in 30 days: again from \(after.formatted(date: .abbreviated, time: .omitted)).") }
                else { note = Text("A name can be changed once in 30 days.") }
            default: note = Text("That didn't go through. Try again.")
            }
            return false
        }
    }

    /// One's line (S2b): seen by oneself at once, by others once approved.
    func setBio(_ bio: String) async -> Bool {
        let gen = generation
        do {
            let fresh = try await client.setBio(bio)
            guard gen == generation else { return false }
            me = fresh
            if let card = authorCard, card.id == fresh.profile.id { authorCard?.bio = fresh.bio }
            return true
        } catch {
            guard gen == generation else { return false }
            if case .words? = error as? Community.Failure {
                note = Text("Up to 40 letters, without links, contacts or rude words.")
            } else { note = Text("That didn't go through. Try again.") }
            return false
        }
    }

    func decideBio(_ b: Community.BioRequest, approve: Bool) async {
        let gen = generation
        do {
            try await client.decideBio(user: b.userId, version: b.version, approve: approve)
            guard gen == generation else { return }
            bioRequests.removeAll { $0.userId == b.userId }
        } catch {
            guard gen == generation else { return }
            note = Text("That didn't go through. Try again.")
            if let fresh = try? await client.adminBios(), gen == generation { bioRequests = fresh }
        }
    }

    func signOut() async {
        await client.signOut()
        forgetHere()
        note = Text("Signed out.")
    }

    /// Deletes the account and everything in it, then everything kept here
    /// for it; says plainly what became of the Apple sign-in grant.
    func deleteAccount() async {
        guard !accountBusy else { return }
        accountBusy = true
        defer { accountBusy = false }
        do {
            let grant = try await client.deleteAccount()
            forgetHere()
            UserDefaults.standard.removeObject(forKey: "communityDraftAsset")
            UserDefaults.standard.removeObject(forKey: "communityDraftCaption")
            UserDefaults.standard.removeObject(forKey: "communityDrafts")
            draftAsset = nil
            draftCaption = ""
            switch grant {
            case .revoked: note = Text("Your account is deleted and Koco's access to your Apple ID withdrawn. Your pictures are being cleared.")
            case .pending: note = Text("Your account is deleted; your pictures are being cleared. Withdrawing Koco's access to your Apple ID will be tried again shortly.")
            case .none: note = Text("Your account is deleted; your pictures are being cleared.")
            }
        } catch {
            note = Text("The account couldn't be deleted. Check the connection and try again.")
        }
    }

    /// Everything shown here for an account, gone (signed out or deleted).
    private func forgetHere() {
        generation += 1
        PictureCache.forgetAll()
        signedIn = false
        me = nil
        mineOpen = false
        posts = []
        thread = []
        news = .none
        newsShown = .none
        notices = []; noticeUnread = 0; noticeNext = nil; noticesFailed = false
        shownPending = [:]; shownFlush?.cancel()
        mineList = .none
        covers = [:]
        ownPosts = [:]
        authorCard = nil
        followingIDs = []; followingPeople = []; followerPeople = []; followBusy = []; followsKnown = false
        ownReadFailed = false
        room = nil
        UserDefaults.standard.removeObject(forKey: "communityPosted")
        queue = []; reported = []; alerts = []; hiddenPosts = []; modComments = []
        failedMail = []; adminStatus = nil; nameRequests = []; bioRequests = []
        afterRules = nil; rulesOpen = false
        commentDraft = ""
        commentClientID = nil
        viewing = nil
    }

    /// Blocks a comment's author: their comments and pictures go, both ways.
    func blockCommenter(_ c: Community.Comment) async {
        do {
            try await client.setBlocked(true, user: c.author.id)
            thread.removeAll { $0.author.id == c.author.id }
            posts.removeAll { $0.author.id == c.author.id }
            followingIDs.remove(c.author.id)
            followingPeople.removeAll { $0.id == c.author.id }; followerPeople.removeAll { $0.id == c.author.id }
            covers = covers.filter { $0.value.author.id != c.author.id }
            note = Text("You won’t see \(c.author.name)’s pictures.")
        } catch { note = Text("That didn't go through. Try again.") }
    }

    func deleteComment(_ c: Community.Comment) async {
        do { try await client.delete(comment: c.id); thread.removeAll { $0.id == c.id }; modComments.removeAll { $0.id == c.id } }
        catch { note = Text("That didn't go through. Try again.") }
    }

    func reportComment(_ c: Community.Comment, _ reason: Community.ReportReason) async {
        do { try await client.report(comment: c.id, reason: reason); note = Text("Reported. Thank you — it will be looked at.") }
        catch { note = Text("The report didn't go through. Try again.") }
    }

    func moderate(_ c: Community.Comment, _ action: Community.ModAction) async {
        do {
            try await client.moderate(comment: c.id, action)
            Haptic.click()
            await refreshModeration()
        } catch { note = Text("That didn't go through. Try again.") }
    }

    /// Every regular paid roll owned for good, by the all-films purchase or one
    /// by one (the day's free roll and the limited ones don't count; GPT review C5c).
    static var hasEveryRoll: Bool {
        let store = FilmStore.shared
        return store.ownsAll || store.paidFilms.allSatisfy { store.owns($0) }
    }

    /// A voucher with no roll left to become (every roll had): the badge.
    func redeemBadge(_ days: Int) async {
        guard claiming == nil else { return }
        claiming = days
        defer { claiming = nil }
        let gen = generation
        do {
            _ = try await client.redeem(milestone: days, film: Community.badge)
            guard gen == generation else { return }
            Haptic.stop()
            // Shown as the badge at once, whatever the refresh does.
            if var m = me, let i = m.rewards.firstIndex(where: { $0.milestone == days }) {
                m.rewards[i] = .init(milestone: days, filmId: Community.badge, claimedAt: Date()); me = m
            }
            let fresh = try? await client.me()
            guard gen == generation else { return }
            if let fresh { me = fresh }
            note = Text("A keepsake badge is yours: you have every roll already.")
        } catch {
            guard gen == generation else { return }
            note = Text("That didn't go through. Try again.")
        }
    }

    /// Paid rolls one doesn't have yet: what a voucher can become.
    var voucherChoices: [Film] {
        FilmStore.shared.paidFilms.filter { !FilmStore.shared.owns($0) && !$0.isLimited }
    }

    /// A voucher turned into a roll, given here.
    func redeem(_ days: Int, film: Film) async {
        guard claiming == nil else { return }
        claiming = days
        defer { claiming = nil }
        do {
            let gen = generation
            let id = try await client.redeem(milestone: days, film: film.id)
            guard gen == generation else { return }
            guard FilmStore.shared.grant(id) else { note = Text("That didn't go through. Try again."); return }
            Haptic.stop()
            // Shown spent at once, whatever the refresh does.
            if var m = me, let i = m.rewards.firstIndex(where: { $0.milestone == days }) {
                m.rewards[i] = .init(milestone: days, filmId: id, claimedAt: Date()); me = m
            }
            if let fresh = try? await client.me(), gen == generation { me = fresh }
            note = Text("\(film.name) is yours. It’s in the bag.")
        } catch { note = Text("That didn't go through. Try again.") }
    }

    /// Opens "Mine": one's account read again, and for admins what waits.
    /// Whom one follows and who follows one, read again.
    func refreshFollows() async {
        guard signedIn else { return }
        let gen = generation
        async let a = client.following()
        async let b = client.followers()
        let (ing, ers) = (try? await a, try? await b)
        guard gen == generation else { return }
        if let ing { followingPeople = ing; followingIDs = Set(ing.map(\.id)); followsKnown = true }
        if let ers { followerPeople = ers }
    }

    /// Follow someone, or stop; the label changes at once, back if it fails.
    func toggleFollow(_ author: Community.Author) async {
        guard followsKnown, !followBusy.contains(author.id) else { return }
        followBusy.insert(author.id)
        defer { followBusy.remove(author.id) }
        let gen = generation
        let on = !followingIDs.contains(author.id)
        if on { followingIDs.insert(author.id) } else { followingIDs.remove(author.id) }
        do {
            try await client.follow(author.id, on)
            guard gen == generation else { return }
            await refreshFollows()
            if room == Self.followed { await reloadAlbum() }
        } catch {
            guard gen == generation else { return }
            if on { followingIDs.remove(author.id) } else { followingIDs.insert(author.id) }
            note = Text("That didn't go through. Try again.")
        }
    }

    func openMine() async {
        // Taken now: the panel clears the mark once it has scrolled back.
        let returning = mineReturnTo != nil
        mineOpen = true
        let gen = generation
        let fresh = try? await client.me()
        guard gen == generation else { return }
        me = fresh
        keepRewards()
        // Back from a follower's page: the pages loaded stay, so the list can
        // return to where one was; pulling down brings the newest.
        if !returning { await refreshNews() }
        if let list = try? await client.mine(), gen == generation { mineList = list }
        await refreshFollows()
        if me?.isAdmin == true { await refreshModeration() }
    }

    func decideName(_ n: Community.NameRequest, approve: Bool) async {
        let gen = generation
        do {
            try await client.decideName(user: n.userId, version: n.version, approve: approve)
            guard gen == generation else { return }   // signed out or another account meanwhile
            nameRequests.removeAll { $0.userId == n.userId }
        } catch {
            guard gen == generation else { return }
            // Changed since it was seen (409): read the list again.
            note = Text("That didn't go through. Try again.")
            if let fresh = try? await client.adminNames(), gen == generation { nameRequests = fresh }
        }
    }

    func refreshModeration() async {
        let gen = generation
        do {
            async let q = client.adminQueue()
            async let r = client.adminReports()
            async let a = client.adminAlerts()
            async let h = client.adminHidden()
            async let cw = client.adminComments("pending")
            async let cr = client.adminComments("reported")
            let (wait, reportedComments) = try await (cw, cr)
            let lists = try await (q, r, a, h)
            let status = try? await client.adminStatus()
            let failed = (try? await client.adminFailedMail()) ?? []
            let names = try? await client.adminNames()
            let bios = try? await client.adminBios()
            guard gen == generation else { return }
            // A failed read keeps what was there and says so (never "none waiting").
            if let bios { bioRequests = bios } else { note = Text("Bios couldn’t be loaded. Pull to try again.") }
            (queue, reported, alerts, hiddenPosts) = lists
            // A failed read keeps what was there (never "none waiting" by mistake).
            if let names { nameRequests = names } else { note = Text("Names couldn’t be loaded. Pull to try again.") }
            adminStatus = status
            failedMail = failed
            modComments = wait + reportedComments.filter { c in !wait.contains { $0.id == c.id } }
        } catch {
            Diag.note("club moderation failed: \(error)")
            note = Text("Couldn’t load. Pull down to try again.")
        }
    }

    /// A moderation step, then the lists and the sleeve read again. True if it went through.
    @discardableResult
    func moderate(_ post: Community.Post, _ action: Community.ModAction) async -> Bool {
        do {
            try await client.moderate(post: post.id, action, reason: nil)
            if action == .hide { PictureCache.forget(post: post.id) }
            Haptic.click()
            await refreshModeration()
            await reloadAlbum()   // the same album, read again
            return true
        } catch { note = Text("That didn't go through. Try again."); return false }
    }

    /// A mail that gave up, sent again from the start.
    func retryMail(_ m: Community.FailedMail) async {
        do { try await client.retryMail(m.id); Haptic.click(); await refreshModeration() }
        catch { note = Text("That didn't go through. Try again.") }
    }

    /// A report settled: hidden or restored first (only if that went through), then closed.
    func settle(_ item: Community.ReportedPost, _ action: Community.ModAction?) async {
        if let action, !(await moderate(item.post, action)) { return }
        do { try await client.markHandled(report: item.report.id); await refreshModeration() }
        catch { note = Text("That didn't go through. Try again.") }
    }

    func ban(_ author: Community.Author) async {
        do {
            try await client.setBanned(true, user: author.id, reason: nil)
            note = Text("\(author.name) is banned; their pictures are hidden.")
            await refreshModeration()
            await reloadAlbum()   // the same album, read again
        } catch { note = Text("That didn't go through. Try again.") }
    }

    /// The app's id for a post of this picture to this theme, kept until it
    /// goes in: a retry (after a lost connection, or a relaunch) sends the
    /// same one, so the server never makes it twice.
    private static func clientID(theme: String, asset: String) -> String {
        let key = "\(theme)|\(asset)"
        var all = UserDefaults.standard.dictionary(forKey: "communityDrafts") as? [String: String] ?? [:]
        if let id = all[key] { return id }
        let id = UUID().uuidString
        all[key] = id
        UserDefaults.standard.set(all, forKey: "communityDrafts")
        return id
    }
    /// Which posts each of one's own pictures went into, by its Photos id:
    /// the film album opens them with their likes and comments (user 11/24).
    /// This account's only: forgotten with it.
    static func postIDs(asset: String) -> [String] {
        (UserDefaults.standard.dictionary(forKey: "communityPosted") as? [String: [String]])?[asset] ?? []
    }
    private static func remember(post id: String, asset: String) {
        var all = UserDefaults.standard.dictionary(forKey: "communityPosted") as? [String: [String]] ?? [:]
        if !(all[asset] ?? []).contains(id) { all[asset, default: []].append(id) }
        UserDefaults.standard.set(all, forKey: "communityPosted")
    }
    /// One's own posts that pictures in the film album went into, by id, as
    /// last read: any age (not just the latest list, retro 10).
    @Published private(set) var ownPosts: [String: Community.Post] = [:]
    /// The last read of them failed: the slip offers to try again.
    @Published private(set) var ownReadFailed = false

    /// Reads the posts these pictures went into, twenty at a time. One the
    /// server no longer returns was deleted: its mark comes off the picture.
    /// A failed read changes nothing (no false marks either way).
    func refreshOwn(assets: [String]) async {
        guard signedIn else { return }
        let ids = Array(Set(assets.flatMap { Self.postIDs(asset: $0) }))
        guard !ids.isEmpty else { return }
        let gen = generation
        for start in stride(from: 0, to: ids.count, by: 20) {
            let chunk = Array(ids[start..<min(start + 20, ids.count)])
            let found: [Community.Post]
            do { found = try await client.myPosts(ids: chunk) } catch {
                if gen == generation { ownReadFailed = true }
                return
            }
            guard gen == generation else { return }
            ownReadFailed = false
            for id in chunk { ownPosts[id] = nil }
            for p in found { ownPosts[p.id] = p }
            let gone = Set(chunk).subtracting(found.map(\.id))
            if !gone.isEmpty { Self.forget(posts: gone) }
        }
    }

    /// One's own post of this picture, as last read (nil: never posted,
    /// signed out — emptied with the account —, or deleted).
    func ownPost(asset: String) -> Community.Post? {
        guard signedIn else { return nil }
        return Self.postIDs(asset: asset).lazy.compactMap { self.ownPosts[$0] }.first
    }

    private static func forget(posts gone: Set<String>) {
        var all = UserDefaults.standard.dictionary(forKey: "communityPosted") as? [String: [String]] ?? [:]
        for (asset, ids) in all {
            let left = ids.filter { !gone.contains($0) }
            all[asset] = left.isEmpty ? nil : left
        }
        UserDefaults.standard.set(all, forKey: "communityPosted")
    }

    private static func posted(theme: String, asset: String) {
        var all = UserDefaults.standard.dictionary(forKey: "communityDrafts") as? [String: String] ?? [:]
        all["\(theme)|\(asset)"] = nil
        UserDefaults.standard.set(all, forKey: "communityDrafts")
    }

    /// Posts one of one's own Koco pictures to the open theme: read from
    /// Photos, made small and stripped of its metadata, sent. True if it went in.
    func post(_ shot: ShotLog.Shot, caption: String) async -> Bool {
        guard let theme, !sending else { return false }
        postFailed = false
        guard signedIn else { note = Text("Sign in to post."); return false }
        if me?.needsRules == true {
            afterRules = { [weak self] in if await self?.post(shot, caption: caption) == true { self?.posting = false } }
            rulesOpen = true
            return false
        }
        sending = true
        defer { sending = false }
        let gen = generation
        let data = await Self.imageData(asset: shot.asset)
        guard gen == generation else { return false }   // signed out while Photos was read: send nothing
        guard let data, let ready = CommunityPhoto.prepare(data) else {
            note = Text("That picture can't be read from Photos.")
            return false
        }
        let line = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let p = try await client.post(theme: theme.id, photo: ready.photo, thumb: ready.thumb, film: shot.film,
                                          caption: line.isEmpty ? nil : line, takenAt: shot.date,
                                          clientID: Self.clientID(theme: theme.id, asset: shot.asset))
            guard gen == generation else { return false }   // another account by now: its draft and sleeve untouched
            Self.posted(theme: theme.id, asset: shot.asset)
            Self.remember(post: p.id, asset: shot.asset)
            // Cleared only if it is still what was sent.
            if draftAsset == shot.asset, draftCaption == caption { draftAsset = nil; draftCaption = "" }
            posts.removeAll { $0.id == p.id }
            // Into the album only if it belongs where the album is (a film's room shows only that film).
            let fits = room == nil ? self.theme?.id == p.themeId : (room == Self.everyone || room == p.filmId)
            if fits { posts.insert(p, at: 0) }
            note = Text("Posted — it’s in the sleeve.")   // review is never felt (user 11/24)
            DailyReminder.shared.notePosted()
            return true
        } catch Community.Failure.rulesNeeded {
            guard gen == generation else { return false }
            // Read again: the rules may have a new version since.
            let fresh = try? await client.me()
            guard gen == generation else { return false }
            if let fresh { me = fresh } else { me?.rulesAgreed = 0 }
            afterRules = { [weak self] in if await self?.post(shot, caption: caption) == true { self?.posting = false } }
            rulesOpen = true
        } catch Community.Failure.signedOut {
            guard gen == generation else { return false }
            signedIn = false
            note = Text("Sign in to post.")
        } catch Community.Failure.words {
            guard gen == generation else { return false }
            note = Text("Those words can’t be posted. Try other ones.")
        } catch Community.Failure.themeClosed {
            guard gen == generation else { return false }
            note = Text("This theme has closed.")
        } catch {
            guard gen == generation else { return false }
            // Lost, timed out, or done but the answer lost: the draft and its id
            // stay, so trying again sends the same post (never a second one).
            postFailed = true
            note = Text("Couldn’t post. Check the connection and try again.")
        }
        return false
    }

    /// A picture's data from Photos (from iCloud if need be).
    private static func imageData(asset id: String) async -> Data? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        return await withCheckedContinuation { done in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                done.resume(returning: data)
            }
        }
    }

    private func update(_ id: String, _ change: (inout Community.Post) -> Void) {
        if let i = posts.firstIndex(where: { $0.id == id }) { change(&posts[i]) }
        if var v = viewing, v.id == id { change(&v); viewing = v }
        if var o = ownPosts[id] { change(&o); ownPosts[id] = o }   // the film album's slip too
    }

    #if DEBUG
    /// `-ownPosted 1`: the picture posted to the open theme, as if from the
    /// folder (the mock keeps it), so the film album's slip can be checked.
    func debugPost(asset: String, film: String) async {
        guard let theme, signedIn else { return }
        try? await client.agreeToRules(version: me?.rulesCurrent ?? 1)
        let p: Community.Post
        do {
            p = try await client.post(theme: theme.id, photo: Data([0xff, 0xd8, 0xff, 0xd9]), thumb: Data([0xff, 0xd8, 0xff, 0xd9]),
                                      film: film, caption: nil, takenAt: Date(), clientID: UUID().uuidString)
        } catch { Diag.note("debug post failed: \(error)"); return }
        Self.remember(post: p.id, asset: asset)
        update(p.id) { $0.likeCount = 7 }
        _ = try? await client.setLike(true, post: p.id)
    }
    #endif

    /// Shows a theme's posts; never another theme's (cleared first, and on failure).
    /// What the album shows (C18): nil, the chosen theme's pictures; "*",
    /// everyone's latest; a film id, that film's room. The theme stays the
    /// one a picture is posted to.
    @Published private(set) var room: String?
    static let everyone = "*"
    /// The album showing the people one follows (S1).
    static let followed = "@following"
    /// The album showing one person's pictures: "u:" + their id (S2).
    static func person(_ id: String) -> String { "u:" + id }
    /// The page open in the album, when it is someone's.
    @Published private(set) var authorCard: Community.AuthorCard?
    /// Their card couldn't be read: the folder says so and offers to try again.
    @Published private(set) var authorFailed = false
    /// Whom one follows (ids), and the two lists for "Mine": one's own only.
    @Published private(set) var followingIDs: Set<String> = []
    @Published private(set) var followingPeople: [Community.Person] = []
    @Published private(set) var followerPeople: [Community.Person] = []
    /// Whom one follows is known (read since signing in): until then no label shows.
    @Published private(set) var followsKnown = false
    /// Whose follow is on its way: their label waits (one request at a time).
    @Published private(set) var followBusy: Set<String> = []
    /// Each theme's newest picture as last seen: its poster's window, also
    /// while the album shows a room.
    @Published private(set) var covers: [String: Community.Post] = [:]
    /// The album's scope, to tell a late answer from the one asked for now.
    private var scopeKey: String { room ?? ("theme:" + (theme?.id ?? "")) }

    private func page(cursor: String?) async throws -> (posts: [Community.Post], next: String?) {
        if room == Self.followed { return try await client.followingFeed(cursor: cursor) }
        if let room, room.hasPrefix("u:") { return try await client.authorPosts(String(room.dropFirst(2)), cursor: cursor) }
        if let room { return try await client.posts(film: room == Self.everyone ? nil : room, cursor: cursor) }
        guard let theme else { return ([], nil) }
        return try await client.posts(theme: theme.id, cursor: cursor)
    }

    /// A theme's poster: the album goes back to its pictures.
    func choose(_ new: Community.Theme?) async {
        theme = new
        room = nil
        await reloadAlbum()
    }

    /// Everyone's latest (`ClubModel.everyone`) or a film's room; nil, the theme again.
    func chooseRoom(_ new: String?) async {
        room = new
        if !(new?.hasPrefix("u:") ?? false) { authorCard = nil }
        await reloadAlbum()
    }

    /// Someone's page (S2): their card on the left page, their pictures in the album.
    func openAuthor(_ author: Community.Author) async {
        withAnimation(.easeOut(duration: 0.2)) { viewing = nil }
        authorCard = .init(id: author.id, name: author.name, topFilm: nil, films: 0, followed: followingIDs.contains(author.id))
        room = Self.person(author.id)
        // The card and the pictures together.
        async let card: Void = readAuthorCard(author.id)
        async let pictures: Void = reloadAlbum()
        _ = await (card, pictures)
    }

    /// Their card read again; gone (blocked, banned, left): back to the theme, said.
    func readAuthorCard(_ id: String) async {
        let gen = generation
        authorFailed = false
        do {
            let card = try await client.author(id)
            guard gen == generation, room == Self.person(id) else { return }
            authorCard = card
        } catch Community.Failure.signedOut {
            if gen == generation { signedIn = false }
        } catch Community.Failure.server(404) {
            guard gen == generation, room == Self.person(id) else { return }
            note = Text("This page isn’t there any more.")
            await choose(theme)
        } catch {
            guard gen == generation, room == Self.person(id) else { return }
            authorFailed = true
        }
    }

    /// The retry under the left page: the themes too, if they were what failed.
    func reloadAlbumAgain() async { if themes.isEmpty { await load() } else { await reloadAlbum() } }

    private func reloadAlbum() async {
        posts = []
        nextPage = nil
        guard signedIn, room != nil || theme != nil else { return }
        failed = false
        let gen = generation, key = scopeKey
        do {
            let page = try await page(cursor: nil)
            if gen == generation, scopeKey == key {   // still the one chosen
                posts = page.posts; nextPage = page.next
                if room == nil, let theme { covers[theme.id] = page.posts.first }   // none left: none shown
            }
        } catch Community.Failure.signedOut {
            if gen == generation { signedIn = false }   // an answer to the account before says nothing of this one
        } catch {
            Diag.note("club posts failed: \(error)")
            if gen == generation, scopeKey == key { failed = true }
        }
    }

    /// The next page, when the sleeve nears its last filled row.
    func loadMore() async {
        guard let cursor = nextPage, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        let gen = generation, key = scopeKey
        do {
            let page = try await page(cursor: cursor)
            guard gen == generation, scopeKey == key, nextPage == cursor else { return }
            let seen = Set(posts.map(\.id))
            posts += page.posts.filter { !seen.contains($0.id) }
            nextPage = page.next
        } catch {
            Diag.note("club more failed: \(error)")
            if gen == generation { note = Text("Couldn’t load more. Scroll again to try.") }
        }
    }
}

/// A post's picture: bundled (the mock's samples) or from the server.
struct PostPicture: View {
    let url: URL
    /// Filling its frame (a pocket) or fitting whole (looked at).
    var fill = true
    /// Told the picture's size once it's in (the viewer lays itself out by it).
    var onImage: ((CGSize) -> Void)? = nil
    @State private var image: UIImage?
    /// It couldn't be loaded: a small mark in its place to try again (C15).
    @State private var failed = false
    @State private var attempt = 0
    var body: some View {
        Group {
            if let image {
                if fill { Image(uiImage: image).resizable().scaledToFill() } else { Image(uiImage: image).resizable().scaledToFit() }
            } else if failed {
                ZStack {
                    Color.black.opacity(0.3)
                    Image(systemName: "arrow.clockwise").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                }
                .contentShape(Rectangle())
                .onTapGesture { failed = false; attempt += 1 }
                .accessibilityLabel(Text("Couldn’t load. Tap to try again."))
                .accessibilityAddTraits(.isButton)
            } else { Color.black.opacity(0.3) }
        }
        .task(id: "\(url.absoluteString)#\(attempt)") {
            // Never the previous picture under a new one, nor a late answer over it.
            image = nil
            let asked = url
            let loaded: UIImage?
            if asked.isFileURL { loaded = UIImage(contentsOfFile: asked.path) }
            else if let kept = PictureCache.image(for: asked) { loaded = kept }
            else if let (data, response) = try? await URLSession.shared.data(from: asked) {
                // A link that ran out (403): fresh links are fetched, this view follows them.
                if (response as? HTTPURLResponse)?.statusCode == 403,
                   let i = asked.pathComponents.firstIndex(of: "photos"), i + 1 < asked.pathComponents.count {
                    await ClubModel.shared.relink(postID: asked.pathComponents[i + 1])
                }
                loaded = (response as? HTTPURLResponse)?.statusCode == 200 ? UIImage(data: data) : nil
                if let loaded { PictureCache.keep(loaded, for: asked) }
            } else { loaded = nil }
            if !Task.isCancelled, asked == url {
                image = loaded; failed = loaded == nil
                if let loaded { onImage?(loaded.size) }
            }
        }
    }
}

/// Pictures seen in the last ten minutes, kept in memory by post and size,
/// not by link (a link changes when it's renewed): fewer requests on the
/// free plan (C12, capacity.md). A hidden picture leaves the lists when they
/// are read again; it is never fetched anew.
enum PictureCache {
    private final class Entry { let image: UIImage; let at = Date(); init(_ i: UIImage) { image = i } }
    // Bounded by memory (decoded bytes, about 60 MB), not by count (GPT review C13).
    private static let store: NSCache<NSString, Entry> = { let c = NSCache<NSString, Entry>(); c.totalCostLimit = 60_000_000; return c }()
    static let lifetime: TimeInterval = 600

    private static func key(_ url: URL) -> NSString? {
        let parts = url.pathComponents
        guard let i = parts.firstIndex(of: "photos"), i + 2 < parts.count else { return nil }
        return "\(parts[i + 1])/\(parts[i + 2])" as NSString
    }
    static func image(for url: URL) -> UIImage? {
        guard let k = key(url), let e = store.object(forKey: k) else { return nil }
        if Date().timeIntervalSince(e.at) > lifetime { store.removeObject(forKey: k); return nil }
        return e.image
    }
    static func keep(_ image: UIImage, for url: URL) {
        guard let k = key(url) else { return }
        let px = image.size.width * image.scale * image.size.height * image.scale
        store.setObject(Entry(image), forKey: k, cost: Int(px * 4))
    }
    static func forgetAll() { store.removeAllObjects() }
    static func forget(post: String) {
        store.removeObject(forKey: "\(post)/thumb" as NSString)
        store.removeObject(forKey: "\(post)/full" as NSString)
    }
}

/// The right page: the sleeve of pictures.
struct ClubSleevePage: View {
    @ObservedObject private var club = ClubModel.shared
    let s: CGFloat
    @State private var rowSeen = 0

    var body: some View {
        let page = RollLibrary.lidPage   // the boards' height; the sleeve spans both pages
        let rowH = ClubArt.rowHeight * s, w = ClubArt.sleeveWidth * s
        let cw = (ClubArt.sleeveRight - ClubArt.scrollX) * s
        let rows = max(Int((CGFloat(club.posts.count) / 3).rounded(.up)), Int(page.height / ClubArt.rowHeight) + 1)
        ZStack(alignment: .topLeading) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { r in
                        row(r, width: w, height: rowH, rows: rows)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .onScrollGeometryChange(for: Int.self) { Int(($0.contentOffset.y / rowH).rounded(.down)) } action: { _, row in
                if row != rowSeen { rowSeen = row; Haptic.detent() }
                // Two rows from the last filled one: the next page.
                if (row + 6) * 3 >= club.posts.count { Task { await club.loadMore() } }
            }
            // Within the boards' height, cut at the right page's outer edge, rounded like it.
            .frame(width: cw, height: page.height * s, alignment: .leading)
            .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: RollLibrary.boardRadius * s,
                                              topTrailingRadius: RollLibrary.boardRadius * s))
            .offset(x: ClubArt.scrollX * s, y: page.minY * s)
        }
        .task { await club.load() }
    }

    /// A sleeve row threaded on its ring, the rail running past it: a length
    /// of rail (every other one turned over, so the joins never show), the
    /// row, and the ring from the rail through the row's hole.
    private func row(_ r: Int, width w: CGFloat, height h: CGFloat, rows: Int) -> some View {
        let lead = (ClubArt.sleeveX - ClubArt.scrollX) * s
        let railX = (ClubArt.railX - ClubArt.scrollX) * s, railW = ClubArt.railWidth * s
        return ZStack(alignment: .topLeading) {
            Image(uiImage: ClubArt.railMid).resizable()
                .frame(width: railW, height: h)
                .scaleEffect(y: r.isMultiple(of: 2) ? 1 : -1)
                .offset(x: railX)
            if r == 0 {
                Image(uiImage: ClubArt.railTop).resizable()
                    .frame(width: railW, height: railW * ClubArt.railTop.size.height / max(ClubArt.railTop.size.width, 1))
                    .offset(x: railX)
            }
            if r == rows - 1 {
                let capH = railW * ClubArt.railBottom.size.height / max(ClubArt.railBottom.size.width, 1)
                Image(uiImage: ClubArt.railBottom).resizable()
                    .frame(width: railW, height: capH)
                    .offset(x: railX, y: h - capH)
            }
            sleeveRow(r, width: w, height: h)
                .offset(x: lead)
            ring(rowHeight: h, holeX: lead + ClubArt.hole.x * w)
        }
        .frame(width: lead + w, height: h, alignment: .topLeading)
    }

    /// The ring of one row: its seat on the rail, its end through the hole.
    private func ring(rowHeight h: CGFloat, holeX: CGFloat) -> some View {
        let seatX = (ClubArt.seatX - ClubArt.scrollX) * s, y = ClubArt.hole.y * h
        let span = ClubArt.ringHole.x - ClubArt.ringSeat.x
        let k = span > 0 ? (holeX - seatX) / span : 0
        let size = CGSize(width: ClubArt.ring.size.width * k, height: ClubArt.ring.size.height * k)
        return Image(uiImage: ClubArt.ring).resizable()
            .frame(width: size.width, height: size.height)
            .offset(x: seatX - ClubArt.ringSeat.x * k, y: y - ClubArt.ringSeat.y * k)
            .allowsHitTesting(false)
    }

    private func sleeveRow(_ r: Int, width w: CGFloat, height h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: ClubArt.row).resizable().frame(width: w, height: h)
            ForEach(0..<3, id: \.self) { c in
                let i = r * 3 + c
                let p = ClubArt.pockets[c]
                let box = CGRect(x: p.minX * w, y: p.minY * h, width: p.width * w, height: p.height * h).insetBy(dx: 2 * s, dy: 2 * s)
                if i < club.posts.count {
                    pocket(club.posts[i], size: box.size)
                        .offset(x: box.minX, y: box.minY)
                }
            }
        }
        .frame(width: w, height: h)
    }

    /// A picture in its pocket, the plastic's sheen over it, and its slip.
    private func pocket(_ post: Community.Post, size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            PostPicture(url: post.thumbURL)
                .frame(width: size.width, height: size.height)
                .clipped()
            // The sleeve's own sheen, laid back over the picture.
            Image(uiImage: ClubArt.row).resizable()
                .frame(width: size.width, height: size.height)
                .blendMode(.screen).opacity(0.18)
                .allowsHitTesting(false)
            HStack(spacing: 4 * s) {
                Text(verbatim: post.author.name).lineLimit(1)
                Text(verbatim: "·")
                Text(verbatim: FilmNames.short(post.filmId)).lineLimit(1)
                Spacer(minLength: 2 * s)
                Image(systemName: post.likedByMe ? "heart.fill" : "heart").foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
                Text(verbatim: "\(post.likeCount)")
            }
            .font(.custom("Marker Felt", size: 15 * s))
            .foregroundStyle(KitArt.ink)
            .padding(.horizontal, 8 * s).padding(.vertical, 3 * s)
            .background(Image(uiImage: ClubArt.slip).resizable())
            .padding(.horizontal, 6 * s).padding(.bottom, 5 * s)
        }
        // The pocket's own size: the slip's spacer would otherwise widen it
        // to the whole row and push the picture a pocket over.
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptic.click()
            withAnimation(.easeOut(duration: 0.25)) { club.viewing = post }
        }
        // One line for VoiceOver: who, which film, and the hearts or its state.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(post.author.name), \(FilmNames.short(post.filmId)), \(post.likeCount) likes"))
        .accessibilityAddTraits(.isButton)
    }
}

/// The left page: the open themes, each on a kraft slip; the chosen one
/// large with its prompt, the others small beneath it to switch to (GPT art
/// for the theme tags and the rest of the page comes with posting, C3c).
struct ClubThemePage: View {
    @ObservedObject private var club = ClubModel.shared
    @ObservedObject private var reminder = DailyReminder.shared
    @ObservedObject private var language = AppLanguage.shared
    let s: CGFloat
    @GestureState private var drag: CGFloat = 0

    // GPT's parts (design/community/v6/parts, from the chosen v6 art): a
    // stack of call posters under a brass clip, studs for which one, index
    // cards for the film rooms with a red dot on the open one, an envelope
    // for one's own. The page as a photo club's call board (user 11/24).
    static let posters = UIImage(named: "club_posters") ?? UIImage()
    static let clip = UIImage(named: "club_clip") ?? UIImage()
    static let stud = UIImage(named: "club_stud") ?? UIImage()
    static let studOn = UIImage(named: "club_stud_on") ?? UIImage()
    static let card = UIImage(named: "club_card") ?? UIImage()
    static let dot = UIImage(named: "club_dot") ?? UIImage()
    static let envelope = UIImage(named: "club_envelope") ?? UIImage()
    static let tag = UIImage(named: "club_tag") ?? UIImage()
    static let follow = UIImage(named: "club_follow") ?? UIImage()
    /// One's name tag in "Mine" (GPT, design/community/club_nametag_src.png).
    static let nameTag = UIImage(named: "club_nametag") ?? UIImage()
    static let wax = UIImage(named: "club_wax") ?? UIImage()
    static let author = UIImage(named: "club_author") ?? UIImage()
    /// Under the envelope: a tag saying what the album shows (retro 10).
    static let tagRect = CGRect(x: 65, y: 828, width: 300, height: 300 * 107 / 600)
    /// Film rooms per page of cards: everyone first, a "more" card last.
    static let roomsPerPage = 6
    static let more = "more"
    @State private var roomPage = 0
    /// On the posters picture, as fractions: the top poster's window, and the paper under it.
    static let window = CGRect(x: 0.1724, y: 0.054, width: 0.7769, height: 0.5081)
    static let paper = CGRect(x: 0.15, y: 0.585, width: 0.79, height: 0.34)
    /// In the bag's units, on the left page (x 50…380).
    static let posterRect = CGRect(x: 65, y: 46, width: 300, height: 300 * 921 / 700)
    static let roomsTop: CGFloat = 492
    static let envelopeRect = CGRect(x: 65, y: 728, width: 300, height: 300 * 179 / 600)

    /// Every regular roll has a room; seven to a page of cards (retro 10:
    /// not just the first eight).
    private var films: [String] { FilmLibrary.shared.films.filter { !$0.isLimited }.map(\.id) }
    private var pages: Int { max(1, (films.count + Self.roomsPerPage - 1) / Self.roomsPerPage) }
    /// The cards shown: everyone, this page's rolls, and "more" when there are more.
    private var rooms: [String] {
        let page = min(roomPage, pages - 1)
        let shown = films.dropFirst(page * Self.roomsPerPage).prefix(Self.roomsPerPage)
        // Everyone, then the people one follows (S1), then the films.
        return [ClubModel.everyone, ClubModel.followed] + shown + (pages > 1 ? [Self.more] : [])
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !club.isOpen {
                Text("The community opens soon.")
                    .font(.custom("American Typewriter", size: 20 * s))
                    .foregroundStyle(KitArt.ink)
                    .padding(18 * s)
                    .frame(width: ClubArt.navWidth * s, alignment: .leading)
                    .background(Image(uiImage: ClubArt.slip).resizable())
                    .offset(x: ClubArt.navX * s, y: 80 * s)
            } else {
                if let card = club.authorCard, club.room == ClubModel.person(card.id) {
                    authorFolder(card)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    posterStack
                    studs
                }
                if club.signedIn {
                    roomCards
                    envelope
                    if !club.failed { scopeTag }   // failed: the retry takes its place
                } else {
                    ClubSignIn(width: ClubArt.navWidth * s, s: s)
                        .offset(x: ClubArt.navX * s, y: Self.roomsTop * s)
                }
                if club.failed {
                    Button {
                        Haptic.click()
                        Task { await club.reloadAlbumAgain() }
                    } label: {
                        Label("Couldn’t load. Tap to try again.", systemImage: "arrow.clockwise")
                            .font(.custom("American Typewriter", size: 16 * s))
                            .foregroundStyle(KitArt.ink)
                            .padding(12 * s)
                            .frame(width: ClubArt.navWidth * s, alignment: .leading)
                            .background(Image(uiImage: ClubArt.slip).resizable())
                    }
                    .buttonStyle(.plain)
                    .offset(x: ClubArt.navX * s, y: Self.tagRect.minY * s)
                }
            }
        }
    }

    // MARK: The posters

    /// One poster per theme (today, this week, a festival): swipe to the
    /// next; tapping it brings the album back to its pictures.
    private var posterStack: some View {
        let r = Self.posterRect.scaled(s)
        let theme = club.theme
        return ZStack(alignment: .topLeading) {
            Image(uiImage: Self.posters).resizable().frame(width: r.width, height: r.height)
            if let theme {
                posterFace(theme, size: r.size)
                    .id(theme.id)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
        }
        .frame(width: r.width, height: r.height, alignment: .topLeading)
        .offset(x: drag * 0.25)
        .overlay(alignment: .top) {
            let w = 110 * s
            Image(uiImage: Self.clip).resizable().frame(width: w, height: w * 173 / 240)
                .offset(y: -28 * s)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 12)
            .updating($drag) { v, st, _ in st = v.translation.width }
            .onEnded { v in
                if abs(v.translation.width) > 40 { turnPoster(v.translation.width < 0 ? 1 : -1) }
            })
        .onTapGesture {
            guard club.room != nil else { return }
            Haptic.click()
            Task { await club.choose(club.theme) }
        }
        .offset(x: r.minX, y: r.minY)
        .accessibilityElement(children: .contain)
    }

    /// The daily nudge is on offer (S6): once one has posted, until answered.
    private var offering: Bool { reminder.hasPosted && !reminder.offered && !reminder.isOn }

    private func posterFace(_ theme: Community.Theme, size: CGSize) -> some View {
        let win = CGRect(x: Self.window.minX * size.width, y: Self.window.minY * size.height,
                         width: Self.window.width * size.width, height: Self.window.height * size.height)
        let paper = CGRect(x: Self.paper.minX * size.width, y: Self.paper.minY * size.height,
                           width: Self.paper.width * size.width, height: Self.paper.height * size.height)
        // The window: the theme's own cover, else its newest picture (while the album shows it).
        let cover = theme.coverURL ?? club.covers[theme.id]?.thumbURL
        return ZStack(alignment: .topLeading) {
            Group {
                if let cover { PostPicture(url: cover) } else { Color(red: 0.86, green: 0.82, blue: 0.74) }
            }
            .frame(width: win.width, height: win.height)
            .clipped()
            .offset(x: win.minX, y: win.minY)
            .zIndex(-1)
            VStack(alignment: .leading, spacing: 3 * s) {
                kindName(theme.kind).font(.custom("American Typewriter", size: 13 * s)).opacity(0.65)
                Text(verbatim: Community.Theme.text(theme.title, language: language.code))
                    .font(.custom("American Typewriter", size: 24 * s).weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(verbatim: Community.Theme.text(theme.prompt, language: language.code))
                    .font(.custom("American Typewriter", size: 13 * s))
                    .lineLimit(2).minimumScaleFactor(0.8)
                    .opacity(0.85)
                Spacer(minLength: 0)
                // One line at the foot: posting (never squeezed), and — once one
                // has posted — the offer of a daily nudge beside it (S6), ✕ to decline.
                HStack(spacing: 6 * s) {
                    if club.signedIn, theme.isOpen(at: Date()) {
                        Button {
                            Haptic.click()
                            withAnimation(.easeOut(duration: 0.25)) { club.posting = true }
                        } label: {
                            (Text(Image(systemName: "plus")) + Text(verbatim: " ") + Text("Post one"))
                                .font(.custom("American Typewriter", size: 17 * s).weight(.semibold))
                                .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
                                .fixedSize()
                                .frame(minHeight: 32 * s).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Post one"))
                        .layoutPriority(1)
                    }
                    Spacer(minLength: 0)
                    if offering {
                        Button {
                            Haptic.click()
                            Task { await reminder.turnOn() }
                        } label: {
                            ZStack {
                                Image(uiImage: Self.follow).resizable()
                                Text("Remind me daily")
                                    .font(.custom("American Typewriter", size: 12 * s * 1.1, relativeTo: .body).weight(.semibold))
                                    .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
                                    .lineLimit(1).minimumScaleFactor(0.5)
                                    .padding(.horizontal, 5 * s)
                            }
                            .frame(width: 92 * s, height: 24 * s)
                            .frame(minHeight: 36).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button { reminder.turnOff(declined: true) } label: {
                            Image(systemName: "xmark").font(.system(size: 10 * s * 1.2, weight: .semibold))
                                .foregroundStyle(KitArt.ink.opacity(0.5))
                                .frame(minWidth: 24, minHeight: 36).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("No thanks"))
                    }
                }
            }
            .foregroundStyle(KitArt.ink)
            .frame(width: paper.width, height: paper.height, alignment: .topLeading)
            .offset(x: paper.minX, y: paper.minY)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// One stud per poster, the open one red; tap one to go to it.
    private var studs: some View {
        let list = club.themes
        let d = 22 * s, gap = 12 * s
        let total = CGFloat(list.count) * d + CGFloat(max(list.count - 1, 0)) * gap
        return HStack(spacing: gap) {
            ForEach(list) { t in
                Button {
                    Haptic.click()
                    Task { await club.choose(t) }
                } label: {
                    // Red only while the album shows that theme (not a room).
                    Image(uiImage: t.id == club.theme?.id && club.room == nil ? Self.studOn : Self.stud).resizable()
                        .frame(width: d, height: d)
                        .frame(width: max(d, 30), height: max(d, 30)).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: Community.Theme.text(t.title, language: language.code)))
                .accessibilityAddTraits(t.id == club.theme?.id && club.room == nil ? .isSelected : [])
            }
        }
        .offset(x: (ClubArt.navX + ClubArt.navWidth / 2) * s - total / 2, y: (Self.posterRect.maxY + 6) * s)
    }

    private func turnPoster(_ d: Int) {
        let list = club.themes
        guard let i = list.firstIndex(where: { $0.id == club.theme?.id }) else { return }
        let j = i + d
        guard list.indices.contains(j) else { Haptic.detent(); return }
        Haptic.click()
        Task { await club.choose(list[j]) }
    }

    // MARK: The film rooms

    /// Three rows of index cards: everyone's latest, then a room per film;
    /// the open one wears the red dot.
    private var roomCards: some View {
        let w = 100 * s, h = w * 208 / 420, gap = 10 * s
        // Rows a touch target apart (at least 30 points), not the cards' own height.
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(w), spacing: gap), count: 3), spacing: 2 * s) {
            ForEach(rooms, id: \.self) { id in
                // "More" wears the dot when the open room is on another page.
                let open = club.room == id || (id == Self.more && club.room.map { r in films.contains(r) && !rooms.contains(r) } == true)
                Button {
                    Haptic.click()
                    if id == Self.more {
                        withAnimation(.easeInOut(duration: 0.2)) { roomPage = (roomPage + 1) % pages }
                    } else {
                        Task { await club.chooseRoom(club.room == id ? nil : id) }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: Self.card).resizable()
                        Group {
                            if id == ClubModel.everyone { Text("Everyone") }
                            else if id == ClubModel.followed { Text("Following") }
                            else if id == Self.more { Text("More rolls \(min(roomPage, pages - 1) + 1)/\(pages)") }
                            else { Text(verbatim: FilmNames.short(id)) }
                        }
                        .font(.custom("American Typewriter", size: 14 * s).weight(open ? .semibold : .regular))
                        .foregroundStyle(KitArt.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .accessibilityHidden(true)   // the card says it whole (its label below)
                        .padding(.horizontal, 8 * s)
                        .frame(width: w, height: h)
                        .offset(y: 4 * s)
                        if open {
                            Image(uiImage: Self.dot).resizable().frame(width: 14 * s, height: 14 * s)
                                .offset(x: -6 * s, y: 6 * s)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: w, height: h)
                    .offset(y: open ? -2 * s : 0)
                    .shadow(color: .black.opacity(open ? 0.45 : 0.25), radius: (open ? 4 : 2) * s, y: (open ? 3 : 1) * s)
                    .frame(minHeight: max(30, h + 8 * s)).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Said apart from the rolls themselves (the film pages have buttons by those names),
                // as one element: its words aren't read again on their own.
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(id == ClubModel.everyone ? Text("Everyone")
                                    : id == ClubModel.followed ? Text("Pictures by people you follow")
                                    : id == Self.more ? Text("More rolls \(min(roomPage, pages - 1) + 1)/\(pages)")
                                    : Text("Pictures on \(FilmNames.short(id))"))
                .accessibilityAddTraits(open ? .isSelected : [])
            }
        }
        .frame(width: 3 * w + 2 * gap)
        .offset(x: (ClubArt.navX + ClubArt.navWidth / 2) * s - (3 * w + 2 * gap) / 2, y: Self.roomsTop * s)
    }

    // MARK: Someone's page (S2)

    /// Their file, drawn out over the posters: a seal with the first letter
    /// of their name, the name, their films (from public pictures), a follow
    /// label; the pocket takes you back to the theme.
    private func authorFolder(_ card: Community.AuthorCard) -> some View {
        let w = Self.posterRect.width * s, h = w * Self.author.size.height / max(Self.author.size.width, 1)
        let ink = KitArt.ink, red = Color(red: 0.72, green: 0.16, blue: 0.1)
        return ZStack(alignment: .topLeading) {
            Image(uiImage: Self.author).resizable().frame(width: w, height: h)
            Text(verbatim: String(card.name.prefix(1)))
                .font(.custom("American Typewriter", size: 30 * s).weight(.bold))
                .foregroundStyle(red)
                .position(x: 0.140 * w, y: 0.138 * h)
            Text(verbatim: card.name)
                .font(.custom("American Typewriter", size: 26 * s).weight(.semibold))
                .foregroundStyle(ink)
                .lineLimit(1).minimumScaleFactor(0.5)
                .frame(width: 0.74 * w, height: 0.115 * h)
                .position(x: 0.5 * w, y: 0.303 * h)
            VStack(alignment: .leading, spacing: 8 * s) {
                if club.authorFailed {
                    Button {
                        Haptic.click()
                        Task { await club.readAuthorCard(card.id) }
                    } label: {
                        Label("Couldn’t load. Tap to try again.", systemImage: "arrow.clockwise")
                            .font(.custom("American Typewriter", size: 14 * s, relativeTo: .body))
                            .foregroundStyle(ink)
                            .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if let bio = card.bio, !club.authorFailed {
                    Text(verbatim: bio)
                        .font(.custom("American Typewriter", size: 15 * s, relativeTo: .body).italic())
                        .foregroundStyle(ink)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                if !club.authorFailed, card.films > 0, let top = card.topFilm {
                    Text("Mostly \(FilmNames.short(top)) · film stocks used: \(card.films)")
                        .font(.custom("American Typewriter", size: 15 * s, relativeTo: .body))
                        .foregroundStyle(ink.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if card.id != club.me?.profile.id, club.followsKnown {
                    AuthorFollowLabel(author: .init(id: card.id, name: card.name), s: s)
                }
            }
            .frame(width: 0.8 * w, alignment: .leading)
            .offset(x: 0.1 * w, y: 0.39 * h)
            Button {
                Haptic.click()
                Task { await club.choose(club.theme) }
            } label: {
                Label("Back to the theme", systemImage: "chevron.left")
                    .font(.custom("American Typewriter", size: 15 * s, relativeTo: .body).weight(.semibold))
                    .foregroundStyle(ink)
                    .frame(width: 0.9 * w, height: max(44, 0.12 * h))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 0.5 * w, y: 0.93 * h)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .shadow(color: .black.opacity(0.4), radius: 4 * s, y: 2 * s)
        .offset(x: Self.posterRect.minX * s, y: 40 * s)
    }

    // MARK: What the album shows

    /// A tag tied under the envelope: the album's scope in words, so a film's
    /// room is never taken for the theme a picture is posted to.
    private var scopeTag: some View {
        let r = Self.tagRect.scaled(s)
        let words: Text = {
            if let room = club.room {
                if room == ClubModel.followed { return Text("Album: people you follow") }
                if room.hasPrefix("u:") { return Text("Album: pictures by \(club.authorCard?.name ?? "")") }
                return room == ClubModel.everyone ? Text("Album: everyone’s pictures")
                                                  : Text("Album: pictures on \(FilmNames.short(room))")
            }
            if let theme = club.theme {
                return Text("Album: theme “\(Community.Theme.text(theme.title, language: language.code))”")
            }
            return Text("Album")
        }()
        return ZStack(alignment: .leading) {
            Image(uiImage: Self.tag).resizable()
            words
                .font(.custom("American Typewriter", size: 14 * s, relativeTo: .body))
                .foregroundStyle(KitArt.ink)
                .lineLimit(2).minimumScaleFactor(0.6)
                .frame(width: r.width * 0.68, alignment: .leading)
                .offset(x: r.width * 0.28)
        }
        .frame(width: r.width, height: r.height)
        .offset(x: r.minX, y: r.minY)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(words)
    }

    // MARK: Mine

    private var envelope: some View {
        let r = Self.envelopeRect.scaled(s)
        // Only what others did shows here; an admin's to-do counts live in the admin tabs (retro 12).
        let unread = club.noticeUnread > 0
        return Button {
            Haptic.click()
            Task { await club.openMine() }
        } label: {
            ZStack(alignment: .leading) {
                Image(uiImage: Self.envelope).resizable()
                Text("Mine").font(.custom("American Typewriter", size: 22 * s).weight(.semibold))
                    .foregroundStyle(KitArt.ink)
                    .padding(.leading, 24 * s)
            }
            .frame(width: r.width, height: r.height)
            .overlay(alignment: .topTrailing) {
                if unread {
                    // A red wax dot (GPT, design/community/club_wax_src.png): something new.
                    Image(uiImage: Self.wax).resizable()
                        .frame(width: 26 * s, height: 26 * s)
                        .shadow(color: .black.opacity(0.35), radius: 1.5 * s, y: 1 * s)
                        .offset(x: 6 * s, y: -8 * s)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(unread ? Text("Something new") : Text(verbatim: ""))
        .offset(x: r.minX, y: r.minY)
    }

    private func kindName(_ kind: Community.Theme.Kind) -> Text {
        switch kind {
        case .daily: Text("Today’s theme")
        case .weekly: Text("This week’s theme")
        case .festival: Text("Festival theme")
        }
    }
}

/// Short film names for the slips (the rolls' own words).
enum FilmNames {
    static func short(_ id: String) -> String {
        FilmLibrary.shared.films.first { $0.id == id }?.name ?? id
    }
}

/// A post drawn out of its pocket (community_detail_v2: the picture large,
/// a kraft card under it): who, which film, which theme, when, their line;
/// the heart; report and block. Tap outside or Close to put it back.
struct ClubPostViewer: View {
    @ObservedObject private var club = ClubModel.shared
    @ObservedObject private var language = AppLanguage.shared
    let post: Community.Post
    /// How far past its frame the screen's glass goes (the safe area the bag
    /// keeps clear of): full screen reaches it.
    var outset: CGFloat = 0
    /// The comment line has the keyboard: a tap anywhere else puts it away (user 11/25).
    @FocusState private var writing: Bool
    /// The open ⋯ bubble: "post", "post:report", "c:<id>", "c:<id>:report", "c:<id>:del".
    @State private var menu: String? = UserDefaults.standard.string(forKey: "clubMenu")   // `-clubMenu post`, for checks
    /// The picture over the whole screen, filling it (user 11/24: no bars;
    /// a double tap goes there; the same button, in the same place, comes back).
    @State private var fullScreen = UserDefaults.standard.bool(forKey: "clubFull")   // `-clubFull 1`, for checks
    /// Full screen, the words over the picture; a tap on it hides or shows them.
    @State private var wordsShown = true
    /// The picture's width over its height, once it's in.
    @State private var aspect: CGFloat = 1.5
    /// Which way the last swipe went: the next picture comes in from that side.
    @State private var direction = 1
    /// A heart over the picture for a moment: liked with a double tap.
    @State private var heart = false
    /// A word on how to use it, the first few times (user 11/24).
    @State private var hint: LocalizedStringKey?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let wide = w > h * 1.1
            ZStack {
                Color.black.opacity(fullScreen ? 1 : 0.88).ignoresSafeArea()
                    .onTapGesture {
                        if writing { writing = false } else if menu != nil { closeMenu() } else if !fullScreen { close() }
                    }
                if fullScreen {
                    ZoomablePicture(onDoubleTap: { likeByTap() }, onTap: {
                        if writing { writing = false; return }
                        if menu != nil { closeMenu(); return }
                        withAnimation(.easeInOut(duration: 0.2)) { wordsShown.toggle() }
                    }, onSwipe: { step($0) }) { PostPicture(url: post.photoURL, fill: true) }
                        .accessibilityElement()
                        .accessibilityIdentifier("viewer-picture")
                        // The bag's canvas stops at the safe area (the camera
                        // island's side); the picture reaches past it to the glass.
                        .padding(-outset)
                        .ignoresSafeArea()
                        .id(post.id)
                        .transition(slide)
                    if heart {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 96))
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.35), radius: 10)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                    if wordsShown {
                        side(height: h * 0.72)
                            .frame(width: sideWidth(w), height: h * 0.72)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(16)
                            .transition(.opacity)
                    }
                } else {
                    // Side by side on a wide screen, one above the other on a
                    // narrow one; the words never wider than the picture's column.
                    let box = wide ? CGSize(width: w - sideWidth(w) - 48, height: h * 0.84)
                                   : CGSize(width: w * 0.9, height: h * 0.5)
                    let pic = fit(box)
                    let picture = ZoomablePicture(onDoubleTap: { goFull(true) }, onTap: {
                        if writing { writing = false } else if menu != nil { closeMenu() }
                    }, onSwipe: { step($0) }) {
                        PostPicture(url: post.photoURL, fill: false) { size in
                            if size.height > 0 { aspect = size.width / size.height }
                        }
                    }
                    .frame(width: pic.width, height: pic.height)
                    .accessibilityElement()
                    .accessibilityIdentifier("viewer-picture")
                    .accessibilityAddTraits(.isImage)
                    .id(post.id)
                    .transition(slide)
                    if wide {
                        HStack(alignment: .top, spacing: 14) {
                            picture
                            side(height: pic.height).frame(width: sideWidth(w), height: pic.height)
                        }
                    } else {
                        let colW = max(pic.width, min(w * 0.9, 420))
                        VStack(spacing: 10) {
                            picture
                            side(height: h * 0.34).frame(width: colW, height: h * 0.34)
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .task(id: post.id) { await club.loadThread(post) }
            // The ⋯ bubbles, drawn over everything at their buttons, over a
            // layer that takes any other tap to put them away (user 11/25:
            // a bubble opened by mistake couldn't be got rid of).
            .overlayPreferenceValue(MenuAnchorKey.self) { anchors in
                GeometryReader { proxy in
                    if let menu, !typeSize.isAccessibilitySize, let key = menuKey(menu), let anchor = anchors[key] {
                        let r = proxy[anchor]
                        ZStack(alignment: .topLeading) {
                            Color.black.opacity(0.001).contentShape(Rectangle())
                                .onTapGesture { closeMenu() }
                            if key == "post" {
                                MenuBubble(arrow: .top) { postMenu }
                                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topTrailing)
                                    .offset(x: r.midX + 15 - proxy.size.width, y: r.maxY - 6)
                                    .transition(.opacity)
                            } else if let c = club.thread.first(where: { "c:" + $0.id == key }) {
                                MenuBubble(arrow: .trailing) { commentMenu(c, mayDelete: mayDelete(c)) }
                                    .alignmentGuide(.top) { $0.height / 2 }
                                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topTrailing)
                                    .offset(x: r.minX + 6 - proxy.size.width, y: r.midY)
                                    .transition(.opacity)
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let hint {
                    Text(hint)
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Capsule().fill(.black.opacity(0.65)))
                        .padding(.bottom, 22)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .onAppear { showHint("Swipe sideways for the next picture · double-tap for full screen", key: "hintClubSwipe") }
            // The same two buttons in the same corner, whichever way it's shown.
            .overlay(alignment: .topTrailing) {
                if !fullScreen || wordsShown {
                    HStack(spacing: 6) {
                        Button { goFull(!fullScreen) } label: {
                            Image(systemName: fullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(.black.opacity(0.5)))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(fullScreen ? "Exit Full Screen" : "Full Screen"))
                        Button("Close") { close() }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(.black.opacity(0.5)))
                    }
                    .padding(16)
                    .transition(.opacity)
                }
            }
        }
    }

    private func sideWidth(_ w: CGFloat) -> CGFloat { min(360, w * 0.34) }

    /// The picture's own shape inside the room it has.
    private func fit(_ box: CGSize) -> CGSize {
        let k = min(box.width / aspect, box.height)
        return CGSize(width: k * aspect, height: k)
    }

    private func goFull(_ on: Bool) {
        Haptic.click()
        withAnimation(.easeInOut(duration: 0.22)) { fullScreen = on; wordsShown = true }
        if on { showHint("Tap to hide the words · double-tap to like", key: "hintClubFull") }
    }

    /// The next picture slides in from the side the finger went to.
    private var slide: AnyTransition {
        .asymmetric(insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .opacity)
    }

    /// The one after (+1) or before (-1) in the album, like turning prints
    /// over one by one (user 11/24); the album reads on as the end nears.
    private func step(_ d: Int) {
        guard let i = club.posts.firstIndex(where: { $0.id == post.id }) else { return }
        let j = i + d
        guard club.posts.indices.contains(j) else {
            Haptic.detent()
            if d > 0 { club.note = Text("No more pictures here.") }
            return
        }
        Haptic.click()
        direction = d
        menu = nil
        withAnimation(.easeOut(duration: 0.25)) { club.viewing = club.posts[j] }
        if j + 6 >= club.posts.count { Task { await club.loadMore() } }
    }

    /// A double tap on the full-screen picture likes it (never un-likes it).
    private func likeByTap() {
        let shown = club.viewing ?? post
        Haptic.tap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { heart = true }
        Task {
            if !shown.likedByMe { await club.toggleLike(shown) }
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 0.25)) { heart = false }
        }
    }

    /// Shown the first three times only, then never again.
    private func showHint(_ text: LocalizedStringKey, key: String) {
        let seen = UserDefaults.standard.integer(forKey: key)
        guard seen < 3 else { return }
        UserDefaults.standard.set(seen + 1, forKey: key)
        withAnimation(.easeOut(duration: 0.25)) { hint = text }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeIn(duration: 0.3)) { if hint == text { hint = nil } }
        }
    }

    /// Who, what, likes, then the comments under it, as one narrow column.
    private func side(height: CGFloat) -> some View {
        VStack(spacing: 8) {
            card.zIndex(1)   // its bubble opens over the comments
                .contentShape(Rectangle())
                .onTapGesture { writing = false }   // the keyboard away with a tap on the card
            back()
        }
        .modifier(ScrollWhenLarge(on: typeSize.isAccessibilitySize))
    }

    private var card: some View {
        let theme = club.themes.first { $0.id == post.themeId }
        let shown = club.viewing ?? post
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 0) {
                Button {
                    Haptic.click()
                    Task { await club.openAuthor(post.author) }   // their page (S2)
                } label: {
                    Text(verbatim: post.author.name).font(.custom("American Typewriter", size: 17, relativeTo: .body).weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("viewer-author")
                .accessibilityHint(Text("Opens their page"))
                .layoutPriority(1)
                Spacer(minLength: 6)
                Button {
                    Haptic.click()
                    Task { await club.toggleLike(shown) }
                } label: {
                    Label("\(shown.likeCount)", systemImage: shown.likedByMe ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
                        .fixedSize()
                        .frame(minHeight: 36).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Like"))
                // A faint ⋯ (user 11/24: the flag didn't read as reporting, and
                // the reasons pushed the card open): a small bubble comes out
                // of it, over everything, and goes again.
                if post.author.id != club.me?.profile.id {
                    moreButton(open: menu?.hasPrefix("post") == true, size: 17) { toggleMenu("post") }
                        .anchorPreference(key: MenuAnchorKey.self, value: .bounds) { ["post": $0] }
                }
            }
            // Film, theme and day on one quiet line under the name.
            // One run of words, so it wraps as words at the largest sizes; the
            // follow label at its end (the name's line is full, S1).
            HStack(alignment: .center, spacing: 6) {
                (Text(verbatim: FilmNames.short(post.filmId))
                 + Text(verbatim: theme.map { " · " + Community.Theme.text($0.title, language: language.code) } ?? "")
                 + Text(verbatim: " · ")
                 + Text(post.createdAt, format: .dateTime.month().day()))
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1).minimumScaleFactor(0.8)
                .font(.custom("American Typewriter", size: 12, relativeTo: .body))
                .opacity(0.75)
                Spacer(minLength: 0)
                // Only once whom one follows is known (a failed read never shows "Follow" wrongly).
                if club.signedIn, club.followsKnown, post.author.id != club.me?.profile.id { followLabel(post.author).fixedSize() }
            }
            // At the largest text sizes the column scrolls and would clip a
            // floating bubble: its words open in the card itself instead.
            if typeSize.isAccessibilitySize, menu == "post" || menu == "post:report" {
                VStack(alignment: .leading, spacing: 0) { postMenu }
                    .padding(.vertical, 4)
            }
            if let caption = post.caption, !caption.isEmpty {
                Text(verbatim: caption).font(.custom("American Typewriter", size: 15, relativeTo: .body))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(KitArt.ink)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Image(uiImage: ClubArt.slip).resizable())
    }


    /// The comments, oldest first, and a line to write one (≤120, approved first).
    private func back() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if club.threadFailed {
                Button { Task { await club.loadThread(post) } } label: {
                    Label("Couldn’t load. Tap to try again.", systemImage: "arrow.clockwise").font(.custom("American Typewriter", size: 15, relativeTo: .body))
                }
                .buttonStyle(.plain)
            } else if club.thread.isEmpty {
                Text("No comments yet.").font(.custom("American Typewriter", size: 15, relativeTo: .body)).opacity(0.55)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(club.thread) { c in commentRow(c) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
            if club.signedIn {
                HStack(spacing: 8) {
                    TextField("", text: $club.commentDraft, prompt: Text("Write a comment").foregroundStyle(KitArt.ink.opacity(0.5)))
                        .font(.custom("American Typewriter", size: 14, relativeTo: .body))
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.5)))
                        .disabled(club.commenting)
                        .onChange(of: club.commentDraft) { _, new in
                            if new.count > Community.commentLimit { club.commentDraft = String(new.prefix(Community.commentLimit)) }
                        }
                        .focused($writing)
                        .submitLabel(.send)
                        .onSubmit { Task { await club.sendComment(on: post) } }
                    Button { Haptic.click(); Task { await club.sendComment(on: post) } } label: {
                        Text(club.commenting ? "Sending…" : "Send")
                            .font(.custom("American Typewriter", size: 14, relativeTo: .body).weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(minHeight: 34)
                            .background(Capsule().fill(Color(red: 0.72, green: 0.16, blue: 0.1)
                                .opacity(club.commentDraft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)))
                    }
                    .buttonStyle(.plain)
                    .disabled(club.commenting || club.commentDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(KitArt.ink)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Image(uiImage: ClubArt.slip).resizable())
    }

    private func commentRow(_ c: Community.Comment) -> some View {
        let mayDelete = c.mine == true || post.author.id == club.me?.profile.id || club.me?.isAdmin == true
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                (Text(verbatim: c.author.name + "  ").font(.custom("American Typewriter", size: 14, relativeTo: .body).weight(.semibold))
                 + Text(verbatim: c.text).font(.custom("American Typewriter", size: 14, relativeTo: .body)))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                // One faint ⋯ (user 11/24): deleting (one's own, or under one's
                // picture), reporting and blocking (others') in a bubble beside it.
                if mayDelete || c.mine != true {
                    moreButton(open: menu?.hasPrefix("c:" + c.id) == true, size: 14) { toggleMenu("c:" + c.id) }
                        .anchorPreference(key: MenuAnchorKey.self, value: .bounds) { ["c:" + c.id: $0] }
                }
            }
            if typeSize.isAccessibilitySize, menu?.hasPrefix("c:" + c.id) == true {
                // Largest text: in the row itself, on lines of their own.
                VStack(alignment: .leading, spacing: 0) { commentMenu(c, mayDelete: mayDelete) }
            }
        }
        .zIndex(menu?.hasPrefix("c:" + c.id) == true ? 1 : 0)
    }

    private func moreButton(open: Bool, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button { Haptic.click(); action() } label: {
            Image(systemName: "ellipsis").font(.system(size: size, weight: .semibold))
                .opacity(open ? 0.9 : 0.7)   // findable (user 11/25: couldn't find it)
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("More"))
    }

    /// A small paper label beside the name: follow, or following (S1). No counts.
    private func followLabel(_ author: Community.Author) -> some View {
        let on = club.followingIDs.contains(author.id)
        let busy = club.followBusy.contains(author.id)
        return Button {
            Haptic.click()
            Task { await club.toggleFollow(author) }
        } label: {
            ZStack {
                Image(uiImage: ClubThemePage.follow).resizable()
                    .opacity(on ? 0.75 : 1)
                (on ? Text("Followed") : Text("Follow"))
                    .font(.custom("American Typewriter", size: 12, relativeTo: .body).weight(.semibold))
                    .foregroundStyle(on ? KitArt.ink.opacity(0.7) : Color(red: 0.72, green: 0.16, blue: 0.1))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 7)
            }
            .frame(width: 52, height: 22)
            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.6 : 1)
        .accessibilityLabel(on ? Text("Following \(author.name)") : Text("Follow \(author.name)"))
    }

    /// Which button a bubble state belongs to: "post" or "c:<id>".
    private func menuKey(_ m: String) -> String? {
        if m.hasPrefix("post") { return "post" }
        guard m.hasPrefix("c:") else { return nil }
        let id = m.dropFirst(2).split(separator: ":").first.map(String.init) ?? ""
        return "c:" + id
    }

    private func mayDelete(_ c: Community.Comment) -> Bool {
        c.mine == true || post.author.id == club.me?.profile.id || club.me?.isAdmin == true
    }

    private func toggleMenu(_ key: String) {
        withAnimation(.easeOut(duration: 0.15)) { menu = menu?.hasPrefix(key) == true ? nil : key }
    }

    private func closeMenu() { withAnimation(.easeIn(duration: 0.12)) { menu = nil } }

    /// The post's bubble: report (then why), or block its author.
    @ViewBuilder private var postMenu: some View {
        if menu == "post:report" {
            Text("Report because:").font(.custom("American Typewriter", size: 11, relativeTo: .body)).opacity(0.55)
                .padding(.vertical, 3)
            ForEach(Community.ReportReason.allCases, id: \.self) { reason in
                menuItem(reasonName(reason)) { closeMenu(); Task { await club.report(post, reason: reason) } }
            }
        } else {
            menuItem(Text("Report")) { withAnimation(.easeOut(duration: 0.15)) { menu = "post:report" } }
            menuItem(Text("Block \(post.author.name)"), red: true) { closeMenu(); Task { await club.block(post) } }
        }
    }

    /// A comment's bubble, in one line.
    @ViewBuilder private func commentMenu(_ c: Community.Comment, mayDelete: Bool) -> some View {
        // One line in the bubble; one word under another at the largest sizes.
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            if menu == "c:" + c.id + ":del" {
                menuItem(Text("Delete this comment"), red: true) { closeMenu(); Task { await club.deleteComment(c) } }
                menuItem(Text("Keep")) { closeMenu() }
            } else if menu == "c:" + c.id + ":report" {
                ForEach([Community.ReportReason.spam, .hate, .other], id: \.self) { r in
                    menuItem(reasonText(r)) { closeMenu(); Task { await club.reportComment(c, r) } }
                }
            } else {
                if mayDelete { menuItem(Text("Delete")) { withAnimation(.easeOut(duration: 0.15)) { menu = "c:" + c.id + ":del" } } }
                if c.mine != true {
                    menuItem(Text("Report")) { withAnimation(.easeOut(duration: 0.15)) { menu = "c:" + c.id + ":report" } }
                    menuItem(Text("Block \(c.author.name)"), red: true) { closeMenu(); Task { await club.blockCommenter(c) } }
                }
            }
        }
    }

    /// A small word in a bubble.
    private func menuItem(_ title: Text, red: Bool = false, action: @escaping () -> Void) -> some View {
        Button { Haptic.click(); action() } label: {
            title.font(.custom("American Typewriter", size: 13, relativeTo: .body))
                .foregroundStyle(red ? Color(red: 0.72, green: 0.16, blue: 0.1) : KitArt.ink)
                // In a bubble, on one line; opened in the card at the largest sizes, wrapping.
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: true)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading).contentShape(Rectangle())   // small to see, full size to hit (retro 10)
        }
        .buttonStyle(.plain)
    }

    /// A word to tap, no box: 44 points tall to hit, small to see.
    private func textLink(_ title: Text, red: Bool = false, action: @escaping () -> Void) -> some View {
        Button { Haptic.click(); action() } label: {
            title.font(.custom("American Typewriter", size: 14, relativeTo: .body))
                .underline(color: (red ? Color(red: 0.72, green: 0.16, blue: 0.1) : KitArt.ink).opacity(0.25))
                .foregroundStyle(red ? Color(red: 0.72, green: 0.16, blue: 0.1) : KitArt.ink.opacity(0.85))
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func smallButton(_ title: Text, red: Bool = false, action: @escaping () -> Void) -> some View {
        Button { Haptic.click(); action() } label: {
            title.font(.custom("American Typewriter", size: 14, relativeTo: .body))
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(red ? Color(red: 0.72, green: 0.16, blue: 0.1) : KitArt.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 4).stroke(KitArt.ink.opacity(0.25), lineWidth: 1))
                .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func reasonName(_ r: Community.ReportReason) -> Text { reasonText(r) }

    private func close() {
        withAnimation(.easeIn(duration: 0.2)) { club.viewing = nil }
    }
}


/// The community's passing word (reported, blocked…), over the whole bag,
/// whether or not a picture is open; gone after a moment.
struct ClubNote: View {
    @ObservedObject private var club = ClubModel.shared
    var body: some View {
        if let note = club.note {
            note.font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(.black.opacity(0.75)))
                .frame(maxHeight: .infinity, alignment: .top).padding(.top, 24)
                .allowsHitTesting(false)
                .transition(.opacity)
                .task(id: club.noteID) {
                    let mine = club.noteID
                    // Cancelled when a newer word comes: that one keeps its time.
                    guard (try? await Task.sleep(for: .seconds(2.5))) != nil, club.noteID == mine else { return }
                    withAnimation { club.note = nil }
                }
        }
    }
}


/// Posting: a kraft folder of one's own pictures taken with Koco (the
/// system's picker can't tell them apart, so only Koco's own record of its
/// shots), one chosen, a line to go with it, put in (community_post_v2).
struct ClubPostFolder: View {
    @ObservedObject private var club = ClubModel.shared
    @ObservedObject private var log = ShotLog.shared
    @ObservedObject private var language = AppLanguage.shared

    // GPT's parts (design/community/post, from community_post_v2): a kraft
    // folder with its tab, strap, inner panel, a slot to write in and a frame
    // for the chosen print; a clear four-pocket sleeve strip; a red leather
    // button, a brass close button, a red check, a paper label. User 11/24:
    // the stretched slip it was drawn on before looked bad.
    static let folder = UIImage(named: "post_folder") ?? UIImage()
    static let sleeve = UIImage(named: "post_sleeve.jpg") ?? UIImage()
    static let button = UIImage(named: "post_button") ?? UIImage()
    static let closeKnob = UIImage(named: "post_close") ?? UIImage()
    static let check = UIImage(named: "post_check") ?? UIImage()
    static let label = UIImage(named: "post_label") ?? UIImage()
    /// Places on the folder, in its pixels (1326 × 1051).
    static let art = CGSize(width: 1326, height: 1051)
    static let tab = CGRect(x: 104, y: 6, width: 368, height: 96)
    static let panel = CGRect(x: 35, y: 186, width: 1259, height: 658)
    static let thumb = CGRect(x: 74, y: 879, width: 114, height: 112)
    static let slot = CGRect(x: 221, y: 895, width: 1040, height: 86)
    static let knob = CGPoint(x: 1262, y: 112)
    /// The sleeve strip's pockets, in its pixels (1076 × 250).
    static let strip = CGSize(width: 1076, height: 250)
    static let pockets = [CGRect(x: 16, y: 13, width: 262, height: 220), CGRect(x: 291, y: 13, width: 244, height: 220),
                          CGRect(x: 551, y: 13, width: 254, height: 220), CGRect(x: 821, y: 13, width: 249, height: 220)]

    var body: some View {
        GeometryReader { geo in
            let k = min(geo.size.width * 0.94 / Self.art.width, geo.size.height * 0.94 / Self.art.height)
            // Every Koco picture, any day (lazily drawn as the folder scrolls).
            let shots = log.shots.sorted { $0.date > $1.date }
            let chosen = shots.first { $0.asset == club.draftAsset }
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .onTapGesture { close() }
                ZStack(alignment: .topLeading) {
                    Image(uiImage: Self.folder).resizable()
                        .frame(width: Self.art.width * k, height: Self.art.height * k)
                    // The tab's label: where it goes.
                    ZStack {
                        Image(uiImage: Self.label).resizable()
                        Group {
                            if let theme = club.theme {
                                Text("Post to · \(Community.Theme.text(theme.title, language: language.code))")
                            } else { Text("Post one") }
                        }
                        .font(.custom("American Typewriter", size: 34 * k, relativeTo: .body).weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .padding(.horizontal, 22 * k)
                    }
                    .frame(width: Self.tab.width * k, height: Self.tab.height * k * 0.72)
                    .offset(x: Self.tab.minX * k, y: (Self.tab.minY + 14) * k)
                    // Under the strap, the one rule, and what went wrong if it did.
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Only pictures taken with Koco")
                        if club.postFailed {
                            Text("It didn't go. Your picture and words are kept: tap Put it in to try again.")
                                .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
                        }
                    }
                    .font(.custom("American Typewriter", size: 24 * k, relativeTo: .body))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 560 * k, alignment: .trailing)
                    .offset(x: (Self.knob.x - 70 - 560) * k, y: 118 * k)
                    // The close knob.
                    Button { close() } label: {
                        Image(uiImage: Self.closeKnob).resizable().frame(width: 72 * k, height: 72 * k)
                            .frame(width: max(44, 72 * k), height: max(44, 72 * k)).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(club.sending)   // once sending, it goes in; no false cancel
                    .accessibilityLabel(Text("Cancel"))
                    .position(x: Self.knob.x * k, y: Self.knob.y * k)
                    // The sleeves, four to a strip, scrolling inside the panel.
                    panel(shots: shots, chosen: chosen, k: k)
                        .frame(width: Self.panel.width * k - 24 * k, height: Self.panel.height * k - 24 * k)
                        .clipShape(RoundedRectangle(cornerRadius: 10 * k))
                        .offset(x: (Self.panel.minX + 12) * k, y: (Self.panel.minY + 12) * k)
                    // The chosen print in its frame.
                    Group {
                        if let chosen { AssetThumbnail(id: chosen.asset, side: 200) }
                    }
                    .frame(width: Self.thumb.width * k - 10 * k, height: Self.thumb.height * k - 10 * k)
                    .clipShape(RoundedRectangle(cornerRadius: 4 * k))
                    .offset(x: (Self.thumb.minX + 5) * k, y: (Self.thumb.minY + 5) * k)
                    // A line to go with it, written into the slot, and the red button at its end.
                    let buttonW = 300 * k, buttonH = buttonW * Self.button.size.height / max(Self.button.size.width, 1)
                    TextField("", text: $club.draftCaption, prompt: Text("Say something (optional)").foregroundStyle(KitArt.ink.opacity(0.5)))
                        .font(.custom("American Typewriter", size: 30 * k, relativeTo: .body))
                        .foregroundStyle(KitArt.ink)
                        .disabled(club.sending)   // what is being sent stays as it is
                        .onChange(of: club.draftCaption) { _, new in
                            if new.count > Community.captionLimit { club.draftCaption = String(new.prefix(Community.captionLimit)) }
                        }
                        .frame(width: Self.slot.width * k - buttonW - 40 * k, height: Self.slot.height * k)
                        .offset(x: (Self.slot.minX + 22) * k, y: Self.slot.minY * k)
                    Button {
                        guard let shot = chosen else { return }
                        Haptic.click()
                        Task { if await club.post(shot, caption: club.draftCaption) { close() } }
                    } label: {
                        ZStack {
                            Image(uiImage: Self.button).resizable()
                            Text(club.sending ? "Sending…" : "Put it in")
                                .font(.custom("American Typewriter", size: 32 * k, relativeTo: .body).weight(.bold))
                                .foregroundStyle(Color(red: 0.98, green: 0.93, blue: 0.82))
                                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                                .lineLimit(1).minimumScaleFactor(0.6)
                                .padding(.horizontal, 40 * k)
                        }
                        .frame(width: buttonW, height: buttonH)
                        .opacity(chosen == nil ? 0.5 : 1)
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(chosen == nil || club.sending || !club.signedIn)
                    .position(x: (Self.slot.maxX - 8) * k - buttonW / 2, y: Self.slot.midY * k)
                }
                .frame(width: Self.art.width * k, height: Self.art.height * k, alignment: .topLeading)
                .foregroundStyle(KitArt.ink)
                .shadow(color: .black.opacity(0.5), radius: 14 * k, y: 6 * k)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder private func panel(shots: [ShotLog.Shot], chosen: ShotLog.Shot?, k: CGFloat) -> some View {
        let w = Self.panel.width * k - 24 * k
        let rowH = w * Self.strip.height / Self.strip.width, u = w / Self.strip.width
        if shots.isEmpty {
            Text("No pictures taken with Koco yet. Take one first.")
                .font(.custom("American Typewriter", size: 34 * k, relativeTo: .body))
                .foregroundStyle(KitArt.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<((shots.count + 3) / 4), id: \.self) { r in
                            ZStack(alignment: .topLeading) {
                                Image(uiImage: Self.sleeve).resizable().frame(width: w, height: rowH)
                                ForEach(0..<4, id: \.self) { c in
                                    let i = r * 4 + c
                                    if i < shots.count {
                                        pocket(shots[i], chosen: chosen == shots[i], box: Self.pockets[c].scaled(u), u: u)
                                    }
                                }
                            }
                            .frame(width: w, height: rowH)
                        }
                    }
                }
                if !club.signedIn {
                    // Signed out (or the sign-in ran out): sign in here, the draft stays.
                    ClubSignIn(width: min(w * 0.7, 420), s: 1)
                        .padding(14)
                        .background(Image(uiImage: Self.label).resizable())
                        .padding(.bottom, 10)
                }
            }
        }
    }

    /// One picture in a pocket, the plastic's sheen laid back over it; the
    /// chosen one lifts a little and wears the red check.
    private func pocket(_ shot: ShotLog.Shot, chosen: Bool, box: CGRect, u: CGFloat) -> some View {
        let inner = box.insetBy(dx: 14 * u, dy: 12 * u)
        return AssetThumbnail(id: shot.asset, side: 300)
            .frame(width: inner.width, height: inner.height)
            .clipped()
            .overlay(Image(uiImage: Self.sleeve).resizable().scaledToFill()
                .frame(width: inner.width, height: inner.height).clipped()
                .blendMode(.screen).opacity(0.1).allowsHitTesting(false))
            .scaleEffect(chosen ? 1.04 : 1)
            .shadow(color: .black.opacity(chosen ? 0.45 : 0), radius: 6 * u, y: 3 * u)
            .overlay(alignment: .topTrailing) {
                if chosen {
                    Image(uiImage: Self.check).resizable()
                        .frame(width: 46 * u, height: 46 * u)
                        .offset(x: 10 * u, y: -10 * u)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !club.sending else { return }
                Haptic.click()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { club.draftAsset = shot.asset }
            }
            .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
            .offset(x: inner.minX, y: inner.minY)
    }

    private func close() {
        guard !club.sending else { return }
        withAnimation(.easeIn(duration: 0.2)) { club.posting = false }
    }
}


/// Sign in with Apple, on the theme column while signed out: posting,
/// liking and looking at others' pictures need it (C2b).
struct ClubSignIn: View {
    let width: CGFloat
    let s: CGFloat
    @ObservedObject private var club = ClubModel.shared
    /// This attempt's nonce: Apple's token carries its hash, the server
    /// checks the two match (no replaying someone else's token).
    @State private var nonce = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10 * s) {
            Text("Sign in to see everyone’s pictures and post your own.")
                .font(.custom("American Typewriter", size: 18 * s))
                .foregroundStyle(KitArt.ink)
                .fixedSize(horizontal: false, vertical: true)
            SignInWithAppleButton(.signIn) { request in
                nonce = Self.randomNonce()
                request.requestedScopes = [.fullName]
                request.nonce = Self.sha256(nonce)
            } onCompletion: { result in
                guard case .success(let auth) = result,
                      let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                      let token = cred.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
                      let code = cred.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }) else {
                    if case .failure(let error) = result { Diag.note("apple sign-in: \(error)") }
                    return
                }
                let name = cred.fullName.flatMap { PersonNameComponentsFormatter.localizedString(from: $0, style: .short) }
                Task {
                    await club.signIn(.init(identityToken: token, authorizationCode: code, nonce: nonce,
                                            name: name?.isEmpty == false ? name : nil))
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: max(44, 56 * s))
        }
        .padding(18 * s)
        .frame(width: width, alignment: .leading)
        .background(Image(uiImage: ClubArt.slip).resizable())
    }

    static func randomNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString().replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-")
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}


/// "Mine": one's name and days in a row; for admins, what waits for them —
/// pictures to approve, reports, alerts (C2c). Laid over the bag like the
/// posting folder, on the same kraft.
struct ClubMinePanel: View {
    @ObservedObject private var club = ClubModel.shared
    @ObservedObject private var reminder = DailyReminder.shared
    @Environment(\.openURL) private var openURL
    @State private var tab = 0
    @State private var banning: String?
    /// The milestone whose voucher is being turned into a roll.
    @State private var choosingFor: Int?

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.9, 760), h = geo.size.height * 0.86
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { close() }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        nameTag
                        Text("\(club.me?.streak ?? 0) days in a row").font(.custom("American Typewriter", size: 17, relativeTo: .body)).opacity(0.7)
                        Spacer()
                        Button("Close") { close() }.font(.custom("American Typewriter", size: 18, relativeTo: .body))
                    }
                    nameActions
                    bioLine
                    // Everything between the name and the account row scrolls as
                    // one, so nothing is squeezed out of the paper (S4b).
                    ScrollViewReader { proxy in
                    ScrollView { VStack(alignment: .leading, spacing: 12) {
                    rewards
                    if let days = choosingFor { voucherPicker(days) }
                    if !club.notices.isEmpty || club.noticesFailed { noticeList }
                    if !club.mineList.posts.isEmpty { mineRow }
                    if !club.followingPeople.isEmpty || !club.followerPeople.isEmpty { followLists }
                    if club.me?.isAdmin == true {
                        ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) {
                            tabButton(0, Text("Waiting \(club.queue.count)"))
                            tabButton(1, Text("Reports \(club.reported.count)"))
                            tabButton(4, Text("Comments \(club.modComments.count)"))
                            tabButton(2, Text("Hidden \(club.hiddenPosts.count)"))
                            tabButton(5, Text("Names \(club.nameRequests.count + club.bioRequests.count)"))
                            tabButton(3, Text("Alerts"))
                        } }
                        LazyVStack(alignment: .leading, spacing: 10) {
                            switch tab {
                            case 0: queueList
                            case 1: reportList
                            case 2: hiddenList
                            case 4: commentModList
                            case 5: nameList
                            default: alertList
                            }
                        }
                    } else {
                        Text("A picture approved in a theme counts its day. Three days in a row give Porto 400; seven and fourteen give limited rolls that are never sold. Once reached, a roll stays yours to claim.")
                            .font(.custom("American Typewriter", size: 16, relativeTo: .body)).opacity(0.75)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    }.frame(maxWidth: .infinity, alignment: .leading) }
                    .refreshable { await club.refreshNotices(); if club.me?.isAdmin == true { await club.refreshModeration() } }
                    .onAppear {
                        // Back from a follower's page: where one was in the list.
                        if let key = club.mineReturnTo {
                            // After the rows are laid out; the mark goes only then.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                proxy.scrollTo(key, anchor: .center)
                                club.mineReturnTo = nil
                            }
                        }
                    }
                    }
                    account
                }
                .modifier(ScrollWhenLarge(on: typeSize.isAccessibilitySize))
                .task { await reminder.refresh() }   // turned off in Settings: shown off here
                #if DEBUG
                .onAppear { if UserDefaults.standard.bool(forKey: "clubRenaming") { renaming = "Koco" } }   // `-clubRenaming 1`, for checks
                #endif
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task { await reminder.refresh() }   // back from Settings
                }
                .foregroundStyle(KitArt.ink)
                .padding(22)
                .frame(width: w, height: h)
                .background(Image(uiImage: ClubArt.slip).resizable())
            }
        }
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    /// The three milestones, as claim slips: reached and waiting, claimed, or days to go.
    /// Side by side; one under another at the largest text sizes.
    private var rewards: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            ForEach(Community.Me.milestones, id: \.days) { m in
                // The roll given: the milestone's, or the one a voucher became.
                let given = club.me?.rewards.first { $0.milestone == m.days }?.filmId
                let film = FilmLibrary.shared.films.first { $0.id == (given.flatMap { $0 == Community.voucher || $0 == Community.badge ? nil : $0 } ?? m.film) }
                let claimed = club.me?.claimed(m.days) == true
                let reached = club.me?.reached(m.days) == true
                let voucher = club.me?.rewards.first { $0.milestone == m.days }?.filmId == Community.voucher
                let badge = club.me?.rewards.first { $0.milestone == m.days }?.filmId == Community.badge
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(m.days) days").font(.custom("American Typewriter", size: 15, relativeTo: .body)).opacity(0.7)
                    if badge {
                        // The keepsake (every roll had): its name, and the pin itself (GPT art).
                        Text("Keepsake badge").font(.custom("American Typewriter", size: 19, relativeTo: .body).weight(.semibold)).lineLimit(1)
                        Image(uiImage: ClubArt.badge).resizable().scaledToFit().frame(width: 40, height: 40)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                            .accessibilityHidden(true)
                    } else {
                        Text(verbatim: film?.name ?? m.film).font(.custom("American Typewriter", size: 19, relativeTo: .body).weight(.semibold)).lineLimit(1)
                    }
                    if badge {
                    } else if voucher {
                        // A voucher waiting to become a roll; with every roll had, the badge instead.
                        if club.voucherChoices.isEmpty {
                            Button { Haptic.click(); Task { await club.redeemBadge(m.days) } } label: {
                                Text("Take the keepsake badge").font(.custom("American Typewriter", size: 15, relativeTo: .body).weight(.semibold))
                                    .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button { Haptic.click(); choosingFor = m.days } label: {
                                Text("Voucher · choose a roll")
                                    .font(.custom("American Typewriter", size: 15, relativeTo: .body).weight(.semibold))
                                    .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
                            }
                            .buttonStyle(.plain)
                        }
                    } else if claimed {
                        Label("Claimed", systemImage: "checkmark").font(.custom("American Typewriter", size: 15, relativeTo: .body))
                    } else if reached, let film, FilmStore.shared.owns(film), !film.isLimited {
                        // Had already: a voucher for another roll, or with every roll the badge.
                        Button { Haptic.click(); Task { await club.claim(m.days) } } label: {
                            Text(ClubModel.hasEveryRoll ? "Claim the keepsake badge" : "Claim a voucher").font(.custom("American Typewriter", size: 15, relativeTo: .body).weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12).frame(minHeight: 36)
                                .background(Capsule().fill(Color(red: 0.72, green: 0.16, blue: 0.1)))
                        }
                        .buttonStyle(.plain)
                        .disabled(club.claiming != nil)
                    } else if reached {
                        Button { Haptic.click(); Task { await club.claim(m.days) } } label: {
                            Text("Claim").font(.custom("American Typewriter", size: 16, relativeTo: .body).weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14).frame(minHeight: 36)
                                .background(Capsule().fill(Color(red: 0.72, green: 0.16, blue: 0.1)))
                        }
                        .buttonStyle(.plain)
                        .disabled(club.claiming != nil)
                        .opacity(club.claiming == m.days ? 0.5 : 1)
                    } else {
                        Text("\(max(m.days - (club.me?.streak ?? 0), 1)) more days").font(.custom("American Typewriter", size: 15, relativeTo: .body)).opacity(0.6)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 6).stroke(KitArt.ink.opacity(claimed || reached ? 0.45 : 0.18), lineWidth: claimed || reached ? 1.5 : 1))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func tabButton(_ i: Int, _ title: Text) -> some View {
        Button { Haptic.click(); tab = i } label: {
            title.font(.custom("American Typewriter", size: 17, relativeTo: .body).weight(tab == i ? .semibold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 6).fill(KitArt.ink.opacity(tab == i ? 0.14 : 0.04)))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var queueList: some View {
        if club.queue.isEmpty { empty(Text("Nothing waiting.")) }
        ForEach(club.queue) { post in
            row(post) {
                action(Text("Approve"), strong: true) { Task { await club.moderate(post, .approve) } }
                action(Text("Turn down")) { Task { await club.moderate(post, .hide) } }
            }
        }
    }

    @ViewBuilder private var reportList: some View {
        if club.reported.isEmpty { empty(Text("No open reports.")) }
        ForEach(club.reported) { item in
            row(item.post, detail: Text("\(reasonText(item.report.reason)) · \(item.report.reporter.name)")
                    + Text(verbatim: item.report.note.map { "\n“\($0)”" } ?? "")) {
                if item.post.state == .hidden {
                    action(Text("Restore")) { Task { await club.settle(item, .restore) } }
                } else {
                    action(Text("Hide"), strong: true) { Task { await club.settle(item, .hide) } }
                }
                action(Text("Keep")) { Task { await club.settle(item, nil) } }
                if banning == item.post.author.id {
                    action(Text("Ban \(item.post.author.name)?"), red: true) { banning = nil; Task { await club.ban(item.post.author) } }
                } else {
                    action(Text("Ban"), red: true) { banning = item.post.author.id }   // a second tap to be sure
                }
            }
        }
    }

    /// Whom one follows and who follows one: names only, for oneself (S1).
    @ViewBuilder private var followLists: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !club.followingPeople.isEmpty {
                Text("Following").font(.custom("American Typewriter", size: 14, relativeTo: .body)).opacity(0.6)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(club.followingPeople) { p in
                            HStack(spacing: 6) {
                                Text(verbatim: p.name).font(.custom("American Typewriter", size: 16, relativeTo: .body).weight(.semibold))
                                action(Text("Unfollow")) { Task { await club.toggleFollow(.init(id: p.id, name: p.name)) } }
                            }
                        }
                    }
                }
            }
            if !club.followerPeople.isEmpty {
                Text("Following you").font(.custom("American Typewriter", size: 14, relativeTo: .body)).opacity(0.6)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(club.followerPeople) { p in
                            Text(verbatim: p.name).font(.custom("American Typewriter", size: 16, relativeTo: .body))
                        }
                    }
                }
            }
        }
    }

    @State private var renaming: String?
    @State private var confirmingDelete = false
    @FocusState private var naming: Bool

    /// One's name on a paper tag tucked into the envelope (GPT art): tap it to
    /// write a new one right there; saved, it is the same tag again.
    @ViewBuilder private var nameTag: some View {
        let w: CGFloat = 230, h = w * 190 / 1016
        ZStack(alignment: .leading) {
            Image(uiImage: ClubThemePage.nameTag).resizable().frame(width: w, height: h)
            Group {
                if let draft = renaming {
                    TextField("", text: Binding(get: { draft }, set: { renaming = String($0.prefix(12)) }),
                              prompt: Text("2 to 12 letters").foregroundStyle(KitArt.ink.opacity(0.45)))
                        .focused($naming)
                        .submitLabel(.done)
                        .onSubmit { saveName() }
                        .disabled(savingName)
                        .onAppear { naming = true }
                } else {
                    Text(verbatim: club.me?.profile.name ?? "")
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
            }
            .font(.custom("American Typewriter", size: 22, relativeTo: .body).weight(.semibold))
            .foregroundStyle(KitArt.ink)
            .padding(.leading, w * 0.06).padding(.trailing, w * 0.04)
            .frame(width: w, height: h * 0.8, alignment: .leading)
            .offset(y: -h * 0.06)
        }
        .frame(width: w, height: h)
        .contentShape(Rectangle())
        .onTapGesture {
            guard renaming == nil else { return }
            // Within the thirty days: said on the tag, not after typing a new one.
            if let after = renameLocked { club.note = Text("A name can be changed once in 30 days: again from \(after.formatted(date: .abbreviated, time: .omitted))."); return }
            renaming = club.me?.profile.name ?? ""
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(renaming == nil ? .isButton : [])
        .accessibilityHint(renaming == nil ? Text("Change name") : Text(verbatim: ""))
        .overlay(alignment: .bottomTrailing) {
            if renaming == nil {
                (renameLocked.map { Text("From \($0.formatted(date: .abbreviated, time: .omitted))") } ?? Text("Tap to change"))
                    .font(.custom("American Typewriter", size: 11, relativeTo: .caption))
                    .foregroundStyle(KitArt.ink.opacity(0.5))
                    .padding(.trailing, w * 0.05).padding(.bottom, h * 0.2)
                    .accessibilityHidden(true)
            }
        }
    }

    @State private var bioDraft: String?
    @State private var savingBio = false
    @FocusState private var writingBio: Bool

    /// One's line about oneself (S2b), right under the name: tap to write it
    /// there; others see it on one's page once approved.
    @ViewBuilder private var bioLine: some View {
        if let draft = bioDraft {
            HStack(spacing: 8) {
                TextField("", text: Binding(get: { draft }, set: { bioDraft = String($0.prefix(Community.bioLimit)) }),
                          prompt: Text("A line about you, up to 40 letters").foregroundStyle(KitArt.ink.opacity(0.45)))
                    .font(.custom("American Typewriter", size: 16, relativeTo: .body))
                    .focused($writingBio).onAppear { writingBio = true }
                    .submitLabel(.done).onSubmit { saveBio() }
                    .disabled(savingBio)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.4)))
                action(Text(savingBio ? "Saving…" : "Save"), strong: true) { saveBio() }
                action(Text("Cancel")) { guard !savingBio else { return }; bioDraft = nil }
                    .opacity(savingBio ? 0.4 : 1)
            }
        } else {
            Button { bioDraft = club.me?.bio ?? "" } label: {
                Group {
                    if let bio = club.me?.bio { Text(verbatim: bio).italic() } else { Text("Add a line about you").opacity(0.55) }
                }
                .font(.custom("American Typewriter", size: 16, relativeTo: .body))
                .lineLimit(2).frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Change your line"))
        }
    }

    private func saveBio() {
        guard let draft = bioDraft, !savingBio else { return }
        savingBio = true
        Task {
            if await club.setBio(draft) { bioDraft = nil }
            savingBio = false
        }
    }

    /// Until when a new name can't be asked for (nil: it can now).
    private var renameLocked: Date? {
        guard let me = club.me, me.needsRename != true, let after = me.renameAfter, after > .now else { return nil }
        return after
    }

    /// Saving and cancelling a new name: a row of its own under the tag.
    @ViewBuilder private var nameActions: some View {
        if renaming != nil {
            HStack(spacing: 8) {
                action(Text(savingName ? "Saving…" : "Save"), strong: true) { saveName() }
                // A save already sent can't be called back: Cancel waits for it.
                action(Text("Cancel")) { guard !savingName else { return }; nameTurn += 1; renaming = nil }
                    .opacity(savingName ? 0.4 : 1)
            }
        }
    }

    @State private var savingName = false
    /// Bumped on each save or cancel: an older save that ends late leaves a new draft alone.
    @State private var nameTurn = 0

    private func saveName() {
        guard let draft = renaming, !savingName else { return }
        nameTurn += 1
        let mine = nameTurn
        savingName = true
        Task {
            let ok = await club.rename(draft)
            guard mine == nameTurn else { return }
            savingName = false
            if ok { renaming = nil }
        }
    }

    /// One's name, the rules, signing out, deleting the account (C4a).
    @ViewBuilder private var account: some View {
        Divider().overlay(KitArt.ink.opacity(0.2))
        if club.me?.needsRename == true, renaming == nil {
            // An earlier account holds this name (S3): choose another.
            VStack(alignment: .leading, spacing: 6) {
                Text("Someone had this name first. Choose another, so people can tell you apart.")
                    .font(.custom("American Typewriter", size: 15, relativeTo: .body))
                    .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
                    .fixedSize(horizontal: false, vertical: true)
                action(Text("Choose a name"), strong: true) { renaming = "" }
            }
        }
        if confirmingDelete {
            VStack(alignment: .leading, spacing: 8) {
                Text("Delete your account? Your name, pictures, comments, likes, reports, blocks and rewards in the community are deleted for good (pictures are cleared in the background), and Koco's access to your Apple ID is withdrawn. Only a one-way code of your Apple ID is kept with the rewards it claimed, so they can't be claimed again. Rolls already given stay on this iPhone; your pictures in Photos are not touched.")
                    .font(.custom("American Typewriter", size: 15, relativeTo: .body)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    action(Text(club.accountBusy ? "Deleting…" : "Delete my account"), strong: true, red: true) {
                        guard !club.accountBusy else { return }
                        Task { await club.deleteAccount(); confirmingDelete = false }
                    }
                    action(Text("Cancel")) { confirmingDelete = false }
                }
            }
        } else {
            HStack(spacing: 8) {
                // The daily nudge (S6), once one has posted: on and off here.
                if reminder.denied && !reminder.isOn && reminder.hasPosted {
                    // Said no to notifications: only Settings can undo it, so go there.
                    action(Text("Reminder: allow in Settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } else if reminder.hasPosted || reminder.isOn {
                    action(reminder.isOn ? Text("Reminder at 19:00: on")
                           : reminder.failed ? Text("Reminder didn’t turn on: retry") : Text("Reminder at 19:00: off")) {
                        if reminder.isOn { reminder.turnOff() } else { Task { await reminder.turnOn() } }
                    }
                }
                action(Text("Community rules")) { club.rulesOpen = true }
                action(Text("Sign out")) { Task { await club.signOut() } }
                Spacer(minLength: 0)
                action(Text("Delete account"), red: true) { confirmingDelete = true }
            }
        }
    }

    /// One's own pictures (no review states shown: user 11/24).
    private var mineRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("My posts").font(.custom("American Typewriter", size: 17, relativeTo: .body).weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(club.mineList.posts) { p in
                        PostPicture(url: p.thumbURL).frame(width: 84, height: 63).clipped()
                            .onTapGesture { club.viewing = p }
                    }
                }
            }
        }
    }

    /// Rolls not had yet, to turn the voucher into one.
    private func voucherPicker(_ days: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Choose a roll for your voucher").font(.custom("American Typewriter", size: 17, relativeTo: .body).weight(.semibold))
                Spacer()
                Button("Cancel") { choosingFor = nil }.font(.custom("American Typewriter", size: 15, relativeTo: .body))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(club.voucherChoices, id: \.id) { film in
                        Button {
                            Haptic.click()
                            choosingFor = nil
                            Task { await club.redeem(days, film: film) }
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(film.bodyColor).frame(width: 14, height: 14)
                                Text(verbatim: film.name).font(.custom("American Typewriter", size: 15, relativeTo: .body))
                            }
                            .padding(.horizontal, 12).frame(minHeight: 40)
                            .background(RoundedRectangle(cornerRadius: 6).stroke(KitArt.ink.opacity(0.3)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// What others did (S4): comments, likes merged per picture, new
    /// followers by day; newest first, 30 at a time. A row read once it shows.
    private var noticeList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("New for you").font(.custom("American Typewriter", size: 17, relativeTo: .body).weight(.semibold))
            if club.noticesFailed && club.notices.isEmpty {
                Button { Task { await club.refreshNotices() } } label: {
                    Text("Couldn’t load. Tap to try again.").font(.custom("American Typewriter", size: 15, relativeTo: .body)).opacity(0.7)
                }.buttonStyle(.plain)
            }
            // In the panel's one scroll: a row counts as shown when it comes into view.
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(club.notices) { n in
                    Button { Task { await club.openNotice(n) } } label: { noticeRow(n) }
                        .buttonStyle(.plain)
                        .id(n.key)
                        // Read once most of it is really on screen, not when built ahead.
                        .onScrollVisibilityChange(threshold: 0.6) { if $0 { club.noticeShown(n) } }
                }
                if club.moreNoticesFailed {
                    Button { Task { await club.moreNotices() } } label: {
                        Text("Couldn’t load. Tap to try again.").font(.custom("American Typewriter", size: 15, relativeTo: .body)).opacity(0.7)
                            .frame(minHeight: 44)
                    }.buttonStyle(.plain)
                } else if club.noticeNext != nil {
                    Color.clear.frame(height: 1).onAppear { Task { await club.moreNotices() } }
                }
            }
        }
    }

    private func noticeRow(_ n: Community.Notice) -> some View {
        HStack(spacing: 10) {
            if let url = n.thumbURL {
                PostPicture(url: url).frame(width: 46, height: 34).clipShape(RoundedRectangle(cornerRadius: 2))
            }
            noticeLine(n)
                .font(.custom("American Typewriter", size: 15, relativeTo: .body))
                .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            if n.unread {
                Image(uiImage: ClubThemePage.wax).resizable().frame(width: 12, height: 12).accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(n.unread ? Text("New") : Text(verbatim: ""))
    }

    private func noticeLine(_ n: Community.Notice) -> Text {
        let first = n.people.first?.name ?? ""
        let bold = { (s: String) in Text(verbatim: s).fontWeight(.semibold) }
        switch n.kind {
        case .comment:
            return bold(first + "  ") + Text(verbatim: n.text ?? "")
        case .likes:
            if n.count <= 1 { return Text("\(bold(first)) liked this picture") }
            if n.count == 2, n.people.count == 2 { return Text("\(bold(first)) and \(bold(n.people[1].name)) liked this picture") }
            return Text("\(bold(first)) and \(n.count - 1) others liked this picture")
        case .follows:
            if n.count <= 1 { return Text("\(bold(first)) followed you") }
            if n.count == 2, n.people.count == 2 { return Text("\(bold(first)) and \(bold(n.people[1].name)) followed you") }
            return Text("\(bold(first)) and \(n.count - 1) others followed you")
        }
    }

    /// New comments on one's pictures since the last look.
    private var newsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("New comments").font(.custom("American Typewriter", size: 17, relativeTo: .body).weight(.semibold))
            ScrollView { VStack(alignment: .leading, spacing: 6) { ForEach(club.newsShown.comments) { c in
                Button {
                    Task { await club.open(postID: c.postId) }
                } label: {
                    (Text(verbatim: c.author.name + "  ").font(.custom("American Typewriter", size: 15, relativeTo: .body).weight(.semibold))
                     + Text(verbatim: c.text).font(.custom("American Typewriter", size: 15, relativeTo: .body)))
                        .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } } }
            .frame(maxHeight: 160)
        }
    }

    /// Comments waiting for approval, and reported ones.
    @ViewBuilder private var commentModList: some View {
        if club.modComments.isEmpty { empty(Text("Nothing waiting.")) }
        ForEach(club.modComments) { c in
            VStack(alignment: .leading, spacing: 4) {
                (Text(verbatim: c.author.name + "  ").font(.custom("American Typewriter", size: 16, relativeTo: .body).weight(.semibold))
                 + Text(verbatim: c.text).font(.custom("American Typewriter", size: 16, relativeTo: .body)))
                if let reasons = c.reasons, !reasons.isEmpty {
                    HStack(spacing: 6) { ForEach(reasons, id: \.self) { reasonText($0) } }
                        .font(.custom("American Typewriter", size: 13, relativeTo: .body)).opacity(0.6)
                }
                HStack(spacing: 8) {
                    if c.isWaiting {
                        action(Text("Approve"), strong: true) { Task { await club.moderate(c, .approve) } }
                        action(Text("Turn down")) { Task { await club.moderate(c, .hide) } }
                    } else {
                        action(Text("Hide"), strong: true) { Task { await club.moderate(c, .hide) } }
                        action(Text("Keep")) { Task { await club.moderate(c, .restore) } }
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).stroke(KitArt.ink.opacity(0.15)))
        }
    }

    /// Names asked for: the old and the new, approve or turn down (silently, S3).
    @ViewBuilder private var nameList: some View {
        if club.nameRequests.isEmpty && club.bioRequests.isEmpty { empty(Text("No names waiting.")) }
        // Lines about oneself (S2b), with the names: the same kind of decision.
        ForEach(club.bioRequests) { b in
            HStack(spacing: 8) {
                (Text(verbatim: b.name + "  ").fontWeight(.semibold) + Text(verbatim: "“" + b.requested + "”"))
                    .font(.custom("American Typewriter", size: 16, relativeTo: .body))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                action(Text("Approve"), strong: true) { Task { await club.decideBio(b, approve: true) } }
                action(Text("Turn down"), red: true) { Task { await club.decideBio(b, approve: false) } }
            }
        }
        ForEach(club.nameRequests) { n in
            HStack(spacing: 8) {
                Text(verbatim: n.name + " → " + n.requested)
                    .font(.custom("American Typewriter", size: 16, relativeTo: .body))
                Spacer(minLength: 4)
                action(Text("Approve"), strong: true) { Task { await club.decideName(n, approve: true) } }
                action(Text("Turn down"), red: true) { Task { await club.decideName(n, approve: false) } }
            }
        }
    }

    @ViewBuilder private var hiddenList: some View {
        if club.hiddenPosts.isEmpty { empty(Text("Nothing hidden.")) }
        ForEach(club.hiddenPosts) { post in
            row(post) {
                action(Text("Restore"), strong: true) { Task { await club.moderate(post, .restore) } }
            }
        }
    }

    /// What waits and since when, and how the mail is doing (C6a).
    private func statusBox(_ st: Community.AdminStatus) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            waitingLine(Text("Pictures waiting: \(st.pictures.waiting)"), st.pictures.oldest)
            waitingLine(Text("Comments waiting: \(st.comments.waiting)"), st.comments.oldest)
            Text("Open reports: \(st.openReports)")
            if !st.mail.configured {
                Text("Report mail: not set up yet (needs a sending domain)").foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
            } else {
                Text("Report mail: \(st.mail.pending) to send, \(st.mail.failed) failed")
            }
        }
        .font(.custom("American Typewriter", size: 15, relativeTo: .body))
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(KitArt.ink.opacity(0.05)))
    }

    private func waitingLine(_ text: Text, _ oldest: Date?) -> Text {
        guard let oldest else { return text }
        return text + Text(verbatim: " · ") + Text("oldest \(oldest, format: .relative(presentation: .named))")
    }

    /// An alert in the reader's language (the server sends its kind and number).
    private func alertText(_ a: Community.Alert) -> Text {
        let n = Int(a.text) ?? 0
        if a.kind.hasPrefix("report:") {
            return Text("New report: \(Community.ReportReason(rawValue: a.text).map(reasonText) ?? Text(verbatim: a.text))")
        }
        switch a.kind {
        case "queue": return Text("\(n) pictures waiting for approval")
        case "reports": return Text("\(n) open reports")
        case "posts-today": return Text("\(n) posts today")
        case "storage": return Text("\(n) pictures stored: nearing the free storage")
        default: return Text(verbatim: a.text)
        }
    }

    @ViewBuilder private var alertList: some View {
        if let st = club.adminStatus { statusBox(st) }
        ForEach(club.failedMail) { m in
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("A mail didn't go (\(m.attempts) tries)").font(.custom("American Typewriter", size: 15, relativeTo: .body))
                    Text(verbatim: "#\(m.id) · \(m.kind) · \(m.count)").font(.custom("American Typewriter", size: 12, relativeTo: .body)).opacity(0.6)
                    Text(m.createdAt, format: .dateTime.month().day().hour().minute()).font(.custom("American Typewriter", size: 12, relativeTo: .body)).opacity(0.6)
                }
                Spacer(minLength: 4)
                action(Text("Send again"), strong: true) { Task { await club.retryMail(m) } }
            }
        }
        if club.alerts.isEmpty { empty(Text("No alerts.")) }
        ForEach(Array(club.alerts.enumerated()), id: \.offset) { _, a in
            VStack(alignment: .leading, spacing: 2) {
                alertText(a).font(.custom("American Typewriter", size: 16, relativeTo: .body))
                Text(a.createdAt, format: .dateTime.month().day().hour().minute()).font(.custom("American Typewriter", size: 13, relativeTo: .body)).opacity(0.6)
            }
        }
    }

    private func row(_ post: Community.Post, detail: Text? = nil, @ViewBuilder actions: () -> some View) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PostPicture(url: post.thumbURL).frame(width: 120, height: 90).clipped()
                .onTapGesture { club.viewing = post }
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: post.author.name + " · " + FilmNames.short(post.filmId)).font(.custom("American Typewriter", size: 16, relativeTo: .body).weight(.semibold))
                if let caption = post.caption { Text(verbatim: caption).font(.custom("American Typewriter", size: 15, relativeTo: .body)).lineLimit(2) }
                if let detail { detail.font(.custom("American Typewriter", size: 14, relativeTo: .body)).opacity(0.7) }
                HStack(spacing: 8) { actions() }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).stroke(KitArt.ink.opacity(0.15)))
    }

    private func action(_ title: Text, strong: Bool = false, red: Bool = false, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            title.font(.custom("American Typewriter", size: 15, relativeTo: .body).weight(strong ? .semibold : .regular))
                .foregroundStyle(red ? Color(red: 0.72, green: 0.16, blue: 0.1) : KitArt.ink)
                .padding(.horizontal, 12).frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 5).stroke(KitArt.ink.opacity(0.3)))
        }
        .buttonStyle(.plain)
    }

    private func empty(_ text: Text) -> some View {
        text.font(.custom("American Typewriter", size: 17, relativeTo: .body)).opacity(0.6).padding(.vertical, 20)
    }

    private func close() { withAnimation(.easeIn(duration: 0.2)) { club.mineOpen = false } }
}


/// A report's reason in the reader's language.
func reasonText(_ r: Community.ReportReason) -> Text {
    switch r {
    case .nudity: Text("Nudity")
    case .violence: Text("Violence")
    case .hate: Text("Hate")
    case .spam: Text("Spam")
    case .notKoco: Text("Not taken with Koco")
    case .other: Text("Something else")
    }
}


/// The community rules, to agree to before the first post or comment (and
/// again when they change). Agreeing sends what was waiting for them.
struct ClubRules: View {
    @ObservedObject private var club = ClubModel.shared

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.86, 640), h = geo.size.height * 0.84
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { club.declineRules() }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Community rules").font(.custom("American Typewriter", size: 26, relativeTo: .body).weight(.semibold))
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Self.rules.indices, id: \.self) { i in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(verbatim: "\(i + 1).").font(.custom("American Typewriter", size: 16, relativeTo: .body).weight(.semibold))
                                    Self.rules[i].font(.custom("American Typewriter", size: 16, relativeTo: .body)).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: 10) {
                        Spacer()
                        Button(club.me?.needsRules == true ? "Not now" : "Close") { club.declineRules() }
                            .font(.custom("American Typewriter", size: 17, relativeTo: .body)).frame(minHeight: 44)
                        if club.me?.needsRules == true {
                            Button { Haptic.click(); Task { await club.agreeToRules() } } label: {
                                Text("I agree").font(.custom("American Typewriter", size: 18, relativeTo: .body).weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20).frame(minHeight: 44)
                                    .background(Capsule().fill(Color(red: 0.72, green: 0.16, blue: 0.1)))
                            }
                            .buttonStyle(.plain)
                            .disabled(club.accountBusy)
                            .opacity(club.accountBusy ? 0.5 : 1)
                        }
                    }
                }
                .foregroundStyle(KitArt.ink)
                .padding(24)
                .frame(width: w, height: h)
                .background(Image(uiImage: ClubArt.slip).resizable())
            }
        }
    }

    static let rules: [Text] = [
        Text("Post only pictures you took with Koco, that fit the theme."),
        Text("No nudity or sexual content, no violence or gore, no hate or harassment, nothing illegal."),
        Text("Only post people who agreed to be shared, and never someone else's private details."),
        Text("No ads, spam or links. Comments are short and kind."),
        Text("Every picture and comment is looked at before it shows; ones that break these rules are turned down or taken away, and accounts that keep breaking them are closed."),
        Text("If something here is wrong, report it from its ⋯. Blocking someone hides them from you and you from them."),
    ]
}


/// The whole panel scrolls at the largest text sizes, so nothing is cut off (C13).
struct ScrollWhenLarge: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { ScrollView { content }.scrollIndicators(.visible) } else { content }
    }
}


/// A small paper bubble with a pointed tip, coming out of the ⋯ it belongs to
/// (user 11/24: light, pointing at where it came from, never pushing the page).
enum BubbleArrow { case top, trailing }

struct MenuBubble<Content: View>: View {
    let arrow: BubbleArrow
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .foregroundStyle(KitArt.ink)   // its own ink, wherever it is drawn (over the viewer's dark ground)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .padding(arrow == .top ? .top : .trailing, 7)
            .background(BubbleShape(arrow: arrow)
                .fill(Color(red: 0.97, green: 0.94, blue: 0.87))
                .shadow(color: .black.opacity(0.35), radius: 6, y: 2))
            .fixedSize()
    }
}

private struct BubbleShape: Shape {
    let arrow: BubbleArrow
    func path(in r: CGRect) -> Path {
        var p = Path()
        switch arrow {
        case .top:
            p.addRoundedRect(in: CGRect(x: 0, y: 7, width: r.width, height: r.height - 7), cornerSize: CGSize(width: 8, height: 8))
            let x = r.width - 15   // under the ⋯'s middle
            p.move(to: CGPoint(x: x - 7, y: 7.5)); p.addLine(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x + 7, y: 7.5))
        case .trailing:
            p.addRoundedRect(in: CGRect(x: 0, y: 0, width: r.width - 7, height: r.height), cornerSize: CGSize(width: 8, height: 8))
            let y = r.midY
            p.move(to: CGPoint(x: r.width - 7.5, y: y - 7)); p.addLine(to: CGPoint(x: r.width, y: y)); p.addLine(to: CGPoint(x: r.width - 7.5, y: y + 7))
        }
        p.closeSubpath()
        return p
    }
}


/// Where each ⋯ button is, so its bubble is drawn over everything at its place.
struct MenuAnchorKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}


/// The follow label on someone's page (S2): the same paper label as the viewer's.
struct AuthorFollowLabel: View {
    @ObservedObject private var club = ClubModel.shared
    let author: Community.Author
    let s: CGFloat
    var body: some View {
        let on = club.followingIDs.contains(author.id)
        Button {
            Haptic.click()
            Task { await club.toggleFollow(author) }
        } label: {
            ZStack {
                Image(uiImage: ClubThemePage.follow).resizable().opacity(on ? 0.75 : 1)
                (on ? Text("Followed") : Text("Follow"))
                    .font(.custom("American Typewriter", size: 15 * s * 1.6, relativeTo: .body).weight(.semibold))
                    .foregroundStyle(on ? KitArt.ink.opacity(0.7) : Color(red: 0.72, green: 0.16, blue: 0.1))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.horizontal, 8)
            }
            .frame(width: 140 * s, height: 44 * s)
            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(club.followBusy.contains(author.id))
        .accessibilityLabel(on ? Text("Following \(author.name)") : Text("Follow \(author.name)"))
    }
}
