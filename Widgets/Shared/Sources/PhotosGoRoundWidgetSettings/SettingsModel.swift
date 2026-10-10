// What the settings screen's two lists show. `Plans/PGR Widgets - iOS.md`.
//
// **Rows, not sources.** A row is a source with what the screen needs to draw
// it: what it is called and which kind it is. The lists are read from what is
// stored and read again after every change, so the screen never shows a change
// that did not take.

import Foundation
import Observation
import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary
import PhotosGoRoundWidgetFace

@MainActor
@Observable
public final class SettingsModel {
    public struct Row: Identifiable, Equatable, Sendable {
        public enum Kind: Sendable { case collection, selectedPhotos, folder, file }

        public let source: SourceSpec
        public let kind: Kind
        public let title: String
        /// Whether something is wrong with the source, which draws it red.
        public let isWrong: Bool
        /// How many pictures the source holds, once it has been counted. None
        /// is a count like any other: an empty album is not wrong.
        public let count: Int?

        public var id: String { source.locator }
        /// Selected Photos is there for as long as access is limited, and
        /// goes by itself when it is not.
        public var isRemovable: Bool { kind != .selectedPhotos }

        init(_ source: SourceSpec, isWrong: Bool = false, count: Int? = nil) {
            self.source = source
            self.isWrong = isWrong
            self.count = count
            switch source.kind {
            case .photosSelection:
                kind = .selectedPhotos
                title = "Selected Photos"
            case .photosCollection:
                kind = .collection
                // An entry written without its description has only the
                // identifier Photos gave it.
                title = source.description?.title ?? source.locator
            case .folder:
                kind = .folder
                title = URL(filePath: source.locator).lastPathComponent
            default:
                kind = .file
                title = URL(filePath: source.locator).lastPathComponent
            }
        }
    }

    public private(set) var collections: [Row] = []
    public private(set) var filesAndFolders: [Row] = []

    /// What the person has said about Photos, once the app has found out.
    public private(set) var photosAccess: LibraryAuthorization?
    /// Whether the collections sheet is up.
    public var showsCollectionPicker = false

    /// What the Photos button brings up: the collections sheet with full
    /// access, the system's own picker with limited access, the way to the
    /// system's settings with access off, and nothing before the app has
    /// found out.
    public enum Chooser: Sendable { case collections, selectedPhotos, settings, nothing }

    public var chooser: Chooser {
        switch photosAccess {
        case .authorized: .collections
        case .limited: .selectedPhotos
        case .denied, .restricted: .settings
        default: .nothing
        }
    }

    /// What the preview draws. Its own face, except that with Photos access
    /// off and no picture to show it says so: the lists may be out of sight,
    /// and this is always in it. Syd, 2026-10-10. A folder's pictures still
    /// show with Photos access off.
    public var face: WidgetFace.Content {
        guard photosAccessIsOff else { return preview.content }
        switch preview.content {
        case .nothingChosen, .noPhotos: return .noAccess
        default: return preview.content
        }
    }

    /// Refused, or restricted by a parent or a profile. The chosen collections
    /// stay in the list; Syd, 2026-10-09: "red with button back to system
    /// settings".
    public var photosAccessIsOff: Bool {
        photosAccess == .denied || photosAccess == .restricted
    }

    /// The preview at the top of the screen. It is told what is chosen each
    /// time the lists are read.
    public let preview: PreviewModel

    private let sources: ChosenSources
    private let library: any PhotoLibrary
    /// What the collections sheet reads the library through. A new one each
    /// time the app comes forward, since a catalog keeps the counts it has
    /// taken and Photos may have changed since.
    private var catalog: PhotosCollectionCatalog
    /// The chosen collections the library no longer holds, as last looked.
    private var gone: Set<String> = []

    private let counts: any SourceCounts
    /// What each source held when it was last counted, by its locator.
    private var counted: [String: Int] = [:]
    /// The counting started by a change made on this screen, for as long as
    /// it runs.
    public private(set) var counting: Task<Void, Never>?

    public init(
        sources: ChosenSources, library: any PhotoLibrary, preview: PreviewModel,
        counts: any SourceCounts = NoSourceCounts()
    ) {
        self.counts = counts
        self.sources = sources
        self.library = library
        self.preview = preview
        catalog = PhotosCollectionCatalog(library: library)
        reload()
    }

    /// Finds out about Photos access, each time the app is opened or brought
    /// forward.
    ///
    /// Syd, 2026-10-09: "the user will automatically be prompted. The
    /// collections selector will come up after the user asks for photos
    /// permission". So the first time, the app asks by itself, and the sheet
    /// follows a yes. Every time after, it only reads the answer, which the
    /// person may have changed in the system's settings since.
    ///
    /// **And the list is read again.** Syd, 2026-10-10: "we need to refresh
    /// the source list when the app is activated". What is stored is read
    /// afresh, and each chosen collection is looked up in the library: one
    /// renamed or moved in Photos takes its new name and place, and one that
    /// is no longer there is wrong.
    ///
    /// **And every source is counted again, behind the pictures.** Syd,
    /// 2026-10-10, with Favorites chosen while empty and two photographs then
    /// marked as favorites in Photos: "Switch back to PGR. No Photos chosen",
    /// and "even if I kill the app and relaunch". The sheet's counts are
    /// started over, and each row's new count is what the preview's picks
    /// are weighed by from then on.
    public func start() async {
        reload()
        catalog = PhotosCollectionCatalog(library: library)
        preview.lookAgain()
        guard var access = try? await library.authorization else { return }
        if access == .notDetermined {
            access = await library.requestAuthorization()
            showsCollectionPicker = access == .authorized
        }
        photosAccess = access
        // With limited access the photographs the person picked are the one
        // Photos source. Syd, 2026-10-09.
        sources.keepSelectedPhotos(access == .limited)
        await refreshCollections()
        await countSources()
    }

    /// Counts every source that can be counted now, one after another, each
    /// row taking its figure as it arrives.
    ///
    /// A collection is counted only with full access and only while the
    /// library still holds it; what cannot be counted now loses the figure it
    /// had, and what can keeps its old one until the new one is in.
    private func countSources() async {
        var countable = sources.filesAndFolders
        if sources.holdsSelectedPhotos {
            countable.append(ChosenSources.selectedPhotos)
        } else if photosAccess == .authorized {
            countable += sources.collections.filter { !gone.contains($0.locator) }
        }
        let locators = Set(countable.map(\.locator))
        counted = counted.filter { locators.contains($0.key) }
        reload()

        let counts = counts
        for source in countable {
            // Off the main thread: a folder is walked, and Photos is asked.
            let count = (try? await BlockingWork.run { try counts.count(of: source) }) ?? nil
            counted[source.locator] = count
            reload()
        }
    }

    /// Looks each chosen collection up in the library as it is now.
    ///
    /// The library itself is asked, not the picker's sections: a collection
    /// the pickers leave out, chosen before they did, is still a source.
    private func refreshCollections() async {
        let chosen = sources.collections
        // With access off no one collection is singled out; the list says so
        // as a whole. And a library that cannot be read is no evidence that
        // anything has gone from it.
        // Nor is a limited library: it lists no albums of the person's own.
        guard photosAccess == .authorized, !chosen.isEmpty,
            let listed = try? await library.collections()
        else {
            gone = []
            reload()
            return
        }
        let folders = (try? await library.folderPaths()) ?? [:]
        var missing: Set<String> = []
        for source in chosen {
            guard let found = listed.first(where: { $0.identifier == source.locator }) else {
                missing.insert(source.locator)
                continue
            }
            let now = SourceDescription(
                title: found.title,
                collectionKind: source.description?.collectionKind ?? found.kind.rawValue,
                folders: folders[found.identifier] ?? [])
            if now != source.description {
                sources.describe(source.locator, as: now)
            }
        }
        gone = missing
        reload()
    }

    /// A model for the collections sheet, opening with what is chosen now.
    public func makePicker() -> CollectionPickerModel {
        CollectionPickerModel(catalog: catalog, chosen: sources.collections)
    }

    /// Reads both lists again from what is stored.
    public func reload() {
        // While the selection is a source it is the only row: the collections
        // chosen with full access are kept, and cannot be read.
        collections =
            sources.holdsSelectedPhotos
            ? [Row(ChosenSources.selectedPhotos, count: counted[ChosenSources.selectedPhotos.locator])]
            : sources.collections.map {
                Row($0, isWrong: gone.contains($0.locator), count: counted[$0.locator])
            }
        filesAndFolders = sources.filesAndFolders.map { Row($0, count: counted[$0.locator]) }
        preview.show(sources.shown)
    }

    /// Done in the collections sheet.
    public func chooseCollections(_ ticked: [SourceSpec]) {
        sources.chooseCollections(ticked)
        showsCollectionPicker = false
        reload()
        counting = Task { await countSources() }
    }

    public func remove(_ row: Row) {
        guard row.isRemovable else { return }
        sources.remove(row.source)
        reload()
    }
}
