import CoreGraphics

/// Which whole row a scroll offset has reached, for the ratchet clicks of the
/// bag's belt and the club's album.
///
/// `Int(_:)` of a value that is not finite, or out of Int's range, stops the
/// app. Both happened on the iPhone Duo's inner screen as the system scaled
/// the app while the phone turned (build 133, crash reports 11/27 23:16 and
/// 23:20: RollLibrary.belt, `Int((old / pitch).rounded(.down))`): a scale of 0
/// made the pitch 0 and the row infinite, or the offset itself was not a number.
/// Such a reading is no row at all: nil, and nothing clicks.
enum ScrollRows {
    static func row(at offset: CGFloat, pitch: CGFloat) -> Int? {
        guard offset.isFinite, pitch.isFinite, pitch > 0 else { return nil }
        let row = (offset / pitch).rounded(.down)
        guard row.isFinite, abs(row) < 1_000_000 else { return nil }
        return Int(row)
    }

    /// A count of rows from a length, never less than `minimum` (and no trap).
    static func count(_ length: CGFloat, pitch: CGFloat, minimum: Int = 0) -> Int {
        guard let rows = row(at: length, pitch: pitch) else { return minimum }
        return max(minimum, rows)
    }
}
