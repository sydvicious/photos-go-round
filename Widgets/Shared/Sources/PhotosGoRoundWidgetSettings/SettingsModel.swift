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

@MainActor
@Observable
public final class SettingsModel {
    public struct Row: Identifiable, Equatable, Sendable {
        public enum Kind: Sendable { case collection, folder, file }

        public let source: SourceSpec
        public let kind: Kind
        public let title: String

        public var id: String { source.locator }

        init(_ source: SourceSpec) {
            self.source = source
            switch source.kind {
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

    /// Refused, or restricted by a parent or a profile. The chosen collections
    /// stay in the list; Syd, 2026-10-09: "red with button back to system
    /// settings".
    public var photosAccessIsOff: Bool {
        photosAccess == .denied || photosAccess == .restricted
    }

    private let sources: ChosenSources
    private let library: any PhotoLibrary
    private let catalog: PhotosCollectionCatalog

    public init(sources: ChosenSources, library: any PhotoLibrary) {
        self.sources = sources
        self.library = library
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
    public func start() async {
        guard var access = try? await library.authorization else { return }
        if access == .notDetermined {
            access = await library.requestAuthorization()
            showsCollectionPicker = access == .authorized
        }
        photosAccess = access
    }

    /// A model for the collections sheet, opening with what is chosen now.
    public func makePicker() -> CollectionPickerModel {
        CollectionPickerModel(catalog: catalog, chosen: sources.collections)
    }

    /// Reads both lists again from what is stored.
    public func reload() {
        collections = sources.collections.map(Row.init)
        filesAndFolders = sources.filesAndFolders.map(Row.init)
    }

    /// Done in the collections sheet.
    public func chooseCollections(_ ticked: [SourceSpec]) {
        sources.chooseCollections(ticked)
        showsCollectionPicker = false
        reload()
    }

    public func remove(_ row: Row) {
        sources.remove(row.source)
        reload()
    }
}
