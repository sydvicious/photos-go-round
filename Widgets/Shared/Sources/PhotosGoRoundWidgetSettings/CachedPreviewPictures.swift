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
import OSLog
import PhotosGoRoundAgentAPI
import TinyCache

public struct CachedPreviewPictures: PreviewPictures {
    private let directory: URL
    private let library: any PhotoLibraryPictures
    private let bookmarks: BookmarkedSources?
    private let onFetch: (@Sendable (PictureResizer.Resize) -> Void)?

    /// - Parameters:
    ///   - directory: Somewhere of the app's own to keep the pictures and the
    ///     counts, such as a folder in its caches.
    ///   - library: Where Photos sources get their pictures. A test hands
    ///     over one of its own.
    ///   - bookmarks: What files and folders are opened through, where the
    ///     Files browser chose them. Without it they are read by their paths.
    ///   - onFetch: Told what each fetch read and wrote, for whoever is
    ///     measuring. Called on the thread that fetched.
    public init(
        directory: URL, library: any PhotoLibraryPictures = SystemPhotoLibraryPictures(),
        bookmarks: BookmarkedSources? = nil,
        onFetch: (@Sendable (PictureResizer.Resize) -> Void)? = nil
    ) {
        self.directory = directory
        self.library = library
        self.bookmarks = bookmarks
        self.onFetch = onFetch
    }

    public func next(from sources: [SourceSpec], fitting box: CGSize) throws -> URL? {
        let cache = TinyCache(
            directory: folder(for: sources, fitting: box),
            source: source(for: sources), fitting: box, fillLimit: 1, onFetch: onFetch)
        // Whoever asked shows "No Photos found" for an error and for nothing
        // alike, so which it was is said here. Nothing found is an empty
        // album as often as a fault, and is asked again every few seconds, so
        // it is logged where it is not kept.
        do {
            let file = try cache.take(upTo: 1, from: .now, every: 1).first?.file
            if file == nil {
                Log.widget.info(
                    """
                    \(Log.widgetsTag, privacy: .public) no picture from any of \(sources.count) sources, \
                    asked for at \(Int(box.width))x\(Int(box.height)), and no error either
                    """)
            }
            return file
        } catch {
            Log.widget.error(
                """
                \(Log.widgetsTag, privacy: .public) could not get a picture: \
                \(String(describing: error), privacy: .public)
                """)
            throw error
        }
    }

    /// The picture is a file on disk and stays there when the app goes, so
    /// the next launch has it without asking Photos for anything. Syd,
    /// 2026-10-10: "we can cache the photo to disk so it does not take up
    /// ram".
    public func last(for sources: [SourceSpec], fitting box: CGSize) -> URL? {
        let cache = TinyCache(
            directory: folder(for: sources, fitting: box),
            source: source(for: []), fitting: box, fillLimit: 1)
        return (try? cache.lastShown()) ?? nil
    }

    /// Fetches one picture ahead of time and keeps it waiting, so that the
    /// next `next` has it without asking any source. A widget does this
    /// after it has handed over what it is showing.
    ///
    /// Nothing fetched is no matter, since the next `next` fetches for
    /// itself. Photos not answering is thrown, so that whoever asked waits
    /// before asking again.
    public func makeReady(from sources: [SourceSpec], fitting box: CGSize) throws {
        let cache = TinyCache(
            directory: folder(for: sources, fitting: box),
            source: source(for: sources), fitting: box, fillLimit: 1, onFetch: onFetch)
        do {
            try cache.fill(to: 1)
        } catch let late as TimedOut {
            throw late
        } catch {}
    }

    /// Each source is tried in the order it was chosen, and the first that
    /// gives a picture is the one. A source that cannot be read is passed
    /// over, as one with nothing in it is. One Photos did not answer for is
    /// not: the next would wait as long again, so that is thrown.
    public func first(from sources: [SourceSpec], fitting box: CGSize) throws -> URL? {
        let folder = folder(for: sources, fitting: box)
        for spec in sources {
            guard let source = spec.firstPicture(in: library, through: bookmarks) else { continue }
            let cache = TinyCache(
                directory: folder, source: source, fitting: box, fillLimit: 1, onFetch: onFetch)
            do {
                if let file = try cache.take(upTo: 1, from: .now, every: 1).first?.file {
                    return file
                }
            } catch let late as TimedOut {
                throw late
            } catch {
                Log.widget.error(
                    """
                    \(Log.widgetsTag, privacy: .public) no first picture from a \
                    \(spec.kind.rawValue, privacy: .public) source: \
                    \(String(describing: error), privacy: .public)
                    """)
            }
        }
        return nil
    }

    /// A folder for each size and each set of sources, so a picture made for
    /// one is never shown for another.
    private func folder(for sources: [SourceSpec], fitting box: CGSize) -> URL {
        let sized = directory.appending(
            path: "\(Int(box.width))x\(Int(box.height))", directoryHint: .isDirectory)
        return (try? CacheFolders.folder(in: sized, forSources: Self.names(of: sources))) ?? sized
    }

    /// What each source is called when a cache's folder is named for them.
    static func names(of sources: [SourceSpec]) -> [String] {
        sources.map { "\($0.kind.rawValue)|\($0.locator)|\($0.recursive)" }
    }

    private var counts: URL { directory.appending(path: "counts.json") }

    /// One source made of every chosen one the preview can read: folders,
    /// single files, Photos collections, and the photographs picked with
    /// limited access. Every picture has an equal chance, whichever of them
    /// it is in, as in a widget.
    private func source(for specs: [SourceSpec]) -> any PictureSource {
        SeveralSources(
            specs.compactMap { $0.counted(in: library, through: bookmarks) },
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
        let count = try LibrarySourceCounts(through: bookmarks).count(of: source)
        if let count, let counted = source.counted(in: library, through: bookmarks) {
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
