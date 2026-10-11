import CoreGraphics
import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundWidgetFace
import Testing

@testable import PhotosGoRoundWidgetSettings
@testable import TinyCache

@Suite("What a widget shows each time the system wakes it")
struct WidgetPicturesTests {
    let box = CGSize(width: 200, height: 200)

    func folder(_ scratch: ScratchFolder) -> SourceSpec {
        .folder(scratch.url.path(percentEncoded: false))
    }

    func counts(in cache: ScratchFolder) -> Bool {
        FileManager.default.fileExists(
            atPath: cache.url.appending(path: "counts.json").path(percentEncoded: false))
    }

    func isPicture(_ face: WidgetFace.Content) -> Bool {
        if case .picture = face { return true }
        return false
    }

    /// The picture's file by name: the same file can be spelled two ways as a
    /// path, through `/var` and through `/private/var`.
    func file(_ face: WidgetFace.Content) -> String? {
        if case .picture(let file) = face { return file.lastPathComponent }
        return nil
    }

    @Test("With nothing chosen it shows the plain icon")
    func nothingChosen() throws {
        let cache = try ScratchFolder()

        #expect(WidgetPictures(directory: cache.url).turn(from: [], fitting: box) == .nothingChosen)
    }

    @Test("Its first picture is the first source's own, and nothing is counted to get it")
    func firstTurn() throws {
        let empty = try ScratchFolder()
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        try pictures.picture("coin.png", width: 800, height: 600)

        let face = WidgetPictures(directory: cache.url).turn(from: [folder(empty), folder(pictures)], fitting: box)

        #expect(isPicture(face))
        #expect(!counts(in: cache))
    }

    @Test("After the first, each picture is picked by how many each source holds")
    func laterTurns() throws {
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        try pictures.picture("coin.png", width: 800, height: 600)
        let widget = WidgetPictures(directory: cache.url)
        let first = widget.turn(from: [folder(pictures)], fitting: box)

        let second = widget.turn(from: [folder(pictures)], fitting: box)

        #expect(isPicture(second))
        #expect(file(second) != file(first))
        #expect(counts(in: cache))
    }

    @Test("With sources chosen and no picture in any of them it says No Photos found")
    func noPhotos() throws {
        let empty = try ScratchFolder()
        let cache = try ScratchFolder()

        #expect(WidgetPictures(directory: cache.url).turn(from: [folder(empty)], fitting: box) == .noPhotos)
    }

    @Test("A library that refuses is No Photos Access, and any other failure is No Photos found")
    func failures() {
        #expect(WidgetPictures.face(for: SystemPhotoLibraryPictures.Refused(status: "denied")) == .noAccess)
        #expect(WidgetPictures.face(for: CocoaError(.fileReadUnknown)) == .noPhotos)
    }

    @Test("What it showed last can be had at once, for the gallery, without asking any source")
    func last() throws {
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        try pictures.picture("coin.png", width: 800, height: 600)
        let widget = WidgetPictures(directory: cache.url)
        #expect(widget.last(from: [folder(pictures)], fitting: box) == .scanning)
        #expect(widget.last(from: [], fitting: box) == .nothingChosen)

        let shown = widget.turn(from: [folder(pictures)], fitting: box)

        #expect(file(shown) != nil)
        #expect(file(widget.last(from: [folder(pictures)], fitting: box)) == file(shown))
    }

    @Test("A picture made ready ahead of time is the next one shown, with nothing fetched then")
    func madeReady() throws {
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        let coin = try pictures.picture("coin.png", width: 800, height: 600)
        let widget = WidgetPictures(directory: cache.url)
        _ = widget.turn(from: [folder(pictures)], fitting: box)

        widget.makeReady(from: [folder(pictures)], fitting: box)
        try FileManager.default.removeItem(at: coin)

        #expect(isPicture(widget.turn(from: [folder(pictures)], fitting: box)))
    }
}
