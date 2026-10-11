// Turning the chosen sources into a WidgetKit timeline.
// `Plans/PGR Widgets - iOS.md`, and `Plans/Photos-Go-Round Widgets.md` for
// the rule the Mac's widget settled on.
//
// **Each wake shows one picture and keeps one more.** Every change of picture
// is a reload, so how often a widget changes is how often the system will
// reload it, whatever the interval asks for.
//
// **What a wake does is `WidgetPictures`**, in the shared package, where it
// is tested. This file is the WidgetKit side of it.

import Foundation
import OSLog
import PhotosGoRoundAgentAPI
import PhotosGoRoundWidgetFace
import PhotosGoRoundWidgetSettings
import TinyCache
import WidgetKit

struct PhotoEntry: TimelineEntry {
    let date: Date
    let face: WidgetFace.Content
}

struct PhotoTimeline: TimelineProvider {
    /// The cache is not safe to call from two places at once, and a timeline
    /// can be asked for while the last wake is still fetching.
    private static let lock = NSLock()

    /// How long each photograph stays up. Syd, 2026-10-09: "initially widgets
    /// are set to change every five minutes until we do settings".
    private static let interval: TimeInterval = 5 * 60

    /// How long to wait before asking again when there was nothing to show.
    /// The app also reloads the widgets when a person leaves it, so a change
    /// made there does not wait this long.
    private static let retry: TimeInterval = 15 * 60

    private static let log = Logger(subsystem: "com.sydpolk.photosgoround", category: "widget")

    func placeholder(in context: Context) -> PhotoEntry {
        PhotoEntry(date: .now, face: .scanning)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (PhotoEntry) -> Void) {
        let wake = Wake(context)
        completion(PhotoEntry(date: .now, face: wake.pictures.last(from: wake.sources, fitting: wake.box)))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<PhotoEntry>) -> Void) {
        let wake = Wake(context)
        let now = Date.now
        Self.log.notice(
            """
            \(SystemPhotoLibraryPictures.logTag, privacy: .public) timeline asked, \
            \(String(describing: context.family), privacy: .public), \
            \(Int(context.displaySize.width))x\(Int(context.displaySize.height)) points, \
            \(wake.sources.count) sources
            """)

        let face = Self.lock.withLock { wake.pictures.turn(from: wake.sources, fitting: wake.box) }
        let showsPicture = if case .picture = face { true } else { false }
        completion(
            Timeline(
                entries: [PhotoEntry(date: now, face: face)],
                policy: .after(now + (showsPicture ? Self.interval : Self.retry))))

        // One more for next time, after this one has been handed over. If the
        // system stops the wake first, the next one fetches for itself.
        if showsPicture {
            Self.lock.withLock { wake.pictures.makeReady(from: wake.sources, fitting: wake.box) }
        }
    }
}

/// What one wake works with: what is chosen, the widget's size in pixels, and
/// the widget's own cache.
private struct Wake {
    let sources: [SourceSpec]
    let box: CGSize
    let pictures: WidgetPictures

    init(_ context: TimelineProviderContext) {
        // The App Group's preferences, which the app writes. The group's name
        // is in `Info.plist` because it differs by configuration.
        let group = Bundle.main.object(forInfoDictionaryKey: "PGRWidgetAppGroup") as? String
        sources = Preferences(suiteName: group).sources.filter(\.enabled)

        // The size the system hands a widget is the only place its real size
        // on this device can be learned, so it is written where the app's
        // preview reads it. The gallery asks for every size it offers.
        RecordedWidgetSizes(suiteName: group)
            .record(context.displaySize, forFamily: String(describing: context.family))

        let scale = context.environmentVariants.displayScale?.max() ?? 3
        box = CGSize(
            width: context.displaySize.width * scale, height: context.displaySize.height * scale)

        // One cache for each size, for now, as on the Mac: two widgets of one
        // size share it. It is the extension's own, apart from the app's
        // preview.
        pictures = WidgetPictures(
            directory: URL.cachesDirectory
                .appending(path: "Widgets", directoryHint: .isDirectory)
                .appending(path: String(describing: context.family), directoryHint: .isDirectory))
    }
}
