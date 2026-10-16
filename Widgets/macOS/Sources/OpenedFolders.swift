// The folders this process has been let into, through the bookmarks the app
// left. `Plans/Photos-Go-Round Widgets.md`, *The hard-coded folder, and the
// sandbox*.
//
// **Opened once and kept.** Access to a folder opened through a bookmark lasts
// while it is not stopped, and nothing here stops it, so each folder is opened
// once in the life of the process.

import Foundation
import TinyCache
import os

enum OpenedFolders {
    private static let opened = OSAllocatedUnfairLock(initialState: [String: URL]())

    /// Where the app leaves its bookmarks: `WidgetSource` in the App Group
    /// container, whose name this extension's `Info.plist` states.
    private static let shared: URL? = {
        guard
            let group = Bundle.main.object(forInfoDictionaryKey: "PGRWidgetAppGroup") as? String,
            let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { return nil }
        return container.appending(path: "WidgetSource", directoryHint: .isDirectory)
    }()

    /// The folder at `path`, opened through its bookmark, or nil if the app
    /// has left none or it did not open. Tried again on every call until it
    /// works, since the app may not have left it yet.
    static func folder(at path: String) -> URL? {
        if let folder = opened.withLock({ $0[path] }) { return folder }
        guard let shared else {
            WidgetLog.note("no App Group container, so no bookmark for \(path)")
            return nil
        }
        do {
            guard let folder = try FolderBookmarks.open(folderAt: path, in: shared) else {
                WidgetLog.note("the app has left no bookmark for \(path)")
                return nil
            }
            opened.withLock { $0[path] = folder }
            WidgetLog.note("opened \(path) through its bookmark")
            return folder
        } catch {
            WidgetLog.note("the bookmark for \(path) did not open: \(error.localizedDescription)")
            return nil
        }
    }
}
