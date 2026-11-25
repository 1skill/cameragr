import Foundation
import SwiftUI

/// One film stock. Colour comes from a baked 3D LUT (see tools/export_luts.py).
struct Film: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    /// Short text printed on the canister.
    let label: String
    /// At most five characters for the camera's LCD: the maker's own short
    /// code where there is one (GB, TX, RVP), else a letter and the speed.
    let lcd: String?
    /// Whether the stock has the three-stage set (<id>_neg, _grain, _print)
    /// for grain from its datasheet granularity.
    let grain: Bool?
    /// 35 mm-equivalent focal length whose natural cos^4 falloff is applied
    /// before the look; nil for none.
    let lens: Double?
    /// A digital camera's own texture after the colour: "ccd" adds the
    /// measured Sony T10 sharpening and ISO-dependent noise.
    let texture: String?
    /// Needs no purchase.
    let free: Bool?
    let iso: Int
    /// "color" or "bw".
    let kind: String
    let lutSize: Int
    /// Two hex colours for the canister body and its band.
    let colors: [String]
    /// Not offered yet: its look is baked, but its canister, samples and place
    /// in the bag are still being made. Kept out of every list.
    let upcoming: Bool?
    /// Never sold, no free shots: only earned with days running in the
    /// community (`earnDays`), see `Community.Me.milestones`.
    let limited: Bool?
    let earnDays: Int?
    var isLimited: Bool { limited == true }

    var bodyColor: Color { Color(hex: colors.first ?? "#888888") }
    var bandColor: Color { Color(hex: colors.dropFirst().first ?? "#222222") }
}

final class FilmLibrary {
    static let shared = FilmLibrary()

    let films: [Film]
    private var cubes: [String: Data] = [:]
    private let lock = NSLock()

    private init() {
        guard let url = Bundle.main.url(forResource: "films", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Film].self, from: data) else {
            films = []
            return
        }
        #if DEBUG
        // `-upcoming 1`: show the films not offered yet, for work on them.
        if UserDefaults.standard.bool(forKey: "upcoming") { films = list; return }
        #endif
        films = list.filter { $0.upcoming != true }
    }

    /// Told how long each cube took to read (the speed run logs it).
    nonisolated(unsafe) static var cubeTimed: ((String, Double, Bool) -> Void)?

    /// Every cube a film uses (its look and the grain set's stages), read and
    /// kept now, off the main thread, so the finder's first frames on it don't
    /// wait for the disk (11/25 speed run: a few seconds at 21–24 fps after a switch).
    func prewarm(_ film: Film) {
        for stage in [nil, "neg", "grain", "print"] as [String?] { _ = cube(for: film, stage: stage) }
    }

    /// Float32 RGBA cube, red fastest (stored as half-float RGB, see tools/pack_luts.py). Nil if missing or the wrong size.
    /// `stage` picks one of the grain set: "neg", "grain" or "print".
    func cube(for film: Film, stage: String? = nil) -> Data? {
        let name = stage.map { "\(film.id)_\($0)" } ?? film.id
        lock.lock()
        defer { lock.unlock() }
        if let cached = cubes[name] { return cached }
        let started = ProcessInfo.processInfo.systemUptime
        defer { Self.cubeTimed?(name, ProcessInfo.processInfo.systemUptime - started, Thread.isMainThread) }
        guard let url = Bundle.main.url(forResource: name, withExtension: "lut"),
              let stored = try? Data(contentsOf: url) else { return nil }
        let count = film.lutSize * film.lutSize * film.lutSize
        let data: Data
        if stored.count == count * 3 * MemoryLayout<Float16>.size {
            // Kept as half floats, RGB (a third of the size; finer than 8-bit
            // output by far): widened here to the float32 RGBA the cube wants.
            var out = [Float32](repeating: 1, count: count * 4)
            stored.withUnsafeBytes { raw in
                let half = raw.bindMemory(to: Float16.self)
                for i in 0..<count {
                    out[i * 4] = Float32(half[i * 3])
                    out[i * 4 + 1] = Float32(half[i * 3 + 1])
                    out[i * 4 + 2] = Float32(half[i * 3 + 2])
                }
            }
            data = out.withUnsafeBufferPointer { Data(buffer: $0) }
        } else if stored.count == count * 4 * MemoryLayout<Float32>.size {
            data = stored
        } else {
            return nil
        }
        cubes[name] = data
        return data
    }
}

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255,
                  opacity: 1)
    }
}
