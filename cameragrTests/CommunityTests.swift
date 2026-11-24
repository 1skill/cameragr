import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import cameragr

@Suite("Community (mock server rules)")
struct CommunityTests {
    let now = Date(timeIntervalSince1970: 1_795_500_000)

    func client(open: Bool = true) -> MockCommunityClient {
        let t = Community.Theme(id: "t", kind: .daily,
                                startsAt: now.addingTimeInterval(open ? -3_600 : -7_200),
                                endsAt: now.addingTimeInterval(open ? 3_600 : -3_600),
                                title: ["en": "T"], prompt: ["en": "P"])
        let fixed = now
        return MockCommunityClient(themes: [t], timeZone: TimeZone(identifier: "Asia/Tokyo")!, now: { fixed })
    }

    @Test func postingNeedsSignInAndAnOpenTheme() async throws {
        let c = client()
        await #expect(throws: Community.Failure.signedOut) {
            _ = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "portra400", caption: nil, takenAt: nil)
        }
        _ = try await c.signIn(appleIdentityToken: "x", name: "A")
        let p = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "portra400", caption: "hi", takenAt: nil)
        #expect(try await c.posts(theme: "t", cursor: nil).posts.map(\.id) == [p.id])

        let closed = client(open: false)
        _ = try await closed.signIn(appleIdentityToken: "x", name: nil)
        await #expect(throws: Community.Failure.themeClosed) {
            _ = try await closed.post(theme: "t", photo: Data(), thumb: Data(), film: "portra400", caption: nil, takenAt: nil)
        }
    }

    @Test func captionsAreFilteredAndShort() async throws {
        let c = client()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        await #expect(throws: Community.Failure.words) {
            _ = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "portra400", caption: "PORN here", takenAt: nil)
        }
        await #expect(throws: Community.Failure.words) {
            _ = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "portra400",
                                 caption: String(repeating: "a", count: Community.captionLimit + 1), takenAt: nil)
        }
    }

    @Test func threeReportsHideAPost() async throws {
        let c = client()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        let p = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "portra400", caption: nil, takenAt: nil)
        try await c.report(post: p.id, reason: .spam, note: nil)
        await c.report(post: p.id, by: "b")
        #expect(try await c.posts(theme: "t", cursor: nil).posts.count == 1)
        await c.report(post: p.id, by: "c")
        #expect(try await c.posts(theme: "t", cursor: nil).posts.isEmpty)
    }

    @Test func blockedPeoplesPostsAreNotShown() async throws {
        let c = client()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        _ = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "portra400", caption: nil, takenAt: nil)
        try await c.setBlocked(true, user: "me")
        #expect(try await c.posts(theme: "t", cursor: nil).posts.isEmpty)
        try await c.setBlocked(false, user: "me")
        #expect(try await c.posts(theme: "t", cursor: nil).posts.count == 1)
    }

    @Test func streaksEarnEachRollOnce() async throws {
        let c = client()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        await #expect(throws: Community.Failure.notYet) { _ = try await c.claimReward(milestone: 3) }
        await c.backdatePost(daysAgo: 1)
        await c.backdatePost(daysAgo: 2)
        #expect(await c.streak() == 2)   // yesterday and the day before: still running
        _ = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "portra400", caption: nil, takenAt: nil)
        let me = try await c.me()
        #expect(me.streak == 3)
        #expect(me.claimable == 3)
        #expect(try await c.claimReward(milestone: 3) == "portra400")
        #expect(try await c.claimReward(milestone: 3) == "portra400")   // again: the same roll, once
        await #expect(throws: Community.Failure.notYet) { _ = try await c.claimReward(milestone: 7) }
        #expect(try await c.me().claimable == nil)
    }

    @Test func signingInAgainKeepsRewardsAndBlocks() async throws {
        let c = client()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        await c.backdatePost(daysAgo: 1); await c.backdatePost(daysAgo: 2)
        _ = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "portra400", caption: nil, takenAt: nil)
        _ = try await c.claimReward(milestone: 3)
        try await c.setBlocked(true, user: "someone")
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        let me = try await c.me()
        #expect(me.rewards.map(\.milestone) == [3])
        #expect(me.blocked == ["someone"])
        #expect(me.claimable == nil)
    }

    @Test func deletingAPostKeepsItsCheckIn() async throws {
        let c = client()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        let p = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "portra400", caption: nil, takenAt: nil)
        try await c.delete(post: p.id)
        #expect(try await c.me().streak == 1)
    }

    @Test func leavingRemovesEverything() async throws {
        let c = client()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        _ = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "portra400", caption: nil, takenAt: nil)
        _ = try await c.deleteAccount()
        #expect(try await c.posts(theme: "t", cursor: nil).posts.isEmpty)
        let fresh = try await c.signIn(appleIdentityToken: "x", name: nil)
        #expect(fresh.streak == 0 && fresh.rewards.isEmpty)
    }

    @Test func aGapBreaksTheStreak() async throws {
        let c = client()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        await c.backdatePost(daysAgo: 2)
        await c.backdatePost(daysAgo: 3)
        #expect(await c.streak() == 0)   // nothing yesterday or today
    }

    @Test func photosAreShrunkAndCarryNoGPS() throws {
        // A 3000×2000 JPEG with a GPS position in it.
        let w = 3000, h = 2000
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)!
        let gps: [CFString: Any] = [kCGImagePropertyGPSLatitude: 35.68, kCGImagePropertyGPSLatitudeRef: "N",
                                    kCGImagePropertyGPSLongitude: 139.76, kCGImagePropertyGPSLongitudeRef: "E"]
        CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImagePropertyGPSDictionary: gps] as CFDictionary)
        #expect(CGImageDestinationFinalize(dest))

        let prepared = try #require(CommunityPhoto.prepare(out as Data))
        for (data, long) in [(prepared.photo, 1600), (prepared.thumb, 400)] {
            let src = try #require(CGImageSourceCreateWithData(data as CFData, nil))
            let props = try #require(CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any])
            #expect(max(props[kCGImagePropertyPixelWidth] as? Int ?? 0, props[kCGImagePropertyPixelHeight] as? Int ?? 0) == long)
            #expect(props[kCGImagePropertyGPSDictionary] == nil)
        }
    }
}

@Suite("Community (network client)")
struct RemoteCommunityTests {
    @Test("A retry with the same client id makes no second post")
    func retryPostsOnce() async throws {
        let t = Community.Theme(id: "t", kind: .daily, startsAt: .distantPast, endsAt: .distantFuture,
                                title: ["en": "T"], prompt: ["en": "P"])
        let c = MockCommunityClient(themes: [t])
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        let a = try await c.post(theme: "t", photo: Data([1]), thumb: Data([2]), film: "portra400", caption: nil, takenAt: nil, clientID: "same-id-1")
        let b = try await c.post(theme: "t", photo: Data([1]), thumb: Data([2]), film: "portra400", caption: nil, takenAt: nil, clientID: "same-id-1")
        #expect(a.id == b.id)
        #expect(try await c.posts(theme: "t", cursor: nil).posts.count == 1)
    }

    @Test("The server's post reads as the app's: dates, a waiting state, no caption")
    func decodesServerPost() throws {
        let json = """
        {"id":"p1","author":{"id":"u1","name":"Momo"},"themeId":"t",
         "photoURL":"https://x.example/v1/photos/p1/full?exp=1&sig=a","thumbURL":"https://x.example/v1/photos/p1/thumb?exp=1&sig=b",
         "filmId":"portra400","createdAt":"2026-11-24T13:20:01.123Z","takenAt":"2026-11-24T10:00:00Z",
         "likeCount":0,"likedByMe":false,"state":"pending"}
        """
        let p = try RemoteCommunityClient.decoder.decode(Community.Post.self, from: Data(json.utf8))
        #expect(p.isWaiting)
        #expect(p.caption == nil)
        #expect(p.createdAt.timeIntervalSince1970 > 1_790_000_000)
        #expect(p.takenAt != nil)
    }
}

@Suite("Community (moderation)")
struct ModerationTests {
    let t = Community.Theme(id: "t", kind: .daily, startsAt: .distantPast, endsAt: .distantFuture,
                            title: ["en": "T"], prompt: ["en": "P"])

    @Test("Approved before public: waits, others don't see it, the day counts on approval")
    func approveFirst() async throws {
        let c = MockCommunityClient(themes: [t], approveFirst: true)
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        let p = try await c.post(theme: "t", photo: Data([1]), thumb: Data([2]), film: "portra400", caption: nil, takenAt: nil)
        #expect(p.isWaiting)
        #expect(try await c.me().streak == 0)
        #expect(try await c.adminQueue().map(\.id) == [p.id])
        try await c.moderate(post: p.id, .approve, reason: nil)
        #expect(try await c.adminQueue().isEmpty)
        #expect(try await c.me().streak == 1)
    }

    @Test("Reports reach the admin; hiding takes a post out; non-admins can't moderate")
    func reports() async throws {
        let c = MockCommunityClient(themes: [t], approveFirst: true)
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        await c.seed(MockCommunityClient.samplePosts(theme: "t"))
        let target = try #require(try await c.posts(theme: "t", cursor: nil).posts.first)
        try await c.report(post: target.id, reason: .spam, note: nil)
        let open = try await c.adminReports()
        #expect(open.map(\.post.id) == [target.id])
        #expect(try await !c.adminAlerts().isEmpty)
        try await c.moderate(post: target.id, .hide, reason: nil)
        try await c.markHandled(report: open[0].report.id)
        #expect(try await c.adminReports().isEmpty)
        #expect(try await !c.posts(theme: "t", cursor: nil).posts.contains { $0.id == target.id })

        let plain = MockCommunityClient(themes: [t])
        _ = try await plain.signIn(appleIdentityToken: "x", name: nil)
        await #expect(throws: Community.Failure.self) { _ = try await plain.adminQueue() }
    }
}

@Suite("Community (rewards)")
struct RewardTests {
    @Test("A milestone reached stays claimable after the run breaks; claimed once")
    func eligibleForGood() {
        var me = Community.Me(profile: .init(id: "u", name: "A", tz: "UTC"), streak: 0, rewards: [], blocked: [], isAdmin: false, eligible: [3])
        #expect(me.reached(3))
        #expect(!me.reached(7))
        #expect(me.claimable == 3)
        me.rewards.append(.init(milestone: 3, filmId: "portra400", claimedAt: Date()))
        #expect(me.claimable == nil)
    }
}

@Suite("Community (comments)")
struct CommentTests {
    let t = Community.Theme(id: "t", kind: .daily, startsAt: .distantPast, endsAt: .distantFuture,
                            title: ["en": "T"], prompt: ["en": "P"])

    @Test("A comment waits, sends once, stays within 120 characters, and goes out once approved")
    func commentRound() async throws {
        let c = MockCommunityClient(themes: [t], approveFirst: true)
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        await c.seed(MockCommunityClient.samplePosts(theme: "t"))
        let post = try #require(try await c.posts(theme: "t", cursor: nil).posts.first)
        let a = try await c.comment(post: post.id, text: "Lovely", clientID: "one-id-1")
        let b = try await c.comment(post: post.id, text: "Lovely", clientID: "one-id-1")
        #expect(a.id == b.id && a.isWaiting)
        await #expect(throws: Community.Failure.words) {
            _ = try await c.comment(post: post.id, text: String(repeating: "a", count: 121), clientID: "two-id-2")
        }
        #expect(try await c.adminComments("pending").map(\.id) == [a.id])
        try await c.moderate(comment: a.id, .approve)
        #expect(try await c.comments(post: post.id).first?.state == .public)
        #expect(try await c.me().streak == 0)   // comments count no day
    }
}

@Suite("Community (vouchers)")
struct VoucherTests {
    @Test("Had the roll already: a voucher, turned into another roll once")
    func voucher() async throws {
        let c = MockCommunityClient()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        await c.backdatePost(daysAgo: 1); await c.backdatePost(daysAgo: 2); await c.backdatePost(daysAgo: 0)
        #expect(try await c.claimReward(milestone: 3, voucher: true) == Community.voucher)
        #expect(try await c.redeem(milestone: 3, film: "cine500t") == "cine500t")
        await #expect(throws: Community.Failure.self) { _ = try await c.redeem(milestone: 3, film: "c200") }
        #expect(try await c.me().rewards.first?.filmId == "cine500t")
    }
}

@Suite("Community (account)")
struct AccountTests {
    let t = Community.Theme(id: "t", kind: .daily, startsAt: .distantPast, endsAt: .distantFuture,
                            title: ["en": "T"], prompt: ["en": "P"])

    @Test("Rules first; a name within 30; deleting takes everything")
    func account() async throws {
        let c = MockCommunityClient(themes: [t])
        await c.setRequiresRules(true)
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        #expect(try await c.me().needsRules)
        await #expect(throws: Community.Failure.rulesNeeded) {
            _ = try await c.post(theme: "t", photo: Data([1]), thumb: Data([2]), film: "portra400", caption: nil, takenAt: nil)
        }
        try await c.agreeToRules(version: MockCommunityClient.rulesVersion)
        #expect(try await !c.me().needsRules)
        _ = try await c.post(theme: "t", photo: Data([1]), thumb: Data([2]), film: "portra400", caption: nil, takenAt: nil)
        #expect(try await c.rename("  Momo  ").profile.name == "Momo")
        await #expect(throws: Community.Failure.words) { _ = try await c.rename(String(repeating: "a", count: 31)) }
        #expect(try await c.deleteAccount() == .none)
        await #expect(throws: Community.Failure.signedOut) { _ = try await c.me() }
    }
}

@Suite("Community (badge)")
struct BadgeTests {
    @Test("Every roll had: the 3-day keepsake badge, and a voucher can become it")
    func badge() async throws {
        let c = MockCommunityClient()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        for d in 0..<3 { await c.backdatePost(daysAgo: d) }
        #expect(try await c.claimReward(milestone: 3, as: .badge) == Community.badge)
        let v = MockCommunityClient()
        _ = try await v.signIn(appleIdentityToken: "x", name: nil)
        for d in 0..<3 { await v.backdatePost(daysAgo: d) }
        _ = try await v.claimReward(milestone: 3, as: .voucher)
        #expect(try await v.redeem(milestone: 3, film: Community.badge) == Community.badge)
    }
}
