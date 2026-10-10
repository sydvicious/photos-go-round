// How many pictures each source held when it was last counted, on disk.
// `Plans/Photos-Go-Round Widgets.md`, *Seen with 0.7 (5) installed*.
//
// **Remembered, because counting a folder is a walk of it.** Syd, 2026-10-09,
// chose this over counting every source on every pick: a source is chosen from
// the counts kept here, and only the one chosen is walked for its picture,
// which counts it again.
//
// **One file for every widget.** A count belongs to a source, not to the
// widget showing it, so widgets of every size read and write the same one.
//
// **Losing it costs a count.** A file that is missing, or cannot be made sense
// of, is nothing remembered, and each source is counted again.

import Foundation

public struct RememberedCounts: Sendable {
    public struct Count: Codable, Equatable, Sendable {
        public var pictures: Int
        public var counted: Date

        public init(pictures: Int, counted: Date) {
            self.pictures = pictures
            self.counted = counted
        }
    }

    public let file: URL

    public init(file: URL) {
        self.file = file
    }

    /// Each source's count, under its `countName`.
    public func read() -> [String: Count] {
        guard let data = try? Data(contentsOf: file) else { return [:] }
        return (try? JSONDecoder().decode([String: Count].self, from: data)) ?? [:]
    }

    public func write(_ counts: [String: Count]) throws {
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(counts).write(to: file, options: .atomic)
    }
}
