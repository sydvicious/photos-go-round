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
        // A folder for each size and each set of sources, so a picture made
        // for one is never shown for another.
        let sized = directory.appending(
            path: "\(Int(box.width))x\(Int(box.height))", directoryHint: .isDirectory)
        let names = sources.map { "\($0.kind.rawValue)|\($0.locator)|\($0.recursive)" }
        let folder = (try? CacheFolders.folder(in: sized, forSources: names)) ?? sized
        let cache = TinyCache(
            directory: folder, source: Self.source(for: sources, counts: directory), fitting: box,
            fillLimit: 1)
        return try cache.take(upTo: 1, from: .now, every: 1).first?.file
    }

    /// Forgets how many pictures each source held. The counts are remembered
    /// for an hour so that a pick does not walk every source; without this, a
    /// collection that was empty when it was counted stays empty to the
    /// preview for that hour, whatever is added to it.
    public func forget() {
        try? FileManager.default.removeItem(at: counts)
    }

    private var counts: URL { directory.appending(path: "counts.json") }

    /// One source made of every chosen one the preview can read: folders,
    /// Photos collections, and the photographs picked with limited access. Every picture has an equal chance, whichever of
    /// them it is in, as in a widget.
    private static func source(for specs: [SourceSpec], counts directory: URL) -> any PictureSource {
        SeveralSources(
            specs.compactMap(\.counted),
            remembering: RememberedCounts(file: directory.appending(path: "counts.json")))
        // The same file `forget` removes.
    }
}
