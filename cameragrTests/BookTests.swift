import Foundation
import UIKit
import Testing
@testable import cameragr

/// The photo book: days in a row, missed days, and the roll it earns.
/// In the purchases suite, which runs one test at a time: claiming changes the store.
extension StoreTests {
    /// A book in a temporary file whose clock the test moves.
    final class Clock: @unchecked Sendable { var now: Date; init(_ d: Date) { now = d } }

    @MainActor
    private func book(_ clock: Clock, at url: URL? = nil) -> BookStore {
        let url = url ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("book-\(UUID().uuidString)", isDirectory: true).appendingPathComponent("books.json")
        return BookStore(url: url, now: { clock.now })
    }

    private func shot(_ n: Int, at date: Date) -> ShotLog.Shot {
        ShotLog.Shot(asset: "asset-\(n)", film: "gold200", date: date)
    }

    /// Noon on a day in November, local time.
    private func noon(_ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 12))!
    }

    @Test @MainActor func threeDaysInARowCompleteTheBook() {
        let clock = Clock(noon(1)); let b = book(clock)
        for d in 1...3 {
            clock.now = noon(d)
            #expect(b.put(shot(d, at: noon(d))))
        }
        #expect(b.isComplete)
        #expect(b.shownDays.map(\.asset) == ["asset-1", "asset-2", "asset-3"])
    }

    @Test @MainActor func aMissedDayStartsAgainButKeepsThePictures() {
        let clock = Clock(noon(1)); let b = book(clock)
        _ = b.put(shot(1, at: noon(1)))
        clock.now = noon(2); _ = b.put(shot(2, at: noon(2)))
        clock.now = noon(4); _ = b.put(shot(4, at: noon(4)))
        #expect(!b.isComplete)
        #expect(b.run.map(\.asset) == ["asset-4"])
        #expect(b.issue.entries.count == 3)
        #expect(b.hasEarlierPictures)
    }

    @Test @MainActor func oneADayAnyKocoPictureButNotTwice() {
        let clock = Clock(noon(1)); let b = book(clock)
        _ = b.put(shot(1, at: noon(1)))
        _ = b.put(shot(2, at: noon(1).addingTimeInterval(60)))
        #expect(b.issue.entries.map(\.asset) == ["asset-2"], "one a day: today's is replaced")
        clock.now = noon(2)
        let older = shot(3, at: noon(1).addingTimeInterval(-86_400 * 30))
        #expect(b.put(older), "a picture taken any day counts as today's check-in")
        #expect(b.issue.entries.last?.day == b.today)
        clock.now = noon(3)
        #expect(!b.put(shot(2, at: noon(1))), "a picture already in on another day can't go in again")
        #expect(b.shotsToPut([shot(2, at: noon(1)), shot(5, at: noon(3))]).map(\.asset) == ["asset-5"])
    }

    @Test @MainActor func claimingGivesTheRollOnceAndKeepsIt() async {
        let clock = Clock(noon(1)); let b = book(clock)
        let porto = films.first { $0.id == "portra400" }!
        #expect(!store.isUnlocked(porto))
        #expect(!b.claim(store: store), "nothing to claim before it's complete")
        for d in 1...3 { clock.now = noon(d); _ = b.put(shot(d, at: noon(d))) }
        #expect(b.claim(store: store))
        #expect(store.isUnlocked(porto))
        #expect(store.trialsLeft(porto) == 0)
        #expect(b.claim(store: store), "claiming again is harmless")
        await store.restore()
        #expect(store.isUnlocked(porto), "restoring purchases doesn't take an earned roll away")
    }

    /// After the issue's roll: 7 days running earn Dusk 200, 14 Ember 400;
    /// a missed day keeps what was reached; limited rolls are never sold.
    @Test @MainActor func longerRunsEarnTheLimitedRolls() async {
        let clock = Clock(noon(1)); let b = book(clock)
        let dusk = films.first { $0.id == "dusk200" }!, ember = films.first { $0.id == "ember400" }!
        #expect(dusk.isLimited && ember.isLimited)
        #expect(!store.isUnlocked(dusk) && store.trialsLeft(dusk) == 0 && store.price(dusk) == nil)
        #expect(!store.paidFilms.contains(dusk), "not counted with the films for sale")
        #expect(await store.buy(dusk) == false, "never sold")
        for d in 1...3 { clock.now = noon(d); _ = b.put(shot(d, at: noon(d))) }
        #expect(!b.canClaimMilestone, "the issue's own roll comes first")
        #expect(b.claim(store: store))
        #expect(b.nextMilestone?.filmID == "dusk200")
        for d in 4...7 { clock.now = noon(d); _ = b.put(shot(d, at: noon(d))) }
        #expect(b.canClaimMilestone)
        clock.now = noon(9)   // a day missed after reaching seven
        #expect(b.canClaimMilestone, "a missed day keeps the seven reached")
        #expect(b.claimMilestone(store: store))
        #expect(store.isUnlocked(dusk))
        #expect(b.nextMilestone?.filmID == "ember400")
        #expect(!b.canClaimMilestone)
        #expect(!b.claimMilestone(store: store))
        for d in 9...22 { clock.now = noon(d); _ = b.put(shot(d, at: noon(d))) }
        #expect(b.claimMilestone(store: store))
        #expect(store.isUnlocked(ember))
        #expect(b.nextMilestone == nil)
    }

    @Test @MainActor func theBookIsReadBackAfterARestart() {
        let clock = Clock(noon(1))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("book-\(UUID().uuidString)/books.json")
        let b = book(clock, at: url)
        for d in 1...2 { clock.now = noon(d); _ = b.put(shot(d, at: noon(d))) }
        let again = book(clock, at: url)
        #expect(again.issue == b.issue)
        #expect(again.run.count == 2)
    }

    @Test @MainActor func aPictureFromJustBeforeMidnightCountsForTheDayItIsPutIn() {
        let late = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 23, minute: 59))!
        let clock = Clock(late.addingTimeInterval(120)); let b = book(clock)
        #expect(b.put(shot(1, at: late)))
        #expect(b.issue.entries.map(\.day) == [b.today], "the check-in is the day it goes in, not the day it was taken")
    }

    @Test @MainActor func aDamagedBookIsKeptAsideNotOverwritten() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("book-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("books.json")
        try Data("not json".utf8).write(to: url)
        let clock = Clock(noon(1)); let b = book(clock, at: url)
        #expect(b.issue.entries.isEmpty)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(names.contains { $0.contains("unreadable") }, "the damaged file is kept")
        #expect(b.put(shot(1, at: noon(1))))
    }

    @Test @MainActor func aFailedWriteChangesNothing() throws {
        // The book's folder is a file: nothing can be written there.
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent("book-\(UUID().uuidString)")
        try Data().write(to: blocker)
        let clock = Clock(noon(1)); let b = book(clock, at: blocker.appendingPathComponent("books.json"))
        #expect(!b.put(shot(1, at: noon(1))))
        #expect(b.issue.entries.isEmpty)
        #expect(b.issue.timeZoneID == nil)
    }

    @Test @MainActor func replacingTodaysPictureRemovesItsCopy() async {
        let clock = Clock(noon(1)); let b = book(clock)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in }
        #expect(await b.keep(image, for: "asset-1"))
        _ = b.put(shot(1, at: noon(1)))
        #expect(await b.keep(image, for: "asset-2"))
        _ = b.put(shot(2, at: noon(1).addingTimeInterval(60)))
        #expect(!FileManager.default.fileExists(atPath: b.keepsake(for: "asset-1").path))
        #expect(FileManager.default.fileExists(atPath: b.keepsake(for: "asset-2").path))
    }

    @Test @MainActor func someoneWhoOwnsTheRollGetsOnlyTheStamp() async {
        let porto = films.first { $0.id == "portra400" }!
        #expect(await store.buy(porto))
        #expect(store.isUnlocked(porto))
        let clock = Clock(noon(1)); let b = book(clock)
        for d in 1...3 { clock.now = noon(d); _ = b.put(shot(d, at: noon(d))) }
        #expect(b.claim(store: store))
        #expect(b.isClaimed)
        #expect(!store.gifted.contains("portra400"), "nothing is given on top of a purchase")
    }
}
