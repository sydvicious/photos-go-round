// Turning the app's sources into a WidgetKit timeline. `Plans/Photos-Go-Round
// Widgets.md`.
//
// **Each wake shows one picture and keeps one more.** Syd, 2026-10-08: "widget
// has to request its first picture from the source and serve it, and then fill
// the cache with one more image. There is probably only one image in the cache
// at a time."
//
// **And nothing further.** The first builds went on filling toward 20 for as
// long as the system left the process running, so that a timeline could carry
// many entries. Measured 2026-10-09: a wake's memory followed how much the wake
// did, about half a megabyte a fetch, and a wake that fetched 32 pictures
// peaked at 38 MB with no large photograph in it. Asked how to bound that, Syd
// chose this: "go back to your original rule exactly".
//
// **So every change of picture is a reload**, and how often a widget changes
// is how often the system will reload it, whatever the interval asks for.
//
// **What a wake does is `WidgetPictures`**, in the shared package, as on iOS:
// the iOS extension's timeline is this one's pattern. Syd, 2026-10-28: "please
// try to share code between mac and ios if possible". `Plans/Widget
// Settings.md`, *On the Mac*.

import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundWidgetFace
import PhotosGoRoundWidgetSettings
import TinyCache
import WidgetKit

struct PhotoEntry: TimelineEntry {
    let date: Date
    let face: WidgetFace.Content
    /// Whether a picture smaller than the widget is drawn larger. Not at
    /// Actual Size.
    var enlarges = true
}

struct PhotoTimeline: AppIntentTimelineProvider {
    /// The cache is not safe to call from two places at once, and a timeline
    /// can be asked for while the last wake is still fetching. So each wake's
    /// work is done in its turn, on a thread that may block: reading Photos
    /// does.
    private static let wakes = SerialWork(label: "com.sydpolk.photosgoround.widget.wakes")

    func placeholder(in context: Context) -> PhotoEntry {
        PhotoEntry(date: .now, face: .scanning)
    }

    func snapshot(for settings: PhotoWidgetSettings, in context: Context) async -> PhotoEntry {
        let wake = Wake(context, settings)
        let face = wake.pictures.last(from: wake.sources, fitting: wake.box, inGallery: context.isPreview)
        WidgetLog.note("snapshot, \(context.family), \(Self.describe(face))")
        return PhotoEntry(date: .now, face: face, enlarges: wake.framing.enlarges)
    }

    func timeline(for settings: PhotoWidgetSettings, in context: Context) async -> Timeline<PhotoEntry> {
        let wake = Wake(context, settings)
        let now = Date.now
        WidgetLog.note(
            """
            timeline asked, \(context.family), \
            \(Int(context.displaySize.width))×\(Int(context.displaySize.height)) points, \
            \(wake.sources.count) sources, every \(wake.every.rawValue) seconds, \(wake.framing.rawValue)
            """)

        let turned = try? await Self.wakes.run {
            wake.pictures.turn(from: wake.sources, fitting: wake.box)
        }
        let face = turned ?? .noPhotos
        let showsPicture = if case .picture = face { true } else { false }
        WidgetLog.note(
            """
            timeline answered, \(context.family), \(Self.describe(face)), after \
            \(Int(Date.now.timeIntervalSince(now).rounded())) seconds
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
            WidgetLog.note("Photos did not answer, asking again in \(Int(wait.rounded(.up))) seconds")
        }
        let due = wait.map { Date.now + $0 } ?? now + wake.every.seconds
        return Timeline(
            entries: [PhotoEntry(date: now, face: face, enlarges: wake.framing.enlarges)], policy: .after(due))
    }

    /// A face in a few words, for the log.
    private static func describe(_ face: WidgetFace.Content) -> String {
        switch face {
        case .picture(let file): "picture \(file.lastPathComponent)"
        case .scanningOver(let file): "scanning, over picture \(file.lastPathComponent)"
        case .nothingChosen: "nothing chosen"
        case .scanning: "scanning"
        case .noPhotos: "no photos"
        case .noAccess: "no access"
        }
    }
}

extension PhotoTimeline {
    /// Clears away the caches of settings no placed widget has: a widget set
    /// to something else, or taken off the desktop, leaves its folder behind.
    /// Each is named for what its settings come to, so a widget following the
    /// app and one set to the same keep one folder. And the caches from
    /// before there were settings, once.
    fileprivate static func clearAway() async {
        guard let placed = try? await WidgetCenter.shared.currentConfigurations() else { return }
        let app = Settings.preferences.widgetFraming
        var keeping: Set<String> = []
        for widget in placed where widget.kind == Settings.kind {
            // One whose settings cannot be read could be set to anything, so
            // nothing is cleared.
            guard let settings = widget.widgetConfigurationIntent(of: PhotoWidgetSettings.self) else { return }
            keeping.insert(
                WidgetPictures.folder(
                    forFamily: String(describing: widget.family), every: settings.every,
                    framing: settings.framing.resolved(app: app)))
        }
        let kept = keeping
        wakes.detached {
            if (try? FileManager.default.removeItem(at: Settings.formerCaches)) != nil {
                WidgetLog.note("cleared away the caches from before each widget had settings")
            }
            let cleared = WidgetPictures.clearAway(in: Settings.caches, keeping: kept)
            guard !cleared.isEmpty else { return }
            WidgetLog.note(
                "cleared away \(cleared.count) caches no widget has: \(cleared.sorted().joined(separator: ", "))")
        }
    }
}

/// What one wake works with: what is chosen, the widget's size in pixels, how
/// often it changes, how its pictures sit in it, and the widget's own cache.
private struct Wake: Sendable {
    let sources: [SourceSpec]
    let box: CGSize
    let every: ChangeEvery
    let framing: Framing
    let pictures: WidgetPictures

    init(_ context: TimelineProviderContext, _ settings: PhotoWidgetSettings) {
        every = settings.every
        sources = Settings.sources()
        // The widget's own choice, or the app's.
        let framing = settings.framing.resolved(app: Settings.preferences.widgetFraming)
        self.framing = framing

        let family = String(describing: context.family)
        // The size the system hands a widget is the only place its real size
        // can be learned, so it is written where the app's preview reads it.
        // The gallery asks for every size it offers.
        RecordedWidgetSizes(suiteName: Bundle.main.object(forInfoDictionaryKey: "PGRWidgetAppGroup") as? String)
            .record(context.displaySize, forFamily: family)
        let scale = context.environmentVariants.displayScale?.max() ?? 2
        box = CGSize(
            width: context.displaySize.width * scale, height: context.displaySize.height * scale)

        pictures = WidgetPictures(
            directory: Settings.caches.appending(
                path: WidgetPictures.folder(forFamily: family, every: every, framing: framing),
                directoryHint: .isDirectory),
            // So the gallery can show a size that has no picture yet one of
            // another size's.
            among: Settings.caches,
            bookmarks: Settings.bookmarks,
            onFetch: { WidgetLog.fetched($0, for: family) },
            framing: framing)
    }
}
