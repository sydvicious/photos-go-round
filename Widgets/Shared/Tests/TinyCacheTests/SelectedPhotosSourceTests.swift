import CoreGraphics
import Foundation
import Testing

@testable import TinyCache

@Suite("The photographs a person picked for the app, as a source of pictures")
struct SelectedPhotosSourceTests {
    let box = CGSize(width: 400, height: 400)

    @Test("It holds as many pictures as the person picked")
    func counts() throws {
        var library = FakeLibrary()
        library.selected = (width: 400, height: 300)
        library.selectedHolds = 12

        #expect(try SelectedPhotosSource(library: library).pictureCount() == 12)
    }

    @Test("A picked photograph is written as the library gave it")
    func writes() throws {
        let scratch = try ScratchFolder()
        let written = scratch.url.appending(path: "written.jpg")
        var library = FakeLibrary()
        library.selected = (width: 400, height: 300)

        let resize = try #require(try SelectedPhotosSource(library: library).writePicture(fitting: box, to: written))

        let size = try #require(pixelSize(of: written))
        #expect(size.width == 400)
        #expect(size.height == 300)
        #expect(resize.originalType == "photos")
    }

    @Test("Asked for its first picture, it writes the first of the picked photographs")
    func firstPicture() throws {
        let scratch = try ScratchFolder()
        let written = scratch.url.appending(path: "written.jpg")
        var library = FakeLibrary()
        library.selected = (width: 400, height: 300)
        library.first = (width: 200, height: 100)

        _ = try #require(
            try SelectedPhotosSource(library: library, pick: .first).writePicture(fitting: box, to: written))

        let size = try #require(pixelSize(of: written))
        #expect(size.width == 200)
        #expect(size.height == 100)
    }

    @Test("With nothing picked, or with access that is not limited to a selection, there is nothing")
    func nothing() throws {
        let scratch = try ScratchFolder()
        let written = scratch.url.appending(path: "written.jpg")
        let source = SelectedPhotosSource(library: FakeLibrary())

        #expect(try source.pictureCount() == 0)
        #expect(try source.writePicture(fitting: box, to: written) == nil)
    }

    @Test("A library that refuses is an error, not an empty answer")
    func refusal() throws {
        var library = FakeLibrary()
        library.selected = (width: 40, height: 30)
        library.refusing = true

        #expect(throws: FakeLibrary.Refused.self) { try SelectedPhotosSource(library: library).pictureCount() }
    }

    @Test("Its count is remembered under a name no collection has")
    func name() {
        #expect(SelectedPhotosSource(library: FakeLibrary()).countName == "photos-selected")
    }
}
