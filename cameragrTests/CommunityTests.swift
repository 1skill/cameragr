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
            _ = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "porto400", caption: nil, takenAt: nil)
        }
        _ = try await c.signIn(appleIdentityToken: "x", name: "A")
        let p = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "porto400", caption: "hi", takenAt: nil)
        #expect(try await c.posts(theme: "t", cursor: nil).posts.map(\.id) == [p.id])

        let closed = client(open: false)
        _ = try await closed.signIn(appleIdentityToken: "x", name: nil)
        await #expect(throws: Community.Failure.themeClosed) {
            _ = try await closed.post(theme: "t", photo: Data(), thumb: Data(), film: "porto400", caption: nil, takenAt: nil)
        }
    }

    @Test func captionsAreFilteredAndShort() async throws {
        let c = client()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        await #expect(throws: Community.Failure.words) {
            _ = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "porto400", caption: "PORN here", takenAt: nil)
        }
        await #expect(throws: Community.Failure.words) {
            _ = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "porto400",
                                 caption: String(repeating: "a", count: Community.captionLimit + 1), takenAt: nil)
        }
    }

    @Test func threeReportsHideAPost() async throws {
        let c = client()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        let p = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "porto400", caption: nil, takenAt: nil)
        try await c.report(post: p.id, reason: .spam, note: nil)
        await c.report(post: p.id, by: "b")
        #expect(try await c.posts(theme: "t", cursor: nil).posts.count == 1)
        await c.report(post: p.id, by: "c")
        #expect(try await c.posts(theme: "t", cursor: nil).posts.isEmpty)
    }

    @Test func blockedPeoplesPostsAreNotShown() async throws {
        let c = client()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        _ = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "porto400", caption: nil, takenAt: nil)
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
        _ = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "porto400", caption: nil, takenAt: nil)
        let me = try await c.me()
        #expect(me.streak == 3)
        #expect(me.claimable == 3)
        #expect(try await c.claimReward(milestone: 3) == "porto400")
        #expect(try await c.claimReward(milestone: 3) == "porto400")   // again: the same roll, once
        await #expect(throws: Community.Failure.notYet) { _ = try await c.claimReward(milestone: 7) }
        #expect(try await c.me().claimable == nil)
    }

    @Test func signingInAgainKeepsRewardsAndBlocks() async throws {
        let c = client()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        await c.backdatePost(daysAgo: 1); await c.backdatePost(daysAgo: 2)
        _ = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "porto400", caption: nil, takenAt: nil)
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
        let p = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "porto400", caption: nil, takenAt: nil)
        try await c.delete(post: p.id)
        #expect(try await c.me().streak == 1)
    }

    @Test func leavingRemovesEverything() async throws {
        let c = client()
        _ = try await c.signIn(appleIdentityToken: "x", name: nil)
        _ = try await c.post(theme: "t", photo: Data(), thumb: Data(), film: "porto400", caption: nil, takenAt: nil)
        try await c.deleteAccount()
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
