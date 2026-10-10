// The settings screen: the Photos collections, then the files and folders.
// `Plans/PGR Widgets - iOS.md`.
//
// **One list for the whole screen.** Syd, 2026-10-09: each list is as tall as
// the rows it holds, "1 for 1, 2 for 2, ..., 10 for 10, ... 100 for 100", and
// "the entire view be be vertically scrollable". A section for each, in one
// `List`, is that: neither scrolls by itself and the whole screen does.
//
// **Shared.** The iOS app shows this now and the Mac's menubar app is to show
// it later, so nothing here belongs to one platform unless it says so.

import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary
import SwiftUI

public struct SettingsView: View {
    @State private var model: SettingsModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    public init(model: SettingsModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Photos") {
                    if model.photosAccessIsOff {
                        accessOff
                    } else if model.collections.isEmpty {
                        nothing("No collections chosen.")
                    }
                    ForEach(model.collections) { row in
                        SourceRow(row: row, isWrong: model.photosAccessIsOff)
                    }
                    .onDelete { offsets in remove(offsets, from: model.collections) }
                    if model.photosAccess == .authorized {
                        Button("Choose Collections…") { model.showsCollectionPicker = true }
                    }
                }
                Section("Files and Folders") {
                    if model.filesAndFolders.isEmpty {
                        nothing("No files or folders chosen.")
                    }
                    ForEach(model.filesAndFolders) { row in
                        SourceRow(row: row)
                    }
                    .onDelete { offsets in remove(offsets, from: model.filesAndFolders) }
                }
            }
            #if os(iOS)
                // The second of three ways out of a list. Syd, 2026-10-09, of
                // a swipe, an Edit button and unticking in the sheet: "all
                // three". The swipe comes with `onDelete`.
                .toolbar { EditButton() }
            #endif
        }
        .sheet(isPresented: $model.showsCollectionPicker) {
            CollectionPickerView(model: model.makePicker()) { ticked in
                model.chooseCollections(ticked)
            }
        }
        // Each time the app is opened or brought forward: the first time this
        // asks for Photos access, and after that it reads what the person has
        // since said in the system's settings.
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model.start() }
        }
    }

    /// Photos access refused. Syd, 2026-10-09: the list says access is off,
    /// with a button to the system's settings; files and folders still work.
    @ViewBuilder
    private var accessOff: some View {
        Label("Photos access is off.", systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        #if os(iOS)
            Button("Open Settings") {
                if let settings = URL(string: UIApplication.openSettingsURLString) {
                    openURL(settings)
                }
            }
        #endif
    }

    private func nothing(_ words: String) -> some View {
        Text(words).foregroundStyle(.secondary)
    }

    private func remove(_ offsets: IndexSet, from rows: [SettingsModel.Row]) {
        // Collected first: removing one row re-reads the list under the rest.
        for row in offsets.map({ rows[$0] }) {
            model.remove(row)
        }
    }
}

/// One source: what it is, and what it is called.
struct SourceRow: View {
    let row: SettingsModel.Row
    /// Red when something is wrong with the source. Syd, 2026-10-09.
    var isWrong = false

    var body: some View {
        Label(row.title, systemImage: symbol)
            .foregroundStyle(isWrong ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
    }

    private var symbol: String {
        switch row.kind {
        case .collection: "photo.on.rectangle"
        case .folder: "folder"
        case .file: "photo"
        }
    }
}

#if DEBUG
    extension SettingsModel {
        /// A model over a store of its own, for a preview. The store is a
        /// path under the temporary directory, so nothing is left in the
        /// preferences folder.
        static func preview(
            _ sources: [SourceSpec], library: SampleLibrary = SampleLibrary(access: .authorized)
        ) -> SettingsModel {
            let folder = URL.temporaryDirectory.appending(path: "pgr-preview-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let preferences = Preferences(
                suiteName: folder.appending(path: "sources").path(percentEncoded: false))
            preferences.setSources(sources)
            return SettingsModel(sources: ChosenSources(preferences: preferences), library: library)
        }
    }

    #Preview("With sources") {
        SettingsView(
            model: .preview([
                SourceSpec(
                    kind: .photosCollection, locator: "A1",
                    description: SourceDescription(
                        title: "Iceland", collectionKind: "album", folders: ["Trips", "2019"])),
                SourceSpec(
                    kind: .photosCollection, locator: "A2",
                    description: SourceDescription(title: "Cats", collectionKind: "album")),
                .folder("/pictures/Raw Coin Images"),
                SourceSpec(kind: .file, locator: "/pictures/moon.jpeg"),
            ]))
    }

    #Preview("Nothing chosen") {
        SettingsView(model: .preview([]))
    }

    #Preview("Photos access off") {
        SettingsView(
            model: .preview(
                [
                    SourceSpec(
                        kind: .photosCollection, locator: "A2",
                        description: SourceDescription(title: "Cats", collectionKind: "album")),
                    .folder("/pictures/Raw Coin Images"),
                ], library: SampleLibrary(access: .denied)))
    }
#endif
