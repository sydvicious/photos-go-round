// The files and folders a person chose in the Files browser, kept as
// bookmarks and opened through them. `Plans/PGR Widgets - iOS.md`, *The files
// and folders*.
//
// **A path is not enough on iOS.** The Files browser lets the app into what
// was chosen for as long as the app runs. After that the path is refused, to
// the app at its next launch as much as to a widget, and a bookmark made
// while the app was let in is what opens it again. So the app opens its own
// sources through this too, and not only the widget extension.
//
// **In the App Group container**, where the app and its extension can both
// read: `FolderBookmarks` is the two halves, and this is what keeps them.
//
// **Opened once and kept.** Access to something opened through a bookmark
// lasts while it is not stopped, and nothing here stops it, so each is opened
// once in the life of the process.

import Foundation
import os

public final class BookmarkedSources: Sendable {
    private let directory: URL
    private let opened = OSAllocatedUnfairLock(initialState: [String: URL]())
    private let note: @Sendable (String) -> Void

    /// - Parameters:
    ///   - directory: Where the bookmarks are kept. The app and its extension
    ///     hand over the same folder of the container they share.
    ///   - note: Told how each opening went, in a sentence for the log. It
    ///     names a file or folder by its own name and not by its path.
    public init(directory: URL, note: @escaping @Sendable (String) -> Void = { _ in }) {
        self.directory = directory
        self.note = note
    }

    /// The app's half: leaves a bookmark to what the person chose. The Files
    /// browser hands over a location the app is let into only between a start
    /// and a stop, and the bookmark carries nothing unless it is made there.
    public func leave(for chosen: URL) throws {
        let letIn = chosen.startAccessingSecurityScopedResource()
        defer { if letIn { chosen.stopAccessingSecurityScopedResource() } }
        try FolderBookmarks.leave(for: chosen, in: directory)
    }

    /// Where the file or folder chosen at `path` is now, opened through its
    /// bookmark. Nil when none was left or it did not open: tried again on
    /// every call until it works, since the app may not have left it yet.
    public func location(of path: String) -> URL? {
        if let location = opened.withLock({ $0[path] }) { return location }
        let name = URL(filePath: path).lastPathComponent
        do {
            guard let location = try FolderBookmarks.open(folderAt: path, in: directory) else {
                note("no bookmark has been left for \(name)")
                return nil
            }
            opened.withLock { $0[path] = location }
            note("opened \(name) through its bookmark, and \(Self.reading(location))")
            return location
        } catch {
            note("the bookmark for \(name) did not open: \(Self.words(for: error))")
            return nil
        }
    }

    /// Removes the bookmark left for `path`, when its source is taken out of
    /// the list.
    public func forget(_ path: String) {
        opened.withLock { $0[path] = nil }
        try? FileManager.default.removeItem(
            at: directory.appending(path: FolderBookmarks.fileName(forFolderAt: path)))
    }

    /// Whether what a bookmark opened can be read, in words for the log. A
    /// bookmark can resolve to a location the process is still refused.
    private static func reading(_ location: URL) -> String {
        do {
            if (try location.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                let held = try FileManager.default.contentsOfDirectory(atPath: location.path(percentEncoded: false))
                return "it can be read: \(held.count) things in it"
            }
            try FileHandle(forReadingFrom: location).close()
            return "it can be read"
        } catch {
            return "it cannot be read: \(words(for: error))"
        }
    }

    /// An error in words for the log, with its domain and code after them:
    /// the words alone are the same for several different refusals.
    private static func words(for error: any Error) -> String {
        let error = error as NSError
        return "\(error.localizedDescription) (\(error.domain) \(error.code))"
    }
}
