import Foundation
import Testing

@testable import TinyCache

@Suite("How many pictures each source held, remembered on disk")
struct RememberedCountsTests {
    let counted = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("With no file there is nothing remembered")
    func noFile() throws {
        let scratch = try ScratchFolder()

        #expect(RememberedCounts(file: scratch.url.appending(path: "counts.json")).read().isEmpty)
    }

    @Test("What was written is read back, by whoever opens the file next")
    func roundTrip() throws {
        let scratch = try ScratchFolder()
        let file = scratch.url.appending(path: "counts.json")
        let counts = [
            "folder|/coins|true": RememberedCounts.Count(pictures: 1200, counted: counted),
            "photos|album": RememberedCounts.Count(pictures: 0, counted: counted + 90),
        ]

        try RememberedCounts(file: file).write(counts)

        #expect(RememberedCounts(file: file).read() == counts)
    }

    @Test("Writing makes the folders on the way to the file")
    func makesItsFolder() throws {
        let scratch = try ScratchFolder()
        let file = scratch.url.appending(path: "TinyCache/counts.json")
        let counts = ["photos|album": RememberedCounts.Count(pictures: 7, counted: counted)]

        try RememberedCounts(file: file).write(counts)

        #expect(RememberedCounts(file: file).read() == counts)
    }

    @Test("A file that cannot be made sense of is nothing remembered, not an error")
    func unreadableFile() throws {
        let scratch = try ScratchFolder()
        let file = try scratch.text("counts.json")

        #expect(RememberedCounts(file: file).read().isEmpty)
    }
}
