import CoreGraphics
import Foundation
import Testing

@testable import TinyCache

@Suite("TinyCache")
struct TinyCacheTests {
    /// 2026-10-08 12:00:00 UTC, so the times in these tests are fixed.
    let noon = Date(timeIntervalSince1970: 1_791_460_800)
    let box = CGSize(width: 40, height: 40)

    /// A cache in a folder of its own, fed by a stub with `count` pictures.
    func cache(
        in scratch: ScratchFolder, pictures count: Int = 5, fillLimit: Int = 20
    ) throws -> (cache: TinyCache, source: StubSource) {
        let originals = try (1...max(count, 1)).map { try scratch.picture("originals/coin-\($0).jpg") }
        let source = StubSource(count == 0 ? [] : originals)
        let cache = TinyCache(
            directory: scratch.url.appending(path: "cache", directoryHint: .isDirectory),
            source: source, fitting: box, fillLimit: fillLimit)
        return (cache, source)
    }

    func exists(_ file: URL) -> Bool {
        FileManager.default.fileExists(atPath: file.path(percentEncoded: false))
    }

    @Test("The picture shown last can be had again, without asking the source")
    func lastShown() throws {
        let scratch = try ScratchFolder()
        let (cache, source) = try cache(in: scratch)
        let shown = try cache.take(upTo: 1, from: noon, every: 60)

        let last = try cache.lastShown()

        #expect(last?.lastPathComponent == shown.first?.file.lastPathComponent)
        #expect(last != nil)
        #expect(source.timesAsked == 1)
    }

    @Test("A cache that has shown nothing has no last picture, and fetches none to have one")
    func noLastShown() throws {
        let scratch = try ScratchFolder()
        let (cache, source) = try cache(in: scratch)

        #expect(try cache.lastShown() == nil)
        #expect(source.timesAsked == 0)
    }

    @Test("With nothing cached, the first picture comes straight from the source")
    func worksWithNoCache() throws {
        let scratch = try ScratchFolder()
        let (cache, source) = try cache(in: scratch)

        let showings = try cache.take(upTo: 20, from: noon, every: 60)

        #expect(showings.count == 1)
        #expect(showings.first?.date == noon)
        #expect(source.timesAsked == 1)
        #expect(showings.allSatisfy { exists($0.file) })
    }

    @Test("Keeping one more leaves exactly one picture waiting")
    func keepsOneMore() throws {
        let scratch = try ScratchFolder()
        let (cache, _) = try cache(in: scratch)

        let added = try cache.fill(to: 1)

        #expect(added == 1)
        #expect(try cache.waiting().count == 1)
    }

    @Test("Filling a cache that already holds enough fetches nothing")
    func fillIsIdempotent() throws {
        let scratch = try ScratchFolder()
        let (cache, source) = try cache(in: scratch)
        try cache.fill(to: 2)

        let added = try cache.fill(to: 2)

        #expect(added == 0)
        #expect(source.timesAsked == 2)
    }

    @Test("Filling stops at the limit, however many are asked for")
    func fillStopsAtTheLimit() throws {
        let scratch = try ScratchFolder()
        let (cache, _) = try cache(in: scratch, fillLimit: 3)

        try cache.fill(to: 10)

        #expect(try cache.waiting().count == 3)
    }

    @Test("Waiting pictures are shown in the order they arrived, one interval apart")
    func showsInOrder() throws {
        let scratch = try ScratchFolder()
        let (cache, source) = try cache(in: scratch)
        try cache.fill(to: 3)
        let arrived = try cache.waiting().map(\.lastPathComponent)

        let showings = try cache.take(upTo: 20, from: noon, every: 60)

        #expect(showings.map(\.file.lastPathComponent) == arrived)
        #expect(showings.map(\.date) == [noon, noon + 60, noon + 120])
        #expect(try cache.waiting().isEmpty)
        #expect(source.timesAsked == 3)
    }

    @Test("No more are taken than were asked for, and the rest go on waiting")
    func takesNoMoreThanAsked() throws {
        let scratch = try ScratchFolder()
        let (cache, _) = try cache(in: scratch)
        try cache.fill(to: 3)

        let showings = try cache.take(upTo: 2, from: noon, every: 60)

        #expect(showings.count == 2)
        #expect(try cache.waiting().count == 1)
    }

    @Test("A picture whose time has come is not shown again, and its file is removed")
    func shownPicturesAreDiscarded() throws {
        let scratch = try ScratchFolder()
        let (cache, _) = try cache(in: scratch)
        let first = try cache.take(upTo: 20, from: noon, every: 60)

        let second = try cache.take(upTo: 20, from: noon + 60, every: 60)

        #expect(second.count == 1)
        #expect(Set(first.map(\.file)).isDisjoint(with: second.map(\.file)))
        #expect(first.allSatisfy { !exists($0.file) })
    }

    @Test("Pictures handed out but not yet due are shown by the next timeline instead of wasted")
    func undueShowingsAreReused() throws {
        let scratch = try ScratchFolder()
        let (cache, source) = try cache(in: scratch)
        try cache.fill(to: 3)
        let first = try cache.take(upTo: 20, from: noon, every: 60)

        // The system asks again 30 seconds in: one picture has had its turn and
        // two have not.
        let second = try cache.take(upTo: 20, from: noon + 30, every: 60)

        #expect(second.count == 2)
        #expect(second.map(\.date) == [noon + 30, noon + 90])
        #expect(source.timesAsked == 3)
        let hadItsTurn = try #require(first.first)
        #expect(!exists(hadItsTurn.file))
        #expect(second.allSatisfy { exists($0.file) })
    }

    @Test("With the source failing, what is already cached is still shown")
    func cachedPicturesSurviveAFailingSource() throws {
        let scratch = try ScratchFolder()
        let (cache, source) = try cache(in: scratch)
        try cache.fill(to: 2)
        source.fail()

        let showings = try cache.take(upTo: 20, from: noon, every: 60)

        #expect(showings.count == 2)
    }

    @Test("With the source failing and nothing cached, the failure is reported")
    func failureIsReported() throws {
        let scratch = try ScratchFolder()
        let (cache, source) = try cache(in: scratch)
        source.fail()

        #expect(throws: StubSource.Failed.self) {
            try cache.take(upTo: 20, from: noon, every: 60)
        }
    }

    @Test("With a source that has no pictures and nothing cached, there is nothing to show")
    func emptySource() throws {
        let scratch = try ScratchFolder()
        let (cache, _) = try cache(in: scratch, pictures: 0)

        #expect(try cache.take(upTo: 20, from: noon, every: 60).isEmpty)
        #expect(try cache.fill(to: 5) == 0)
    }

    @Test("A cached picture is at the widget's size, not the original's")
    func cachedAtWidgetSize() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("originals/big.jpg", width: 800, height: 400)
        let cache = TinyCache(
            directory: scratch.url.appending(path: "cache", directoryHint: .isDirectory),
            source: StubSource([original]), fitting: box)

        try cache.fill(to: 1)

        let cached = try #require(try cache.waiting().first)
        let size = try #require(pixelSize(of: cached))
        #expect(size.width == 40)
        #expect(size.height == 20)
    }

    @Test("Each picture fetched is reported, with the size it was written at")
    func fetchesAreReported() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("originals/big.jpg", width: 800, height: 400)
        let reports = Collected<PictureResizer.Resize>()
        let cache = TinyCache(
            directory: scratch.url.appending(path: "cache", directoryHint: .isDirectory),
            source: StubSource([original]), fitting: box, onFetch: reports.add)

        try cache.fill(to: 2)

        #expect(reports.values.count == 2)
        #expect(reports.values.allSatisfy { $0.originalWidth == 800 && $0.writtenWidth == 40 })
    }

    @Test("A preview shows a picture without using it up")
    func previewDoesNotConsume() throws {
        let scratch = try ScratchFolder()
        let (cache, _) = try cache(in: scratch)

        let preview = try #require(try cache.preview())

        #expect(exists(preview))
        #expect(try cache.waiting() == [preview])
    }
}
