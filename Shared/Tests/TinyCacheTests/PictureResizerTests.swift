import CoreGraphics
import Foundation
import Testing

@testable import TinyCache

@Suite("Resizing a picture to fit a widget")
struct PictureResizerTests {

    @Test("A wide picture is shrunk until its width is the box's, and its height is inside it")
    func wideIntoSquare() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("wide.jpg", width: 2000, height: 1000)
        let resized = scratch.url.appending(path: "resized.jpg")

        try PictureResizer().write(original, fitting: CGSize(width: 400, height: 400), to: resized)

        let size = try #require(pixelSize(of: resized))
        #expect(size.width == 400)
        #expect(size.height == 200)
    }

    @Test("A tall picture is shrunk until its height is the box's, and its width is inside it")
    func tallIntoWide() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("tall.jpg", width: 1000, height: 2000)
        let resized = scratch.url.appending(path: "resized.jpg")

        try PictureResizer().write(original, fitting: CGSize(width: 400, height: 200), to: resized)

        let size = try #require(pixelSize(of: resized))
        #expect(size.height == 200)
        #expect(size.width == 100)
    }

    @Test("A picture smaller than the box is written at its own size, not enlarged")
    func smallIsNotEnlarged() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("small.png", width: 120, height: 90)
        let resized = scratch.url.appending(path: "resized.jpg")

        try PictureResizer().write(original, fitting: CGSize(width: 400, height: 400), to: resized)

        let size = try #require(pixelSize(of: resized))
        #expect(size.width == 120)
        #expect(size.height == 90)
    }

    @Test("It reports what it read and what it wrote, in pixels and in bytes")
    func reportsTheResize() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("wide.jpg", width: 2000, height: 1000)
        let resized = scratch.url.appending(path: "resized.jpg")

        let resize = try PictureResizer().write(
            original, fitting: CGSize(width: 400, height: 400), to: resized)

        #expect(resize.originalType == "public.jpeg")
        #expect(resize.originalWidth == 2000)
        #expect(resize.originalHeight == 1000)
        #expect(resize.originalBytes == byteCount(of: original))
        #expect(resize.writtenWidth == 400)
        #expect(resize.writtenHeight == 200)
        #expect(resize.writtenBytes == byteCount(of: resized))
        #expect(resize.writtenBytes > 0)
    }

    @Test("A file that is not a picture is an error, and nothing is written")
    func notAPicture() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.text("coin.jpg")
        let resized = scratch.url.appending(path: "resized.jpg")

        #expect(throws: (any Error).self) {
            try PictureResizer().write(original, fitting: CGSize(width: 400, height: 400), to: resized)
        }
        #expect(!FileManager.default.fileExists(atPath: resized.path(percentEncoded: false)))
    }
}
