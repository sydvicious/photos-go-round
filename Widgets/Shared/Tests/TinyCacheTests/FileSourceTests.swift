import CoreGraphics
import Foundation
import Testing

@testable import TinyCache

@Suite("A single file as a source of pictures")
struct FileSourceTests {
    let box = CGSize(width: 200, height: 200)

    @Test("It gives the file's own picture, made to fit the box")
    func givesItsPicture() throws {
        let scratch = try ScratchFolder()
        let moon = try scratch.picture("moon.png", width: 800, height: 600)
        let written = scratch.url.appending(path: "written.heic")

        let resize = try #require(try FileSource(file: moon).writePicture(fitting: box, to: written))

        #expect(resize.writtenWidth == 200)
        #expect(resize.writtenHeight == 150)
    }

    @Test("It holds one picture")
    func holdsOne() throws {
        let scratch = try ScratchFolder()
        let moon = try scratch.picture("moon.png")

        #expect(try FileSource(file: moon).pictureCount() == 1)
    }

    @Test("A file that is no longer there cannot be read, which is not holding none")
    func gone() throws {
        let scratch = try ScratchFolder()
        let moon = scratch.url.appending(path: "moon.png")
        let source = FileSource(file: moon)

        #expect(throws: (any Error).self) { try source.pictureCount() }
        #expect(throws: (any Error).self) {
            try source.writePicture(fitting: box, to: scratch.url.appending(path: "written.heic"))
        }
    }

    @Test("A file that is not a picture has nothing to show, which is not an error")
    func notAPicture() throws {
        let scratch = try ScratchFolder()
        let notes = try scratch.text("notes.png")

        let resize = try FileSource(file: notes)
            .writePicture(fitting: box, to: scratch.url.appending(path: "written.heic"))

        #expect(resize == nil)
    }

    @Test("Two files' counts are remembered under different names")
    func countNames() throws {
        let scratch = try ScratchFolder()
        let moon = try scratch.picture("moon.png")
        let coin = try scratch.picture("coin.png")

        #expect(FileSource(file: moon).countName != FileSource(file: coin).countName)
    }
}
