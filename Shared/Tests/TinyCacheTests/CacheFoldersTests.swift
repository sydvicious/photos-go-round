import Foundation
import Testing

@testable import TinyCache

@Suite("A cache folder for each list of sources")
struct CacheFoldersTests {

    func exists(_ folder: URL) -> Bool {
        FileManager.default.fileExists(atPath: folder.path(percentEncoded: false))
    }

    @Test("One list of sources has one folder, in whatever order the list is given")
    func sameListSameFolder() throws {
        let scratch = try ScratchFolder()

        let first = try CacheFolders.folder(in: scratch.url, forSources: ["folder|/Coins", "photos|album"])
        let second = try CacheFolders.folder(in: scratch.url, forSources: ["photos|album", "folder|/Coins"])

        #expect(first == second)
        #expect(first.path(percentEncoded: false).hasPrefix(scratch.url.path(percentEncoded: false)))
    }

    @Test("When the list changes, the pictures cached for the old list are removed")
    func changedListStartsEmpty() throws {
        let scratch = try ScratchFolder()
        let old = try CacheFolders.folder(in: scratch.url, forSources: ["folder|/Coins", "photos|album"])
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try Data("a coin".utf8).write(to: old.appending(path: "coin.jpg"))

        let new = try CacheFolders.folder(in: scratch.url, forSources: ["photos|album"])

        #expect(new != old)
        #expect(!exists(old))
    }

    @Test("While the list stays the same, what is cached for it is kept")
    func sameListKeepsItsPictures() throws {
        let scratch = try ScratchFolder()
        let folder = try CacheFolders.folder(in: scratch.url, forSources: ["photos|album"])
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let picture = folder.appending(path: "photo.jpg")
        try Data("a photograph".utf8).write(to: picture)

        _ = try CacheFolders.folder(in: scratch.url, forSources: ["photos|album"])

        #expect(exists(picture))
    }

    @Test("A base folder that is not there yet is not an error")
    func noBaseYet() throws {
        let scratch = try ScratchFolder()
        let base = scratch.url.appending(path: "not-made-yet", directoryHint: .isDirectory)

        #expect(throws: Never.self) {
            try CacheFolders.folder(in: base, forSources: ["photos|album"])
        }
    }
}
