
import SwiftUI

/// The camera bag on an iPhone that doesn't fold, held upright: one page at a
/// time, filling the screen. Films is laid out for the upright phone
/// (`UprightFilms`); the community and the settings keep the landscape pair
/// they have always had, shown across the phone as before, until their own
/// upright pages are made. The bag does not turn with the hold.
struct UprightBag: View {
    @EnvironmentObject private var model: CameraModel
    let size: CGSize
    @State private var page: Spread
    /// What is on the card survives a visit to the other pages.
    @State private var looking: Film?
    private let start: CameraModel.BagOpening

    init(start: CameraModel.BagOpening, size: CGSize) {
        self.start = start
        self.size = size
        _page = State(initialValue: start.spread)
    }

    var body: some View {
        Group {
            if page == .films {
                UprightFilms(start: start, size: size, looking: $looking) { page = $0 }
            } else {
                FixedToPhone(wide: true, turnOnGlass: FoldLayout.bodyTurnOnGlass) {
                    RollLibrary(start: CameraModel.BagOpening(spread: page, look: nil), showsClasp: true,
                                portraitFilms: { page = .films })
                        .environmentObject(model)
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .transition(.opacity)
    }
}
