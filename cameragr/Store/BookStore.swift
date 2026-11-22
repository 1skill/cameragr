import Foundation

/// The photo book in the bag's third pair of pages: a theme, and one Koco
/// picture a day put into it. Days in a row earn the issue's roll. Kept only
/// on this iPhone (Application Support/books.json), no account, nothing sent.
///
/// A day counts when a picture taken that day with Koco is put in that same
/// day (one a day; putting in another replaces it). Days are calendar days in
/// the time zone the book was started in, so travelling does not move them.
/// A missed day starts the count again; the pictures already in stay.
@MainActor
final class BookStore: ObservableObject {
    static let shared = BookStore()

    struct Entry: Codable, Equatable {
        let asset: String       // PHAsset.localIdentifier
        let film: String        // Film.id
        let day: String         // yyyy-MM-dd in the book's time zone
        let addedAt: Date
    }

    struct Issue: Codable, Equatable {
        let id: String
        let requiredDays: Int
        let rewardFilmID: String
        var timeZoneID: String?
        var entries: [Entry] = []
        /// The days that completed it, kept as they were.
        var completedDays: [String]?
        var completedAt: Date?
        var claimedAt: Date?
    }

    /// The first issue: "it fell asleep", three days in a row, Porto 400.
    static let first = Issue(id: "asleep-1", requiredDays: 3, rewardFilmID: "portra400")

    @Published private(set) var issue: Issue
    private let url: URL
    private let now: () -> Date

    init(url: URL = URL.applicationSupportDirectory.appendingPathComponent("books.json"),
         now: @escaping () -> Date = Date.init) {
        self.url = url
        self.now = now
        if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(Issue.self, from: data) {
            issue = saved
        } else {
            issue = Self.first
        }
    }

    // MARK: Days

    private var timeZone: TimeZone { issue.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current }

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }

    func day(of date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    var today: String { day(of: now()) }

    /// The day before `day`.
    private func previous(_ day: String) -> String {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              let before = calendar.date(byAdding: .day, value: -1, to: date) else { return "" }
        return self.day(of: before)
    }

    // MARK: Progress

    /// The pictures of the run still going: the latest days in a row, ending
    /// today or yesterday (a run that ended earlier is broken). Oldest first.
    var run: [Entry] { run(in: issue.entries) }

    private func run(in entries: [Entry]) -> [Entry] {
        let byDay = Dictionary(entries.map { ($0.day, $0) }, uniquingKeysWith: { _, newer in newer })
        var day = byDay[today] != nil ? today : previous(today)
        var days: [Entry] = []
        while let entry = byDay[day] {
            days.insert(entry, at: 0)
            day = previous(day)
        }
        return days
    }

    /// What the pages show: the days that completed the book once it is
    /// complete, else the run going on.
    var shownDays: [Entry] {
        if let done = issue.completedDays {
            return done.compactMap { d in issue.entries.last { $0.day == d } }
        }
        return Array(run.suffix(issue.requiredDays))
    }

    var isComplete: Bool { issue.completedAt != nil }
    var isClaimed: Bool { issue.claimedAt != nil }
    var hasToday: Bool { issue.entries.contains { $0.day == today } }
    /// Days put in before, which a missed day left behind.
    var hasEarlierPictures: Bool { issue.entries.count > run.count }

    /// Today's Koco pictures, newest first: the ones that can go in today.
    func todaysShots(_ shots: [ShotLog.Shot]) -> [ShotLog.Shot] {
        shots.filter { day(of: $0.date) == today }.sorted { $0.date > $1.date }
    }

    // MARK: Changes

    /// Puts a picture taken today in the book (replacing today's, if any).
    /// False if it was not taken today, or the book could not be written.
    @discardableResult
    func put(_ shot: ShotLog.Shot) -> Bool {
        if issue.timeZoneID == nil { issue.timeZoneID = TimeZone.current.identifier }
        guard day(of: shot.date) == today else { return false }
        var next = issue
        next.entries.removeAll { $0.day == today }
        next.entries.append(Entry(asset: shot.asset, film: shot.film, day: today, addedAt: now()))
        if next.completedAt == nil {
            let days = run(in: next.entries)
            if days.count >= next.requiredDays {
                next.completedDays = days.suffix(next.requiredDays).map(\.day)
                next.completedAt = now()
            }
        }
        return save(next)
    }

    /// Takes the roll the book earned. Someone who already has the film keeps
    /// the book's stamp only; nothing else changes. Safe to repeat.
    @discardableResult
    func claim(store: FilmStore) -> Bool {
        guard isComplete else { return false }
        if isClaimed { return true }
        if let film = FilmLibrary.shared.films.first(where: { $0.id == issue.rewardFilmID }), !store.isUnlocked(film) {
            guard store.grant(film.id) else { return false }
        }
        var next = issue
        next.claimedAt = now()
        return save(next)
    }

    private func save(_ next: Issue) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: url, options: .atomic)
            issue = next
            return true
        } catch {
            return false
        }
    }

    #if DEBUG
    /// Tests and checks: forgets the book.
    func resetForTesting() { issue = Self.first; try? FileManager.default.removeItem(at: url) }
    #endif
}
