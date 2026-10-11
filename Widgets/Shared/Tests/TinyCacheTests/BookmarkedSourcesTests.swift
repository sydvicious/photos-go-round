import Foundation
import Testing

@testable import TinyCache

@Suite("The files and folders a person chose, opened through the bookmarks left for them")
struct BookmarkedSourcesTests {
    func bookmarks(in scratch: ScratchFolder) -> BookmarkedSources {
        BookmarkedSources(directory: scratch.url.appending(path: "shared", directoryHint: .isDirectory))
    }

    @Test("A folder a bookmark was left for is opened through it")
    func folder() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("Coins/coin.jpg")
        let coins = scratch.url.appending(path: "Coins", directoryHint: .isDirectory)
        let bookmarks = bookmarks(in: scratch)

        try bookmarks.leave(for: coins)
        let opened = try #require(bookmarks.location(of: coins.path(percentEncoded: false)))

        #expect(try FolderSource(folder: opened).pictures(5).map(\.lastPathComponent) == ["coin.jpg"])
    }

    @Test("So is a single file")
    func file() throws {
        let scratch = try ScratchFolder()
        let moon = try scratch.picture("moon.png")
        let bookmarks = bookmarks(in: scratch)

        try bookmarks.leave(for: moon)
        let opened = try #require(bookmarks.location(of: moon.path(percentEncoded: false)))

        #expect(try FileSource(file: opened).pictureCount() == 1)
    }

    @Test("What one process left, another opens")
    func anotherReader() throws {
        let scratch = try ScratchFolder()
        let moon = try scratch.picture("moon.png")

        try bookmarks(in: scratch).leave(for: moon)

        #expect(bookmarks(in: scratch).location(of: moon.path(percentEncoded: false)) != nil)
    }

    @Test("Something no bookmark was left for has no location")
    func nothingLeft() throws {
        let scratch = try ScratchFolder()

        #expect(bookmarks(in: scratch).location(of: "/Users/someone/Pictures/Coins") == nil)
    }

    @Test("Once forgotten it has no location, even after it has been opened")
    func forgotten() throws {
        let scratch = try ScratchFolder()
        let moon = try scratch.picture("moon.png")
        let path = moon.path(percentEncoded: false)
        let bookmarks = bookmarks(in: scratch)
        try bookmarks.leave(for: moon)
        #expect(bookmarks.location(of: path) != nil)

        bookmarks.forget(path)

        #expect(bookmarks.location(of: path) == nil)
        #expect(self.bookmarks(in: scratch).location(of: path) == nil)
    }
}
