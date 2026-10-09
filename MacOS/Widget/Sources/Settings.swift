// The widget's settings, hard-coded for the proof of concept.
// `Plans/Photos-Go-Round Widgets.md`, *The proof of concept, in the existing app*.
//
// Syd, 2026-10-08: "hard code settings to 1 minute with a source of
// ~/Documents/Coins/Raw Coin Images (recursive) for now". The menubar app is
// where these will be set; there is no menubar app yet.

import CoreGraphics
import Foundation
import TinyCache
import WidgetKit

enum Settings {
    static let kind = "PhotosGoRoundPhotoWidget"

    /// How long each photograph stays up.
    static let interval: TimeInterval = 60

    /// *Photos-Go-Round*, with this build's suffix, from `Info.plist`. Debug,
    /// Release and Claude builds each show under their own name in the widget
    /// gallery.
    static let displayName =
        Bundle.main.object(forInfoDictionaryKey: "PGRWidgetName") as? String ?? "Photos-Go-Round"

    /// The folder the photographs come from, with every folder inside it.
    ///
    /// **The real home folder, asked of the password database.** A sandboxed
    /// process is told its container is its home, so `NSHomeDirectory()` here
    /// is `~/Library/Containers/…/Data`. The entitlement that lets this
    /// extension read the folder names it relative to the real one.
    static let folder: URL = {
        let home =
            getpwuid(getuid()).flatMap { $0.pointee.pw_dir }.map { String(cString: $0) }
            ?? NSHomeDirectory()
        return URL(fileURLWithPath: home, isDirectory: true)
            .appending(path: "Documents/Coins/Raw Coin Images", directoryHint: .isDirectory)
    }()

    /// This widget's TinyCache.
    ///
    /// **One per size, for now.** Each widget is to have its own, found by its
    /// name, and how a placed widget keeps a name is still to be found out. Two
    /// widgets of one size share a cache until then.
    static func cache(for context: TimelineProviderContext) -> TinyCache {
        let caches =
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let scale = context.environmentVariants.displayScale?.max() ?? 2
        let family = "\(context.family)"
        let box = CGSize(
            width: context.displaySize.width * scale, height: context.displaySize.height * scale)
        return TinyCache(
            directory: caches.appending(path: "TinyCache/\(context.family)", directoryHint: .isDirectory),
            // Through a bookmark from the app when one opens the folder; by its
            // path otherwise, which the privacy system refuses.
            source: FolderSource(folder: BookmarkedFolder.folder() ?? folder), fitting: box,
            onFetch: { WidgetLog.fetched($0, for: family) })
    }
}
