import Testing
import UIKit
@testable import cameragr

/// The one way up for each place on the glass (user 11/27: the swipe home
/// along the picture's own bottom edge).
@MainActor
struct GlassSideTests {
    private let plain = CGSize(width: 402, height: 874)
    private let outer = CGSize(width: 466, height: 678)
    private let inner = CGSize(width: 669, height: 951)

    @Test func screensAreToldApart() {
        #expect(GlassSide.Screen(plain) == .plain)
        #expect(GlassSide.Screen(outer) == .outer)
        #expect(GlassSide.Screen(CGSize(width: 678, height: 466)) == .outer)
        #expect(GlassSide.Screen(inner) == .inner)
    }

    @Test func eachTurnHasItsOrientation() {
        // A plain screen (no measured difference).
        #expect(GlassSide.orientation(forLie: 0, onScreen: plain) == .portrait)
        #expect(GlassSide.orientation(forLie: 90, onScreen: plain) == .landscapeRight)
        #expect(GlassSide.orientation(forLie: 270, onScreen: plain) == .landscapeLeft)
        #expect(GlassSide.orientation(forLie: -90, onScreen: plain) == .landscapeLeft)
    }

    @Test func beforeAnyLayoutEachScreenOpensOnItsBody() {
        guard GlassSide.front == nil else { return }   // the test host may have one up
        #expect(GlassSide.mask(onScreen: plain) == .portrait)
        #expect(GlassSide.mask(onScreen: outer) == .landscapeRight)
        #expect(GlassSide.mask(onScreen: inner) == .all)
    }

    @Test func neverAsksForUpsideDownAlone() {
        #expect(GlassSide.mask(.portraitUpsideDown) == .portraitUpsideDown)
        // The open bag takes the other side rather than an upside-down interface.
        let turn = GlassSide.bagTurn(onScreen: inner)
        #expect(turn == 270 || turn == 90)
        #expect(GlassSide.orientation(forLie: turn, onScreen: inner) != .portraitUpsideDown)
    }
}
