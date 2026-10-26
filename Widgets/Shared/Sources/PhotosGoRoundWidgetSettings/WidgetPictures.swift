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
//
// **When Photos does not answer, what is showing stays, with "Scanning…" over
// it**, and Photos is not asked again until a wait is over: `RequestBackoff`.
// Syd, 2026-10-11: "If there is already a photo loaded just keep displaying
// it. If not use the scanning… overlay on the app icon", and then "put the
// scanning overlay over whatever is showing so the user knows something is
// wrong". The wait is kept in a file beside the pictures, since the next wake
// may be a new process.

import CoreGraphics
import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundWidgetFace
import TinyCache

public struct WidgetPictures: Sendable {
    private let pictures: CachedPreviewPictures
    private let root: URL?
    /// How the pictures sit in the widget. `Plans/Widget Settings.md`.
    private let framing: Framing
    /// Where the wait is kept while Photos is not answering.
    private let asking: URL

    /// - Parameters:
    ///   - directory: Somewhere of this widget's own to keep its pictures
    ///     and its counts.
    ///   - root: The folder that holds every size's `directory`, when the
    ///     sizes are kept side by side. It is where the gallery's preview of
    ///     a size with no picture yet looks for another size's.
    ///   - library: Where Photos sources get their pictures. A test hands
    ///     over one of its own.
    ///   - bookmarks: What files and folders are opened through: the
    ///     bookmarks the app left. Without it they are read by their paths.
    ///   - onFetch: Told what each fetch read and wrote, for whoever is
    ///     measuring. Called on the thread that fetched.
    ///   - resizer: What shrinks a file's picture. A test hands over one
    ///     with a memory limit of its own.
    ///   - onSkip: Told which source a picture was in when it is passed over
    ///     because no wake could shrink it inside an extension's memory.
    ///   - framing: How the pictures sit in the widget.
    public init(
        directory: URL, among root: URL? = nil,
        library: any PhotoLibraryPictures = SystemPhotoLibraryPictures(),
        bookmarks: BookmarkedSources? = nil,
        onFetch: (@Sendable (PictureResizer.Resize) -> Void)? = nil,
        resizer: PictureResizer = PictureResizer(),
        onSkip: (@Sendable (SourceSpec) -> Void)? = nil,
        framing: Framing = .fit
    ) {
        pictures = CachedPreviewPictures(
            directory: directory, library: library, bookmarks: bookmarks, onFetch: onFetch,
            resizer: resizer, onSkip: onSkip, framing: framing)
        self.root = root
        self.framing = framing
        asking = directory.appending(path: "asking.json")
    }

    /// The face for this wake. May block: it reads Photos or walks a folder.
    ///
    /// - Parameter now: The time, read when it is needed: a wait starts when
    ///   Photos is given up on, which is some seconds after the wake began.
    public func turn(
        from sources: [SourceSpec], fitting box: CGSize, at now: @autoclosure () -> Date = .now
    ) -> WidgetFace.Content {
        guard !sources.isEmpty else { return .nothingChosen }
        var backoff = RequestBackoff.read(from: asking)
        // Photos did not answer last time, and it is not yet time to ask.
        guard backoff.wait(at: now()) == nil else { return held(for: sources, fitting: box) }
        do {
            let face = try asked(of: sources, fitting: box)
            if backoff.failures > 0 {
                backoff.answered()
                backoff.write(to: asking)
            }
            return face
        } catch is TimedOut {
            backoff.timedOut(at: now())
            backoff.write(to: asking)
            return held(for: sources, fitting: box)
        } catch PictureResizer.Failure.tooLarge {
            // No room just now for what a fetch would take: the picture
            // showing stays as it is, and the next wake asks again. Nothing
            // is wrong, so nothing is put over it.
            return pictures.last(for: sources, fitting: box).map { .picture($0) } ?? .scanning
        } catch {
            return Self.face(for: error)
        }
    }

    /// How long until Photos may be asked again. Nil when it may be asked
    /// now, which is when it answered last time. A wake that gets a wait is
    /// due again when the wait is over, whatever the widget is set to.
    public func wait(at now: Date = .now) -> TimeInterval? {
        RequestBackoff.read(from: asking).wait(at: now)
    }

    private func asked(of sources: [SourceSpec], fitting box: CGSize) throws -> WidgetFace.Content {
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
    }

    /// What shows while Photos is not answering: the picture shown last with
    /// "Scanning…" over it, or the icon with it when there has been none.
    private func held(for sources: [SourceSpec], fitting box: CGSize) -> WidgetFace.Content {
        pictures.last(for: sources, fitting: box).map { .scanningOver($0) } ?? .scanning
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
    ///
    /// **Only one framed as this widget is.** A picture made to fill another
    /// size is that size's shape, and one made to fit is not this one's.
    /// Fit and Actual Size share pictures.
    private func lastOfAnySize(from sources: [SourceSpec]) -> URL? {
        guard let root else { return nil }
        let manager = FileManager.default
        func folders(in folder: URL) -> [URL] {
            (try? manager.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        }
        let name = CacheFolders.name(forSources: CachedPreviewPictures.names(of: sources))
        var best: (pixels: Int, file: URL)?
        let suffix = CachedPreviewPictures.suffix(for: framing)
        for sized in folders(in: root).flatMap(folders(in:)) {
            // Named for its pixels, as in "600x600", and "600x600-fill" for
            // pictures made to fill.
            let named = sized.lastPathComponent
            let size = named.split(separator: "-", maxSplits: 1).first.map(String.init) ?? named
            guard String(named.dropFirst(size.count)) == suffix else { continue }
            let sides = size.split(separator: "x").compactMap { Int($0) }
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
    ///
    /// Nothing is asked while Photos is being waited for, and Photos not
    /// answering here starts the wait as it does in `turn`.
    public func makeReady(
        from sources: [SourceSpec], fitting box: CGSize, at now: @autoclosure () -> Date = .now
    ) {
        guard !sources.isEmpty else { return }
        var backoff = RequestBackoff.read(from: asking)
        guard backoff.wait(at: now()) == nil else { return }
        do {
            try pictures.makeReady(from: sources, fitting: box)
        } catch {
            backoff.timedOut(at: now())
            backoff.write(to: asking)
        }
    }

    /// Deletes every cache in `root` but those named in `keeping`, and says
    /// which it deleted.
    ///
    /// A widget's cache is a folder named for its size and its setting. When
    /// a widget is set to something else or taken away, its folder is left
    /// behind with a picture or two in it; this is what clears those away.
    ///
    /// **With nothing to keep, nothing is deleted.** Whoever asks is a widget
    /// being woken, so there is always one to keep, and an empty list means
    /// the list could not be had.
    @discardableResult
    public static func clearAway(in root: URL, keeping: Set<String>) -> [String] {
        guard !keeping.isEmpty else { return [] }
        let manager = FileManager.default
        let folders =
            (try? manager.contentsOfDirectory(
                at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        var cleared: [String] = []
        for folder in folders where !keeping.contains(folder.lastPathComponent) {
            guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                (try? manager.removeItem(at: folder)) != nil
            else { continue }
            cleared.append(folder.lastPathComponent)
        }
        return cleared
    }

    /// The face for a wake that failed. Photos refusing is the one failure a
    /// person can do something about, in the system's settings.
    static func face(for error: any Error) -> WidgetFace.Content {
        error is SystemPhotoLibraryPictures.Refused ? .noAccess : .noPhotos
    }
}
