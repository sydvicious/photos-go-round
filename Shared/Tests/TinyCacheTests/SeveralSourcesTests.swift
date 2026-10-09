import CoreGraphics
import Foundation
import Testing

@testable import TinyCache

@Suite("Several sources as one")
struct SeveralSourcesTests {
    let box = CGSize(width: 40, height: 40)

    /// A stub with one picture, and a place to write.
    func stub(in scratch: ScratchFolder, named name: String = "coin") throws -> StubSource {
        StubSource([try scratch.picture("originals/\(name).jpg")])
    }

    @Test("With no sources there is nothing to write")
    func noSources() throws {
        let scratch = try ScratchFolder()

        let resize = try SeveralSources([]).writePicture(
            fitting: box, to: scratch.url.appending(path: "written.jpg"))

        #expect(resize == nil)
    }

    @Test("A source with no pictures is passed over for one that has them")
    func passesOverAnEmptySource() throws {
        let scratch = try ScratchFolder()
        let sources = SeveralSources([StubSource([]), try stub(in: scratch), StubSource([])])

        for attempt in 0..<12 {
            let written = scratch.url.appending(path: "written-\(attempt).jpg")
            #expect(try sources.writePicture(fitting: box, to: written) != nil)
            #expect(pixelSize(of: written) != nil)
        }
    }

    @Test("A source that fails is passed over for one that works")
    func passesOverAFailingSource() throws {
        let scratch = try ScratchFolder()
        let broken = try stub(in: scratch, named: "unreachable")
        broken.fail()
        let sources = SeveralSources([broken, try stub(in: scratch)])

        for attempt in 0..<12 {
            let written = scratch.url.appending(path: "written-\(attempt).jpg")
            #expect(try sources.writePicture(fitting: box, to: written) != nil)
        }
    }

    @Test("When every source fails, the failure is reported")
    func everySourceFails() throws {
        let scratch = try ScratchFolder()
        let first = try stub(in: scratch, named: "first")
        let second = try stub(in: scratch, named: "second")
        first.fail()
        second.fail()

        #expect(throws: StubSource.Failed.self) {
            try SeveralSources([first, second]).writePicture(
                fitting: box, to: scratch.url.appending(path: "written.jpg"))
        }
    }

    @Test("A failure is reported in preference to there being nothing, when those are the only answers")
    func failureBeatsEmpty() throws {
        let scratch = try ScratchFolder()
        let broken = try stub(in: scratch)
        broken.fail()

        #expect(throws: StubSource.Failed.self) {
            try SeveralSources([StubSource([]), broken]).writePicture(
                fitting: box, to: scratch.url.appending(path: "written.jpg"))
        }
    }
}
