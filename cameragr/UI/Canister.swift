import SwiftUI

/// A 35mm cartridge drawn in code: spool caps, body, colour band, label.
struct Canister: View {
    let film: Film

    var body: some View {
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
