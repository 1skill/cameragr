import AuthenticationServices
import CryptoKit
import Photos
import SwiftUI
import UIKit

/// The community's pair of pages in the bag (user 11/24: the community is in
/// v1, in place of the Book). Right: a long clear three-pocket sleeve threaded
/// on brass rings, one picture per pocket with a kraft slip under it (author ·
/// film · hearts); it slides and rests on whole rows. Left: the theme.
/// Art is GPT's (design/community/parts): the spread with its rail and rings,
/// one tileable sleeve row, the rings as their own layer.
enum ClubArt {
    /// The 3-day keepsake badge (GPT, cut out of its white ground).
    static let badge = UIImage(named: "badge_3day") ?? UIImage()
    static let spread = UIImage(named: "club_spread.jpg") ?? UIImage()
    static let row = UIImage(named: "sleeve_row.jpg") ?? UIImage()
    static let rings = UIImage(named: "club_rings") ?? UIImage()
    static let slip = UIImage(named: "kraft_slip") ?? UIImage()

    /// Bag pixels (community_v4, as agreed): the rail and rings on the left
    /// page near the spine; the sleeve threaded on them runs across the spine
    /// to the right page's edge, most of the bag (user 11/24).
    static let sleeveX: CGFloat = 470
    static let sleeveRight: CGFloat = 1430
    static var sleeveWidth: CGFloat { sleeveRight - sleeveX }
    static var rowHeight: CGFloat { sleeveWidth * row.size.height / max(row.size.width, 1) }
    static let ringsRect = CGRect(x: 380, y: 30, width: 190, height: 970)
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
        if let client { self.client = client } else if let base = CommunityConfig.apiBase {
            self.client = RemoteCommunityClient(base: base)
        } else {
            #if DEBUG
            // Until the Worker is deployed (CommunityConfig.apiBase): the
            // in-memory community, with the app's sample pictures as others' posts.
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
        // The in-memory community (no server set) signs in by itself.
        if let mock = client as? MockCommunityClient, !UserDefaults.standard.bool(forKey: "clubSignedOut") {   // `-clubSignedOut 1`, for checks
            _ = try? await mock.signIn(appleIdentityToken: "mock", name: nil)
        }
        signedIn = await client.isSignedIn
        if signedIn { me = try? await client.me(); keepRewards(); await refreshNews() }
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
        guard let r = try? await client.setLike(!post.likedByMe, post: post.id) else { return }
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
            await choose(theme)
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
        let gen = generation
        if let fresh = try? await client.news(), gen == generation { news = fresh }
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
            if case Community.Failure.words = error { note = Text("That name can’t be used. Try another one.") }
            else { note = Text("That didn't go through. Try again.") }
            return false
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
        mineList = .none
        queue = []; reported = []; alerts = []; hiddenPosts = []; modComments = []
        failedMail = []; adminStatus = nil
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
    func openMine() async {
        mineOpen = true
        let gen = generation
        let fresh = try? await client.me()
        guard gen == generation else { return }
        me = fresh
        keepRewards()
        await refreshNews()
        if let list = try? await client.mine(), gen == generation { mineList = list }
        newsShown = news
        if news.count > 0, (try? await client.markNewsSeen()) != nil { news = .none }
        if me?.isAdmin == true { await refreshModeration() }
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
            guard gen == generation else { return }
            (queue, reported, alerts, hiddenPosts) = lists
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
            await choose(theme)
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
            await choose(theme)
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
            // Cleared only if it is still what was sent.
            if draftAsset == shot.asset, draftCaption == caption { draftAsset = nil; draftCaption = "" }
            posts.removeAll { $0.id == p.id }
            posts.insert(p, at: 0)
            note = Text("Posted — it’s in the sleeve.")   // review is never felt (user 11/24)
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
    }

    /// Shows a theme's posts; never another theme's (cleared first, and on failure).
    func choose(_ new: Community.Theme?) async {
        theme = new
        posts = []
        nextPage = nil
        guard let new, signedIn else { return }
        failed = false
        let gen = generation
        do {
            let page = try await client.posts(theme: new.id, cursor: nil)
            if gen == generation, theme?.id == new.id { posts = page.posts; nextPage = page.next }   // still the one chosen
        } catch Community.Failure.signedOut {
            signedIn = false
        } catch {
            Diag.note("club posts failed: \(error)")
            if theme?.id == new.id { failed = true }
        }
    }

    /// The next page, when the sleeve nears its last filled row.
    func loadMore() async {
        guard let theme, let cursor = nextPage, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        let gen = generation
        do {
            let page = try await client.posts(theme: theme.id, cursor: cursor)
            guard gen == generation, self.theme?.id == theme.id, nextPage == cursor else { return }
            let seen = Set(posts.map(\.id))
            posts += page.posts.filter { !seen.contains($0.id) }
            nextPage = page.next
        } catch {
            Diag.note("club more failed: \(error)")
            note = Text("Couldn’t load more. Scroll again to try.")
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
        let rows = max(Int((CGFloat(club.posts.count) / 3).rounded(.up)), Int(page.height / ClubArt.rowHeight) + 1)
        ZStack(alignment: .topLeading) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { r in
                        row(r, width: w, height: rowH)
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
            .frame(width: w, height: page.height * s, alignment: .leading)
            .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: RollLibrary.boardRadius * s,
                                              topTrailingRadius: RollLibrary.boardRadius * s))
            .offset(x: ClubArt.sleeveX * s, y: page.minY * s)
            // The rings over the sleeve.
            Image(uiImage: ClubArt.rings).resizable()
                .frame(width: ClubArt.ringsRect.width * s, height: ClubArt.ringsRect.height * s)
                .offset(x: ClubArt.ringsRect.minX * s, y: ClubArt.ringsRect.minY * s)
                .allowsHitTesting(false)
        }
        .task { await club.load() }
    }

    private func row(_ r: Int, width w: CGFloat, height h: CGFloat) -> some View {
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
    @ObservedObject private var language = AppLanguage.shared
    let s: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 18 * s) {
            if let theme = club.theme {
                VStack(alignment: .leading, spacing: 8 * s) {
                    kindName(theme.kind).font(.custom("American Typewriter", size: 20 * s)).opacity(0.7)
                    Text(verbatim: Community.Theme.text(theme.title, language: language.code))
                        .font(.custom("American Typewriter", size: 32 * s).weight(.semibold))
                    Text(verbatim: Community.Theme.text(theme.prompt, language: language.code))
                        .font(.custom("American Typewriter", size: 19 * s))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(KitArt.ink)
                .padding(20 * s)
                .frame(width: ClubArt.navWidth * s, alignment: .leading)
                .background(Image(uiImage: ClubArt.slip).resizable())
                .accessibilityElement(children: .combine)
            }
            if !club.isOpen {
                Text("The community opens soon.")
                    .font(.custom("American Typewriter", size: 20 * s))
                    .foregroundStyle(KitArt.ink)
                    .padding(18 * s)
                    .frame(width: ClubArt.navWidth * s, alignment: .leading)
                    .background(Image(uiImage: ClubArt.slip).resizable())
            } else if club.failed {
                Button {
                    Haptic.click()
                    Task { await club.load() }
                } label: {
                    Label("Couldn’t load. Tap to try again.", systemImage: "arrow.clockwise")
                        .font(.custom("American Typewriter", size: 18 * s))
                        .foregroundStyle(KitArt.ink)
                        .padding(16 * s)
                        .frame(width: ClubArt.navWidth * s, alignment: .leading)
                        .background(Image(uiImage: ClubArt.slip).resizable())
                }
                .buttonStyle(.plain)
            }
            if !club.isOpen {
                EmptyView()
            } else if !club.signedIn {
                ClubSignIn(width: ClubArt.navWidth * s, s: s)
            } else if let theme = club.theme, theme.isOpen(at: Date()) {
                Button {
                    Haptic.click()
                    withAnimation(.easeOut(duration: 0.25)) { club.posting = true }
                } label: {
                    Label("Post one", systemImage: "plus")
                        .font(.custom("American Typewriter", size: 24 * s).weight(.semibold))
                        .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
                        .padding(.horizontal, 26 * s).padding(.vertical, 12 * s)
                        .background(Image(uiImage: ClubArt.slip).resizable())
                }
                .buttonStyle(.plain)
            }
            ForEach(club.themes.filter { $0.id != club.theme?.id }) { other in
                Button {
                    Haptic.click()
                    Task { await club.choose(other) }
                } label: {
                    HStack(spacing: 10 * s) {
                        kindName(other.kind).font(.custom("American Typewriter", size: 17 * s)).opacity(0.7)
                        Text(verbatim: Community.Theme.text(other.title, language: language.code))
                            .font(.custom("American Typewriter", size: 24 * s).weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 16 * s, weight: .semibold)).opacity(0.6)
                    }
                    .foregroundStyle(KitArt.ink)
                    .padding(.horizontal, 18 * s).padding(.vertical, 12 * s)
                    .frame(width: ClubArt.navWidth * s, alignment: .leading)
                    .background(Image(uiImage: ClubArt.slip).resizable())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .offset(x: ClubArt.navX * s, y: 80 * s)
        // "Mine", at the foot of the column (C2c: admins moderate from here).
        .overlay(alignment: .topLeading) {
            if club.signedIn {
                Button {
                    Haptic.click()
                    Task { await club.openMine() }
                } label: {
                    HStack(spacing: 10 * s) {
                        Image(systemName: "person.crop.circle").font(.system(size: 20 * s))
                        Text("Mine").font(.custom("American Typewriter", size: 24 * s).weight(.semibold))
                        Spacer(minLength: 0)
                        let waiting = club.news.count + (club.me?.isAdmin == true ? club.queue.count + club.reported.count + club.modComments.count : 0)
                        if waiting > 0 {
                            Text(verbatim: "\(waiting)")
                                .font(.system(size: 15 * s, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 8 * s).padding(.vertical, 2 * s)
                                .background(Capsule().fill(Color(red: 0.72, green: 0.16, blue: 0.1)))
                        }
                    }
                    .foregroundStyle(KitArt.ink)
                    .padding(.horizontal, 18 * s).padding(.vertical, 12 * s)
                    .frame(width: ClubArt.navWidth * s, alignment: .leading)
                    .background(Image(uiImage: ClubArt.slip).resizable())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: ClubArt.navX * s, y: 790 * s)
            }
        }
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
                    .onTapGesture { if menu != nil { closeMenu() } else if !fullScreen { close() } }
                if fullScreen {
                    ZoomablePicture(onDoubleTap: { likeByTap() }, onTap: {
                        if menu != nil { closeMenu(); return }
                        withAnimation(.easeInOut(duration: 0.2)) { wordsShown.toggle() }
                    }, onSwipe: { step($0) }) { PostPicture(url: post.photoURL, fill: true) }
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
                    let picture = ZoomablePicture(onDoubleTap: { goFull(true) }, onSwipe: { step($0) }) {
                        PostPicture(url: post.photoURL, fill: false) { size in
                            if size.height > 0 { aspect = size.width / size.height }
                        }
                    }
                    .frame(width: pic.width, height: pic.height)
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
            back()
        }
        .modifier(ScrollWhenLarge(on: typeSize.isAccessibilitySize))
    }

    private var card: some View {
        let theme = club.themes.first { $0.id == post.themeId }
        let shown = club.viewing ?? post
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 0) {
                Text(verbatim: post.author.name).font(.custom("American Typewriter", size: 17, relativeTo: .body).weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.7)
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
                    moreButton(open: menu?.hasPrefix("post") == true, size: 14) { toggleMenu("post") }
                        .overlay(alignment: .topTrailing) {
                            if menu == "post" || menu == "post:report" {
                                MenuBubble(arrow: .top) { postMenu }
                                    .offset(y: 34)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
                            }
                        }
                }
            }
            // Film, theme and day on one quiet line under the name.
            HStack(spacing: 0) {
                Text(verbatim: FilmNames.short(post.filmId))
                if let theme { Text(verbatim: " · " + Community.Theme.text(theme.title, language: language.code)) }
                Text(verbatim: " · ")
                Text(post.createdAt, format: .dateTime.month().day())
            }
            .lineLimit(1).minimumScaleFactor(0.8)
            .font(.custom("American Typewriter", size: 12, relativeTo: .body))
            .opacity(0.75)
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
                    moreButton(open: menu?.hasPrefix("c:" + c.id) == true, size: 12) { toggleMenu("c:" + c.id) }
                        .overlay(alignment: .trailing) {
                            if menu?.hasPrefix("c:" + c.id) == true {
                                MenuBubble(arrow: .trailing) { commentMenu(c, mayDelete: mayDelete) }
                                    .offset(x: -30)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
                            }
                        }
                }
            }
        }
        .zIndex(menu?.hasPrefix("c:" + c.id) == true ? 1 : 0)
    }

    private func moreButton(open: Bool, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button { Haptic.click(); action() } label: {
            Image(systemName: "ellipsis").font(.system(size: size, weight: .semibold))
                .opacity(open ? 0.8 : 0.4)
                .frame(minWidth: 30, minHeight: 36).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("More"))
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
        HStack(spacing: 12) {
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
                .lineLimit(1).fixedSize()
                .frame(minHeight: 30, alignment: .leading).contentShape(Rectangle())
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

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.9, 760), h = geo.size.height * 0.86
            // Every Koco picture, any day (lazily drawn as the folder scrolls).
            let shots = log.shots.sorted { $0.date > $1.date }
            let chosen = shots.first { $0.asset == club.draftAsset }
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .onTapGesture { close() }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Post one").font(.custom("American Typewriter", size: 26, relativeTo: .body).weight(.semibold))
                        Spacer()
                        Button("Cancel") { close() }.font(.custom("American Typewriter", size: 18, relativeTo: .body))
                            .disabled(club.sending)   // once sending, it goes in; no false cancel
                    }
                    Text("Only pictures taken with Koco").font(.custom("American Typewriter", size: 15, relativeTo: .body)).opacity(0.7)
                    if shots.isEmpty {
                        Text("No pictures taken with Koco yet. Take one first.")
                            .font(.custom("American Typewriter", size: 19, relativeTo: .body))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                                ForEach(shots, id: \.asset) { shot in
                                    AssetThumbnail(id: shot.asset, side: 300)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                        .overlay(RoundedRectangle(cornerRadius: 3)
                                            .strokeBorder(Color(red: 0.72, green: 0.16, blue: 0.1), lineWidth: chosen == shot ? 4 : 0))
                                        .contentShape(Rectangle())
                                        .onTapGesture { guard !club.sending else { return }; Haptic.click(); club.draftAsset = shot.asset }
                                        .accessibilityAddTraits(chosen == shot ? [.isButton, .isSelected] : .isButton)
                                }
                            }
                        }
                    }
                    if !club.signedIn {
                        // Signed out (or the sign-in ran out): sign in here, the draft stays.
                        ClubSignIn(width: w - 44, s: 1)
                    }
                    HStack(spacing: 10) {
                        TextField("", text: $club.draftCaption, prompt: Text("Say something (optional)").foregroundStyle(KitArt.ink.opacity(0.55)))
                            .font(.custom("American Typewriter", size: 18, relativeTo: .body))
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.55)))
                            .disabled(club.sending)   // what is being sent stays as it is
                            .onChange(of: club.draftCaption) { _, new in
                                if new.count > Community.captionLimit { club.draftCaption = String(new.prefix(Community.captionLimit)) }
                            }
                        Button {
                            guard let shot = chosen else { return }
                            Haptic.click()
                            Task { if await club.post(shot, caption: club.draftCaption) { close() } }
                        } label: {
                            Text(club.sending ? "Sending…" : "Put it in")
                                .font(.custom("American Typewriter", size: 20, relativeTo: .body).weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18).padding(.vertical, 10)
                                .background(Capsule().fill(Color(red: 0.72, green: 0.16, blue: 0.1).opacity(chosen == nil ? 0.4 : 1)))
                        }
                        .buttonStyle(.plain)
                        .disabled(chosen == nil || club.sending || !club.signedIn)
                    }
                    if club.postFailed {
                        Text("It didn't go. Your picture and words are kept: tap Put it in to try again.")
                            .font(.custom("American Typewriter", size: 14, relativeTo: .body)).foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.1))
                    }
                }
                .foregroundStyle(KitArt.ink)
                .padding(22)
                .frame(width: w, height: h)
                .background(Image(uiImage: ClubArt.slip).resizable())
            }
        }
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
                        Text(verbatim: club.me?.profile.name ?? "").font(.custom("American Typewriter", size: 26, relativeTo: .body).weight(.semibold))
                        Text("\(club.me?.streak ?? 0) days in a row").font(.custom("American Typewriter", size: 17, relativeTo: .body)).opacity(0.7)
                        Spacer()
                        Button("Close") { close() }.font(.custom("American Typewriter", size: 18, relativeTo: .body))
                    }
                    rewards
                    if let days = choosingFor { voucherPicker(days) }
                    if !club.mineList.posts.isEmpty { mineRow }
                    if !club.newsShown.comments.isEmpty { newsList }
                    if club.me?.isAdmin == true {
                        ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) {
                            tabButton(0, Text("Waiting \(club.queue.count)"))
                            tabButton(1, Text("Reports \(club.reported.count)"))
                            tabButton(4, Text("Comments \(club.modComments.count)"))
                            tabButton(2, Text("Hidden \(club.hiddenPosts.count)"))
                            tabButton(3, Text("Alerts"))
                        } }
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                switch tab {
                                case 0: queueList
                                case 1: reportList
                                case 2: hiddenList
                                case 4: commentModList
                                default: alertList
                                }
                            }
                        }
                        .refreshable { await club.refreshModeration() }
                    } else {
                        Text("A picture approved in a theme counts its day. Three days in a row give Porto 400; seven and fourteen give limited rolls that are never sold. Once reached, a roll stays yours to claim.")
                            .font(.custom("American Typewriter", size: 16, relativeTo: .body)).opacity(0.75)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    account
                }
                .modifier(ScrollWhenLarge(on: typeSize.isAccessibilitySize))
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

    @State private var renaming: String?
    @State private var confirmingDelete = false

    /// One's name, the rules, signing out, deleting the account (C4a).
    @ViewBuilder private var account: some View {
        Divider().overlay(KitArt.ink.opacity(0.2))
        if let draft = renaming {
            HStack(spacing: 8) {
                TextField("", text: Binding(get: { draft }, set: { renaming = String($0.prefix(30)) }))
                    .font(.custom("American Typewriter", size: 16, relativeTo: .body))
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.5)))
                action(Text("Save"), strong: true) { Task { if await club.rename(draft) { renaming = nil } } }
                action(Text("Cancel")) { renaming = nil }
            }
        } else if confirmingDelete {
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
                action(Text("Change name")) { renaming = club.me?.profile.name ?? "" }
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
