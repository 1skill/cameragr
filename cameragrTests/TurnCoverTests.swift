import Testing
import UIKit
@testable import cameragr

/// The launch cover is up only while the system holds a way up the app did
/// not ask for (user 11/28: the turn at launch).
struct TurnCoverTests {
    @Test func coversOnlyAWayUpNotAskedFor() {
        // A plain iPhone opened in landscape by Info.plist, the camera wants portrait.
        #expect(TurnCover.turnPending(mask: .portrait, interface: .landscapeRight))
        #expect(TurnCover.turnPending(mask: .portrait, interface: .landscapeLeft))
        // The Duo's outer screen opened straight in its one way up: nothing to cover.
        #expect(!TurnCover.turnPending(mask: .landscapeRight, interface: .landscapeRight))
        #expect(!TurnCover.turnPending(mask: .portrait, interface: .portrait))
    }

    @Test func theInnerScreenIsNeverCovered() {
        // The inner screen asks for any way up (GlassSide.innerLie).
        for way in [UIInterfaceOrientation.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown] {
            #expect(!TurnCover.turnPending(mask: .all, interface: way))
        }
        #expect(!TurnCover.turnPending(mask: .portrait, interface: .unknown))
    }
}
