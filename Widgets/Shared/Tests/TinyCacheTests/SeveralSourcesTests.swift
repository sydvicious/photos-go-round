import CoreGraphics
import Foundation
import Testing

@testable import TinyCache

@Suite("Several sources as one")
struct SeveralSourcesTests {
    let box = CGSize(width: 40, height: 40)

    static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// A stub with one picture to write, saying it holds `count` of them.
    func stub(
        in scratch: ScratchFolder, named name: String, counting count: Int? = nil, finding found: Int? = nil
    ) throws -> StubSource {
        StubSource([try scratch.picture("originals/\(name).jpg")], named: name, counting: count, finding: found)
    }

    func counts(in scratch: ScratchFolder) -> RememberedCounts {
        RememberedCounts(file: scratch.url.appending(path: "counts.json"))
    }

    /// The sources as one, with nothing left to chance: the clock stands at
    /// `moment`, and the draw is always the lowest, which falls in the first
    /// source that holds anything.
    func several(_ sources: [StubSource], in scratch: ScratchFolder, at moment: Date = start) -> SeveralSources {
        SeveralSources(sources, remembering: counts(in: scratch), now: { moment }, choosing: { $0.lowerBound })
    }

    func written(in scratch: ScratchFolder) -> URL {
        scratch.url.appending(path: "written-\(UUID().uuidString).jpg")
    }

    @Test("With no sources there is nothing to write")
    func noSources() throws {
        let scratch = try ScratchFolder()

        #expect(try several([], in: scratch).writePicture(fitting: box, to: written(in: scratch)) == nil)
    }

    // MARK: Which source

    @Test("A source is chosen in proportion to how many pictures it holds")
    func chosenInProportion() throws {
        // One picture and three: of the four draws there are, the first is the
        // small source's and the other three the large one's.
        for (draw, expected) in [(0, "one"), (1, "three"), (2, "three"), (3, "three")] {
            let scratch = try ScratchFolder()
            let one = try stub(in: scratch, named: "one", counting: 1)
            let three = try stub(in: scratch, named: "three", counting: 3)
            let drawnFrom = Collected<Range<Int>>()
            let sources = SeveralSources(
                [one, three], remembering: counts(in: scratch), now: { Self.start },
                choosing: {
                    drawnFrom.add($0)
                    return draw
                })

            #expect(try sources.writePicture(fitting: box, to: written(in: scratch)) != nil)

            #expect(drawnFrom.values == [0..<4])
            #expect(one.timesAsked == (expected == "one" ? 1 : 0), "draw \(draw)")
            #expect(three.timesAsked == (expected == "three" ? 1 : 0), "draw \(draw)")
        }
    }

    @Test("A source that holds no pictures is never asked for one")
    func holdsNone() throws {
        let scratch = try ScratchFolder()
        let empty = StubSource([], named: "empty")
        let full = try stub(in: scratch, named: "full")

        #expect(try several([empty, full], in: scratch).writePicture(fitting: box, to: written(in: scratch)) != nil)

        #expect(empty.timesAsked == 0)
        #expect(full.timesAsked == 1)
    }

    // MARK: Remembering

    @Test("A count is remembered, and not taken again within the hour")
    func remembersACount() throws {
        let scratch = try ScratchFolder()
        let source = try stub(in: scratch, named: "coins", counting: 40)

        _ = try several([source], in: scratch).writePicture(fitting: box, to: written(in: scratch))
        _ = try several([source], in: scratch, at: Self.start + 59 * 60)
            .writePicture(fitting: box, to: written(in: scratch))

        #expect(source.timesCounted == 1)
        #expect(source.timesAsked == 2)
        #expect(counts(in: scratch).read() == ["coins": .init(pictures: 40, counted: Self.start)])
    }

    @Test("A count an hour old is taken again")
    func countsAgainAfterAnHour() throws {
        let scratch = try ScratchFolder()
        let source = try stub(in: scratch, named: "coins", counting: 40)
        let later = Self.start + 60 * 60

        _ = try several([source], in: scratch).writePicture(fitting: box, to: written(in: scratch))
        _ = try several([source], in: scratch, at: later).writePicture(fitting: box, to: written(in: scratch))

        #expect(source.timesCounted == 2)
        #expect(counts(in: scratch).read() == ["coins": .init(pictures: 40, counted: later)])
    }

    @Test("A count from after now is taken again: the clock has been set back")
    func countsAgainWhenTheClockWentBack() throws {
        let scratch = try ScratchFolder()
        let source = try stub(in: scratch, named: "coins")
        let earlier = Self.start - 24 * 60 * 60

        _ = try several([source], in: scratch).writePicture(fitting: box, to: written(in: scratch))
        _ = try several([source], in: scratch, at: earlier).writePicture(fitting: box, to: written(in: scratch))

        #expect(source.timesCounted == 2)
    }

    @Test("A source that finds how many it holds while writing a picture has its count taken from that")
    func aPickRefreshesTheCount() throws {
        let scratch = try ScratchFolder()
        let source = try stub(in: scratch, named: "coins", counting: 40, finding: 55)

        _ = try several([source], in: scratch).writePicture(fitting: box, to: written(in: scratch))

        #expect(counts(in: scratch).read() == ["coins": .init(pictures: 55, counted: Self.start)])
    }

    @Test("So a source that goes on being picked is never asked for its count again")
    func aPickedSourceIsNotCountedAgain() throws {
        let scratch = try ScratchFolder()
        let source = try stub(in: scratch, named: "coins", counting: 40, finding: 40)
        let last = Self.start + 100 * 60

        for moment in [Self.start, Self.start + 50 * 60, last] {
            _ = try several([source], in: scratch, at: moment).writePicture(fitting: box, to: written(in: scratch))
        }

        #expect(source.timesCounted == 1)
        #expect(source.timesAsked == 3)
        #expect(counts(in: scratch).read() == ["coins": .init(pictures: 40, counted: last)])
    }

    @Test("A source that holds no pictures is remembered as holding none")
    func remembersNone() throws {
        let scratch = try ScratchFolder()
        let empty = StubSource([], named: "empty")

        #expect(try several([empty], in: scratch).writePicture(fitting: box, to: written(in: scratch)) == nil)
        #expect(try several([empty], in: scratch).writePicture(fitting: box, to: written(in: scratch)) == nil)

        #expect(empty.timesCounted == 1)
        #expect(counts(in: scratch).read() == ["empty": .init(pictures: 0, counted: Self.start)])
    }

    @Test("When nothing was counted, the counts on disk are left as they were")
    func writesOnlyWhatChanged() throws {
        let scratch = try ScratchFolder()
        let source = try stub(in: scratch, named: "coins")
        let file = counts(in: scratch).file
        _ = try several([source], in: scratch).writePicture(fitting: box, to: written(in: scratch))
        // The same counts in other bytes, which writing them again would undo.
        let spaced = try Data(contentsOf: file) + Data("\n\n".utf8)
        try spaced.write(to: file)

        _ = try several([source], in: scratch).writePicture(fitting: box, to: written(in: scratch))

        #expect(source.timesCounted == 1)
        #expect(try Data(contentsOf: file) == spaced)
    }

    @Test("Each counting is reported, with what it found")
    func reportsEachCounting() throws {
        let scratch = try ScratchFolder()
        let coins = try stub(in: scratch, named: "coins", counting: 40)
        let stamps = try stub(in: scratch, named: "stamps", counting: 7)
        let reports = Collected<SeveralSources.Counting>()
        let sources = SeveralSources(
            [coins, stamps], remembering: counts(in: scratch), now: { Self.start },
            choosing: { $0.lowerBound }, onCount: reports.add)

        _ = try sources.writePicture(fitting: box, to: written(in: scratch))
        _ = try sources.writePicture(fitting: box, to: written(in: scratch))

        #expect(reports.values.map(\.name) == ["coins", "stamps"])
        #expect(reports.values.map(\.pictures) == [40, 7])
        #expect(reports.values.allSatisfy { $0.seconds >= 0 })
    }

    // MARK: Trouble

    @Test("A source that fails is passed over for one that works, and counted again next time")
    func passesOverAFailingSource() throws {
        let scratch = try ScratchFolder()
        let broken = try stub(in: scratch, named: "unreachable")
        broken.failToWrite()
        let working = try stub(in: scratch, named: "working")

        #expect(try several([broken, working], in: scratch).writePicture(fitting: box, to: written(in: scratch)) != nil)

        #expect(broken.timesAsked == 1)
        #expect(working.timesAsked == 1)
        #expect(counts(in: scratch).read() == ["working": .init(pictures: 1, counted: Self.start)])

        #expect(try several([broken, working], in: scratch).writePicture(fitting: box, to: written(in: scratch)) != nil)

        #expect(broken.timesCounted == 2)
        #expect(working.timesCounted == 1)
    }

    @Test("A source that holds fewer than it said is passed over, and counted again next time")
    func passesOverASourceThatTurnsOutEmpty() throws {
        let scratch = try ScratchFolder()
        let emptied = StubSource([], named: "emptied", counting: 5)
        let working = try stub(in: scratch, named: "working")

        #expect(try several([emptied, working], in: scratch).writePicture(fitting: box, to: written(in: scratch)) != nil)

        #expect(emptied.timesAsked == 1)
        #expect(counts(in: scratch).read() == ["working": .init(pictures: 1, counted: Self.start)])
    }

    @Test("A source that finds it holds none while writing is passed over, and remembered as holding none")
    func passesOverASourceFoundEmpty() throws {
        let scratch = try ScratchFolder()
        let emptied = StubSource([], named: "emptied", counting: 5, finding: 0)
        let working = try stub(in: scratch, named: "working")

        #expect(try several([emptied, working], in: scratch).writePicture(fitting: box, to: written(in: scratch)) != nil)
        #expect(try several([emptied, working], in: scratch).writePicture(fitting: box, to: written(in: scratch)) != nil)

        #expect(emptied.timesAsked == 1)
        #expect(emptied.timesCounted == 1)
        #expect(
            counts(in: scratch).read() == [
                "emptied": .init(pictures: 0, counted: Self.start),
                "working": .init(pictures: 1, counted: Self.start),
            ])
    }

    @Test("A source that cannot be counted is passed over, and nothing is remembered of it")
    func passesOverASourceThatCannotBeCounted() throws {
        let scratch = try ScratchFolder()
        let broken = try stub(in: scratch, named: "unreachable")
        broken.fail()
        let working = try stub(in: scratch, named: "working")

        #expect(try several([broken, working], in: scratch).writePicture(fitting: box, to: written(in: scratch)) != nil)

        #expect(broken.timesAsked == 0)
        #expect(counts(in: scratch).read() == ["working": .init(pictures: 1, counted: Self.start)])
    }

    @Test("When every source fails, the failure is reported")
    func everySourceFails() throws {
        let scratch = try ScratchFolder()
        let first = try stub(in: scratch, named: "first")
        let second = try stub(in: scratch, named: "second")
        first.fail()
        second.failToWrite()

        #expect(throws: StubSource.Failed.self) {
            try several([first, second], in: scratch).writePicture(fitting: box, to: written(in: scratch))
        }
    }

    @Test("A failure is reported in preference to there being nothing, when those are the only answers")
    func failureBeatsEmpty() throws {
        let scratch = try ScratchFolder()
        let broken = try stub(in: scratch, named: "unreachable")
        broken.fail()

        #expect(throws: StubSource.Failed.self) {
            try several([StubSource([]), broken], in: scratch).writePicture(fitting: box, to: written(in: scratch))
        }
    }
}
