// Which setting a widget had before its settings changed, so that it can show
// the same photograph again. Syd, 2026-10-31: "try to display the same pic in
// a widget when changing widget fit/fill/actual size settings", and of the
// Mac: "That last point applies to Mac widgets as well". **Whatever is
// changed**: Syd, 2026-11-01, "You see a picture in a widget, you invoke
// widget settings. That is the picture we are working with, no matter what
// settings are or are not changed."
//
// **A wake is not told why it came**, nor which widget it is for: the system
// asks once for each setting at each size. So it is worked out. A setting of
// the same size as one that has been woken and that no placed widget has now
// is that one changed. **Of several, the one with the same interval**: when the
// app's own Fit, Fill or Actual Size changes, every widget following it
// changes at once, and their intervals tell them apart. The settings woken are
// kept in a file beside the caches, since the next wake may be a new process.
//
// **That holds when another widget of the size already has the new settings**:
// the system gives the two one timeline, so the changed widget keeps its
// picture and the other changes to it. Syd, 2026-11-01, chose that over the
// changed widget taking the other's picture.
//
// **The setting replaced keeps its cache until it has been drawn from.** When
// the app's own setting changes, every widget following it is reloaded, and
// each wake clears away the caches no widget has; without this, the first
// would clear away what the others are to draw again.

import Foundation
import PhotosGoRoundAgentAPI

/// A setting as a wake sees it: the widget's size, how often it changes, and
/// how its pictures sit, with "As in the app" resolved.
public struct WidgetSetting: Hashable, Sendable {
    /// The widget's size, as WidgetKit names it.
    public let family: String
    public let every: ChangeEvery
    public let framing: Framing

    public init(family: String, every: ChangeEvery, framing: Framing) {
        self.family = family
        self.every = every
        self.framing = framing
    }

    /// Where its pictures are kept, under the caches' folder.
    public var folder: String {
        WidgetPictures.folder(forFamily: family, every: every, framing: framing)
    }
}

public struct WokenSettings: Sendable {
    private let file: URL

    /// - Parameter root: The folder that holds every widget's cache.
    public init(in root: URL) {
        file = root.appending(path: "woken.json")
    }

    /// Notes a wake for `setting`, and gives back the setting it replaced:
    /// one of the same size, woken before and placed no more; of several,
    /// the one with the same interval. Nil when it replaced nothing.
    public func woke(_ setting: WidgetSetting, placed: Set<WidgetSetting>) -> WidgetSetting? {
        var woken = current(placed: placed)
        let replaced =
            woken
            .filter { $0.family == setting.family && !placed.contains($0) }
            .min { order($0, for: setting) < order($1, for: setting) }
        if let replaced {
            woken.remove(replaced)
        }
        let (added, _) = woken.insert(setting)
        if added || replaced != nil {
            write(woken)
        }
        return replaced
    }

    /// Which of several it replaced comes first: the same interval, and
    /// otherwise any, always the same one.
    private func order(_ former: WidgetSetting, for setting: WidgetSetting) -> (Int, Int, String) {
        (former.every == setting.every ? 0 : 1, former.every.rawValue, former.framing.rawValue)
    }

    /// The caches to keep: the placed settings', and those of settings
    /// replaced and not yet drawn from.
    public func folders(placed: Set<WidgetSetting>) -> Set<String> {
        Set(placed.union(current(placed: placed)).map(\.folder))
    }

    /// The settings woken, less those of a size no widget has: no wake is
    /// coming to draw from them.
    private func current(placed: Set<WidgetSetting>) -> Set<WidgetSetting> {
        let families = Set(placed.map(\.family))
        return read().filter { families.contains($0.family) }
    }

    private struct Kept: Codable {
        let family: String
        let every: Int
        let framing: String
    }

    private func read() -> Set<WidgetSetting> {
        guard let data = try? Data(contentsOf: file),
            let kept = try? JSONDecoder().decode([Kept].self, from: data)
        else { return [] }
        return Set(
            kept.compactMap { kept in
                guard let every = ChangeEvery(rawValue: kept.every), let framing = Framing(rawValue: kept.framing)
                else { return nil }
                return WidgetSetting(family: kept.family, every: every, framing: framing)
            })
    }

    private func write(_ woken: Set<WidgetSetting>) {
        let kept = woken.map { Kept(family: $0.family, every: $0.every.rawValue, framing: $0.framing.rawValue) }
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(kept).write(to: file, options: .atomic)
    }
}
