// How long to wait before asking Photos again, when it did not answer.
// `Plans/PGR Widgets - iOS.md`, *When Photos does not answer*.
//
// **Each time in a row, twice as long, and it never gives up.** Syd,
// 2026-10-11: "When it times out start a new request. Do exponential delays
// before asking again up to 30 minutes", and "don't stop. After exponential
// delays reaches thirty minutes keep trying every 30 minutes".
//
// **The app's preview waits a minute at most.** Syd, the same day: "Previews
// in the app wait for 1 minute max". Someone is looking at it.
//
// **A widget keeps it in a file**, since each wake may be a new process.

import Foundation

public struct RequestBackoff: Codable, Equatable, Sendable {
    /// The wait after the first time-out. Claude's figure.
    public static let first: TimeInterval = 5
    /// The longest a widget waits.
    public static let longestForAWidget: TimeInterval = 30 * 60
    /// The longest the app's preview waits.
    public static let longestForThePreview: TimeInterval = 60

    public private(set) var failures = 0
    public private(set) var notBefore: Date?
    private let longest: TimeInterval

    public init(longest: TimeInterval = RequestBackoff.longestForAWidget) {
        self.longest = longest
    }

    /// How long to wait after this many time-outs in a row.
    public static func delay(
        afterFailures failures: Int, longest: TimeInterval = RequestBackoff.longestForAWidget
    ) -> TimeInterval {
        guard failures > 0 else { return 0 }
        // Past thirty doublings it is longer than any wait there is, and the
        // doubling itself would run out of room.
        guard failures <= 30 else { return longest }
        return min(first * pow(2, Double(failures - 1)), longest)
    }

    /// Photos did not answer.
    public mutating func timedOut(at now: Date) {
        failures += 1
        notBefore = now + Self.delay(afterFailures: failures, longest: longest)
    }

    /// Photos answered, with a picture or with none.
    public mutating func answered() {
        failures = 0
        notBefore = nil
    }

    /// How much of the wait is left. Nil when Photos may be asked.
    public func wait(at now: Date) -> TimeInterval? {
        guard let notBefore, notBefore > now else { return nil }
        return notBefore.timeIntervalSince(now)
    }

    /// What `file` holds, or no wait at all when it is not there or cannot be
    /// read.
    public static func read(from file: URL, longest: TimeInterval = RequestBackoff.longestForAWidget) -> RequestBackoff {
        guard let data = try? Data(contentsOf: file),
            let kept = try? JSONDecoder().decode(RequestBackoff.self, from: data)
        else { return RequestBackoff(longest: longest) }
        return kept
    }

    /// Kept in `file` while there is a wait, and the file taken away when
    /// there is none. A wait that could not be written is not kept: the next
    /// wake asks, which is what it would have done before there were waits.
    public func write(to file: URL) {
        guard failures > 0 else {
            try? FileManager.default.removeItem(at: file)
            return
        }
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(self).write(to: file, options: .atomic)
    }
}
