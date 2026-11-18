#if DEBUG
import SwiftUI

/// Shows the widgets at their home-screen sizes, for checking their look
/// without adding them to a home screen. Launch with `-widgets 1`.
struct WidgetGallery: View {
    var body: some View {
        HStack(spacing: 12) {
            tile(SingleFilmView(film: FilmLibrary.shared.films.first), width: 158, height: 158)
            tile(FilmShelfView(previewLarge: false), width: 338, height: 158)
            tile(FilmShelfView(previewLarge: true), width: 338, height: 354)
        }
        .scaleEffect(0.7)
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
