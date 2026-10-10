import CoreGraphics
import Foundation
import ImageIO
import PhotosGoRoundAgentAPI
import Testing

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

    @Test("Forgetting throws away what was counted, so every source is counted afresh")
    func forgetting() throws {
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        try pictures.picture("coin.png")
        let preview = CachedPreviewPictures(directory: cache.url)
        let counts = cache.url.appending(path: "counts.json")
        _ = try preview.next(
            from: [.folder(pictures.url.path(percentEncoded: false))], fitting: CGSize(width: 200, height: 200))
        #expect(FileManager.default.fileExists(atPath: counts.path(percentEncoded: false)))

        preview.forget()

        #expect(!FileManager.default.fileExists(atPath: counts.path(percentEncoded: false)))
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
}
