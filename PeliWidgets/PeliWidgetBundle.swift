import SwiftUI
import WidgetKit

/// Home-screen widgets: rolls of film that open the camera with that film loaded.
@main
struct PeliWidgets: WidgetBundle {
    var body: some Widget {
        FilmShelfWidget()
        SingleFilmWidget()
        PeliCaptureControl()
    }
}

