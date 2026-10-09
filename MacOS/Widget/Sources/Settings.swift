// What the widget shows and how often. `Plans/Photos-Go-Round Widgets.md`,
// *Next: the app's sources, then Photos*.
//
// **The sources are the app's.** Syd, 2026-10-08: "the widgets sharing the
// app's sources. the only setting a widget would have is how often it updates."
// The list is read from the app's preferences on every wake, so a source added
// in the app is in the next timeline.
//
// **The interval is still hard-coded**, at five minutes. It becomes each
// widget's own setting.

import CoreGraphics
import Foundation
import PhotosGoRoundAgentAPI
import TinyCache
import WidgetKit

enum Settings {
    static let kind = "PhotosGoRoundPhotoWidget"

    /// How long each photograph stays up. Syd, 2026-10-09: "set the value for
    /// widget refresh to five minutes until we have individual settings
    /// panels." It was one minute through the first night's run.
    static let interval: TimeInterval = 5 * 60

    /// *Photos-Go-Round*, with this build's suffix, from `Info.plist`. Debug,
    /// Release and Claude builds each show under their own name in the widget
    /// gallery.
    static let displayName =
        Bundle.main.object(forInfoDictionaryKey: "PGRWidgetName") as? String ?? "Photos-Go-Round"

    /// The app's sources that are switched on, as the app's preferences have
    /// them. The domain is asked for rather than spelled: it carries the build
    /// variant, so a Debug widget reads the Debug app's sources.
    static func sources() -> [SourceSpec] {
        Preferences(suiteName: MacHostEnvironment.preferenceDomain()).sources.filter(\.enabled)
    }

    /// One source made of all of `specs` that a widget can show: folders and
    /// Photos collections. Each has an equal chance, whatever it holds.
    static func source(for specs: [SourceSpec]) -> any PictureSource {
        SeveralSources(
            specs.compactMap { spec -> (any PictureSource)? in
                switch spec.kind {
                case .folder:
                    // Through the bookmark the app left when there is one; by
                    // its path otherwise, which the privacy system refuses for
                    // a folder it protects.
                    let folder =
                        OpenedFolders.folder(at: spec.locator)
                        ?? URL(fileURLWithPath: spec.locator, isDirectory: true)
                    return FolderSource(folder: folder, recursive: spec.recursive)
                case .photosCollection:
                    return PhotosSource(collections: [spec.locator])
                default:
                    return nil
                }
            })
    }

    /// `2 folders, 3 Photos collections`, for the log and for the widget's face
    /// when it has nothing to show.
    static func describe(_ specs: [SourceSpec]) -> String {
        let folders = specs.filter { $0.kind == .folder }.count
        let collections = specs.filter { $0.kind == .photosCollection }.count
        let others = specs.count - folders - collections
        return "\(folders) folders, \(collections) Photos collections"
            + (others > 0 ? ", \(others) of other kinds not shown" : "")
    }

    /// This widget's TinyCache.
    ///
    /// **One per size, for now.** Each widget is to have its own, found by its
    /// name, and how a placed widget keeps a name is still to be found out. Two
    /// widgets of one size share a cache until then.
    static func cache(for context: TimelineProviderContext, showing specs: [SourceSpec]) -> TinyCache {
        let caches =
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let scale = context.environmentVariants.displayScale?.max() ?? 2
        let family = "\(context.family)"
        let box = CGSize(
            width: context.displaySize.width * scale, height: context.displaySize.height * scale)
        // Kept per list of sources, so that a source taken off the list stops
        // being shown: the pictures cached while it was on are deleted.
        let ours = caches.appending(path: "TinyCache/\(context.family)", directoryHint: .isDirectory)
        let names = specs.map { "\($0.kind.rawValue)|\($0.locator)|\($0.recursive)" }
        let directory = (try? CacheFolders.folder(in: ours, forSources: names)) ?? ours
        return TinyCache(
            directory: directory,
            source: source(for: specs), fitting: box,
            onFetch: { WidgetLog.fetched($0, for: family) })
    }
}
