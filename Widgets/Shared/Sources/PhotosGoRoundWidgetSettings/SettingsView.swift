// The settings screen: the preview, the Photos collections, then the files
// and folders.
// `Plans/PGR Widgets - iOS.md`.
//
// **One list for both kinds of source.** Syd, 2026-10-09: each list is as tall
// as the rows it holds, "1 for 1, 2 for 2, ..., 10 for 10, ... 100 for 100". A
// section for each, in one `List`, is that: neither scrolls by itself.
//
// **The preview stays at the top and the sources scroll under it.** Syd,
// 2026-10-10, having tried it both ways: "I want the pinned behavior".
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

    /// Brings up the system's picker for the photographs the app may see, and
    /// returns when it has gone. The app supplies it: it is UIKit's, and wants
    /// a view controller to come up from.
    private let selectPhotos: (@MainActor () async -> Void)?

    public init(model: SettingsModel, selectPhotos: (@MainActor () async -> Void)? = nil) {
        _model = State(initialValue: model)
        self.selectPhotos = selectPhotos
    }

    public var body: some View {
        // No navigation bar: there is nothing to go in one, and the preview
        // has its room. Syd, 2026-10-10: "let's ditch the Edit button as well
        // and claim the toolbar space".
        GeometryReader { screen in
            switch SettingsLayout(for: screen.size) {
            case .previewBeside:
                // Wider than it is tall: an iPhone on its side, or an iPad's
                // window dragged that way.
                HStack(spacing: 0) {
                    preview(room: screen.size.height - SettingsLayout.controlHeight - 24)
                        .frame(width: min(screen.size.width / 2, model.preview.widest + 32))
                        .frame(maxHeight: .infinity)
                    list(room: 0, showsPreview: false)
                }
            case .previewOnTop:
                list(room: SettingsLayout.room(inWindowOfHeight: screen.size.height), showsPreview: true)
            }
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

    /// The sources as one list, with the preview pinned above it when
    /// `showsPreview`. `room` is the most height the preview's widget may take
    /// there.
    private func list(room: CGFloat, showsPreview: Bool) -> some View {
            List {
                Section {
                    if model.photosAccessIsOff {
                        accessOff
                    } else if model.collections.isEmpty {
                        nothing("No collections chosen.")
                    }
                    ForEach(model.collections) { row in
                        SourceRow(row: row, isWrong: row.isWrong || model.photosAccessIsOff)
                            .deleteDisabled(!row.isRemovable)
                    }
                    .onDelete { offsets in remove(offsets, from: model.collections) }
                } header: {
                    // The button is beside the heading so that it is right
                    // under the preview, and in reach in the smallest window.
                    // Syd, 2026-10-10: "the same photo library icon as things
                    // like messages do".
                    // Always there, and greyed out while there is no access
                    // to choose with. With limited access it is the system's
                    // picker that comes up, and this is the only way to it.
                    // Syd, 2026-10-10.
                    heading("Photos") {
                        headingButton(
                            "photo.on.rectangle.angled",
                            model.chooser == .selectedPhotos ? "Select photos" : "Choose collections"
                        ) {
                            switch model.chooser {
                            case .collections: model.showsCollectionPicker = true
                            case .selectedPhotos: changeSelection()
                            case .nothing: break
                            }
                        }
                        .disabled(model.chooser == .nothing)
                    }
                }
                Section {
                    if model.filesAndFolders.isEmpty {
                        nothing("No files or folders chosen.")
                    }
                    ForEach(model.filesAndFolders) { row in
                        SourceRow(row: row)
                    }
                    .onDelete { offsets in remove(offsets, from: model.filesAndFolders) }
                } header: {
                    heading("Files and Folders") {
                        // Adding a file or a folder is not built yet, so the
                        // button cannot be pressed. Syd, 2026-10-10: it stays
                        // greyed out until it is.
                        headingButton("folder", "Add files or folders") {}
                            .disabled(true)
                    }
                }
            }
            // A source leaves its list by a swipe on its row, which comes
            // with `onDelete`, or, a collection, by being unticked in the
            // sheet. There was an Edit button too, until 2026-10-10.
            // Above the list and outside it, so it runs edge to edge: inside,
            // a list's side margins left its space narrower than a large
            // widget on a 390-point phone, which the Home Screen has room for.
            .safeAreaInset(edge: .top, spacing: 0) {
                if showsPreview {
                    preview(room: room)
                        .padding(.vertical, 8)
                        .background(.bar)
                }
            }
    }

    /// A list's heading with a button at its right.
    private func heading(_ title: String, @ViewBuilder button: () -> some View) -> some View {
        HStack {
            Text(title)
            Spacer()
            button()
        }
    }

    /// A button for a heading, drawn as `symbol` and said aloud as `label`.
    private func headingButton(
        _ symbol: String, _ label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                // Room for a finger: a heading's own height is less.
                .frame(minWidth: 44, minHeight: 32, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }

    /// The preview, as wide as it is given: a widget that fits the Home
    /// Screen fits here.
    private func preview(room: CGFloat) -> some View {
        WidgetPreviewView(model: model.preview, room: room)
    }

    /// Photos access refused: one row, with the way to the system's settings
    /// in it. Syd, 2026-10-10: "Should look like the icon, "No Photos Access"
    /// text, and "Settings..." button". Files and folders still work.
    private var accessOff: some View {
        HStack {
            Label("No Photos Access", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
            Spacer()
            #if os(iOS)
                Button("Settings…") {
                    if let settings = URL(string: UIApplication.openSettingsURLString) {
                        openURL(settings)
                    }
                }
                // A button in a row with other things in it: without this
                // the whole row is the button.
                .buttonStyle(.borderless)
            #endif
        }
    }

    /// Shows the system's picker, and reads the library again once it has
    /// gone: the app does not leave the screen for it, so nothing else would.
    private func changeSelection() {
        Task {
            await selectPhotos?()
            await model.start()
        }
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

/// One source: what it is, what it is called, and how many pictures it holds.
struct SourceRow: View {
    let row: SettingsModel.Row
    /// Red when something is wrong with the source. Syd, 2026-10-09.
    var isWrong = false

    var body: some View {
        HStack {
            Label(row.title, systemImage: symbol)
                .foregroundStyle(isWrong ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
            Spacer()
            // At the right of the row, as in the collections sheet.
            if let count = row.count {
                Text(count, format: .number)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var symbol: String {
        switch row.kind {
        case .collection, .selectedPhotos: "photo.on.rectangle"
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
            _ sources: [SourceSpec], library: SampleLibrary = SampleLibrary(access: .authorized),
            counts: [String: Int] = [:], pictures: any PreviewPictures = NoPictures()
        ) -> SettingsModel {
            let folder = URL.temporaryDirectory.appending(path: "pgr-preview-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let preferences = Preferences(
                suiteName: folder.appending(path: "sources").path(percentEncoded: false))
            preferences.setSources(sources)
            return SettingsModel(
                sources: ChosenSources(preferences: preferences), library: library,
                preview: .sample(pictures), counts: SampleCounts(counts))
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
            ],
            library: SampleLibrary(
                access: .authorized,
                collections: [
                    LibraryCollection(identifier: "A1", title: "Iceland", kind: .userAlbum),
                    LibraryCollection(identifier: "A2", title: "Cats", kind: .userAlbum),
                ], folders: ["A1": ["Trips", "2019"]]),
            // A library that holds what is chosen, a figure for each, and
            // something where the photograph goes. Syd, 2026-10-10.
            counts: [
                "A1": 87, "A2": 1203, "/pictures/Raw Coin Images/": 412, "/pictures/moon.jpeg": 1,
            ],
            pictures: SamplePictures()))
    }

    #Preview("Nothing chosen") {
        SettingsView(model: .preview([]))
    }

    #Preview("An iPhone on its side", traits: .landscapeLeft) {
        SettingsView(
            model: .preview(
                [
                    SourceSpec(
                        kind: .photosCollection, locator: "A2",
                        description: SourceDescription(title: "Cats", collectionKind: "album"))
                ],
                library: SampleLibrary(
                    access: .authorized,
                    collections: [LibraryCollection(identifier: "A2", title: "Cats", kind: .userAlbum)]),
                counts: ["A2": 1203], pictures: SamplePictures()))
    }

    #Preview("Limited Photos access") {
        SettingsView(
            model: .preview(
                [.folder("/pictures/Raw Coin Images")], library: SampleLibrary(access: .limited),
                counts: ["selected": 3, "/pictures/Raw Coin Images/": 412],
                pictures: SamplePictures()))
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
