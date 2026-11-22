import Foundation
import Testing
@testable import cameragr

/// The photo book: days in a row, missed days, and the roll it earns.
/// In the purchases suite, which runs one test at a time: claiming changes the store.
extension StoreTests {
    /// A book in a temporary file whose clock the test moves.
    final class Clock: @unchecked Sendable { var now: Date; init(_ d: Date) { now = d } }

    @MainActor
    private func book(_ clock: Clock) -> BookStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("book-\(UUID().uuidString).json")
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

    @Test @MainActor func oneADayAndOnlyTodaysPictures() {
        let clock = Clock(noon(1)); let b = book(clock)
        _ = b.put(shot(1, at: noon(1)))
        _ = b.put(shot(2, at: noon(1).addingTimeInterval(60)))
        #expect(b.issue.entries.map(\.asset) == ["asset-2"])
        clock.now = noon(2)
        let yesterdays = shot(3, at: noon(1))
        #expect(!b.put(yesterdays), "a picture from yesterday doesn't count today")
        #expect(b.todaysShots([yesterdays, shot(4, at: noon(2))]).map(\.asset) == ["asset-4"])
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
}
