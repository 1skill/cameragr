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
    let iso: Int
    /// "color" or "bw".
    let kind: String
    let lutSize: Int
    /// Two hex colours for the canister body and its band.
    let colors: [String]

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
        films = list
    }

    /// Raw float32 RGBA cube, red fastest. Nil if the file is missing or the wrong size.
    func cube(for film: Film) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cubes[film.id] { return cached }
        guard let url = Bundle.main.url(forResource: film.id, withExtension: "lut"),
              let data = try? Data(contentsOf: url),
              data.count == film.lutSize * film.lutSize * film.lutSize * 4 * MemoryLayout<Float32>.size else {
            return nil
        }
        cubes[film.id] = data
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
