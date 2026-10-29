// What every widget shares: the app's sources, and how the app says pictures
// sit. `Plans/Photos-Go-Round Widgets.md`, *Next: the app's sources, then
// Photos*, and `Plans/Widget Settings.md`, *On the Mac*.
//
// **The sources are the app's.** Syd, 2026-10-08: "the widgets sharing the
// app's sources. the only setting a widget would have is how often it updates."
// They are read from the app's preferences on every wake, so a source added in
// the app is in the next timeline. How often, and how the pictures sit, are
// each widget's own: `PhotoWidgetSettings`.

import Foundation
import PhotosGoRoundAgentAPI
import TinyCache

enum Settings {
    static let kind = "PhotosGoRoundPhotoWidget"

    /// *Photos-Go-Round*, with this build's suffix, from `Info.plist`. Debug,
    /// Release and Claude builds each show under their own name in the widget
    /// gallery.
    static let displayName =
        Bundle.main.object(forInfoDictionaryKey: "PGRWidgetName") as? String ?? "Photos-Go-Round"

    /// The app's preferences. The domain is asked for rather than spelled: it
    /// carries the build variant, so a Debug widget reads the Debug app's.
    static var preferences: Preferences {
        Preferences(suiteName: MacHostEnvironment.preferenceDomain())
    }

    /// The app's sources that are switched on.
    static func sources() -> [SourceSpec] {
        preferences.sources.filter(\.enabled)
    }

    /// What a folder the person chose is opened through: the bookmark the app
    /// left in the App Group container, whose name this extension's
    /// `Info.plist` states. One for the life of the process, since what it
    /// has opened stays open from one wake to the next. Without it a folder
    /// is read by its path, which the privacy system refuses for a folder it
    /// protects.
    static let bookmarks: BookmarkedSources? = {
        guard
            let group = Bundle.main.object(forInfoDictionaryKey: "PGRWidgetAppGroup") as? String,
            let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else {
            WidgetLog.note("no App Group container, so no bookmarks")
            return nil
        }
        return BookmarkedSources(
            directory: container.appending(path: "WidgetSource", directoryHint: .isDirectory),
            note: { WidgetLog.note($0) })
    }()

    /// Where every widget's cache is, in the extension's own caches.
    static var caches: URL {
        URL.cachesDirectory.appending(path: "Widgets", directoryHint: .isDirectory)
    }

    /// Where every widget's cache was, one for each size, before each widget
    /// had settings of its own. Cleared away.
    static var formerCaches: URL {
        URL.cachesDirectory.appending(path: "TinyCache", directoryHint: .isDirectory)
    }
}
