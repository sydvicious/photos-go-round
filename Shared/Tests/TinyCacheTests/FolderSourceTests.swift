import CoreGraphics
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

    @Test("Told not to look inside folders, it finds only the pictures at the top")
    func notRecursive() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("top.jpg")
        try scratch.picture("inside/second.png")

        let found = try FolderSource(folder: scratch.url, recursive: false).pictures(10)

        #expect(found.map(\.lastPathComponent) == ["top.jpg"])
    }

    @Test("It writes one of its pictures at the size that fits")
    func writesAPicture() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("pictures/coin.jpg", width: 800, height: 400)
        let written = scratch.url.appending(path: "written.jpg")

        let resize = try FolderSource(folder: scratch.url.appending(path: "pictures"))
            .writePicture(fitting: CGSize(width: 40, height: 40), to: written)

        #expect(resize?.originalWidth == 800)
        let size = try #require(pixelSize(of: written))
        #expect(size.width == 40)
        #expect(size.height == 20)
    }

    @Test("A file that will not decode is passed over for one that will")
    func passesOverABadFile() throws {
        let scratch = try ScratchFolder()
        try scratch.text("pictures/broken.jpg")
        try scratch.picture("pictures/coin.jpg")
        let folder = FolderSource(folder: scratch.url.appending(path: "pictures"))

        // Which of the two is tried first is chance; neither order may fail.
        for attempt in 0..<12 {
            let written = scratch.url.appending(path: "written-\(attempt).jpg")
            #expect(try folder.writePicture(fitting: CGSize(width: 40, height: 40), to: written) != nil)
            #expect(pixelSize(of: written) != nil)
        }
    }

    @Test("A folder with nothing that decodes writes nothing, and says so")
    func nothingDecodes() throws {
        let scratch = try ScratchFolder()
        try scratch.text("pictures/broken.jpg")
        let written = scratch.url.appending(path: "written.jpg")

        let resize = try FolderSource(folder: scratch.url.appending(path: "pictures"))
            .writePicture(fitting: CGSize(width: 40, height: 40), to: written)

        #expect(resize == nil)
        #expect(pixelSize(of: written) == nil)
    }
}
