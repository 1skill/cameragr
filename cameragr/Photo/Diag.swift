import Foundation

/// A short record of what happened and when, kept only in debug builds. The
/// Lock Screen camera can't be watched from Xcode, so it writes this beside
/// its pictures and the app prints it the next time it is opened.
enum Diag {
    static let fileName = "diag.txt"
    private static let start = ProcessInfo.processInfo.systemUptime
    private static let lock = NSLock()
    private static var lines: [String] = []
    private static var file: URL?

    static func write(to url: URL) {
        #if DEBUG
        lock.lock(); file = url; lock.unlock()
        note("record opened")
        #endif
    }

    static func note(_ text: @autoclosure () -> String) {
        #if DEBUG
        let line = String(format: "%7.3f  ", ProcessInfo.processInfo.systemUptime - start) + text()
        lock.lock()
        lines.append(line)
        if let file { try? lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8) }
        lock.unlock()
        #endif
    }
}
