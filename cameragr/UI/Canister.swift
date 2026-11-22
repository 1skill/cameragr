import SwiftUI

/// A 35mm cartridge: the film's own picture where one is in the bundle
/// (roll_<id>.png, standing upright, its name reading downwards), and
/// otherwise one drawn in code: spool caps, body, colour band, label.
struct Canister: View {
    let film: Film
    /// Stretch to the frame instead of keeping the picture's shape (a few
    /// percent at most), so a roll fills its cradle end to end.
    var fill = false

    private static var pictures: [String: UIImage?] = [:]

    private static func picture(for film: Film) -> UIImage? {
        if let known = pictures[film.id] { return known }
        let found = UIImage(named: "roll_\(film.id)")
        pictures[film.id] = found
        return found
    }

    var body: some View {
        if let picture = Self.picture(for: film) {
            let image = Image(uiImage: picture).resizable().interpolation(.high)
            if fill {
                image
            } else {
                image.scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            drawn
        }
    }

    private var drawn: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Spool nub on top.
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(white: 0.12))
                    .frame(width: w * 0.30, height: h * 0.10)
                    .position(x: w / 2, y: h * 0.05)
                // Body.
                RoundedRectangle(cornerRadius: w * 0.10)
                    .fill(film.bodyColor)
                    .frame(width: w, height: h * 0.86)
                    .position(x: w / 2, y: h * 0.55)
                // Colour band with the stock's short name.
                Rectangle()
                    .fill(film.bandColor)
                    .frame(width: w, height: h * 0.30)
                    .position(x: w / 2, y: h * 0.60)
                Text(film.label)
                    .font(.system(size: max(5, w * 0.24), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(width: w * 0.92)
                    .position(x: w / 2, y: h * 0.60)
                // Caps.
                Rectangle().fill(Color(white: 0.12)).frame(width: w, height: h * 0.07).position(x: w / 2, y: h * 0.155)
                Rectangle().fill(Color(white: 0.12)).frame(width: w, height: h * 0.07).position(x: w / 2, y: h * 0.945)
                // Cylinder shading.
                LinearGradient(colors: [.black.opacity(0.45), .white.opacity(0.22), .clear, .black.opacity(0.5)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: w, height: h * 0.86)
                    .position(x: w / 2, y: h * 0.55)
                    .clipShape(RoundedRectangle(cornerRadius: w * 0.10))
            }
        }
    }
}
