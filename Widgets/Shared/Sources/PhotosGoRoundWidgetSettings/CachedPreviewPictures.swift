// The preview's pictures, from the chosen sources through a cache of the
// app's own. `Plans/Photos-Go-Round Widgets.md`: the app "has a second
// TinyCache of its own, for previews of the widgets", so a preview never takes
// a picture a widget was going to show.
//
// **A cache of one.** Each change takes the picture that is waiting, or
// fetches one, and what was shown before is cleared away as the next is taken.
// That is how a widget's own timeline uses its cache.

import CoreGraphics
import Foundation
import PhotosGoRoundAgentAPI
import TinyCache

public struct CachedPreviewPictures: PreviewPictures {
    private let directory: URL

    /// - Parameter directory: Somewhere of the app's own to keep the pictures
    ///   and the counts, such as a folder in its caches.
    public init(directory: URL) {
        self.directory = directory
    }

    public func next(from sources: [SourceSpec], fitting box: CGSize) throws -> URL? {
        let cache = TinyCache(
            directory: folder(for: sources, fitting: box),
            source: Self.source(for: sources, counts: directory), fitting: box, fillLimit: 1)
        return try cache.take(upTo: 1, from: .now, every: 1).first?.file
    }

    /// The picture is a file on disk and stays there when the app goes, so
    /// the next launch has it without asking Photos for anything. Syd,
    /// 2026-10-10: "we can cache the photo to disk so it does not take up
    /// ram".
    public func last(for sources: [SourceSpec], fitting box: CGSize) -> URL? {
        let cache = TinyCache(
            directory: folder(for: sources, fitting: box),
            source: Self.source(for: [], counts: directory), fitting: box, fillLimit: 1)
        return (try? cache.lastShown()) ?? nil
    }

    /// Each source is tried in the order it was chosen, and the first that
    /// gives a picture is the one. A source that cannot be read is passed
    /// over, as one with nothing in it is.
    public func first(from sources: [SourceSpec], fitting box: CGSize) throws -> URL? {
        let folder = folder(for: sources, fitting: box)
        for spec in sources {
            guard let source = spec.firstPicture else { continue }
            let cache = TinyCache(directory: folder, source: source, fitting: box, fillLimit: 1)
            if let file = try? cache.take(upTo: 1, from: .now, every: 1).first?.file {
                return file
            }
        }
        return nil
    }

    /// A folder for each size and each set of sources, so a picture made for
    /// one is never shown for another.
    private func folder(for sources: [SourceSpec], fitting box: CGSize) -> URL {
        let sized = directory.appending(
            path: "\(Int(box.width))x\(Int(box.height))", directoryHint: .isDirectory)
        let names = sources.map { "\($0.kind.rawValue)|\($0.locator)|\($0.recursive)" }
        return (try? CacheFolders.folder(in: sized, forSources: names)) ?? sized
    }

    private var counts: URL { directory.appending(path: "counts.json") }

    /// One source made of every chosen one the preview can read: folders,
    /// Photos collections, and the photographs picked with limited access. Every picture has an equal chance, whichever of
    /// them it is in, as in a widget.
    private static func source(for specs: [SourceSpec], counts directory: URL) -> any PictureSource {
        SeveralSources(
            specs.compactMap(\.counted),
            remembering: RememberedCounts(file: directory.appending(path: "counts.json")))
        // The same file a row's count is written to.
    }
}

/// **The count on a row is the count the picks are weighed by.** Syd,
/// 2026-10-10. A source is counted once, for its row, and the figure is put
/// where `SeveralSources` reads it, so the preview does not count it again on
/// the way to a picture. On a library of tens of thousands of photographs
/// that count is the slow part.
extension CachedPreviewPictures: SourceCounts {
    public func count(of source: SourceSpec) throws -> Int? {
        let count = try LibrarySourceCounts().count(of: source)
        if let count, let counted = source.counted {
            // Nothing is remembered of an empty source, as in
            // `SeveralSources`: it is asked again each time. A pick may be
            // writing its own counts to the same file at this moment, and an
            // update loses neither.
            try? RememberedCounts(file: counts).update { known in
                known[counted.countName] = count > 0 ? .init(pictures: count, counted: .now) : nil
            }
        }
        return count
    }
}
