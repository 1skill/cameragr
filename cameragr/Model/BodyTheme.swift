import SwiftUI
import UIKit

/// Dark or light body: the slide switch on the camera flips it, and every
/// body follows (outer-screen body, half-fold waist-level body and deck, the
/// upright iPhone body). Kept across launches; dark by default.
final class BodyTheme: ObservableObject {
    static let shared = BodyTheme()
    private static let key = "bodyLight"

    @Published var isLight: Bool {
        didSet { if oldValue != isLight { UserDefaults.standard.set(isLight, forKey: Self.key) } }
    }

    private init() {
        // `-bodyLight 1` on the command line reads the same way.
        isLight = UserDefaults.standard.bool(forKey: Self.key)
    }

    /// A picture of the current body: the light one carries `_light` before its extension.
    func art(_ name: String) -> UIImage { Self.art(name, light: isLight) }

    static func art(_ name: String, light: Bool) -> UIImage {
        if light {
            let url = URL(fileURLWithPath: name)
            let lit = url.deletingPathExtension().lastPathComponent + "_light" + (url.pathExtension.isEmpty ? "" : "." + url.pathExtension)
            if let image = UIImage(named: lit) { return image }
        }
        return UIImage(named: name) ?? UIImage()
    }

    /// What is printed on a key (cream on black plastic, dark on cream).
    var keyInk: Color { isLight ? Color(red: 0.20, green: 0.19, blue: 0.17) : Color(red: 0.86, green: 0.82, blue: 0.72) }
    var labelInk: Color { isLight ? Color(red: 0.24, green: 0.23, blue: 0.20) : Color(red: 0.80, green: 0.78, blue: 0.72) }
    /// A lit key's mark.
    var litInk: Color { isLight ? Color(red: 0.86, green: 0.42, blue: 0.04) : Color(red: 1.0, green: 0.74, blue: 0.24) }
}

extension BodyTheme {
    /// The slide switch's empty track, cut out of the body picture (1536×1024)
    /// with a little margin, for the upright body where it has no slot of its own.
    static let trackCut = CGRect(x: 1030, y: 560, width: 214, height: 82)
    /// Where the knob sits in `trackCut`: centres of its two ends, and its size.
    static let trackKnobLeft = CGPoint(x: 1076 - 1030, y: 601 - 560)
    static let trackKnobRight = CGPoint(x: 1198 - 1030, y: 601 - 560)
    static let knobSize = CGSize(width: 72, height: 56)

    private static var trackCache: [Bool: UIImage] = [:]
    var trackSprite: UIImage {
        if let made = Self.trackCache[isLight] { return made }
        let plate = art("body_plate.jpg")
        guard let whole = plate.cgImage else { return UIImage() }
        let k = CGFloat(whole.width) / 1536
        let r = Self.trackCut
        let made = whole.cropping(to: CGRect(x: r.minX * k, y: r.minY * k, width: r.width * k, height: r.height * k))
            .map { UIImage(cgImage: $0) } ?? UIImage()
        Self.trackCache[isLight] = made
        return made
    }
}
