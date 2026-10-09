// A probe: can the app let its widget into a folder macOS protects?
// `Plans/Photos-Go-Round Widgets.md`, *The hard-coded folder, and the sandbox*.
//
// **What was measured first**, 2026-10-08: the widget extension cannot read
// `~/Documents/Coins/Raw Coin Images` by its path. The privacy system refuses,
// and will not show a prompt on a widget's behalf.
//
// **What this tries.** An app can be shown the prompt. So the app reads the
// folder, makes bookmarks to it, and leaves them in the App Group container it
// shares with the widget extension. The extension tries to open each one. Two
// kinds are left because it is not known which, if either, another program can
// use: one made with a security scope, and one made without.
//
// **It is a probe, not a feature.** The folder is hard-coded, as the widget's
// settings are for now, and this goes when the question is answered.

import Foundation
import OSLog
import PhotosGoRoundAgentAPI
import WidgetKit

nonisolated enum WidgetFolderBookmark {
    private static let log = Logger(subsystem: Log.subsystem, category: "widget")

    /// Off the main thread: the first read of the folder waits for as long as
    /// the privacy prompt is on the screen.
    static func leaveForWidget() {
        Task.detached(priority: .utility) { leave() }
    }

    private static func leave() {
        let folder = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appending(path: "Documents/Coins/Raw Coin Images", directoryHint: .isDirectory)
        let manager = FileManager.default

        do {
            let entries = try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            note("app read the folder, \(entries.count) entries at its top level")
        } catch {
            note("app could not read the folder: \(error.localizedDescription)")
            return
        }

        // The group's name is the widget's to state, in its `Info.plist`, so
        // that the two cannot disagree about it.
        guard
            let widget = Bundle.main.builtInPlugInsURL?
                .appending(path: "Photos-Go-Round Widget.appex"),
            let group = Bundle(url: widget)?.object(forInfoDictionaryKey: "PGRWidgetAppGroup") as? String,
            let container = manager.containerURL(forSecurityApplicationGroupIdentifier: group)
        else {
            note("app found no App Group container to leave a bookmark in")
            return
        }
        let shared = container.appending(path: "WidgetSource", directoryHint: .isDirectory)

        do {
            try manager.createDirectory(at: shared, withIntermediateDirectories: true)
        } catch {
            note("app could not make \(shared.path(percentEncoded: false)): \(error.localizedDescription)")
            return
        }
        leave(folder, options: [.withSecurityScope], as: "scoped", in: shared)
        leave(folder, options: [], as: "plain", in: shared)

        // So the widget tries what was just left, instead of at its next reload.
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func leave(
        _ folder: URL, options: URL.BookmarkCreationOptions, as name: String, in shared: URL
    ) {
        do {
            let bookmark = try folder.bookmarkData(options: options)
            try bookmark.write(to: shared.appending(path: "\(name).bookmark"), options: .atomic)
            note("app left the \(name) bookmark, \(bookmark.count) bytes")
        } catch {
            note("app could not leave the \(name) bookmark: \(error.localizedDescription)")
        }
    }

    private static func note(_ message: String) {
        log.notice("widget: \(message, privacy: .public)")
    }
}
