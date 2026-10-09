import Foundation
import Testing

@testable import TinyCache

@Suite("A folder as a source of pictures")
struct FolderSourceTests {

    @Test("It finds the pictures in the folder and in every folder inside it")
    func isRecursive() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("top.jpg")
        try scratch.picture("inside/second.png")
        try scratch.picture("inside/deeper/third.jpg")

        let found = try FolderSource(folder: scratch.url).pictures(10)

        #expect(Set(found.map(\.lastPathComponent)) == ["top.jpg", "second.png", "third.jpg"])
    }

    @Test("It passes over files that are not pictures")
    func skipsOtherFiles() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("coin.jpg")
        try scratch.text("notes.txt")
        try scratch.text("inside/catalogue.csv")

        let found = try FolderSource(folder: scratch.url).pictures(10)

        #expect(found.map(\.lastPathComponent) == ["coin.jpg"])
    }

    @Test("It gives back no more than it was asked for, and no picture twice")
    func respectsTheCount() throws {
        let scratch = try ScratchFolder()
        let names = (1...6).map { "coin-\($0).jpg" }
        for name in names { try scratch.picture(name) }

        let found = try FolderSource(folder: scratch.url).pictures(4).map(\.lastPathComponent)

        #expect(found.count == 4)
        #expect(Set(found).count == 4)
        #expect(Set(found).isSubset(of: Set(names)))
    }

    @Test("Asked for none, it gives none")
    func askedForNone() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("coin.jpg")

        #expect(try FolderSource(folder: scratch.url).pictures(0).isEmpty)
    }

    @Test("A folder with no pictures in it gives none")
    func emptyFolder() throws {
        let scratch = try ScratchFolder()
        try scratch.text("notes.txt")

        #expect(try FolderSource(folder: scratch.url).pictures(5).isEmpty)
    }

    @Test("A folder that cannot be read is an error, not an empty answer")
    func missingFolder() throws {
        let scratch = try ScratchFolder()
        let missing = scratch.url.appending(path: "not-here", directoryHint: .isDirectory)

        #expect(throws: (any Error).self) {
            try FolderSource(folder: missing).pictures(1)
        }
    }
}
