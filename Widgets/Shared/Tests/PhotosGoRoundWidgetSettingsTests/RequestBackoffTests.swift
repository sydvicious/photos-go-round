import Foundation
import Testing

@testable import PhotosGoRoundWidgetSettings

@Suite("How long to wait before asking Photos again, when it did not answer")
struct RequestBackoffTests {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("The wait starts at five seconds and doubles each time")
    func doubles() {
        #expect(RequestBackoff.delay(afterFailures: 1) == 5)
        #expect(RequestBackoff.delay(afterFailures: 2) == 10)
        #expect(RequestBackoff.delay(afterFailures: 3) == 20)
        #expect(RequestBackoff.delay(afterFailures: 9) == 1280)
    }

    @Test("It is never longer than thirty minutes")
    func longest() {
        #expect(RequestBackoff.delay(afterFailures: 10) == 30 * 60)
        #expect(RequestBackoff.delay(afterFailures: 11) == 30 * 60)
        #expect(RequestBackoff.delay(afterFailures: 100_000) == 30 * 60)
    }

    @Test("The app's preview waits a minute at most")
    func previewsLongest() {
        var backoff = RequestBackoff(longest: 60)
        var now = start
        var waits: [TimeInterval] = []

        for _ in 0..<6 {
            backoff.timedOut(at: now)
            waits.append(backoff.wait(at: now) ?? 0)
            now += waits.last ?? 0
        }

        #expect(waits == [5, 10, 20, 40, 60, 60])
    }

    @Test("With nothing gone wrong there is no wait")
    func fresh() {
        #expect(RequestBackoff().wait(at: start) == nil)
        #expect(RequestBackoff.delay(afterFailures: 0) == 0)
    }

    @Test("After a time-out the wait runs from that moment, and then is over")
    func waits() {
        var backoff = RequestBackoff()

        backoff.timedOut(at: start)

        #expect(backoff.wait(at: start) == 5)
        #expect(backoff.wait(at: start + 3) == 2)
        #expect(backoff.wait(at: start + 5) == nil)
    }

    @Test("A second time-out in a row waits twice as long")
    func secondInARow() {
        var backoff = RequestBackoff()

        backoff.timedOut(at: start)
        backoff.timedOut(at: start + 5)

        #expect(backoff.wait(at: start + 5) == 10)
    }

    @Test("It never gives up: past thirty minutes it goes on asking every thirty")
    func neverGivesUp() {
        var backoff = RequestBackoff()
        var now = start

        for _ in 0..<40 {
            backoff.timedOut(at: now)
            now += backoff.wait(at: now) ?? 0
        }

        backoff.timedOut(at: now)
        #expect(backoff.wait(at: now) == 1800)
    }

    @Test("An answer ends it, and the next time-out waits five seconds again")
    func answered() {
        var backoff = RequestBackoff()
        backoff.timedOut(at: start)
        backoff.timedOut(at: start + 5)

        backoff.answered()

        #expect(backoff.wait(at: start + 6) == nil)
        backoff.timedOut(at: start + 20)
        #expect(backoff.wait(at: start + 20) == 5)
    }

    @Test("It is kept in a file from one wake of a widget to the next")
    func kept() throws {
        let scratch = try ScratchFolder()
        let file = scratch.url.appending(path: "asking.json")
        var backoff = RequestBackoff()
        backoff.timedOut(at: start)
        backoff.timedOut(at: start + 5)

        backoff.write(to: file)

        #expect(RequestBackoff.read(from: file) == backoff)
    }

    @Test("With no file there is no wait, and an answer takes the file away")
    func noFile() throws {
        let scratch = try ScratchFolder()
        let file = scratch.url.appending(path: "asking.json")
        #expect(RequestBackoff.read(from: file) == RequestBackoff())

        var backoff = RequestBackoff()
        backoff.timedOut(at: start)
        backoff.write(to: file)
        backoff.answered()
        backoff.write(to: file)

        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
    }
}
