import CoreGraphics
import Foundation
import Testing

@testable import TinyCache

@Suite("The Photos library as a source of pictures")
struct PhotosSourceTests {
    let box = CGSize(width: 400, height: 400)

    @Test("A picture the library hands back is written as it came, and reported")
    func writesWhatTheLibraryGave() throws {
        let scratch = try ScratchFolder()
        let written = scratch.url.appending(path: "written.jpg")
        let library = FakeLibrary(collections: ["album": (width: 400, height: 300)])

        let resize = try #require(
            try PhotosSource(collections: ["album"], library: library).writePicture(fitting: box, to: written))

        let size = try #require(pixelSize(of: written))
        #expect(size.width == 400)
        #expect(size.height == 300)
        #expect(resize.originalType == "photos")
        #expect(resize.originalWidth == 4032)
        #expect(resize.originalHeight == 3024)
        #expect(resize.writtenWidth == 400)
        #expect(resize.writtenHeight == 300)
        #expect(resize.writtenBytes == byteCount(of: written))
    }

    @Test("A collection with no pictures is passed over for one that has them")
    func passesOverAnEmptyCollection() throws {
        let scratch = try ScratchFolder()
        let library = FakeLibrary(collections: ["empty": nil, "album": (width: 40, height: 30), "gone": nil])
        let source = PhotosSource(collections: ["empty", "album", "gone"], library: library)

        for attempt in 0..<12 {
            let written = scratch.url.appending(path: "written-\(attempt).jpg")
            #expect(try source.writePicture(fitting: box, to: written) != nil)
        }
    }

    @Test("With no collections, or none with pictures, there is nothing to write")
    func nothingToWrite() throws {
        let scratch = try ScratchFolder()
        let written = scratch.url.appending(path: "written.jpg")
        let library = FakeLibrary(collections: ["empty": nil])

        #expect(try PhotosSource(collections: [], library: library).writePicture(fitting: box, to: written) == nil)
        #expect(try PhotosSource(collections: ["empty"], library: library).writePicture(fitting: box, to: written) == nil)
        #expect(pixelSize(of: written) == nil)
    }

    @Test("A library that refuses is an error, not an empty answer")
    func refusalIsReported() throws {
        let scratch = try ScratchFolder()
        let library = FakeLibrary(collections: ["album": (width: 40, height: 30)], refusing: true)

        #expect(throws: FakeLibrary.Refused.self) {
            try PhotosSource(collections: ["album"], library: library).writePicture(
                fitting: box, to: scratch.url.appending(path: "written.jpg"))
        }
    }
}
