import Foundation

/// A short record of what happened and when, kept only in debug builds. The
/// Lock Screen camera can't be watched from Xcode, so it writes this beside
/// its pictures and the app prints it the next time it is opened.
enum Diag {
    static let fileName = "diag.txt"
    #if DEBUG
    private static let start = ProcessInfo.processInfo.systemUptime
    #endif
    private static let lock = NSLock()
    private static var lines: [String] = []
    private static var file: URL?

    static func write(to url: URL) {
        #if DEBUG
        // The last run's record is kept beside it (…-prev.txt): after a crash
        // the app is opened again, and that must not wipe what led to it.
        let prev = url.deletingPathExtension().appendingPathExtension("prev.txt")
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            try? fm.removeItem(at: prev)
            try? fm.moveItem(at: url, to: prev)
        }
        lock.lock(); file = url; lock.unlock()
        note("record opened")
        // Memory now and then: a process the system ends for memory says so here.
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in note(String(format: "memory %.0f MB", footprintMB())) }
        #endif
    }

    #if DEBUG
    private static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }
    #endif

    static func note(_ text: @autoclosure () -> String) {
        #if DEBUG
        let line = String(format: "%7.3f  ", ProcessInfo.processInfo.systemUptime - start) + text()
        lock.lock()
        lines.append(line)
        if lines.count > 4000 { lines.removeFirst(lines.count - 4000) }
        if let file { try? lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8) }
        lock.unlock()
        #endif
    }
}
