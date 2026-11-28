import CoreGraphics
import Testing
@testable import cameragr

/// The belt's and the album's row from a scroll offset: never a trap
/// (build 133 crashed in RollLibrary.belt on the inner screen while turning).
struct ScrollRowsTests {
    @Test func ordinaryOffsetsGiveTheirRow() {
        #expect(ScrollRows.row(at: 0, pitch: 100) == 0)
        #expect(ScrollRows.row(at: 250, pitch: 100) == 2)
        #expect(ScrollRows.row(at: -30, pitch: 100) == -1)   // pulled past the top
    }

    @Test func whatCrashedIsNoRow() {
        // A scale of 0 (pitch 0): offset / 0 is infinite or not a number.
        #expect(ScrollRows.row(at: 120, pitch: 0) == nil)
        #expect(ScrollRows.row(at: 0, pitch: 0) == nil)
        #expect(ScrollRows.row(at: -5, pitch: 0) == nil)
        // The offset itself not a number, or endless.
        #expect(ScrollRows.row(at: .nan, pitch: 100) == nil)
        #expect(ScrollRows.row(at: .infinity, pitch: 100) == nil)
        #expect(ScrollRows.row(at: -.infinity, pitch: 100) == nil)
        #expect(ScrollRows.row(at: 100, pitch: .nan) == nil)
        #expect(ScrollRows.row(at: 100, pitch: -10) == nil)
        // Finite but beyond any real belt (and Int's range for a tiny pitch).
        #expect(ScrollRows.row(at: 1e300, pitch: 1e-300) == nil)
        #expect(ScrollRows.row(at: .greatestFiniteMagnitude, pitch: 1) == nil)
    }

    @Test func countsNeverTrap() {
        #expect(ScrollRows.count(950, pitch: 100) == 9)
        #expect(ScrollRows.count(.nan, pitch: 100, minimum: 1) == 1)
        #expect(ScrollRows.count(950, pitch: 0, minimum: 2) == 2)
        #expect(ScrollRows.count(-500, pitch: 100) == 0)
    }
}
