// How many pictures a chosen source holds, for the count on its row.
// `Plans/PGR Widgets - iOS.md`.
//
// **Counted the way a widget counts.** A widget weighs its sources by how many
// pictures each holds, and the row shows that same figure, from the same code:
// what a widget would take for an empty album is what the row calls 0.

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

/// The real count, from the folder or from Photos.
public struct LibrarySourceCounts: SourceCounts {
    public init() {}

    public func count(of source: SourceSpec) throws -> Int? {
        // A single file is one picture. Syd, 2026-10-10. One that is no
        // longer there is not counted as none: it cannot be read.
        if source.kind == .file {
            guard FileManager.default.fileExists(atPath: source.locator) else {
                throw CocoaError(.fileNoSuchFile)
            }
            return 1
        }
        return try source.counted?.pictureCount()
    }
}

extension SourceSpec {
    /// The source as something that gives its first picture, for a picture
    /// wanted at once. A folder has no first, and gives any of its own.
    var firstPicture: (any PictureSource)? {
        switch kind {
        case .photosCollection: PhotosSource(collection: locator, pick: .first)
        case .photosSelection: SelectedPhotosSource(pick: .first)
        default: counted
        }
    }

    /// The source as something pictures are counted in and taken from: a
    /// folder, a Photos collection, or the photographs picked with limited
    /// access. Nil for a kind the widgets do not show from.
    var counted: (any CountedSource)? {
        switch kind {
        case .folder:
            FolderSource(folder: URL(filePath: locator, directoryHint: .isDirectory), recursive: recursive)
        case .photosCollection:
            PhotosSource(collection: locator)
        case .photosSelection:
            SelectedPhotosSource()
        default:
            nil
        }
    }
}
