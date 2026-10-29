// A widget's own few pictures, at the widget's size. `Plans/Photos-Go-Round
// Widgets.md`.
//
// **Classes and objects, called directly.** Syd, 2026-10-08: "TinyCache will
// just be classes and objects that are called and returned rather than accessed
// via HTTP". Whoever is showing pictures makes one of these in its own process
// and asks it.
//
// **It works with nothing in it.** The first picture comes straight from the
// source and is shown; one more is then kept for next time, and only a process
// that is left running goes on to fill it. Syd: "should be able to work without
// a cache at all or with a cache of 1".
//
// **All of its state is the files.** A widget extension is woken, asked, and
// killed whenever the system likes, so nothing is remembered between calls
// except what is on disk: a picture waiting its turn is in `waiting`, and one
// handed to a timeline is in `shown` with its turn as its modification date.
//
// **Not safe to call from two places at once.** The caller serializes.

import CoreGraphics
import Foundation

public struct TinyCache: Sendable {
    /// One picture's turn in a timeline.
    public struct Showing: Sendable, Equatable {
        public let file: URL
        public let date: Date
    }

    /// Syd, 2026-10-08: "space for 30 to have room in case pictures are bigger,
    /// but we only fill 20".
    public static let defaultFillLimit = 20

    private let waitingFolder: URL
    private let shownFolder: URL
    /// Where each picture came from, by its file's name. Hidden, so that a
    /// listing of the pictures never takes it for one.
    private let originsFile: URL
    private let source: any PictureSource
    private let box: CGSize
    private let fillLimit: Int
    private let onFetch: (@Sendable (PictureResizer.Resize) -> Void)?

    /// - Parameters:
    ///   - directory: This widget's own folder. Two widgets do not share one.
    ///   - box: The widget's size in pixels; pictures are cached to fit it.
    ///   - onFetch: Told what each fetch read and wrote, for whoever is
    ///     measuring. Called on the thread that fetched.
    public init(
        directory: URL, source: any PictureSource, fitting box: CGSize,
        fillLimit: Int = TinyCache.defaultFillLimit,
        onFetch: (@Sendable (PictureResizer.Resize) -> Void)? = nil
    ) {
        waitingFolder = directory.appending(path: "waiting", directoryHint: .isDirectory)
        shownFolder = directory.appending(path: "shown", directoryHint: .isDirectory)
        originsFile = directory.appending(path: ".origins.json")
        self.source = source
        self.box = box
        self.fillLimit = fillLimit
        self.onFetch = onFetch
    }

    /// The pictures waiting their turn, in the order they arrived.
    /// The picture that was shown last, if it is still kept. Nothing is asked
    /// of the source, so it is there at once: a picture to put up while a new
    /// one is fetched.
    public func lastShown() throws -> URL? {
        try pictures(in: shownFolder).last
    }

    public func waiting() throws -> [URL] {
        try pictures(in: waitingFolder)
    }

    /// The pictures for a timeline that starts at `start` and changes every
    /// `interval`: everything waiting, up to `count`, or one fetched now when
    /// nothing is. Empty only when the source has no pictures at all.
    ///
    /// A new timeline replaces the last one, so what the last one was handed is
    /// settled first: a picture whose turn has come is deleted, and one whose
    /// turn had not come waits again instead of being wasted.
    ///
    /// **What was shown is cleared away only once there is something to show
    /// in its place.** A fetch that throws, or gives nothing, leaves the
    /// picture shown last where it is, so whoever asked can go on showing
    /// it. Photos not answering is such a throw, and the first of two chosen
    /// sources being empty is such a nothing. 2026-10-11.
    public func take(upTo count: Int, from start: Date, every interval: TimeInterval) throws -> [Showing] {
        try waitAgain(asOf: start)
        if try waiting().isEmpty {
            _ = try fetchOne()
        }
        guard try !waiting().isEmpty else { return [] }
        try clearShown(asOf: start)
        let manager = FileManager.default
        try manager.createDirectory(at: shownFolder, withIntermediateDirectories: true)
        var showings: [Showing] = []
        for (turn, file) in try waiting().prefix(max(count, 0)).enumerated() {
            let date = start + Double(turn) * interval
            let shown = shownFolder.appending(path: file.lastPathComponent)
            try manager.moveItem(at: file, to: shown)
            try manager.setAttributes(
                [.modificationDate: date], ofItemAtPath: shown.path(percentEncoded: false))
            showings.append(Showing(file: shown, date: date))
        }
        return showings
    }

    /// Fetches until `count` pictures are waiting, and never past the fill
    /// limit. One at a time, so a process killed part-way keeps what it has.
    /// - Returns: How many it added.
    @discardableResult
    public func fill(to count: Int) throws -> Int {
        let wanted = min(count, fillLimit)
        var added = 0
        while try waiting().count < wanted {
            guard try fetchOne() else { break }
            added += 1
        }
        return added
    }

    /// A picture to show where nothing is being scheduled — the widget gallery,
    /// a preview in the app. It is not used up: a waiting picture still waits.
    public func preview() throws -> URL? {
        if let file = try waiting().first { return file }
        if let file = try pictures(in: shownFolder).last { return file }
        try fill(to: 1)
        return try waiting().first
    }

    /// Where a picture this cache wrote came from, read beside it. Nil for
    /// one written before origins were kept, or by a source that does not
    /// say.
    public static func origin(of file: URL) -> PictureOrigin? {
        let directory = file.deletingLastPathComponent().deletingLastPathComponent()
        return origins(in: directory.appending(path: ".origins.json"))[file.lastPathComponent]
    }

    /// The picture `origin` names, written again at this cache's size and
    /// shown now: the one on screen, drawn again for another size or another
    /// framing. Nil when the source cannot write it again.
    public func showAgain(_ origin: PictureOrigin) throws -> URL? {
        try FileManager.default.createDirectory(at: shownFolder, withIntermediateDirectories: true)
        let destination = shownFolder.appending(path: try nextName())
        guard
            let resize = try autoreleasepool(invoking: {
                try source.writePicture(origin, fitting: box, to: destination)
            })
        else { return nil }
        try FileManager.default.setAttributes(
            [.modificationDate: Date.now], ofItemAtPath: destination.path(percentEncoded: false))
        try keep(resize.origin ?? origin, for: destination)
        onFetch?(resize)
        return destination
    }

    // MARK: -

    private static func origins(in file: URL) -> [String: PictureOrigin] {
        guard let data = try? Data(contentsOf: file) else { return [:] }
        return (try? JSONDecoder().decode([String: PictureOrigin].self, from: data)) ?? [:]
    }

    /// Records where a picture came from, and forgets the pictures that are
    /// gone.
    private func keep(_ origin: PictureOrigin, for file: URL) throws {
        let present = Set(try (pictures(in: waitingFolder) + pictures(in: shownFolder)).map(\.lastPathComponent))
        var origins = Self.origins(in: originsFile).filter { present.contains($0.key) }
        origins[file.lastPathComponent] = origin
        try JSONEncoder().encode(origins).write(to: originsFile, options: .atomic)
    }

    /// One picture from the source into `waiting`.
    /// - Returns: Whether a picture was added.
    private func fetchOne() throws -> Bool {
        try FileManager.default.createDirectory(at: waitingFolder, withIntermediateDirectories: true)
        // In a pool of its own, so that what a fetch made on the way is let go
        // before the next one. Measured 2026-10-08: twenty Photos fetches in a
        // row, in one wake, took the extension from 13 MB to 28 MB with nothing
        // released between them.
        let destination = try nextWaitingFile()
        guard let resize = try autoreleasepool(invoking: { try source.writePicture(fitting: box, to: destination) })
        else { return false }
        if let origin = resize.origin { try? keep(origin, for: destination) }
        onFetch?(resize)
        return true
    }

    /// When a shown picture's turn was, or is to be.
    private func turn(of file: URL) throws -> Date {
        try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            ?? .distantPast
    }

    /// A picture handed to the last timeline whose turn had not come waits
    /// again.
    private func waitAgain(asOf now: Date) throws {
        let manager = FileManager.default
        for file in try pictures(in: shownFolder) where try turn(of: file) > now {
            try manager.createDirectory(at: waitingFolder, withIntermediateDirectories: true)
            try manager.moveItem(at: file, to: waitingFolder.appending(path: file.lastPathComponent))
        }
    }

    /// A picture whose turn has come is deleted.
    private func clearShown(asOf now: Date) throws {
        for file in try pictures(in: shownFolder) where try turn(of: file) <= now {
            try FileManager.default.removeItem(at: file)
        }
    }

    /// The folder's pictures by name, which is by arrival. A folder that does
    /// not exist yet has none.
    private func pictures(in folder: URL) throws -> [URL] {
        let manager = FileManager.default
        guard manager.fileExists(atPath: folder.path(percentEncoded: false)) else { return [] }
        return try manager.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Names begin with a count that only goes up, so sorting by name is
    /// sorting by arrival, and end with something unique so that a name is
    /// never used twice even after the folders have emptied.
    private func nextWaitingFile() throws -> URL {
        waitingFolder.appending(path: try nextName())
    }

    private func nextName() throws -> String {
        let names = try (pictures(in: waitingFolder) + pictures(in: shownFolder)).map(\.lastPathComponent)
        let last = names.compactMap { Int($0.prefix { $0.isNumber }) }.max() ?? 0
        let count = String(last + 1)
        let padded = String(repeating: "0", count: max(0, 10 - count.count)) + count
        return "\(padded)-\(UUID().uuidString.suffix(4)).jpg"
    }
}
