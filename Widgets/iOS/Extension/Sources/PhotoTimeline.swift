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
//
// **How often is the widget's own setting**, and so is its cache: the system
// asks once for each different setting at each size, and not once for each
// widget. `PhotoWidgetSettings`.

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

struct PhotoTimeline: AppIntentTimelineProvider {
    /// The cache is not safe to call from two places at once, and a timeline
    /// can be asked for while the last wake is still fetching. So each wake's
    /// work is done in its turn, on a thread that may block: reading Photos
    /// does.
    private static let wakes = SerialWork(label: "com.sydpolk.photosgoround.widgets.wakes")

    func placeholder(in context: Context) -> PhotoEntry {
        PhotoEntry(date: .now, face: .scanning)
    }

    func snapshot(for settings: PhotoWidgetSettings, in context: Context) async -> PhotoEntry {
        let wake = Wake(context, settings.every)
        let face = wake.pictures.last(
            from: wake.sources, fitting: wake.box, inGallery: context.isPreview)
        // What the gallery was given for each size, and whether the picture
        // it names is still there to draw.
        Log.widget.info(
            """
            \(Log.widgetsTag, privacy: .public) snapshot, \
            \(String(describing: context.family), privacy: .public), \
            \(Int(context.displaySize.width))x\(Int(context.displaySize.height)) points, \
            \(Self.describe(face), privacy: .public)
            """)
        return PhotoEntry(date: .now, face: face)
    }

    /// A face in a few words, for the log.
    private static func describe(_ face: WidgetFace.Content) -> String {
        switch face {
        case .picture(let file):
            let there = FileManager.default.fileExists(atPath: file.path(percentEncoded: false))
            return "picture \(file.lastPathComponent)\(there ? "" : ", which is gone")"
        case .scanningOver(let file): return "scanning, over picture \(file.lastPathComponent)"
        case .nothingChosen: return "nothing chosen"
        case .scanning: return "scanning"
        case .noPhotos: return "no photos"
        case .noAccess: return "no access"
        }
    }

    func timeline(for settings: PhotoWidgetSettings, in context: Context) async -> Timeline<PhotoEntry> {
        let wake = Wake(context, settings.every)
        let now = Date.now
        // Once for each reload, with the size the system handed the widget
        // and what the widget is set to.
        Log.widget.notice(
            """
            \(Log.widgetsTag, privacy: .public) timeline asked, \
            \(String(describing: context.family), privacy: .public), \
            \(Int(context.displaySize.width))x\(Int(context.displaySize.height)) points, \
            \(wake.sources.count) sources, every \(wake.every.rawValue) seconds
            """)

        let turned = try? await Self.wakes.run {
            wake.pictures.turn(from: wake.sources, fitting: wake.box)
        }
        let face = turned ?? .noPhotos
        let showsPicture = if case .picture = face { true } else { false }
        // What the wake came to, and how long it took: a wake that never gets
        // here was stopped by the system or is still waiting on a source.
        Log.widget.notice(
            """
            \(Log.widgetsTag, privacy: .public) timeline answered, \
            \(String(describing: context.family), privacy: .public), \
            \(Self.describe(face), privacy: .public), after \
            \(Int(Date.now.timeIntervalSince(now).rounded())) seconds, \
            \(Wake.memory(), privacy: .public)
            """)

        // One more for next time, without this one waiting for it. If the
        // system stops the wake first, the next one fetches for itself.
        if showsPicture {
            Self.wakes.detached { wake.pictures.makeReady(from: wake.sources, fitting: wake.box) }
        }
        // And nobody waits for the tidying.
        Task.detached { await Self.clearAway() }
        // Photos did not answer: due again when the wait is over, and not at
        // the widget's own time.
        let wait = wake.pictures.wait()
        if let wait {
            Log.widget.notice(
                """
                \(Log.widgetsTag, privacy: .public) Photos did not answer, asking again in \
                \(Int(wait.rounded(.up))) seconds
                """)
        }
        // Due at the widget's own time whatever it shows. With nothing to show
        // it was a quarter of an hour, until Syd, 2026-10-11: "the widget
        // looks again when the system pings it".
        let due = wait.map { Date.now + $0 } ?? now + wake.every.seconds
        return Timeline(entries: [PhotoEntry(date: now, face: face)], policy: .after(due))
    }
}

extension PhotoTimeline {
    /// Clears away the caches of settings no placed widget has: a widget set
    /// to something else, or taken off the Home Screen, leaves its folder
    /// behind.
    fileprivate static func clearAway() async {
        guard let placed = try? await WidgetCenter.shared.currentConfigurations() else { return }
        var keeping: Set<String> = []
        for widget in placed where widget.kind == PhotoWidget.kind {
            // One whose settings cannot be read could be set to anything, so
            // nothing is cleared.
            guard let settings = widget.widgetConfigurationIntent(of: PhotoWidgetSettings.self) else { return }
            keeping.insert(Wake.folder(for: widget.family, every: settings.every))
        }
        let kept = keeping
        wakes.detached {
            let cleared = WidgetPictures.clearAway(in: Wake.caches, keeping: kept)
            guard !cleared.isEmpty else { return }
            Log.widget.info(
                """
                \(Log.widgetsTag, privacy: .public) cleared away \(cleared.count) caches no widget has: \
                \(cleared.sorted().joined(separator: ", "), privacy: .public)
                """)
        }
    }
}

/// What one wake works with: what is chosen, the widget's size in pixels, how
/// often it changes, and the widget's own cache.
private struct Wake: Sendable {
    let sources: [SourceSpec]
    let box: CGSize
    let every: ChangeEvery
    let pictures: WidgetPictures

    init(_ context: TimelineProviderContext, _ every: ChangeEvery) {
        self.every = every

        // The App Group's preferences, which the app writes. The group's name
        // is in `Info.plist` because it differs by configuration.
        let group = Bundle.main.object(forInfoDictionaryKey: "PGRWidgetAppGroup") as? String
        sources = Preferences(suiteName: group).sources.filter(\.enabled)

        // The size the system hands a widget is the only place its real size
        // on this device can be learned, so it is written where the app's
        // preview reads it. The gallery asks for every size it offers.
        RecordedWidgetSizes(suiteName: group)
            .record(context.displaySize, forFamily: String(describing: context.family))

        let family = String(describing: context.family)
        let scale = context.environmentVariants.displayScale?.max() ?? 3
        box = CGSize(
            width: context.displaySize.width * scale, height: context.displaySize.height * scale)

        pictures = WidgetPictures(
            directory: Self.caches.appending(
                path: Self.folder(for: context.family, every: every), directoryHint: .isDirectory),
            // So the gallery can show a size that has no picture yet one of
            // another size's.
            among: Self.caches,
            bookmarks: Self.bookmarks,
            onFetch: { Self.fetched($0, for: family) })
    }

    /// What the extension holds, against the limit it is held to: about
    /// 30 MB, which a phone enforces and a simulator is not expected to.
    /// `Plans/PGR Widgets - iOS.md`, Phase 5.
    static func memory() -> String {
        Footprint.now().map(Footprint.againstLimit) ?? "memory unread"
    }

    /// One line for each fetch, with the memory as it ends: a fetch is where
    /// the extension holds most, and the kernel's peak says how much that
    /// was. The original's size is there so a high peak names its picture.
    private static func fetched(_ resize: PictureResizer.Resize, for family: String) {
        Log.widget.notice(
            """
            \(Log.widgetsTag, privacy: .public) fetched, \(family, privacy: .public), \
            \(resize.said, privacy: .public), \(memory(), privacy: .public)
            """)
    }

    /// What a file or folder the person chose in the app is opened through:
    /// the bookmark the app left for it. One for the life of the process,
    /// since what it has opened stays open from one wake to the next.
    private static let bookmarks = BookmarkedSources.inAppGroup(
        Bundle.main.object(forInfoDictionaryKey: "PGRWidgetAppGroup") as? String)

    /// Where every widget's cache is: the extension's own, apart from the
    /// app's preview.
    static var caches: URL {
        URL.cachesDirectory.appending(path: "Widgets", directoryHint: .isDirectory)
    }

    /// One cache for each setting at each size, which is as near as there is
    /// to one for each widget: `systemSmall-300`.
    static func folder(for family: WidgetKit.WidgetFamily, every: ChangeEvery) -> String {
        "\(family)-\(every.rawValue)"
    }
}
