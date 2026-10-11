// What a widget shows each time the system wakes it for a timeline.
// `Plans/PGR Widgets - iOS.md`, *The first picture, as fast as possible*.
//
// **It starts as the app's preview does.** Syd, 2026-10-10: "of course, each
// widget will be doing this as well". The first picture is the first source's
// own, with nothing counted; after that each is picked by how many pictures
// each source holds. On a library of tens of thousands of photographs the
// count is the slow part, and a widget has little time and less memory.
//
// **Everything is a file.** A widget extension is held to a few tens of
// megabytes. A picture is fetched at the widget's size, written to the
// widget's own cache, and drawn from there.
//
// **A face, not a sentence.** What comes back is what `WidgetFace` draws: a
// picture, or one of the faces without one.

import CoreGraphics
import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundWidgetFace
import TinyCache

public struct WidgetPictures: Sendable {
    private let pictures: CachedPreviewPictures

    /// - Parameter directory: Somewhere of this widget's own to keep its
    ///   pictures and its counts.
    public init(directory: URL) {
        pictures = CachedPreviewPictures(directory: directory)
    }

    /// The face for this wake. May block: it reads Photos or walks a folder.
    public func turn(from sources: [SourceSpec], fitting box: CGSize) -> WidgetFace.Content {
        guard !sources.isEmpty else { return .nothingChosen }
        do {
            // Nothing shown yet for these sources at this size: the quick
            // first picture.
            if pictures.last(for: sources, fitting: box) == nil,
                let first = try pictures.first(from: sources, fitting: box)
            {
                return .picture(first)
            }
            if let next = try pictures.next(from: sources, fitting: box) {
                return .picture(next)
            }
            return .noPhotos
        } catch {
            return Self.face(for: error)
        }
    }

    /// What it showed last, with nothing asked of any source: for the widget
    /// gallery, which wants a face at once. "Scanning…" when there is nothing
    /// kept, since a picture is on its way.
    public func last(from sources: [SourceSpec], fitting box: CGSize) -> WidgetFace.Content {
        guard !sources.isEmpty else { return .nothingChosen }
        return pictures.last(for: sources, fitting: box).map { .picture($0) } ?? .scanning
    }

    /// Fetches the next wake's picture now, so that wake has it without
    /// asking. Best done after this wake's face has been handed over; if it
    /// does not get done, the next wake fetches for itself.
    public func makeReady(from sources: [SourceSpec], fitting box: CGSize) {
        guard !sources.isEmpty else { return }
        pictures.makeReady(from: sources, fitting: box)
    }

    /// The face for a wake that failed. Photos refusing is the one failure a
    /// person can do something about, in the system's settings.
    static func face(for error: any Error) -> WidgetFace.Content {
        error is SystemPhotoLibraryPictures.Refused ? .noAccess : .noPhotos
    }
}
