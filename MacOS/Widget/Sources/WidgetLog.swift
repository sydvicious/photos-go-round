// What the widget extension says to the unified log, and how much memory it
// has used when it says it. `Plans/Photos-Go-Round Widgets.md`, *Spike: a
// 1-minute refresh, and the extension's memory*.
//
// **Every line carries the process's memory.** The extension runs under about
// 30 MB, and the spike's question is whether that stays flat as a timeline gets
// longer. `now` is the footprint at this moment and `peak` the most this
// process has ever held, which is the figure the ceiling is measured against.
//
//     /usr/bin/log show --info --last 1h --predicate 'subsystem == "com.sydpolk.photosgoround" AND category == "widget"'

import Darwin
import Foundation
import OSLog
import TinyCache

enum WidgetLog {
    private static let log = Logger(subsystem: "com.sydpolk.photosgoround", category: "widget")

    static func note(_ message: String) {
        log.notice("widget: \(message, privacy: .public) [\(memory(), privacy: .public)]")
    }

    /// What one fetch read and wrote: `fetched for systemSmall, public.tiff
    /// 6000×4500 54.1 MB → 438×328 41 KB`. The original's size in pixels is
    /// what a full decode of it costs, at four bytes each; the written size in
    /// bytes is what TinyCache's space is measured in.
    static func fetched(_ resize: PictureResizer.Resize, for family: String) {
        note(
            """
            fetched for \(family), \(resize.originalType) \
            \(resize.originalWidth)×\(resize.originalHeight) \(megabytes(UInt64(resize.originalBytes))) → \
            \(resize.writtenWidth)×\(resize.writtenHeight) \(resize.writtenBytes / 1024) KB
            """)
    }

    /// `now 11.2 MB, peak 14.0 MB`, or why it could not be read.
    private static func memory() -> String {
        var usage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0)
            }
        }
        guard result == 0 else { return "memory unread, errno \(errno)" }
        return "now \(megabytes(usage.ri_phys_footprint)), peak \(megabytes(usage.ri_lifetime_max_phys_footprint))"
    }

    private static func megabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }
}
