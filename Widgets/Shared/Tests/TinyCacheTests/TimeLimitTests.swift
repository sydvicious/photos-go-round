import Foundation
import Testing

@testable import TinyCache

@Suite("A time limit on work that may never answer")
struct TimeLimitTests {
    @Test("Work that answers in time gives its answer")
    func answers() throws {
        #expect(try TimeLimit.run(within: .seconds(30)) { 7 } == 7)
    }

    @Test("Work that throws in time throws what it threw")
    func throwsItsOwn() {
        #expect(throws: CocoaError.self) {
            try TimeLimit.run(within: .seconds(30)) { () throws -> Int in throw CocoaError(.fileNoSuchFile) }
        }
    }

    @Test("Work that does not answer in time is given up on, and the caller goes on")
    func timesOut() {
        let started = ContinuousClock.now

        #expect(throws: TimedOut(after: .milliseconds(50))) {
            try TimeLimit.run(within: .milliseconds(50)) { () -> Int in
                Thread.sleep(forTimeInterval: 10)
                return 7
            }
        }

        #expect(ContinuousClock.now - started < .seconds(5))
    }
}
