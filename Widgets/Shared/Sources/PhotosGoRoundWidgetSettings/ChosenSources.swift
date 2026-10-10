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

    public var collections: [SourceSpec] {
        preferences.sources.filter { $0.kind == .photosCollection }
    }

    public var filesAndFolders: [SourceSpec] {
        preferences.sources.filter { $0.kind == .folder || $0.kind == .file }
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

    public func remove(_ source: SourceSpec) {
        _ = preferences.removeSource(locator: source.locator)
    }
}
