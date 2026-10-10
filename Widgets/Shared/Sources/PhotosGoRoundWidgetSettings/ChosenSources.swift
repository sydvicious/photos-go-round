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
import PhotosGoRoundAgentAPI

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

    /// Makes the selection a source, or stops it being one. The collections
    /// chosen with full access are left as they are either way: the person may
    /// give full access back.
    public func keepSelectedPhotos(_ keep: Bool) {
        guard keep != holdsSelectedPhotos else { return }
        let others = preferences.sources.filter { $0.kind != .photosSelection }
        preferences.setSources(keep ? others + [Self.selectedPhotos] : others)
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
}
