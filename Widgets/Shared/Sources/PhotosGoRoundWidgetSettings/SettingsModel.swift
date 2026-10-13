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

        /// What is wrong with a source. Syd, 2026-10-11: "grey - something
        /// that is probably temporary; red - a problem that needs to be
        /// addressed". One that has gone is grey too: "It's gone from the
        /// source, but up to the user to remove".
        public enum Trouble: Sendable, Equatable {
            /// Gone from where it was. Grey, and it stays until the person
            /// takes it out.
            case removed
            /// Out of reach just now, which should pass. Grey.
            case unavailable
            /// A collection with Photos access off. Red.
            case noAccess

            /// What is beside the name. The two greys are told apart by it,
            /// and not by their colour.
            public var words: String? {
                switch self {
                case .removed: "(removed)"
                case .unavailable: "(unavailable)"
                case .noAccess: nil
                }
            }

            /// What a file or folder that could not be read is taken for.
            /// Syd, 2026-10-11: gone, when the app cannot tell whether it was
            /// deleted or is out of reach. So it is out of reach only when
            /// the system says something that passes.
            static func ofFile(failingWith error: any Error) -> Trouble {
                passes(error) ? .unavailable : .removed
            }

            /// No connection, a server that does not answer, iCloud not to
            /// be had. Which errors the system gives for those on a phone is
            /// not checked; these are the ones that say so.
            private static func passes(_ error: any Error) -> Bool {
                let error = error as NSError
                switch error.domain {
                case NSURLErrorDomain:
                    return true
                case NSPOSIXErrorDomain:
                    let passing: [POSIXErrorCode] = [
                        .ETIMEDOUT, .ENETDOWN, .ENETUNREACH, .EHOSTDOWN, .EHOSTUNREACH, .ENOTCONN,
                    ]
                    if passing.contains(where: { Int($0.rawValue) == error.code }) { return true }
                case NSCocoaErrorDomain:
                    let passing = [
                        NSUbiquitousFileUnavailableError, NSUbiquitousFileNotUploadedDueToQuotaError,
                        NSUbiquitousFileUbiquityServerNotAvailable,
                    ]
                    if passing.contains(error.code) { return true }
                default:
                    break
                }
                // What the file system said, under what Foundation says of it.
                guard let under = error.userInfo[NSUnderlyingErrorKey] as? any Error else { return false }
                return passes(under)
            }
        }

        public let source: SourceSpec
        public let kind: Kind
        public let title: String
        /// What is wrong with the source, if anything is.
        public let trouble: Trouble?
        /// How many pictures the source holds, once it has been counted. None
        /// is a count like any other: an empty album is not wrong.
        public let count: Int?
        /// Whether a picture in the source has been passed over as too large
        /// for a widget to shrink. The row carries a warning triangle. Syd,
        /// 2026-10-12: "a triangle with an exclamation point icon next to
        /// the sources with offending images".
        public let somePicturesSkipped: Bool

        public var id: String { source.locator }
        /// Whether a folder's pictures include those in the folders inside
        /// it. Nil for anything that is not a folder, which has no such box.
        public var includesSubfolders: Bool? { kind == .folder ? source.recursive : nil }

        init(
            _ source: SourceSpec, trouble: Trouble? = nil, count: Int? = nil, somePicturesSkipped: Bool = false
        ) {
            self.source = source
            self.trouble = trouble
            self.count = count
            self.somePicturesSkipped = somePicturesSkipped
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

    /// What the alert for sources that have gone says, while there is
    /// something to say. The screen empties it when the alert is dismissed.
    /// No picker follows it; Syd, 2026-10-11: "We have told the user that
    /// something is gone, and they can see what it is".
    public var goneMessage: String?

    /// Whether the alert about Photos access is up. It comes by itself, once
    /// in a run of the app, and from the bar's Photos button.
    public var showsNoAccess = false

    /// Syd's words, 2026-10-11, with "Cancel" and "Settings" under them.
    public static let noAccessMessage =
        "PhotosGoRound needs access to Photos to continue serving your pictures."

    /// Whether the collections' rows are red, which is when the "Photos"
    /// heading and the bar's Photos button are. Syd, 2026-10-11: only then.
    /// Grey rows change neither.
    public var collectionsAreRefused: Bool {
        photosAccessIsOff && !collections.isEmpty
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
    /// Whether the library could not be read when last looked, with access
    /// to it given. Nothing is called gone then, and nothing can be shown.
    private var unread = false
    /// What is wrong with each file and folder that could not be counted
    /// when last tried, by its locator.
    private var failed: [String: Row.Trouble] = [:]

    /// What this run of the app has already said is gone, so that it is said
    /// once. Syd, 2026-10-11: "the first time the app is launched or brought
    /// forward, and then every time it is launched from them on". A model
    /// lasts a run, so nothing is kept between runs for it.
    private var toldGone: Set<String> = []
    /// Whether this run has put up the alert about Photos access since
    /// access was last found off.
    private var toldAccessIsOff = false

    private let counts: any SourceCounts
    /// What each source held when it was last counted, by its locator.
    private var counted: [String: Int] = [:]
    /// The counting started by a change made on this screen, for as long as
    /// it runs.
    public private(set) var counting: Task<Void, Never>?

    /// Where a bookmark is left for each file and folder added, for the app
    /// and its widgets to open it through.
    private let bookmarks: BookmarkedSources?

    /// Which sources a widget has passed a picture over in, as the widgets
    /// record it.
    private let skipped: SkippedPictures?
    /// Whether a widget has passed over a picture in a source that is still
    /// chosen, for being too large to shrink in the memory a widget is held
    /// to. The screen says so in a note, until that source goes away. Syd,
    /// 2026-10-12.
    public private(set) var somePicturesSkipped = false

    public init(
        sources: ChosenSources, library: any PhotoLibrary, preview: PreviewModel,
        counts: any SourceCounts = NoSourceCounts(), bookmarks: BookmarkedSources? = nil,
        skipped: SkippedPictures? = nil
    ) {
        self.skipped = skipped
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
        // Before the selection is dropped for access being off: it is a
        // source that depended on Photos.
        tellOfAccess()
        // With limited access the photographs the person picked are the one
        // Photos source. Syd, 2026-10-09.
        sources.keepSelectedPhotos(access == .limited)
        await refreshCollections()
        await countSources(tellingOfGone: true)
    }

    /// Puts up the alert about Photos access when it is off and something
    /// chosen depends on it. Syd, 2026-10-11: "if there are sources that
    /// depend on it, and it's gone, present. otherwise don't", and "the first
    /// time the app is launched or brought forward after access is turned
    /// off, and then once per launch until it is fixed".
    private func tellOfAccess() {
        guard photosAccessIsOff else {
            toldAccessIsOff = false
            return
        }
        let dependsOnPhotos = !sources.collections.isEmpty || sources.showsSelectedPhotos
        guard dependsOnPhotos, !toldAccessIsOff else { return }
        toldAccessIsOff = true
        showsNoAccess = true
    }

    /// Says what has gone since this run last said so: at launch that is
    /// everything gone, and later only what has gone since. One alert for
    /// both lists, and it names nothing.
    private func tellOfGone() {
        let lost = (collections + filesAndFolders).filter { $0.trouble == .removed }
        let new = lost.filter { !toldGone.contains($0.id) }
        toldGone = Set(lost.map(\.id))
        guard !new.isEmpty else { return }
        let ofCollections = new.contains { $0.kind == .collection }
        let ofFiles = new.contains { $0.kind != .collection }
        // The words for each list are Syd's, 2026-10-11; those for both at
        // once are Claude's.
        goneMessage =
            switch (ofCollections, ofFiles) {
            case (true, true): "Some collections, files and/or folders are no longer available."
            case (true, false): "Some collections are no longer available."
            default: "Some files and/or folders are no longer available."
            }
    }

    /// Counts every source that can be counted now, one after another, each
    /// row taking its figure as it arrives.
    ///
    /// A collection is counted only with full access and only while the
    /// library still holds it; what cannot be counted now loses the figure it
    /// had, and what can keeps its old one until the new one is in.
    ///
    /// **The counting is also the looking, for a file or folder.** One that
    /// cannot be counted is gone or out of reach, by what the failure was.
    /// They are counted first, so that with `tellingOfGone` the alert comes
    /// before Photos is asked anything.
    private func countSources(tellingOfGone: Bool = false) async {
        let files = sources.filesAndFolders
        var photos: [SourceSpec] = []
        if sources.showsSelectedPhotos {
            photos = [ChosenSources.selectedPhotos]
        } else if photosAccess == .authorized {
            photos = sources.collections.filter { !gone.contains($0.locator) }
        }
        let locators = Set((files + photos).map(\.locator))
        counted = counted.filter { locators.contains($0.key) }
        failed = failed.filter { locators.contains($0.key) }
        reload()

        await count(files)
        if tellingOfGone { tellOfGone() }
        await count(photos)
    }

    private func count(_ countable: [SourceSpec]) async {
        let counts = counts
        for source in countable {
            do {
                // Off the main thread: a folder is walked, and Photos is asked.
                counted[source.locator] = try await BlockingWork.run { try counts.count(of: source) }
                failed[source.locator] = nil
            } catch {
                counted[source.locator] = nil
                // A collection is gone only when the library says so.
                if source.kind == .folder || source.kind == .file {
                    failed[source.locator] = .ofFile(failingWith: error)
                }
            }
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
        guard photosAccess == .authorized, !chosen.isEmpty else {
            gone = []
            unread = false
            reload()
            return
        }
        guard let listed = try? await library.collections() else {
            gone = []
            unread = true
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
        unread = false
        reload()
    }

    /// Red with access off, whatever else is so: the library cannot be asked
    /// then, and no one collection is singled out.
    private func trouble(of collection: SourceSpec) -> Row.Trouble? {
        if photosAccessIsOff { return .noAccess }
        if gone.contains(collection.locator) { return .removed }
        return unread ? .unavailable : nil
    }

    /// A model for the collections sheet, opening with what is chosen now.
    public func makePicker() -> CollectionPickerModel {
        CollectionPickerModel(catalog: catalog, chosen: sources.collections)
    }

    /// Reads both lists again from what is stored.
    public func reload() {
        // While the selection is a source it is the only row: the collections
        // chosen with full access are kept, and cannot be read. Once the
        // person has taken it out it is no row at all, and it is still held,
        // switched off, whatever access becomes; so with it held that way
        // the collections show only when access is known not to be limited.
        let selection = ChosenSources.selectedPhotos
        let limited = photosAccess == nil || photosAccess == .limited
        collections =
            if sources.showsSelectedPhotos {
                [Row(selection, count: counted[selection.locator])]
            } else if sources.holdsSelectedPhotos && limited {
                []
            } else {
                sources.collections.map { Row($0, trouble: trouble(of: $0), count: counted[$0.locator]) }
            }
        // Only a file's picture is ever passed over: Photos hands a
        // photograph over at the size asked for. A source that is gone from
        // the list takes its record with it.
        skipped?.keep(only: sources.filesAndFolders)
        lookForSkipped()
        preview.show(sources.shown)
    }

    /// Reads again whether a picture has been passed over in a source that
    /// is still chosen. The preview passes over what a widget would, so the
    /// screen looks each time the preview's picture changes.
    public func lookForSkipped() {
        let rows = sources.filesAndFolders.map {
            Row(
                $0, trouble: failed[$0.locator], count: counted[$0.locator],
                somePicturesSkipped: skipped?.holds($0) ?? false)
        }
        // Looked for each time the preview's picture changes, and nearly
        // always with nothing new to find.
        if rows != filesAndFolders { filesAndFolders = rows }
        let some = rows.contains(where: \.somePicturesSkipped)
        if some != somePicturesSkipped { somePicturesSkipped = some }
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

    /// A swipe on a row. Syd, 2026-10-11: "you can remove any source line
    /// with a swipe. the widgets will continue operating as normal when the
    /// sources are updated".
    public func remove(_ row: Row) {
        switch row.kind {
        case .selectedPhotos:
            sources.showSelectedPhotos(false)
        case .collection:
            sources.remove(row.source)
        case .folder, .file:
            sources.remove(row.source)
            bookmarks?.forget(row.source.locator)
        }
        reload()
    }

    /// What the Photos button does once the system's picker for the
    /// selection has gone: Selected Photos is a row again if it had been
    /// taken out, and the library is read again.
    public func selectedPhotosChanged() async {
        sources.showSelectedPhotos(true)
        await start()
    }
}
