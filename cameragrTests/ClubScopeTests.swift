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

    @Test("one's own page holds Mine; someone's page from there returns to it, then home")
    func ownPage() async throws {
        let club = await model()
        let me = try #require(club.me)
        let other = try #require(club.posts.first { $0.author.id != me.profile.id }?.author)
        await club.openMine()
        #expect(club.isOwnPage && club.mineOpen)
        await club.openAuthor(other)
        #expect(club.scope == .author(other.id) && !club.mineOpen)
        await club.leaveAuthor()
        #expect(club.isOwnPage && club.mineOpen)   // back to one's own news
        await club.leaveAuthor()
        #expect(club.scope == .theme && !club.mineOpen && club.authorCard == nil)
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

    @Test("member card: numbers from the community; Mine opened clears the new ones")
    func memberCard() async throws {
        let now = Date()
        let t = Community.Theme(id: "t", kind: .daily, startsAt: now.addingTimeInterval(-3_600), endsAt: now.addingTimeInterval(3_600),
                                title: ["en": "T"], prompt: ["en": "P"])
        let mock = MockCommunityClient(themes: [t])
        let club = ClubModel(client: mock)
        await club.load()
        await club.refreshMineCard()
        let zero = try #require(club.card)
        #expect(zero.published == 0 && zero.likes == 0 && zero.followers == 0 && !zero.fresh.any)
        let url = URL(string: "file:///x.jpg")!
        await mock.seed([Community.Post(id: "m1", author: .init(id: "me", name: "Koco"), themeId: "t", photoURL: url, thumbURL: url,
                                        filmId: "portra400", caption: nil, takenAt: nil, createdAt: now, likeCount: 0, likedByMe: false)])
        await mock.seedLikes(post: "m1", at: [now, now])
        await mock.seedFollowers(["u1": now])
        await mock.seedComment(post: "m1", by: "Lena", text: "Nice")
        await club.refreshMineCard()
        let card = try #require(club.card)
        #expect(card.published == 1 && card.likes == 2 && card.comments == 1 && card.followers == 1)
        #expect(card.fresh.likes == 2 && card.fresh.followers == 1 && card.fresh.comments == 1)
        await club.openMine()
        #expect(club.card?.fresh.any == false && club.card?.likes == 2)
        await club.refreshMineCard()
        #expect(club.card?.fresh.any == false)   // seen on the community's side too
    }

    @Test("polish 2: a theme with no cover gets its newest public picture; one with none is marked, so the film shows the fogged blank")
    func coversFilled() async {
        let now = Date()
        let open = { (id: String) in Community.Theme(id: id, kind: .weekly, startsAt: now.addingTimeInterval(-3_600), endsAt: now.addingTimeInterval(86_400),
                                                     title: ["en": id], prompt: ["en": "P"]) }
        let mock = MockCommunityClient(themes: [open("a"), open("b"), open("c")])
        let url = URL(string: "file:///x.jpg")!
        let post = { (id: String, theme: String, age: Double, state: Community.Post.State?) in
            Community.Post(id: id, author: .init(id: "u-\(id)", name: "N"), themeId: theme, photoURL: url, thumbURL: url, filmId: "a",
                           caption: nil, takenAt: nil, createdAt: now.addingTimeInterval(-age), likeCount: 0, likedByMe: false, state: state)
        }
        await mock.seed([post("a1", "a", 10, nil), post("b-old", "b", 50, nil), post("b-new", "b", 5, nil)])
        let club = ClubModel(client: mock)
        await club.load()
        // "a" is the chosen theme (its album read it); "b" is read for its cover; "c" has nothing.
        #expect(club.covers["a"]?.id == "a1")
        #expect(club.covers["b"]?.id == "b-new")
        #expect(club.covers["c"] == nil && club.coverless.contains("c"))
    }

    @Test("polish 2: the film's middle frame lies whole between the cuts, with a sliver of each neighbour")
    func filmGeometry() {
        for w: CGFloat in [180, 233, 260] {
            let h = ThemeFilm.filmHeight(width: w, height: .infinity)
            let u = h * ThemeFilm.aspect
            let slitW = (h + 6) / ThemeFilm.cut.height * ThemeFilm.slitAspect
            let between = w - 2 * slitW * ThemeFilm.cut.maxX
            #expect(u <= between - 2 * ThemeFilm.sliver + 1 && u >= between - 2 * ThemeFilm.sliver - 2)
        }
        // A short box: the cuts' height rules.
        #expect(ThemeFilm.filmHeight(width: 400, height: 100) == floor(100 * ThemeFilm.cut.height - 6))
        #expect(ThemeFilm.index(-1, 4) == 3 && ThemeFilm.index(5, 4) == 1)
    }
}
