import CoreGraphics
import Foundation
import Testing

@testable import TinyCache

@Suite("A Photos collection as a source of pictures")
struct PhotosSourceTests {
    let box = CGSize(width: 400, height: 400)

    @Test("A picture the library hands back is written as it came, and reported")
    func writesWhatTheLibraryGave() throws {
        let scratch = try ScratchFolder()
        let written = scratch.url.appending(path: "written.jpg")
        let library = FakeLibrary(collections: ["album": (width: 400, height: 300)])

        let resize = try #require(
            try PhotosSource(collection: "album", library: library).writePicture(fitting: box, to: written))

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

    @Test("Asked for its first picture, it writes the collection's first and not one picked at random")
    func firstPicture() throws {
        let scratch = try ScratchFolder()
        let written = scratch.url.appending(path: "written.jpg")
        var library = FakeLibrary(collections: ["album": (width: 400, height: 300)])
        library.first = (width: 200, height: 100)

        _ = try #require(
            try PhotosSource(collection: "album", library: library, pick: .first)
                .writePicture(fitting: box, to: written))

        let size = try #require(pixelSize(of: written))
        #expect(size.width == 200)
        #expect(size.height == 100)
    }

    @Test("A collection with no pictures, or one that is gone, has nothing to write")
    func nothingToWrite() throws {
        let scratch = try ScratchFolder()
        let written = scratch.url.appending(path: "written.jpg")
        let library = FakeLibrary(collections: ["empty": nil])

        #expect(try PhotosSource(collection: "empty", library: library).writePicture(fitting: box, to: written) == nil)
        #expect(try PhotosSource(collection: "gone", library: library).writePicture(fitting: box, to: written) == nil)
        #expect(pixelSize(of: written) == nil)
    }

    @Test("A library that refuses is an error, not an empty answer")
    func refusalIsReported() throws {
        let scratch = try ScratchFolder()
        let library = FakeLibrary(collections: ["album": (width: 40, height: 30)], refusing: true)

        #expect(throws: FakeLibrary.Refused.self) {
            try PhotosSource(collection: "album", library: library).writePicture(
                fitting: box, to: scratch.url.appending(path: "written.jpg"))
        }
    }

    @Test("It holds as many pictures as the library says its collection does")
    func countsItsPictures() throws {
        let library = FakeLibrary(
            collections: ["album": (width: 40, height: 30), "empty": nil], counts: ["album": 250])

        #expect(try PhotosSource(collection: "album", library: library).pictureCount() == 250)
        #expect(try PhotosSource(collection: "empty", library: library).pictureCount() == 0)
        #expect(try PhotosSource(collection: "gone", library: library).pictureCount() == 0)
    }

    @Test("Writing a picture does not say how many it holds: that is the library's to answer")
    func writingDoesNotCount() throws {
        let scratch = try ScratchFolder()
        let library = FakeLibrary(collections: ["album": (width: 40, height: 30)], counts: ["album": 250])

        let picked = try PhotosSource(collection: "album", library: library)
            .writePictureAndCount(fitting: box, to: scratch.url.appending(path: "written.jpg"))

        #expect(picked.resize != nil)
        #expect(picked.pictures == nil)
    }

    @Test("A library that refuses cannot be counted, which is not a count of none")
    func refusalIsNotCounted() throws {
        let library = FakeLibrary(collections: ["album": (width: 40, height: 30)], refusing: true)

        #expect(throws: FakeLibrary.Refused.self) {
            try PhotosSource(collection: "album", library: library).pictureCount()
        }
    }

    @Test("Its count is remembered under its collection")
    func countName() throws {
        let library = FakeLibrary()

        #expect(
            PhotosSource(collection: "album", library: library).countName
                == PhotosSource(collection: "album", library: library).countName)
        #expect(
            PhotosSource(collection: "album", library: library).countName
                != PhotosSource(collection: "other", library: library).countName)
    }
}
