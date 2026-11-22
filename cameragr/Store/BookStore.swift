import Foundation
import UIKit

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
        issue = Self.first
        guard let data = try? Data(contentsOf: url) else { return }   // a new book
        if let saved = try? JSONDecoder().decode(Issue.self, from: data) {
            issue = saved
        } else {
            // Unreadable (damaged, or from a later version): kept aside, never
            // overwritten; if it can't be moved, nothing is written this time.
            let aside = url.deletingPathExtension().appendingPathExtension("unreadable-\(Int(Date().timeIntervalSince1970)).json")
            writable = (try? FileManager.default.moveItem(at: url, to: aside)) != nil
        }
    }

    /// False while an unreadable book could not be moved aside.
    private var writable = true

    // MARK: Days

    private var timeZone: TimeZone { issue.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current }

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }

    func day(of date: Date) -> String { day(of: date, in: issue) }

    private func day(of date: Date, in book: Issue) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = book.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
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
        var next = issue
        if next.timeZoneID == nil { next.timeZoneID = TimeZone.current.identifier }
        let today = day(of: now(), in: next)
        guard day(of: shot.date, in: next) == today else { return false }
        let replaced = next.entries.filter { $0.day == today && $0.asset != shot.asset }.map(\.asset)
        next.entries.removeAll { $0.day == today }
        next.entries.append(Entry(asset: shot.asset, film: shot.film, day: today, addedAt: now()))
        if next.completedAt == nil {
            let days = run(in: next.entries)
            if days.count >= next.requiredDays {
                next.completedDays = days.suffix(next.requiredDays).map(\.day)
                next.completedAt = now()
            }
        }
        guard save(next) else { return false }
        // Today's picture replaced: its copy goes, unless another day has it.
        for asset in replaced where !next.entries.contains(where: { $0.asset == asset }) { forget(asset) }
        return true
    }

    /// Removes the book's copy of a picture the book doesn't hold (a copy
    /// written for a picture that then couldn't be put in, or one replaced).
    func forget(_ asset: String) {
        guard !issue.entries.contains(where: { $0.asset == asset }) else { return }
        try? FileManager.default.removeItem(at: keepsake(for: asset))
        Self.cache.removeObject(forKey: asset as NSString)
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

    // MARK: Keepsakes

    /// The book keeps its own small copy of each picture put in, so deleting
    /// it from Photos (or taking away access) doesn't empty the book.
    private var keepsakes: URL { url.deletingLastPathComponent().appendingPathComponent("book", isDirectory: true) }

    func keepsake(for asset: String) -> URL {
        let name = asset.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined()
        return keepsakes.appendingPathComponent(name + ".jpg")
    }

    /// Pictures already read from the book's copies.
    private static let cache = NSCache<NSString, UIImage>()

    /// The book's copy of a picture, read off the main thread (and kept).
    func keepsakeImage(for asset: String) async -> UIImage? {
        if let known = Self.cache.object(forKey: asset as NSString) { return known }
        let file = keepsake(for: asset)
        let image = await Task.detached(priority: .userInitiated) { UIImage(contentsOfFile: file.path)?.preparingForDisplay() }.value
        if let image { Self.cache.setObject(image, forKey: asset as NSString) }
        return image
    }

    /// Writes the book's copy of a picture, encoding it off the main thread.
    /// False if it couldn't be written.
    func keep(_ image: UIImage, for asset: String) async -> Bool {
        let folder = keepsakes, file = keepsake(for: asset)
        let written = await Task.detached(priority: .userInitiated) { () -> Bool in
            guard let data = image.jpegData(compressionQuality: 0.85) else { return false }
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try data.write(to: file, options: .atomic)
                return true
            } catch {
                return false
            }
        }.value
        if written { Self.cache.setObject(image, forKey: asset as NSString) }
        return written
    }

    private func save(_ next: Issue) -> Bool {
        guard writable else { return false }
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
    /// `-bookDays N`: as if the last N days (ending today) each had a picture
    /// put in, from the pictures Koco knows; with N ≥ 3 the book is complete.
    func demo(days: Int, shots: [ShotLog.Shot]) {
        guard days > 0 else { return }
        var next = Self.first
        next.timeZoneID = TimeZone.current.identifier
        for back in (0..<days).reversed() {
            let date = Calendar.current.date(byAdding: .day, value: -back, to: now()) ?? now()
            let shot = shots.isEmpty ? nil : shots[back % shots.count]
            next.entries.append(Entry(asset: shot?.asset ?? "none", film: shot?.film ?? "gold200", day: day(of: date), addedAt: date))
        }
        if days >= next.requiredDays {
            next.completedDays = next.entries.suffix(next.requiredDays).map(\.day)
            next.completedAt = now()
        }
        issue = next
    }

    /// Tests and checks: forgets the book.
    func resetForTesting() { issue = Self.first; try? FileManager.default.removeItem(at: url) }
    #endif
}
