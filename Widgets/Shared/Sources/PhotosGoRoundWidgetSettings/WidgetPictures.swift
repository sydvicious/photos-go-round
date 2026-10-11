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
    private let root: URL?

    /// - Parameters:
    ///   - directory: Somewhere of this widget's own to keep its pictures
    ///     and its counts.
    ///   - root: The folder that holds every size's `directory`, when the
    ///     sizes are kept side by side. It is where the gallery's preview of
    ///     a size with no picture yet looks for another size's.
    public init(directory: URL, among root: URL? = nil) {
        pictures = CachedPreviewPictures(directory: directory)
        self.root = root
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
    /// gallery, which wants a face at once.
    ///
    /// **A size that has shown nothing borrows another size's picture.** Syd,
    /// 2026-10-10. Until a widget of a size has been placed, that size has no
    /// picture of its own, and the gallery showed "Scanning…" for it. The
    /// picture borrowed is the one made for the biggest widget, which loses
    /// least when it is drawn larger.
    ///
    /// **With no picture from any size, the gallery shows the plain icon.**
    /// Syd, 2026-10-10: "just the app icon without an overlay". Nothing is
    /// being scanned there; a widget fetches once it is placed. Anywhere
    /// else it is "Scanning…", since a picture is on its way.
    public func last(
        from sources: [SourceSpec], fitting box: CGSize, inGallery: Bool = false
    ) -> WidgetFace.Content {
        guard !sources.isEmpty else { return .nothingChosen }
        if let own = pictures.last(for: sources, fitting: box) { return .picture(own) }
        if let another = lastOfAnySize(from: sources) { return .picture(another) }
        // The plain icon is the face for nothing chosen, and is what is
        // wanted here too.
        return inGallery ? .nothingChosen : .scanning
    }

    /// The last picture shown for these sources by any size under `root`,
    /// preferring the one made for the most pixels. The layout is the
    /// extension's: a folder for each size of widget, in it one for each
    /// size in pixels, in that one for each list of sources.
    private func lastOfAnySize(from sources: [SourceSpec]) -> URL? {
        guard let root else { return nil }
        let manager = FileManager.default
        func folders(in folder: URL) -> [URL] {
            (try? manager.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        }
        let name = CacheFolders.name(forSources: CachedPreviewPictures.names(of: sources))
        var best: (pixels: Int, file: URL)?
        for sized in folders(in: root).flatMap(folders(in:)) {
            // Named for its pixels, as in "600x600".
            let sides = sized.lastPathComponent.split(separator: "x").compactMap { Int($0) }
            guard sides.count == 2 else { continue }
            let shown = sized.appending(path: name).appending(path: "shown")
            guard let last = folders(in: shown).max(by: { $0.lastPathComponent < $1.lastPathComponent })
            else { continue }
            let pixels = sides[0] * sides[1]
            if best == nil || pixels > best!.pixels {
                best = (pixels, last)
            }
        }
        return best?.file
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
