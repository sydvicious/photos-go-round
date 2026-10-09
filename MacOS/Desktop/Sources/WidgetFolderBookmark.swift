// The app's half of letting its widget into the folders it shows.
// `Plans/Photos-Go-Round Widgets.md`, *The hard-coded folder, and the sandbox*.
//
// **Measured 2026-10-08**: the widget extension cannot read a folder in
// `~/Documents` by its path, because the privacy system refuses and will not
// show a prompt on a widget's behalf. An app can be let in, and a plain bookmark
// the app leaves in the App Group container opens the folder for the extension.
//
// **So the app leaves a bookmark for every folder source**, when it launches
// and whenever its sources change. Syd, of when: "the app is making the
// changes". `FolderBookmarks` in `TinyCache` is both halves of the mechanism;
// this is only the app deciding when and for which folders.

import Foundation
import OSLog
import PhotosGoRoundAgentAPI
import TinyCache
import WidgetKit

nonisolated enum WidgetFolderBookmark {
    private static let log = Logger(subsystem: Log.subsystem, category: "widget")

    /// Off the main thread: the first read of a folder waits for as long as a
    /// privacy prompt is on the screen.
    static func leaveForWidget() {
        // A test of the app's models announces source changes as the app does,
        // and must not reach the real widgets or the real App Group for it.
        guard !Log.subsystem.hasSuffix(".tests") else { return }
        Task.detached(priority: .utility) { leave() }
    }

    private static func leave() {
        let manager = FileManager.default
        // The group's name is the widget's to state, in its `Info.plist`, so
        // that the two cannot disagree about it.
        guard
            let widget = Bundle.main.builtInPlugInsURL?
                .appending(path: "Photos-Go-Round Widget.appex"),
            let group = Bundle(url: widget)?.object(forInfoDictionaryKey: "PGRWidgetAppGroup") as? String,
            let container = manager.containerURL(forSecurityApplicationGroupIdentifier: group)
        else {
            note("app found no App Group container to leave bookmarks in")
            return
        }
        let shared = container.appending(path: "WidgetSource", directoryHint: .isDirectory)

        let folders = Preferences(suiteName: MacHostEnvironment.preferenceDomain()).sources
            .filter { $0.kind == .folder }
        for spec in folders {
            let folder = URL(fileURLWithPath: spec.locator, isDirectory: true)
            do {
                // Read first: this is where the app is asked, if it is going
                // to be, and a bookmark from an app that was refused carries
                // nothing.
                _ = try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                try FolderBookmarks.leave(for: folder, in: shared)
                note("app left a bookmark for \(spec.locator)")
            } catch {
                note("app left no bookmark for \(spec.locator): \(error.localizedDescription)")
            }
        }

        // So the widgets show what has just changed, instead of at their next
        // reload.
        WidgetCenter.shared.reloadAllTimelines()
        note("app asked the widgets to reload, \(folders.count) folder sources")
    }

    private static func note(_ message: String) {
        log.notice("widget: \(message, privacy: .public)")
    }
}
