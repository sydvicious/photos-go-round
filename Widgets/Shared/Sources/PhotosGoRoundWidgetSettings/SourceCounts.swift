// How many pictures a chosen source holds, for the count on its row.
// `Plans/PGR Widgets - iOS.md`.
//
// **Counted the way a widget counts.** A widget weighs its sources by how many
// pictures each holds, and the row shows that same figure, from the same code:
// what a widget would take for an empty album is what the row calls 0.

import CoreGraphics
import Foundation
import PhotosGoRoundAgentAPI
import TinyCache

public protocol SourceCounts: Sendable {
    /// How many pictures `source` holds now. Nil for a kind of source that is
    /// not counted, and an error when it cannot be read. It may block: a
    /// folder is walked, and Photos is asked.
    func count(of source: SourceSpec) throws -> Int?
}

/// Counts nothing, for a screen that shows no counts.
public struct NoSourceCounts: SourceCounts {
    public init() {}
    public func count(of source: SourceSpec) throws -> Int? { nil }
}

/// The real count, from the file or folder or from Photos.
public struct LibrarySourceCounts: SourceCounts {
    private let bookmarks: BookmarkedSources?

    /// - Parameter bookmarks: What files and folders are opened through, where
    ///   the Files browser chose them. Without it they are read by their paths.
    public init(through bookmarks: BookmarkedSources? = nil) {
        self.bookmarks = bookmarks
    }

    /// A single file is one picture. Syd, 2026-10-10. One that is no longer
    /// there is not counted as none: it cannot be read.
    public func count(of source: SourceSpec) throws -> Int? {
        try source.counted(through: bookmarks)?.pictureCount()
    }
}

extension SourceSpec {
    /// The source as something that gives its first picture, for a picture
    /// wanted at once. A folder has no first, and gives any of its own.
    ///
    /// The library is a parameter, here and below, so that a test can hand
    /// over one that does not answer.
    func firstPicture(
        in library: any PhotoLibraryPictures = SystemPhotoLibraryPictures(),
        through bookmarks: BookmarkedSources? = nil,
        resizer: PictureResizer = PictureResizer(), skipped: (@Sendable () -> Void)? = nil
    ) -> (any PictureSource)? {
        switch kind {
        case .photosCollection: PhotosSource(collection: locator, library: library, pick: .first)
        case .photosSelection: SelectedPhotosSource(library: library, pick: .first)
        default: counted(in: library, through: bookmarks, resizer: resizer, skipped: skipped)
        }
    }

    /// The source as something pictures are counted in and taken from: a
    /// folder, a single file, a Photos collection, or the photographs picked
    /// with limited access. Nil for a kind the widgets do not show from.
    ///
    /// **With bookmarks kept, a file or folder is opened through its own and
    /// never by its path.** On a phone the path is refused anyway. In a
    /// simulator it is not, and reading by it there would say a widget can
    /// open what on a phone it cannot.
    ///
    /// - Parameters:
    ///   - resizer: What shrinks a file's picture. A test hands over one
    ///     with a memory limit of its own.
    ///   - skipped: Told when a picture in a file or folder is passed over
    ///     because no wake could shrink it inside an extension's memory.
    func counted(
        in library: any PhotoLibraryPictures = SystemPhotoLibraryPictures(),
        through bookmarks: BookmarkedSources? = nil,
        resizer: PictureResizer = PictureResizer(), skipped: (@Sendable () -> Void)? = nil
    ) -> (any CountedSource)? {
        // Which file it was is not passed on: the note is about the source.
        var ofAFile: (@Sendable (URL) -> Void)?
        if let skipped { ofAFile = { _ in skipped() } }
        switch kind {
        case .folder:
            guard let folder = location(through: bookmarks) else { return UnopenedSource(self) }
            return FolderSource(folder: folder, recursive: recursive, resizer: resizer, skipped: ofAFile)
        case .file:
            guard let file = location(through: bookmarks) else { return UnopenedSource(self) }
            return FileSource(file: file, resizer: resizer, skipped: ofAFile)
        case .photosCollection:
            return PhotosSource(collection: locator, library: library)
        case .photosSelection:
            return SelectedPhotosSource(library: library)
        default:
            return nil
        }
    }

    /// Where a file or folder is to be read from: through its bookmark when
    /// bookmarks are kept, and at its path when they are not.
    private func location(through bookmarks: BookmarkedSources?) -> URL? {
        guard let bookmarks else {
            return URL(filePath: locator, directoryHint: kind == .folder ? .isDirectory : .notDirectory)
        }
        return bookmarks.location(of: locator)
    }
}

/// A file or folder whose bookmark did not open. It cannot be read, which is
/// not the same as holding nothing.
private struct UnopenedSource: CountedSource {
    let countName: String

    init(_ source: SourceSpec) {
        countName = "unopened|\(source.locator)"
    }

    func pictureCount() throws -> Int {
        throw CocoaError(.fileReadNoPermission)
    }

    func writePicture(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize? {
        throw CocoaError(.fileReadNoPermission)
    }
}
