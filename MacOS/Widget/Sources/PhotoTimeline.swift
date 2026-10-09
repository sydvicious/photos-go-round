// Turning a TinyCache into a WidgetKit timeline. `Plans/Photos-Go-Round
// Widgets.md`.
//
// **A photograph changes because a timeline has several entries**, each dated
// one interval after the last, which the system shows in turn without waking
// this extension. So a timeline can show only what is already on disk when it
// is handed over.
//
// **What each wake does**, Syd, 2026-10-08: "widget has to request its first
// picture from the source and serve it, and then fill the cache with one more
// image … if the extension survives and is still running, it can go ahead and
// fill the cache while that is true up to 20 pictures".

import Foundation
import TinyCache
import WidgetKit

struct PhotoEntry: TimelineEntry {
    let date: Date
    /// The photograph to show, already at the widget's size.
    let picture: URL?
    /// Why there is no photograph, in words a person can act on.
    let trouble: String?
}

struct PhotoTimeline: TimelineProvider {
    /// TinyCache is not safe to call from two places at once, and a timeline
    /// can be asked for while the last wake is still filling.
    private static let lock = NSLock()

    /// How long to wait before asking again when there was nothing to show.
    private static let retry: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> PhotoEntry {
        PhotoEntry(date: .now, picture: nil, trouble: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (PhotoEntry) -> Void) {
        let cache = Settings.cache(for: context)
        let entry = Self.lock.withLock {
            do {
                return PhotoEntry(date: .now, picture: try cache.preview(), trouble: nil)
            } catch {
                return PhotoEntry(date: .now, picture: nil, trouble: Self.describe(error))
            }
        }
        WidgetLog.note("snapshot, \(context.family)")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<PhotoEntry>) -> Void) {
        let now = Date.now
        let cache = Settings.cache(for: context)
        WidgetLog.note("timeline asked, \(context.family), \(Int(context.displaySize.width))×\(Int(context.displaySize.height)) points")

        let (entries, reload) = Self.lock.withLock { () -> ([PhotoEntry], Date) in
            do {
                let showings = try cache.take(
                    upTo: TinyCache.defaultFillLimit, from: now, every: Settings.interval)
                guard let last = showings.last else {
                    let trouble = "No pictures in \(Settings.folder.path(percentEncoded: false))"
                    return ([PhotoEntry(date: now, picture: nil, trouble: trouble)], now + Self.retry)
                }
                // One more for next time, which is all a wake can count on.
                _ = try? cache.fill(to: 1)
                let entries = showings.map { PhotoEntry(date: $0.date, picture: $0.file, trouble: nil) }
                return (entries, last.date + Settings.interval)
            } catch {
                return ([PhotoEntry(date: now, picture: nil, trouble: Self.describe(error))], now + Self.retry)
            }
        }

        WidgetLog.note("timeline handed over, \(context.family), \(entries.count) entries, \(entries.first?.trouble ?? "no trouble")")
        completion(Timeline(entries: entries, policy: .after(reload)))

        // Whatever time the system leaves this process is spent filling, one
        // picture at a time, so that being stopped part-way loses nothing.
        // Measured 2026-10-08: that time is a second or two. A fill that waited
        // two seconds after the handover never ran at all.
        let family = "\(context.family)"
        Task.detached(priority: .utility) {
            Self.keepFilling(cache, family: family)
        }
    }

    private static func keepFilling(_ cache: TinyCache, family: String) {
        for _ in 0..<TinyCache.defaultFillLimit {
            let waiting = lock.withLock { () -> Int? in
                guard
                    let waiting = try? cache.waiting().count,
                    let added = try? cache.fill(to: waiting + 1), added > 0
                else { return nil }
                return waiting + added
            }
            guard let waiting else { return }
            WidgetLog.note("filled, \(family), \(waiting) waiting")
        }
    }

    /// The folder and what the system said about it. The widget shows this on
    /// its face, since a sandbox refusal is otherwise an empty widget.
    private static func describe(_ error: any Error) -> String {
        """
        Can't read \(Settings.folder.path(percentEncoded: false)): \(error.localizedDescription) \
        \(BookmarkedFolder.report)
        """
    }
}
