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

    /// The inner screen showing the app scaled (log diag-duo-1128-129): the
    /// screen reports 469×669, which the old size rule took for the closed
    /// phone's outer screen, whatever the hinge said.
    private let scaledInner = CGSize(width: 469, height: 669)

    @Test func aScaledInnerScreenIsNeverTheOuter() {
        for size in [scaledInner, CGSize(width: 669, height: 469)] {
            for hinge in [HingeReading.unknown, .closed, .partial, .full] {
                #expect(GlassSide.Screen(size, hinge: hinge) == .inner)
                #expect(GlassSide.Screen(size, hinge: hinge) != .outer)
            }
        }
        // The outer panel stays the outer one while the phone is opened (the
        // hinge already open, the inner screen not yet lit), and the inner
        // one stays the inner one while it is closed.
        #expect(GlassSide.Screen(outer, hinge: .partial) == .outer)
        #expect(GlassSide.Screen(inner, hinge: .closed) == .inner)
        // An iPhone that doesn't fold.
        #expect(GlassSide.Screen(plain, hinge: .unknown) == .plain)
        #expect(GlassSide.Screen(CGSize(width: 440, height: 956), hinge: .unknown) == .plain)
    }

    @Test func aScaledWindowOnTheOpenPhoneStaysOpen() {
        // 469×669 with the hinge open flat: the inner screen, so the fold
        // stays flat (the bag), not closed (the outer camera).
        #expect(GlassSide.Screen(scaledInner, hinge: .full) == .inner)
        var tracker = FoldTracker(awaitingFirstReading: true)
        tracker.read(.full, at: 0)
        let onInner = GlassSide.Screen(scaledInner, hinge: .full) == .inner
        #expect(tracker.shown(onInnerScreen: onInner, showing: .flat) == .flat)
        var half = FoldTracker(awaitingFirstReading: true)
        half.read(.partial, at: 0)
        #expect(half.shown(onInnerScreen: GlassSide.Screen(scaledInner, hinge: .partial) == .inner) == .half)
    }

    @Test func theInnerScreenNeverAsksForPortrait() {
        // Every layout on the inner screen, in front or in a gap, at full size
        // or scaled: one landscape, the same one, never portrait (that is what
        // makes the system scale the app down).
        let wanted = GlassSide.mask(onScreen: inner)
        #expect(wanted == .landscapeLeft || wanted == .landscapeRight)
        for size in [inner, CGSize(width: 951, height: 669), scaledInner, CGSize(width: 669, height: 469)] {
            let mask = GlassSide.mask(onScreen: size)
            #expect(mask == .landscapeLeft || mask == .landscapeRight)
            #expect(!mask.contains(.portrait) && !mask.contains(.portraitUpsideDown))
            let lie = GlassSide.wantedLie(onScreen: size) ?? -1
            #expect(lie == 90 || lie == 270)
            #expect(GlassSide.orientation(forLie: lie, onScreen: size).isLandscape)
        }
        #expect(GlassSide.mask(onScreen: CGSize(width: 951, height: 669)) == wanted)
        // The half-open finder and the bag's camera are drawn upright (0) on
        // the glass; the inner screen still asks for the bag's landscape.
        #expect(GlassSide.innerLie(onScreen: inner) == GlassSide.bagTurn(onScreen: inner))
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
        #expect(GlassSide.mask(onScreen: inner) != .all)
    }

    @Test func neverAsksForUpsideDownAlone() {
        #expect(GlassSide.mask(.portraitUpsideDown) == .portraitUpsideDown)
        // The open bag takes the other side rather than an upside-down interface.
        let turn = GlassSide.bagTurn(onScreen: inner)
        #expect(turn == 270 || turn == 90)
        #expect(GlassSide.orientation(forLie: turn, onScreen: inner) != .portraitUpsideDown)
    }

    @Test func gapsKeepTheLastWayUpNotAll() {
        guard GlassSide.front == nil else { return }
        // With no layout settled the answer is the remembered one, never "any",
        // and it does not read how the phone is held.
        for screen in [plain, outer, inner] {
            let first = GlassSide.mask(onScreen: screen)
            #expect(first != .all)
            #expect(GlassSide.mask(onScreen: screen) == first)
            #expect(GlassSide.mask(onScreen: CGSize(width: screen.height, height: screen.width)) == first)
        }
    }
}
