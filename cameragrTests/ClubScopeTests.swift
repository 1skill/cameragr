import Foundation
import Testing
@testable import cameragr

/// The community's album: three entries, a film filter on them, and the
/// way back from a person's page (v7).
@MainActor
@Suite("Community album scope", .serialized)
struct ClubScopeTests {
    func model() async -> ClubModel {
        let now = Date()
        let t = Community.Theme(id: "t", kind: .daily, startsAt: now.addingTimeInterval(-3_600), endsAt: now.addingTimeInterval(3_600),
                                title: ["en": "T"], prompt: ["en": "P"])
        let mock = MockCommunityClient(themes: [t])
        let url = URL(string: "file:///x.jpg")!
        await mock.seed((0..<12).map { i in
            Community.Post(id: "p\(i)", author: .init(id: "u\(i % 3)", name: "N\(i % 3)"), themeId: i < 8 ? "t" : "other",
                           photoURL: url, thumbURL: url, filmId: i.isMultiple(of: 2) ? "a" : "b", caption: nil, takenAt: nil,
                           createdAt: now.addingTimeInterval(-Double(i)), likeCount: 0, likedByMe: false)
        })
        let club = ClubModel(client: mock)
        await club.load()
        return club
    }

    @Test("three entries; a film narrows each, and survives switching")
    func entriesAndFilm() async {
        let club = await model()
        #expect(club.scope == .theme)
        #expect(club.posts.count == 8)
        await club.chooseFilm("a")
        #expect(club.posts.count == 4 && club.posts.allSatisfy { $0.filmId == "a" })
        await club.chooseScope(.everyone)
        #expect(club.film == "a" && club.posts.count == 6 && club.posts.allSatisfy { $0.filmId == "a" })
        await club.chooseFilm(nil)
        #expect(club.posts.count == 12)
        await club.chooseScope(.following)
        #expect(club.posts.isEmpty && !club.loading && !club.failed)   // empty, not loading, not failed
    }

    @Test("a person's page returns to the entry, the film and the pictures")
    func returning() async {
        let club = await model()
        await club.chooseScope(.everyone)
        await club.chooseFilm("b")
        let before = club.posts.map(\.id)
        await club.openAuthor(club.posts[0].author)
        #expect(club.scope.isPerson)
        #expect(club.film == "b")          // kept, not applied
        await club.leaveAuthor()
        #expect(club.scope == .everyone && club.film == "b" && club.posts.map(\.id) == before)
        #expect(club.authorCard == nil)
    }

    @Test("the picks are read with the page; a blocked person leaves them at once")
    func picksAndBlocking() async {
        let club = await model()
        #expect(club.picks == [])   // none picked: an honest empty note, not a failure
        #expect(!club.picksFailed)
        if let mock = club.client as? MockCommunityClient { await mock.seedPicks() }
        await club.refreshPicks()
        let first = club.picks?.first?.author
        #expect(club.picks?.count == 3)
        if let first { await club.block(first) }
        #expect(club.picks?.contains { $0.author.id == first?.id } == false)
    }

    @Test("framework E: picks open as a row; the album holds the picked pictures only, never filtered by film")
    func picksAsARow() async {
        let club = await model()
        await club.chooseScope(.picks)
        #expect(club.posts.isEmpty && !club.failed)   // nothing picked: empty, honestly
        if let mock = club.client as? MockCommunityClient { await mock.seedPicks() }
        await club.chooseScope(.theme)
        await club.chooseScope(.picks)
        #expect(club.posts.map(\.id) == club.picks?.map(\.post))
        #expect(!club.filmApplies)
        await club.choose(club.theme)
        #expect(club.scope == .theme && club.posts.count == 8)
    }

    @Test("framework E: the names under the theme are its real posters; a word shows only when someone wrote one")
    func namesAndWords() async {
        let club = await model()
        #expect(club.themeNames == ["N0", "N1", "N2"])
        #expect(club.firstWords.isEmpty)
        if let mock = club.client as? MockCommunityClient { await mock.seedComment(post: "p1", by: "Momo", text: "Lovely") }
        await club.chooseScope(.everyone)
        await club.chooseScope(.theme)
        #expect(club.firstWords["p1"]?.text == "Lovely")
        #expect(club.firstWords["p0"] == nil)
    }
}
