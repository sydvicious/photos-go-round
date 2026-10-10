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
