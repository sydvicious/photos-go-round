// What the settings screen's two lists show. `Plans/PGR Widgets - iOS.md`.
//
// **Rows, not sources.** A row is a source with what the screen needs to draw
// it: what it is called and which kind it is. The lists are read from what is
// stored and read again after every change, so the screen never shows a change
// that did not take.

import Foundation
import OSLog
import Observation
import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary
import PhotosGoRoundWidgetFace
import TinyCache

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
        /// Whether a folder's pictures include those in the folders inside
        /// it. Nil for anything that is not a folder, which has no such box.
        public var includesSubfolders: Bool? { kind == .folder ? source.recursive : nil }
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

    /// The names of what could not be added just now. The screen puts up an
    /// alert while there are any, and empties this when it is dismissed.
    public var notAdded: [String] = []

    /// What the alert says. Syd, 2026-10-11: "A modal alert saying "%s could
    /// not be added." where the name of the file or folder or collection is
    /// substituted". Several at once are named in the one sentence, as
    /// several sources wrong at once get one alert. And: "if there is no
    /// name, simply says "That item"".
    public var notAddedMessage: String? {
        guard !notAdded.isEmpty else { return nil }
        let names = notAdded.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "That item" : $0
        }
        return "\(names.formatted(.list(type: .and))) could not be added."
    }

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

    /// Where a bookmark is left for each file and folder added, for the app
    /// and its widgets to open it through.
    private let bookmarks: BookmarkedSources?

    public init(
        sources: ChosenSources, library: any PhotoLibrary, preview: PreviewModel,
        counts: any SourceCounts = NoSourceCounts(), bookmarks: BookmarkedSources? = nil
    ) {
        self.bookmarks = bookmarks
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

    /// What the Files browser hands back: each folder and each image file
    /// chosen there becomes a source. A folder starts without the folders
    /// inside it, as on the Mac; Syd, 2026-10-09.
    ///
    /// **A bookmark is left first, and what none can be left for is not
    /// added.** Without one it could be read until the app was next launched
    /// and never by a widget. The person is told which: `notAdded`.
    public func add(_ chosen: [URL]) {
        var added: [SourceSpec] = []
        var refused: [String] = []
        defer { notAdded = refused }
        for url in chosen {
            do {
                try bookmarks?.leave(for: url)
            } catch {
                Log.widget.error(
                    """
                    \(Log.widgetsTag, privacy: .public) no bookmark could be left for \
                    \(url.lastPathComponent, privacy: .public), so it was not added: \
                    \(String(describing: error), privacy: .public)
                    """)
                refused.append(url.lastPathComponent)
                continue
            }
            let path = url.path(percentEncoded: false)
            added.append(Self.isFolder(url) ? .folder(path) : SourceSpec(kind: .file, locator: path))
        }
        guard !added.isEmpty else { return }
        sources.add(added)
        reload()
        counting = Task { await countSources() }
    }

    /// Asked of the disk, and of the location's own spelling when the disk
    /// will not say.
    private static func isFolder(_ url: URL) -> Bool {
        let letIn = url.startAccessingSecurityScopedResource()
        defer { if letIn { url.stopAccessingSecurityScopedResource() } }
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? url.hasDirectoryPath
    }

    /// What ticking a folder's box does. Its count is of other pictures
    /// from then on, so it is counted again, and the preview starts over.
    /// Syd, 2026-10-11: "a checkbox in the same line as the entry that
    /// toggles it on or off".
    public func include(subfolders: Bool, of row: Row) {
        guard row.kind == .folder, row.source.recursive != subfolders else { return }
        sources.include(subfolders: subfolders, of: row.source)
        counted[row.source.locator] = nil
        reload()
        counting = Task { await countSources() }
    }

    public func remove(_ row: Row) {
        guard row.isRemovable else { return }
        sources.remove(row.source)
        if row.kind == .folder || row.kind == .file {
            bookmarks?.forget(row.source.locator)
        }
        reload()
    }
}
