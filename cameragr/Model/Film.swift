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

    /// Raw float32 RGBA cube, red fastest. Nil if the file is missing or the wrong size.
    /// `stage` picks one of the grain set: "neg", "grain" or "print".
    func cube(for film: Film, stage: String? = nil) -> Data? {
        let name = stage.map { "\(film.id)_\($0)" } ?? film.id
        lock.lock()
        defer { lock.unlock() }
        if let cached = cubes[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "lut"),
              let data = try? Data(contentsOf: url),
              data.count == film.lutSize * film.lutSize * film.lutSize * 4 * MemoryLayout<Float32>.size else {
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
