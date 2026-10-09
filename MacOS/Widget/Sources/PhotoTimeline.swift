// Turning a TinyCache into a WidgetKit timeline. `Plans/Photos-Go-Round
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
// chose this: "go back to your original rule exactly". A wake now fetches one
// picture, two the first time.
//
// **So every change of picture is a reload**, and how often a widget changes
// is how often the system will reload it, whatever the interval asks for.

import Foundation
import PhotosGoRoundAgentAPI
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
        let specs = Settings.sources()
        let cache = Settings.cache(for: context, showing: specs)
        let entry = Self.lock.withLock {
            do {
                let picture = try cache.preview()
                return PhotoEntry(
                    date: .now, picture: picture, trouble: picture == nil ? Self.nothing(in: specs) : nil)
            } catch {
                return PhotoEntry(date: .now, picture: nil, trouble: Self.describe(error))
            }
        }
        WidgetLog.note("snapshot, \(context.family)")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<PhotoEntry>) -> Void) {
        let now = Date.now
        let specs = Settings.sources()
        let cache = Settings.cache(for: context, showing: specs)
        WidgetLog.note(
            "timeline asked, \(context.family), \(Int(context.displaySize.width))×\(Int(context.displaySize.height)) points, \(Settings.describe(specs))")

        let (entries, reload) = Self.lock.withLock { () -> ([PhotoEntry], Date) in
            do {
                let showings = try cache.take(upTo: 1, from: now, every: Settings.interval)
                guard let last = showings.last else {
                    return ([PhotoEntry(date: now, picture: nil, trouble: Self.nothing(in: specs))], now + Self.retry)
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
    }

    /// Why there is nothing to show when nothing went wrong.
    private static func nothing(in specs: [SourceSpec]) -> String {
        specs.isEmpty
            ? "No sources are set in Photos-Go-Round."
            : "No pictures in the sources set in Photos-Go-Round: \(Settings.describe(specs))."
    }

    /// What the system said. The widget shows this on its face, since a
    /// refusal is otherwise an empty widget.
    private static func describe(_ error: any Error) -> String {
        "Can't get a picture: \(error.localizedDescription)"
    }
}
