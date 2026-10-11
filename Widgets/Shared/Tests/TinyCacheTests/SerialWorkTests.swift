import Foundation
import Synchronization
import Testing

@testable import TinyCache

@Suite("Work done one piece at a time")
struct SerialWorkTests {
    /// How many pieces of work are under way, and the most there have been.
    private final class Underway: Sendable {
        private let counts = Mutex((now: 0, most: 0))

        var most: Int { counts.withLock { $0.most } }

        func enter() {
            counts.withLock {
                $0.now += 1
                $0.most = max($0.most, $0.now)
            }
        }

        func leave() { counts.withLock { $0.now -= 1 } }
    }

    @Test("It gives back what the work gave")
    func answers() async throws {
        #expect(try await SerialWork(label: "test.answers").run { 7 } == 7)
    }

    @Test("It throws what the work threw")
    func throwsItsOwn() async {
        await #expect(throws: CocoaError.self) {
            try await SerialWork(label: "test.throws").run { () throws -> Int in
                throw CocoaError(.fileNoSuchFile)
            }
        }
    }

    @Test("Asked from many places at once, it does one piece at a time")
    func oneAtATime() async throws {
        let work = SerialWork(label: "test.one")
        let underway = Underway()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await work.run {
                        underway.enter()
                        Thread.sleep(forTimeInterval: 0.002)
                        underway.leave()
                    }
                }
            }
            try await group.waitForAll()
        }

        #expect(underway.most == 1)
    }

    @Test("Work it is not waited for is done in the order it was handed over, and before what is asked after")
    func inOrder() async throws {
        let work = SerialWork(label: "test.order")
        let done = Mutex<[Int]>([])

        for number in 1...5 {
            work.detached { done.withLock { $0.append(number) } }
        }
        let seen = try await work.run { done.withLock { $0 } }

        #expect(seen == [1, 2, 3, 4, 5])
    }
}
