// The settings screen: the controls in the bar, the preview, and under it the
// Photos collections and the files and folders when there is room.
// `Plans/PGR Widgets - iOS.md`, *The redesign: controls in the nav bar*.
//
// **The controls are in the bar.** Syd, 2026-10-10: "This will allow the users
// a consistent place to have controls". Two groups: which size is previewed,
// and where photographs come from.
//
// **The lists are under the preview, or beside it.** Where there is no room
// under the preview for a heading and one row, as on an iPhone on its side,
// the preview is at the left and the lists at its right.
//
// **Shared.** The iOS app shows this now and the Mac's menubar app is to show
// it later, so nothing here belongs to one platform unless it says so.

import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary
import SwiftUI

public struct SettingsView: View {
    @State private var model: SettingsModel
    @State private var showsNoAccess = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    /// How tall the tallest size's shape is in the bar. It grows with the
    /// text size the person has set.
    @ScaledMetric(relativeTo: .body) private var shapeHeight: CGFloat = 24

    /// Brings up the system's picker for the photographs the app may see, and
    /// returns when it has gone. The app supplies it: it is UIKit's, and wants
    /// a view controller to come up from.
    private let selectPhotos: (@MainActor () async -> Void)?

    public init(model: SettingsModel, selectPhotos: (@MainActor () async -> Void)? = nil) {
        _model = State(initialValue: model)
        self.selectPhotos = selectPhotos
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { view in
                let tallest = model.preview.tallest
                if SettingsLayout.listsFitUnderPreview(
                    inViewOfHeight: view.size.height, underPreviewOf: tallest)
                {
                    // The preview's bounds from the top of the view, as tall
                    // as the tallest size so that choosing another size moves
                    // nothing, and the lists under them.
                    VStack(spacing: 0) {
                        preview(in: CGSize(width: view.size.width, height: tallest), alignment: .center)
                            .padding(.bottom, SettingsLayout.previewPadding)
                        lists
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    // No room under the preview for a heading and one row, as
                    // on an iPhone on its side: the preview at the left, and
                    // the lists beside it.
                    let column = SettingsLayout.previewColumn(
                        inViewOfWidth: view.size.width, widest: model.preview.widest)
                    let boundsFit = SettingsLayout.previewBoundsFit(
                        inViewOfHeight: view.size.height, tallest: tallest)
                    HStack(spacing: 0) {
                        // In the middle of the column when the tallest size
                        // fits there, and at the top when it does not.
                        preview(
                            in: CGSize(width: column, height: view.size.height),
                            alignment: boundsFit ? .center : .top)
                        lists
                    }
                }
            }
            .background(Self.backdrop)
            .toolbar {
                // Both groups at the trailing edge, the sizes first. Syd,
                // 2026-10-10: "I want the size controls on the right as well".
                // Each group is one item, drawn close together: as a button
                // each, the bar is too wide for an iPad's narrowest window,
                // and the system folds what does not fit into a "…" menu.
                ToolbarItem(placement: .primaryAction) { sizes }
                ToolbarSpacer(.fixed, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { sources }
            }
            .toolbarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $model.showsCollectionPicker) {
            CollectionPickerView(model: model.makePicker()) { ticked in
                model.chooseCollections(ticked)
            }
        }
        .alert("No Photos Access", isPresented: $showsNoAccess) {
            Button("Settings…") { openSettings() }
            Button("Cancel", role: .cancel) {}
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

    /// The bar's first group: a shape for each size the Home Screen offers,
    /// in that size's proportions. Syd, 2026-10-10: "proportionately-sized
    /// round rects for each available size".
    ///
    /// Closer together than bar buttons are, so the two smallest are narrower
    /// to press than a bar button; Syd, 2026-10-10, chose that over a bar
    /// that does not fit.
    private var sizes: some View {
        HStack(spacing: 2) {
            ForEach(model.preview.families) { family in
                let isShowing = model.preview.family == family
                Button {
                    model.preview.family = family
                } label: {
                    SizeShape(
                        size: model.preview.shape(of: family, height: shapeHeight), isShowing: isShowing
                    )
                    .padding(.horizontal, 4)
                    // As tall to press as the bar is, whatever the shape.
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(family.title)
                .accessibilityAddTraits(isShowing ? .isSelected : [])
            }
        }
        .padding(.horizontal, 4)
    }

    /// The bar's second group: where photographs come from.
    private var sources: some View {
        HStack(spacing: 2) {
            // What it brings up goes by the access there is: the collections
            // sheet, the system's picker for a selection, or the way to the
            // system's settings. Greyed out only until the app has found out.
            Button {
                switch model.chooser {
                case .collections: model.showsCollectionPicker = true
                case .selectedPhotos: changeSelection()
                case .settings: showsNoAccess = true
                case .nothing: break
                }
            } label: {
                sourceSymbol("photo.on.rectangle.angled")
            }
            .accessibilityLabel(model.chooser == .selectedPhotos ? "Select photos" : "Choose collections")
            .disabled(model.chooser == .nothing)

            // Adding a file or a folder is not built yet, so the button
            // cannot be pressed.
            Button {
            } label: {
                sourceSymbol("folder")
            }
            .accessibilityLabel("Add files or folders")
            .disabled(true)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    private func sourceSymbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.body.weight(.medium))
            .frame(minWidth: 36, minHeight: 36)
            .contentShape(Rectangle())
    }

    /// The preview in the bounds the screen has for it.
    ///
    /// What scrolls is the widget, at its own size. Syd, 2026-10-10: "The
    /// preview's scroll area should be the size of the widget. When the view
    /// is big enough, no scrolling is necessary. When it is not, you should
    /// be able to scroll it either way. This will allow the user to see all
    /// of the image in landscape on the phone, and when their iPad window is
    /// small".
    private func preview(in bounds: CGSize, alignment: Alignment) -> some View {
        ScrollView([.vertical, .horizontal]) {
            WidgetPreviewView(model: model.preview, face: model.face, width: bounds.width) {
                openSettings()
            }
            // A widget smaller than the bounds sits in them and has nowhere
            // to scroll to.
            .frame(minWidth: bounds.width, minHeight: bounds.height, alignment: alignment)
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.horizontal, .vertical])
        .frame(width: bounds.width, height: bounds.height)
    }

    /// What is chosen, under the preview or beside it. A collection leaves by being
    /// unticked in the sheet; Syd, 2026-10-10: "non-editable".
    private var lists: some View {
        List {
            Section("Photos") {
                if model.photosAccessIsOff {
                    accessOff
                } else if model.collections.isEmpty {
                    nothing("No collections chosen.")
                }
                ForEach(model.collections) { row in
                    SourceRow(row: row, isWrong: row.isWrong || model.photosAccessIsOff)
                }
            }
            Section("Files and Folders") {
                if model.filesAndFolders.isEmpty {
                    nothing("No files or folders chosen.")
                }
                ForEach(model.filesAndFolders) { row in
                    SourceRow(row: row)
                }
                // Nothing adds a file or a folder yet, and how one is to be
                // taken out in this design was not said; the swipe is what
                // there is.
                .onDelete { offsets in remove(offsets, from: model.filesAndFolders) }
            }
        }
        // One backdrop for the preview and the lists.
        .scrollContentBackground(.hidden)
    }

    private static var backdrop: Color {
        #if os(iOS)
            Color(uiColor: .systemGroupedBackground)
        #else
            Color.clear
        #endif
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
                Button("Settings…") { openSettings() }
                    // A button in a row with other things in it: without this
                    // the whole row is the button.
                    .buttonStyle(.borderless)
            #endif
        }
    }

    /// The app's own page in the system's settings, where Photos access is.
    private func openSettings() {
        #if os(iOS)
            if let settings = URL(string: UIApplication.openSettingsURLString) {
                openURL(settings)
            }
        #endif
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

/// One size in the bar: a rounded rectangle in the widget's proportions,
/// filled when it is the size the preview is showing.
private struct SizeShape: View {
    let size: CGSize
    let isShowing: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.28, style: .continuous)
            .fill(isShowing ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear))
            // Dark and thick enough to read as a shape at this size. Syd,
            // 2026-10-10: "darker or thicker".
            .strokeBorder(isShowing ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary), lineWidth: 2)
            .frame(width: size.width, height: size.height)
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
