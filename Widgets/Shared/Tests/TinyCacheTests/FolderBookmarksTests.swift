import Foundation
import Testing

@testable import TinyCache

@Suite("Bookmarks the app leaves for the widget")
struct FolderBookmarksTests {

    @Test("A folder's bookmark has one name, however its path is written")
    func nameIsStable() {
        let name = FolderBookmarks.fileName(forFolderAt: "/Users/someone/Pictures/Coins")

        #expect(name == FolderBookmarks.fileName(forFolderAt: "/Users/someone/Pictures/Coins/"))
        #expect(name == FolderBookmarks.fileName(forFolderAt: "/Users/someone/Pictures/../Pictures/Coins"))
        #expect(name.hasSuffix(".bookmark"))
        #expect(!name.contains("/"))
    }

    /// The app can see a folder the person chose and its widget cannot, and
    /// both have to come to the same name for it. On Syd's phone, 2026-10-11,
    /// they did not for a folder in iCloud Drive: the widget said no bookmark
    /// had been left for one the app had just opened through its own.
    @Test("The name is the same whether or not the folder can be seen")
    func nameDoesNotDependOnTheDisk() throws {
        let scratch = try ScratchFolder()
        // Spelled with `/private` in front, as the Files browser hands a
        // location over on a phone.
        let seen = scratch.url.appending(path: "Coins").path(percentEncoded: false)
        let path = seen.hasPrefix("/private/") ? seen : "/private" + seen
        let unseen = FolderBookmarks.fileName(forFolderAt: path)

        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        try #require(FileManager.default.fileExists(atPath: path))

        #expect(FolderBookmarks.fileName(forFolderAt: path) == unseen)
    }

    @Test("Two folders' bookmarks have different names")
    func namesDiffer() {
        #expect(
            FolderBookmarks.fileName(forFolderAt: "/Users/someone/Pictures/Coins")
                != FolderBookmarks.fileName(forFolderAt: "/Users/someone/Pictures/Stamps"))
    }

    @Test("A bookmark that was left opens the folder it was left for")
    func leftThenOpened() throws {
        let scratch = try ScratchFolder()
        let folder = scratch.url.appending(path: "Coins", directoryHint: .isDirectory)
        let shared = scratch.url.appending(path: "shared", directoryHint: .isDirectory)
        try scratch.picture("Coins/coin.jpg")

        try FolderBookmarks.leave(for: folder, in: shared)
        let opened = try #require(try FolderBookmarks.open(folderAt: folder.path(percentEncoded: false), in: shared))

        let found = try FolderSource(folder: opened).pictures(5)
        #expect(found.map(\.lastPathComponent) == ["coin.jpg"])
    }

    @Test("A folder no bookmark was left for opens as nothing")
    func nothingLeft() throws {
        let scratch = try ScratchFolder()

        #expect(try FolderBookmarks.open(folderAt: "/Users/someone/Pictures/Coins", in: scratch.url) == nil)
    }
}
