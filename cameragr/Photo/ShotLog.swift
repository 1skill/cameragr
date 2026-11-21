import Foundation

/// Which film each picture was taken with, so a film's own pictures can be
/// shown with it (the film library's contact sheet). Pictures live in Photos;
/// this keeps only their Photos identifier, the film and the time, in the
/// app's own folder. A picture deleted from Photos is simply not found later.
@MainActor
final class ShotLog: ObservableObject {
    static let shared = ShotLog()

    struct Shot: Codable, Equatable {
        let asset: String   // PHAsset.localIdentifier
        let film: String    // Film.id
        let date: Date
    }

    @Published private(set) var shots: [Shot] = []
    private let url: URL

    init(url: URL = URL.applicationSupportDirectory.appendingPathComponent("shots.json")) {
        self.url = url
        if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode([Shot].self, from: data) {
            shots = saved
        }
    }

    /// In the Lock Screen camera: the file in its session folder where shots
    /// are noted for the app, which cannot see this extension's own folder.
    static var lockScreenLog: URL?
    static let lockScreenLogName = "shots.txt"

    /// Notes a picture. False if it could not be kept (the file couldn't be written).
    @discardableResult
    func add(asset: String, film: String, date: Date = .now) -> Bool {
        if let log = Self.lockScreenLog {
            let line = Data("\(asset)\t\(film)\t\(date.timeIntervalSince1970)\n".utf8)
            if let handle = try? FileHandle(forWritingTo: log) {
                try? handle.seekToEnd(); try? handle.write(contentsOf: line); try? handle.close()
            } else {
                return (try? line.write(to: log)) != nil
            }
            return true
        }
        guard !shots.contains(where: { $0.asset == asset }) else { return true }
        shots.append(Shot(asset: asset, film: film, date: date))
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? JSONEncoder().encode(shots).write(to: url, options: .atomic)) != nil
    }

    /// In the app: takes in the shots a Lock Screen session noted. Safe to
    /// repeat: a picture already known is not added twice.
    /// False if they could not be kept: the session must then stay for another try.
    @discardableResult
    func addLockScreenShots(from folder: URL) -> Bool {
        guard let text = try? String(contentsOf: folder.appendingPathComponent(Self.lockScreenLogName), encoding: .utf8)
        else { return true }   // nothing noted
        var kept = true
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t").map(String.init)
            guard parts.count == 3, let seconds = Double(parts[2]) else { continue }
            kept = add(asset: parts[0], film: parts[1], date: Date(timeIntervalSince1970: seconds)) && kept
        }
        return kept
    }

    /// A film's pictures, newest first.
    func assets(for film: String) -> [String] {
        shots.filter { $0.film == film }.sorted { $0.date > $1.date }.map(\.asset)
    }
}
