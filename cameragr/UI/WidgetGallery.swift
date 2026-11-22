#if DEBUG
import SwiftUI

/// Shows the widgets at their home-screen sizes, for checking their look
/// without adding them to a home screen. Launch with `-widgets 1`.
struct WidgetGallery: View {
    var body: some View {
        // Stacked, so all three fit an upright phone screen.
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                tile(SingleFilmView(film: FilmLibrary.shared.films.first), width: 158, height: 158)
                tile(SingleFilmView(film: FilmLibrary.shared.films.last), width: 158, height: 158)
            }
            // `-widgetPicks 1`: shelves with a few rolls picked, as configured.
            if UserDefaults.standard.bool(forKey: "widgetPicks") {
                let all = FilmLibrary.shared.films
                tile(FilmShelfView(chosen: Array(all.suffix(3)), previewLarge: false), width: 338, height: 158)
                tile(FilmShelfView(chosen: [all[11], all[2], all[9], all[5], all[14]], previewLarge: true), width: 338, height: 354)
            } else {
                tile(FilmShelfView(previewLarge: false), width: 338, height: 158)
                tile(FilmShelfView(previewLarge: true), width: 338, height: 354)
            }
        }
        .scaleEffect(0.85)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.5))
        .ignoresSafeArea()
    }

    private func tile(_ view: some View, width: CGFloat, height: CGFloat) -> some View {
        view.frame(width: width, height: height)
            .background(BodyBackground())
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
#endif
