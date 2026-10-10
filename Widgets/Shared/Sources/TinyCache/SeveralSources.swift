// Every source the app has set, as one. `Plans/Photos-Go-Round Widgets.md`,
// *Seen with 0.7 (5) installed*.
//
// **Every picture is as likely as every other, whichever source it is in.**
// Syd, 2026-10-09: "I thought we already had pictures drawn alike from all
// sources. That's what I want." So a source is chosen in proportion to how
// many pictures it holds, and the picture inside it at random. An album of ten
// photographs is asked one time in two thousand beside a library of twenty
// thousand. The first builds gave each source an equal chance, and one
// photograph in an album of its own came up 18 times in 31.
//
// **The counts are remembered.** `RememberedCounts`. A source is counted when
// it has no count, or one an hour old, so a source that grows or shrinks is
// weighed by its old size for up to an hour.
//
// **A folder is counted by the walk that chooses from it.** Syd, 2026-10-09,
// asked for that rather than a walk of every folder each hour. A folder that
// goes on being chosen is walked once a pick, as it always was, and never just
// to be counted; one that is not chosen for an hour is.
//
// **A photograph in two sources counts twice.**
//
// **Not safe to call from two places at once**, as TinyCache is not: the
// counts are read, changed and written back. The caller serializes.

import CoreGraphics
import Foundation

public struct SeveralSources: PictureSource {
    /// One source counted: what it held, and how long the counting took.
    public struct Counting: Sendable {
        public let name: String
        public let pictures: Int
        public let seconds: TimeInterval
    }

    /// How long a count stands before the source is counted again.
    public static let countStandsFor: TimeInterval = 60 * 60

    private let sources: [any CountedSource]
    private let counts: RememberedCounts
    private let now: @Sendable () -> Date
    private let choose: @Sendable (Range<Int>) -> Int
    private let onCount: (@Sendable (Counting) -> Void)?

    /// - Parameters:
    ///   - now: The clock a count's age is read against.
    ///   - choose: A number from the range, each as likely as the others. It
    ///     and the clock are parameters so that a test leaves nothing to chance.
    ///   - onCount: Told of each counting, for whoever is measuring. Called on
    ///     the thread that counted.
    public init(
        _ sources: [any CountedSource], remembering counts: RememberedCounts,
        now: @escaping @Sendable () -> Date = { .now },
        choosing choose: @escaping @Sendable (Range<Int>) -> Int = { Int.random(in: $0) },
        onCount: (@Sendable (Counting) -> Void)? = nil
    ) {
        self.sources = sources
        self.counts = counts
        self.now = now
        self.choose = choose
        self.onCount = onCount
    }

    /// A picture from one of the sources, each chosen in proportion to what it
    /// holds, until one has a picture to give.
    ///
    /// **One source's trouble does not stop the others.** A folder that cannot
    /// be read is passed over for a source that can. Its error is thrown only
    /// when no source gave a picture, so that a widget with nothing to show
    /// can say why instead of saying there are no pictures.
    ///
    /// **A source that did not give a picture is forgotten**, whether it
    /// failed or held less than its count said, so that it is counted again
    /// next time. One that said how many it holds on the way is remembered by
    /// that instead.
    public func writePicture(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize? {
        let remembered = counts.read()
        var known = remembered
        // Only what changed here is written, over the file as it is by then:
        // someone else may have counted a source of their own meanwhile. A
        // count that could not be written is taken again next time.
        defer {
            let changed = Set(remembered.keys).union(known.keys).filter { remembered[$0] != known[$0] }
            if !changed.isEmpty {
                try? counts.update { current in
                    for name in changed {
                        current[name] = known[name]
                    }
                }
            }
        }

        var trouble: (any Error)?
        var holding: [(source: any CountedSource, pictures: Int)] = []
        let moment = now()
        for source in sources {
            do {
                let pictures = try count(source, at: moment, among: &known)
                if pictures > 0 { holding.append((source, pictures)) }
            } catch {
                known[source.countName] = nil
                trouble = trouble ?? error
            }
        }

        while !holding.isEmpty {
            var draw = choose(0..<holding.reduce(0) { $0 + $1.pictures })
            var chosen = 0
            while chosen < holding.count - 1, draw >= holding[chosen].pictures {
                draw -= holding[chosen].pictures
                chosen += 1
            }
            let source = holding.remove(at: chosen).source
            do {
                let picked = try source.writePictureAndCount(fitting: box, to: destination)
                if let pictures = picked.pictures {
                    Self.remember(pictures, of: source, at: moment, among: &known)
                } else if picked.resize == nil {
                    known[source.countName] = nil
                }
                if let resize = picked.resize { return resize }
            } catch {
                known[source.countName] = nil
                trouble = trouble ?? error
            }
        }
        if let trouble { throw trouble }
        return nil
    }

    /// How many pictures `source` holds: its count in `known` while that
    /// stands, and a new one, put in `known`, when it does not.
    /// Keeps a source's count, unless it is none.
    ///
    /// **Nothing is remembered of an empty source**, since 2026-10-10. A count
    /// stands for an hour, so an album counted while it was empty went on being
    /// taken for empty for an hour after photographs were added to it: Syd
    /// chose Favorites with nothing in it, marked two photographs as favorites,
    /// and got none of them. An empty source is counted again at each pick,
    /// which costs little, there being nothing in it to count.
    private static func remember(
        _ pictures: Int, of source: any CountedSource, at moment: Date,
        among known: inout [String: RememberedCounts.Count]
    ) {
        known[source.countName] = pictures > 0 ? .init(pictures: pictures, counted: moment) : nil
    }

    private func count(
        _ source: any CountedSource, at moment: Date, among known: inout [String: RememberedCounts.Count]
    ) throws -> Int {
        // A count of none is never believed, whoever wrote it: see `remember`.
        if let last = known[source.countName], last.pictures > 0 {
            // A count from after now has no age to go by: the clock has been
            // set back.
            let age = moment.timeIntervalSince(last.counted)
            if age >= 0, age < Self.countStandsFor { return last.pictures }
        }
        let began = ContinuousClock.now
        let pictures = try source.pictureCount()
        Self.remember(pictures, of: source, at: moment, among: &known)
        onCount?(
            Counting(name: source.countName, pictures: pictures, seconds: (ContinuousClock.now - began) / .seconds(1)))
        return pictures
    }
}
