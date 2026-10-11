// A time limit on work that may never answer. `Plans/PGR Widgets - iOS.md`,
// *When Photos does not answer*.
//
// **A request to Photos for a picture can go unanswered for good.** Seen
// 2026-10-10: two at once, each waiting inside PhotoKit on the Photos daemon,
// and neither came back. Nothing in PhotoKit's synchronous request gives up
// by itself, so whoever asked waited for ever.
//
// **The work is given up on, not stopped.** It runs on a thread of its own
// that is allowed to block, and the caller waits for it only so long. Work
// that answers late answers nobody. `BlockingWork` has why a blocked thread
// there costs only itself.

import Foundation
import PhotosGoRoundAgentAPI

/// The work did not answer within its limit.
public struct TimedOut: Error, Equatable, LocalizedError, Sendable {
    public let limit: Duration

    public init(after limit: Duration) {
        self.limit = limit
    }

    public var errorDescription: String? {
        "Photos did not answer in \(limit.formatted(.units(allowed: [.minutes, .seconds], width: .wide)))."
    }
}

public enum TimeLimit {
    /// How long Photos has to hand over one picture. Claude's figure,
    /// 2026-10-11: a picture on the device comes back in well under a second,
    /// and one fetched from iCloud has not been timed.
    public static let forAPicture: Duration = .seconds(15)

    /// Runs `work` on a thread that may block, and gives its answer or what it
    /// threw. Throws `TimedOut` when `limit` passes first.
    public static func run<T: Sendable>(
        within limit: Duration, _ work: @escaping @Sendable () throws -> T
    ) throws -> T {
        let answer = Answer<T>()
        let answered = DispatchSemaphore(value: 0)
        BlockingWork.detached {
            answer.result = Result { try work() }
            answered.signal()
        }
        let (seconds, attoseconds) = limit.components
        let wait = DispatchTimeInterval.nanoseconds(
            Int(seconds) * 1_000_000_000 + Int(attoseconds / 1_000_000_000))
        guard answered.wait(timeout: .now() + wait) == .success, let result = answer.result else {
            throw TimedOut(after: limit)
        }
        return try result.get()
    }

    /// Written once, before the signal, and read only after it.
    private final class Answer<T>: @unchecked Sendable {
        var result: Result<T, any Error>?
    }
}
