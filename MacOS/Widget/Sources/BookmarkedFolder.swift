// A probe: can this extension open a folder through a bookmark its app made?
// `Plans/Photos-Go-Round Widgets.md`, *The hard-coded folder, and the sandbox*.
//
// The app's half is `WidgetFolderBookmark`. It leaves two bookmarks in the App
// Group container, one made with a security scope and one without. This tries
// each in turn, and what happened to each is logged and shown on the widget's
// face, so the answer can be read without the log.
//
// **It is a probe, not a feature.** It goes when the question is answered.

import Foundation
import os

enum BookmarkedFolder {
    private struct Found: Sendable {
        var folder: URL?
        var report = "No bookmark tried yet."
    }

    /// Kept for the life of the process once a bookmark has worked: access
    /// started on a folder lasts only while it is not stopped.
    private static let found = OSAllocatedUnfairLock(initialState: Found())

    /// The folder, if either bookmark opens it. Tried again on every call until
    /// one works, since the app may not have left them yet.
    static func folder() -> URL? {
        if let folder = found.withLock({ $0.folder }) { return folder }
        let tried = tryBookmarks()
        found.withLock { $0 = tried }
        WidgetLog.note("bookmarks: \(tried.report)")
        return tried.folder
    }

    /// What happened to each bookmark, in a line each.
    static var report: String { found.withLock { $0.report } }

    private static func tryBookmarks() -> Found {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "PGRWidgetAppGroup") as? String else {
            return Found(report: "No App Group named in Info.plist.")
        }
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else {
            return Found(report: "No container for the App Group \(group).")
        }
        let shared = container.appending(path: "WidgetSource", directoryHint: .isDirectory)

        var lines: [String] = []
        for (name, options) in [
            ("scoped", URL.BookmarkResolutionOptions.withSecurityScope), ("plain", []),
        ] {
            let (folder, line) = open(shared.appending(path: "\(name).bookmark"), options: options)
            lines.append("\(name) bookmark: \(line)")
            if let folder {
                return Found(folder: folder, report: lines.joined(separator: " "))
            }
        }
        return Found(report: lines.joined(separator: " "))
    }

    private static func open(_ file: URL, options: URL.BookmarkResolutionOptions) -> (URL?, String) {
        let bookmark: Data
        do {
            bookmark = try Data(contentsOf: file)
        } catch {
            return (nil, "not there (\(error.localizedDescription)).")
        }
        var stale = false
        let folder: URL
        do {
            folder = try URL(
                resolvingBookmarkData: bookmark, options: options, bookmarkDataIsStale: &stale)
        } catch {
            return (nil, "did not resolve (\(error.localizedDescription)).")
        }
        let started = folder.startAccessingSecurityScopedResource()
        do {
            let entries = try FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil)
            return (folder, "opened, \(entries.count) entries, access started \(started), stale \(stale).")
        } catch {
            if started { folder.stopAccessingSecurityScopedResource() }
            return (
                nil,
                "resolved but unreadable, access started \(started), stale \(stale) (\(error.localizedDescription))."
            )
        }
    }
}
