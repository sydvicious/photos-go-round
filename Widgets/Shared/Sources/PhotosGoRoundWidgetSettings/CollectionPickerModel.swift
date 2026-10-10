// Choosing collections: the library as a tree, with what is ticked.
// `Plans/PGR Widgets - iOS.md`, *The collections*.
//
// **A chooser, not an adder**, as the Mac app's picker is. It opens with what
// is already chosen ticked, and what is ticked when Done is pressed becomes
// the set of Photos sources. Nothing changes until then.
//
// **The library is read here, in the app's own process.** The Mac app asks its
// agent over HTTP; the Widgets app has none, and reads PhotoKit through the
// catalog, which also counts each collection in the background.

import Foundation
import Observation
import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary

@MainActor
@Observable
public final class CollectionPickerModel {
    public typealias Node = FolderNode<LibraryCollection>
    public enum Chosen: Sendable { case none, some, all }

    /// The identifiers of the collections that are ticked.
    public var ticked: Set<String>
    /// Why the library could not be read, when it could not.
    public private(set) var failure: String?
    /// Whether some collections are still waiting for their count.
    public private(set) var isCounting = false

    private let catalog: PhotosCollectionCatalog
    private var sections: [LibrarySectionGroup] = []
    private var hasRead = false
    private var collapsed: Set<String> = []

    public init(catalog: PhotosCollectionCatalog, chosen: [SourceSpec]) {
        self.catalog = catalog
        ticked = Set(chosen.filter { $0.kind == .photosCollection }.map(\.locator))
    }

    public func load() async {
        await refresh()
    }

    /// Reads the library again: what it holds, and how far the counting has got.
    public func refresh() async {
        do {
            let listing = try await catalog.listing()
            // Hidden and the whole library are not among them: the catalog's
            // sections leave both out, for every picker.
            sections = listing.sections
            isCounting = listing.counted < listing.total
            failure = nil
            hasRead = true
        } catch {
            failure =
                (error as? PhotoLibraryError)?.sentence ?? "Your Photos library could not be read."
        }
    }

    // MARK: - The tree

    /// Favorites first, by itself, then each section with its collections
    /// filed under their folders. The Mac app's picker has the same order.
    public var tree: [Node] {
        var out: [Node] = []
        if let favorites = listed.first(where: { $0.kind == .favorites }) {
            out.append(
                Node(
                    id: favorites.identifier, title: favorites.title, depth: 0, item: favorites,
                    children: []))
        }
        out += sections.compactMap { group in
            let children = Node.tree(
                of: group.collections.filter { $0.kind != .favorites },
                under: group.section.rawValue, depth: 1)
            // Favorites is one of Albums and is drawn above; with nothing else
            // in the section there is no heading to draw.
            guard !children.isEmpty else { return nil }
            return Node(
                id: group.section.rawValue, title: group.section.title, depth: 0, item: nil,
                children: children)
        }
        return out
    }

    /// The rows to draw under a section, with shut folders left shut.
    public func rows(under node: Node) -> [Node] {
        Node.rows(under: node.children, isCollapsed: isCollapsed)
    }

    public func isCollapsed(_ id: String) -> Bool { collapsed.contains(id) }

    public func toggleCollapsed(_ id: String) {
        if collapsed.contains(id) {
            collapsed.remove(id)
        } else {
            collapsed.insert(id)
        }
    }

    // MARK: - What is ticked

    public func isTicked(_ collection: LibraryCollection) -> Bool {
        ticked.contains(collection.identifier)
    }

    public func toggle(_ collection: LibraryCollection) {
        if ticked.contains(collection.identifier) {
            ticked.remove(collection.identifier)
        } else {
            ticked.insert(collection.identifier)
        }
    }

    /// How much of what is under a section or a folder is ticked.
    public func chosen(under node: Node) -> Chosen {
        let collections = node.items
        let count = collections.count { ticked.contains($0.identifier) }
        if count == 0 { return .none }
        return count == collections.count ? .all : .some
    }

    /// Ticks everything under a section or a folder, or clears it when
    /// everything under it is ticked already.
    public func chooseAll(under node: Node) {
        let identifiers = node.items.map(\.identifier)
        if chosen(under: node) == .all {
            ticked.subtract(identifiers)
        } else {
            ticked.formUnion(identifiers)
        }
    }

    // MARK: - Done

    /// Whether there is a reading of the library for Done to apply. Without
    /// one, Done would take away every collection that is chosen.
    public var canFinish: Bool { hasRead }

    /// What Done applies: each ticked collection that is in the library. One
    /// that was chosen and has since gone from the library is not among them,
    /// so it leaves the list.
    public var sources: [SourceSpec] {
        listed.filter { ticked.contains($0.identifier) }.map { collection in
            SourceSpec(
                kind: .photosCollection, locator: collection.identifier,
                description: SourceDescription(
                    title: collection.title, collectionKind: collection.kind.rawValue,
                    folders: collection.folders))
        }
    }

    private var listed: [LibraryCollection] { sections.flatMap(\.collections) }
}
