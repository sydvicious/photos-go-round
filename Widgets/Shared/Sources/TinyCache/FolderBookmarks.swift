// How the app lets its widget into a folder. `Plans/Photos-Go-Round Widgets.md`,
// *The hard-coded folder, and the sandbox*.
//
// **Knowing a folder's path is not being let into it.** Measured 2026-10-08: a
// widget extension is refused a folder in `~/Documents` by the privacy system,
// which will not show a prompt on a widget's behalf. An app can be let in. So
// the app leaves a bookmark to each folder in the App Group container it shares
// with the extension, and the extension opens the folder through that.
//
// **A plain bookmark, not a security-scoped one.** The same day: the
// security-scoped bookmark the app made did not resolve in the extension at
// all, and the plain one opened the folder.
//
// Both halves are here so that the app and the extension cannot disagree about
// which file is which folder's.

import Foundation

public enum FolderBookmarks {
    /// The name of the file a folder's bookmark is kept in: the same for a
    /// path however it is written, and with nothing of the path readable in it.
    public static func fileName(forFolderAt path: String) -> String {
        let standard = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
            .path(percentEncoded: false)
        let trimmed = standard.count > 1 && standard.hasSuffix("/") ? String(standard.dropLast()) : standard
        // FNV-1a, 64 bits. Not Swift's `Hasher`, which is seeded afresh in
        // every process: the app and the extension must get the same name.
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in trimmed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - hex.count) + hex + ".bookmark"
    }

    /// The app's half: leaves a bookmark to `folder` in `directory`. The app
    /// has to have been let into the folder for the bookmark to carry anything.
    public static func leave(for folder: URL, in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bookmark = try folder.bookmarkData(options: [])
        let file = directory.appending(path: fileName(forFolderAt: folder.path(percentEncoded: false)))
        try bookmark.write(to: file, options: .atomic)
    }

    /// The extension's half: the folder at `path`, opened through the bookmark
    /// left for it, or nil if none was left. Access to it is started and never
    /// stopped, so open a folder once in a process and keep what comes back.
    public static func open(folderAt path: String, in directory: URL) throws -> URL? {
        let file = directory.appending(path: fileName(forFolderAt: path))
        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else { return nil }
        var stale = false
        let folder = try URL(
            resolvingBookmarkData: try Data(contentsOf: file), options: [], bookmarkDataIsStale: &stale)
        _ = folder.startAccessingSecurityScopedResource()
        return folder
    }
}
