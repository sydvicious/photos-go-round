// The sources a person has chosen, as the settings screen's two lists.
// `Plans/PGR Widgets - iOS.md`.
//
// **Kept in preferences, and those are the App Group's.** The app writes the
// list and the widget extension reads it, each in its own process, so the
// domain handed in here is the one both can open. The list itself is the
// `SourceSpec` list the rest of Photos-Go-Round keeps.
//
// **Two lists over one.** The screen shows Photos collections apart from files
// and folders; they are stored together, in the order they were chosen.

import Foundation
import OSLog
import PhotosGoRoundAgentAPI
import TinyCache

public struct ChosenSources: Sendable {
    private let preferences: Preferences

    public init(preferences: Preferences) {
        self.preferences = preferences
    }

    /// The photographs the person picked for the app, as a source. There is
    /// one of it, so its locator is only a name.
    public static let selectedPhotos = SourceSpec(kind: .photosSelection, locator: "selected")

    /// Whether the selection is a source now, which it is while Photos access
    /// is limited to one.
    public var holdsSelectedPhotos: Bool {
        preferences.sources.contains { $0.kind == .photosSelection }
    }

    /// Whether the selection is a source the widgets show from. It is not
    /// once the person has taken its row out, though it is still held.
    public var showsSelectedPhotos: Bool {
        preferences.sources.contains { $0.kind == .photosSelection && $0.enabled }
    }

    /// Takes the selection's row out, or brings it back. Syd, 2026-10-11:
    /// "you can remove any source line with a swipe", and it comes back "By
    /// the Photos button".
    ///
    /// **Switched off, not dropped.** The app adds the selection whenever it
    /// finds access limited and none held, so one that was dropped would be
    /// back the next time the app came forward. Switched off it is still
    /// held, and a widget shows only from what is switched on. It stays
    /// held, switched off, whatever access becomes: Syd, 2026-10-11, over
    /// the row coming back when access is made limited again.
    public func showSelectedPhotos(_ shown: Bool) {
        preferences.setSourceEnabled(shown, locator: Self.selectedPhotos.locator)
    }

    /// Makes the selection a source, or stops it being one. The collections
    /// chosen with full access are left as they are either way: the person may
    /// give full access back.
    public func keepSelectedPhotos(_ keep: Bool) {
        let stored = preferences.sources
        if keep {
            guard !holdsSelectedPhotos else { return }
            preferences.setSources(stored + [Self.selectedPhotos])
        } else {
            // One the person took out is left, switched off: that is how
            // the swipe is remembered.
            let kept = stored.filter { $0.kind != .photosSelection || !$0.enabled }
            guard kept.count != stored.count else { return }
            preferences.setSources(kept)
        }
    }

    public var collections: [SourceSpec] {
        preferences.sources.filter { $0.kind == .photosCollection }
    }

    public var filesAndFolders: [SourceSpec] {
        preferences.sources.filter { $0.kind == .folder || $0.kind == .file }
    }

    /// Every source that is switched on, which is what a widget shows from.
    public var shown: [SourceSpec] {
        preferences.sources.filter(\.enabled)
    }

    /// What Done in the collections sheet does: `ticked` becomes the set of
    /// Photos sources. Syd, 2026-10-09.
    ///
    /// A collection that was already chosen keeps its entry and its place, so
    /// what was stored about it is not lost by ticking it again. New ones go
    /// after everything else, in the order they were ticked.
    public func chooseCollections(_ ticked: [SourceSpec]) {
        let stored = preferences.sources
        let wanted = Set(ticked.map(\.locator))
        let kept = stored.filter { $0.kind != .photosCollection || wanted.contains($0.locator) }

        var have = Set(kept.filter { $0.kind == .photosCollection }.map(\.locator))
        let added = ticked.filter {
            $0.kind == .photosCollection && have.insert($0.locator).inserted
        }
        preferences.setSources(kept + added)
    }

    /// What choosing in the Files browser does: each of `added` goes after
    /// everything else, in the order given. One that is already chosen stays
    /// as it is, with what was stored about it.
    public func add(_ added: [SourceSpec]) {
        let stored = preferences.sources
        var have = Set(stored.map(\.locator))
        preferences.setSources(stored + added.filter { have.insert($0.locator).inserted })
    }

    /// Whether a folder's pictures include those in the folders inside it.
    /// The folder stays where it is in the list. Nothing else has the option.
    public func include(subfolders: Bool, of folder: SourceSpec) {
        var stored = preferences.sources
        guard folder.kind == .folder,
            let index = stored.firstIndex(where: { $0.kind == .folder && $0.locator == folder.locator }),
            stored[index].recursive != subfolders
        else { return }
        stored[index].recursive = subfolders
        preferences.setSources(stored)
    }

    /// Stores what a source is called and where it sits now, when Photos says
    /// that has changed. The source stays where it is in the list.
    public func describe(_ locator: String, as description: SourceDescription) {
        var stored = preferences.sources
        guard let index = stored.firstIndex(where: { $0.locator == locator }) else { return }
        stored[index].description = description
        preferences.setSources(stored)
    }

    public func remove(_ source: SourceSpec) {
        _ = preferences.removeSource(locator: source.locator)
    }

    /// How the photographs sit in every widget, which is chosen beside the
    /// sources and kept with them. `Plans/Widget Settings.md`, *Fit or fill*.
    public var framing: Framing { preferences.widgetFraming }

    public func frame(_ framing: Framing) {
        preferences.setWidgetFraming(framing)
    }
}

extension BookmarkedSources {
    /// The bookmarks to the chosen files and folders, in the container of the
    /// App Group the sources themselves are kept in, with how each opening
    /// went written to the log. Nil when the group has no container, which
    /// leaves files and folders to be read by their paths.
    ///
    /// The app and its extension each keep one for the life of the process:
    /// what it has opened stays open.
    public static func inAppGroup(_ group: String?) -> BookmarkedSources? {
        guard let group,
            let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { return nil }
        // The folder the Mac's app leaves its bookmarks in.
        return BookmarkedSources(
            directory: container.appending(path: "WidgetSource", directoryHint: .isDirectory)
        ) { sentence in
            Log.widget.notice("\(Log.widgetsTag, privacy: .public) \(sentence, privacy: .public)")
        }
    }
}
