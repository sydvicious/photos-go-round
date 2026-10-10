import CoreGraphics
import Foundation
import ImageIO
import PhotosGoRoundAgentAPI
import Testing
import TinyCache

@testable import PhotosGoRoundWidgetSettings

@Suite("The preview's pictures, from the chosen sources through a cache of the app's own")
struct CachedPreviewPicturesTests {
    func pixels(of file: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return CGSize(width: image.width, height: image.height)
    }

    @Test("A folder's picture comes back as a file, made to fit the box")
    func fromAFolder() throws {
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        try pictures.picture("coin.png", width: 800, height: 600)

        let file = try CachedPreviewPictures(directory: cache.url)
            .next(from: [.folder(pictures.url.path(percentEncoded: false))], fitting: CGSize(width: 200, height: 200))

        let made = try #require(file)
        #expect(pixels(of: made) == CGSize(width: 200, height: 150))
    }

    @Test("Asked again, it gives another file, and the one before has gone")
    func oneAtATime() throws {
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        try pictures.picture("coin.png")
        let preview = CachedPreviewPictures(directory: cache.url)
        let sources = [SourceSpec.folder(pictures.url.path(percentEncoded: false))]
        let box = CGSize(width: 200, height: 200)

        let first = try #require(try preview.next(from: sources, fitting: box))
        let second = try #require(try preview.next(from: sources, fitting: box))

        #expect(first != second)
        #expect(!FileManager.default.fileExists(atPath: first.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: second.path(percentEncoded: false)))
    }

    @Test("A folder with no pictures in it has none to give")
    func emptyFolder() throws {
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()

        let file = try CachedPreviewPictures(directory: cache.url)
            .next(from: [.folder(pictures.url.path(percentEncoded: false))], fitting: CGSize(width: 200, height: 200))

        #expect(file == nil)
    }

    @Test("A source counted for its row is remembered for the preview's picks, so it is counted once")
    func countedOnce() throws {
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        try pictures.picture("coin.png")
        try pictures.picture("moon.png")
        let preview = CachedPreviewPictures(directory: cache.url)

        let count = try preview.count(of: .folder(pictures.url.path(percentEncoded: false)))

        #expect(count == 2)
        let remembered = RememberedCounts(file: cache.url.appending(path: "counts.json")).read()
        #expect(remembered.values.map(\.pictures) == [2])
    }

    @Test("A source counted at none is not remembered, and what was remembered of it goes")
    func countedAtNone() throws {
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        let coin = try pictures.picture("coin.png")
        let preview = CachedPreviewPictures(directory: cache.url)
        let source = SourceSpec.folder(pictures.url.path(percentEncoded: false))
        #expect(try preview.count(of: source) == 1)

        try FileManager.default.removeItem(at: coin)

        #expect(try preview.count(of: source) == 0)
        #expect(RememberedCounts(file: cache.url.appending(path: "counts.json")).read().isEmpty)
    }

    @Test("A folder that was empty gives its first picture the next time it is asked")
    func emptyThenFilled() throws {
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        let preview = CachedPreviewPictures(directory: cache.url)
        let sources = [SourceSpec.folder(pictures.url.path(percentEncoded: false))]
        let box = CGSize(width: 200, height: 200)
        #expect(try preview.next(from: sources, fitting: box) == nil)

        try pictures.picture("coin.png")

        #expect(try preview.next(from: sources, fitting: box) != nil)
    }

    @Test("A kind of source the preview cannot read is passed over")
    func otherKinds() throws {
        let cache = try ScratchFolder()

        let file = try CachedPreviewPictures(directory: cache.url)
            .next(from: [SourceSpec(kind: .googleAlbum, locator: "G1")], fitting: CGSize(width: 200, height: 200))

        #expect(file == nil)
    }

    @Test("The picture it gave last can be had again at once, for the same sources and size")
    func last() throws {
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        try pictures.picture("coin.png", width: 800, height: 600)
        let preview = CachedPreviewPictures(directory: cache.url)
        let sources = [SourceSpec.folder(pictures.url.path(percentEncoded: false))]
        let box = CGSize(width: 200, height: 200)
        #expect(preview.last(for: sources, fitting: box) == nil)

        let file = try #require(try preview.next(from: sources, fitting: box))

        #expect(preview.last(for: sources, fitting: box)?.lastPathComponent == file.lastPathComponent)
        #expect(preview.last(for: sources, fitting: CGSize(width: 100, height: 100)) == nil)
    }

    @Test("The first picture is from the first source that has one, and nothing is counted to get it")
    func first() throws {
        let empty = try ScratchFolder()
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        try pictures.picture("coin.png", width: 800, height: 600)
        let preview = CachedPreviewPictures(directory: cache.url)

        let file = try preview.first(
            from: [
                .folder(empty.url.path(percentEncoded: false)),
                .folder(pictures.url.path(percentEncoded: false)),
            ], fitting: CGSize(width: 200, height: 200))

        let made = try #require(file)
        #expect(pixels(of: made) == CGSize(width: 200, height: 150))
        #expect(
            !FileManager.default.fileExists(
                atPath: cache.url.appending(path: "counts.json").path(percentEncoded: false)))
    }

    @Test("With no source that has a picture there is no first picture")
    func noFirst() throws {
        let empty = try ScratchFolder()
        let cache = try ScratchFolder()

        let file = try CachedPreviewPictures(directory: cache.url)
            .first(from: [.folder(empty.url.path(percentEncoded: false))], fitting: CGSize(width: 200, height: 200))

        #expect(file == nil)
    }
}
