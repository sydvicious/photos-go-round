// Work done one piece at a time, on a thread that may block.
// `Plans/PGR Widgets - iOS.md`, *One fetch at a time*.
//
// **A TinyCache is not safe to call from two places at once**, and a widget's
// timeline can be asked for while the last wake is still fetching. Two
// requests to Photos at the same moment are also what never came back on
// 2026-10-10. So a widget's wakes do their work through one of these.
//
// **A queue, not a lock.** Syd, 2026-09-17: "I flatout don't want NSLocks".
// The widget's timeline held one until 2026-10-11. A serial queue does each
// piece in the order it was handed over, and whoever asked waits without
// holding a thread of Swift's own: `BlockingWork` has why that matters.

import Foundation

public struct SerialWork: Sendable {
    private let queue: DispatchQueue

    /// - Parameter label: The queue's name, as a debugger shows it.
    public init(label: String) {
        queue = DispatchQueue(label: label, qos: .utility)
    }

    /// Does `work` when everything handed over before it is done, and gives
    /// its answer or what it threw.
    public func run<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try work() })
            }
        }
    }

    /// Does `work` in its turn, without anyone waiting for it.
    public func detached(_ work: @escaping @Sendable () -> Void) {
        queue.async(execute: work)
    }
}
