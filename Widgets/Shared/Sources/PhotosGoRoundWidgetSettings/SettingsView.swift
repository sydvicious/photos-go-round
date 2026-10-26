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
import UniformTypeIdentifiers

public struct SettingsView: View {
    @State private var model: SettingsModel
    @State private var showsFileBrowser = false
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
                let bounds = model.preview.boundsHeight
                if SettingsLayout.listsFitUnderPreview(
                    inViewOfHeight: view.size.height, underPreviewOf: bounds)
                {
                    // The preview's bounds from the top of the view, as tall
                    // as the tallest size so that choosing another size moves
                    // nothing, and the lists under them.
                    VStack(spacing: 0) {
                        preview(in: CGSize(width: view.size.width, height: bounds), alignment: .center)
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
                        inViewOfHeight: view.size.height, bounds: bounds)
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if model.somePicturesSkipped { skippedNote }
            }
            // The preview passes over what a widget would, and a picture
            // passed over is followed by the one shown in its place.
            .onChange(of: model.preview.content) { model.lookForSkipped() }
            .toolbar {
                // Both groups at the trailing edge, the sizes first. Syd,
                // 2026-10-10: "I want the size controls on the right as well".
                if model.preview.device == .pad {
                    // On an iPad each group is one item, drawn close
                    // together: as a button each, the bar is too wide for
                    // the narrowest window, and the system folds what does
                    // not fit into a "…" menu.
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 2) { sizes(compact: true) }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 4)
                    }
                    ToolbarSpacer(.fixed, placement: .primaryAction)
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 2) { sources(compact: true) }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 4)
                    }
                } else {
                    // On a phone they are ordinary bar buttons, which fit,
                    // and which the system can lay out its own way: on the
                    // iPhone Duo it is to move them to the side. Drawn as
                    // one view of ours they stayed where they were.
                    ToolbarItemGroup(placement: .primaryAction) { sizes(compact: false) }
                    ToolbarSpacer(.fixed, placement: .primaryAction)
                    ToolbarItemGroup(placement: .primaryAction) { sources(compact: false) }
                }
            }
            .toolbarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $model.showsCollectionPicker) {
            CollectionPickerView(model: model.makePicker()) { ticked in
                model.chooseCollections(ticked)
            }
        }
        // The Files browser on iOS, and the open panel on the Mac. Folders
        // and image files in one browser, where the Mac app has a menu item
        // for each.
        .fileImporter(
            isPresented: $showsFileBrowser, allowedContentTypes: [.folder, .image],
            allowsMultipleSelection: true
        ) { result in
            // Cancelled, or the browser failed: nothing was chosen.
            guard case .success(let chosen) = result else { return }
            model.add(chosen)
        }
        // Something chosen in the Files browser that could not be added.
        // Syd, 2026-10-11: "A modal alert saying "%s could not be added."".
        .alert(
            model.notAddedMessage ?? "",
            isPresented: Binding(
                get: { !model.notAdded.isEmpty },
                set: { if !$0 { model.notAdded = [] } })
        ) {
            Button("OK", role: .cancel) {}
        }
        // Photos access is off and something chosen needs it: by itself once
        // in a run of the app, and from the bar's Photos button. The words
        // are Syd's, 2026-10-11.
        .alert(SettingsModel.noAccessMessage, isPresented: $model.showsNoAccess) {
            Button("Cancel", role: .cancel) {}
            Button("Settings") { openSettings() }
        }
        // Sources that have gone. It waits for the alert about access, which
        // comes first when both do: two cannot be up at once.
        .alert(
            model.goneMessage ?? "",
            isPresented: Binding(
                get: { model.goneMessage != nil && !model.showsNoAccess },
                set: { if !$0 { model.goneMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
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
    /// `compact` is for an iPad's bar, where they are closer together than
    /// bar buttons are, and the two smallest narrower to press than one; Syd,
    /// 2026-10-10, chose that over a bar that does not fit.
    @ViewBuilder private func sizes(compact: Bool) -> some View {
        ForEach(model.preview.families) { family in
            let isShowing = model.preview.family == family
            let shape = model.preview.shape(of: family, height: shapeHeight)
            Button {
                model.preview.family = family
            } label: {
                if compact {
                    SizeShape(size: shape, isShowing: isShowing)
                        .padding(.horizontal, 4)
                        // As tall to press as the bar is, whatever the shape.
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                } else {
                    // A name and a picture, as the Photos and Files buttons
                    // are, and not a view of ours: on the iPhone Duo the
                    // system moved those two to the side and left a drawn
                    // shape where it was. Syd, 2026-10-10.
                    Label {
                        Text(family.title)
                    } icon: {
                        SizeShape.image(size: shape, isShowing: isShowing)
                    }
                }
            }
            .accessibilityLabel(family.title)
            .accessibilityAddTraits(isShowing ? .isSelected : [])
        }
    }

    /// The bar's second group: where photographs come from.
    @ViewBuilder private func sources(compact: Bool) -> some View {
        // What it brings up goes by the access there is: the collections
        // sheet, the system's picker for a selection, or the way to the
        // system's settings. Greyed out only until the app has found out.
        Button {
            switch model.chooser {
            case .collections: model.showsCollectionPicker = true
            case .selectedPhotos: changeSelection()
            case .settings: model.showsNoAccess = true
            case .nothing: break
            }
        } label: {
            sourceSymbol(
                "photo.on.rectangle.angled", compact: compact, refused: model.collectionsAreRefused)
        }
        // On a red background while the collections' rows are red. Syd,
        // 2026-10-11. An ordinary bar button takes it as its tint.
        .modifier(Refused(model.collectionsAreRefused && !compact))
        .accessibilityLabel(model.chooser == .selectedPhotos ? "Select photos" : "Choose collections")
        .disabled(model.chooser == .nothing)

        Button {
            showsFileBrowser = true
        } label: {
            sourceSymbol("folder", compact: compact)
        }
        .accessibilityLabel("Add files or folders")
    }

    @ViewBuilder private func sourceSymbol(_ name: String, compact: Bool, refused: Bool = false) -> some View {
        if compact {
            Image(systemName: name)
                .font(.body.weight(.medium))
                .foregroundStyle(refused ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .frame(minWidth: 36, minHeight: 36)
                .background(
                    refused ? Color.trouble : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .contentShape(Rectangle())
        } else {
            Image(systemName: name)
        }
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
            WidgetPreviewView(model: model.preview, face: model.face, viewport: bounds) {
                openSettings()
            }
            // A widget smaller than the bounds sits in them and has nowhere
            // to scroll to.
            .frame(minWidth: bounds.width, minHeight: bounds.height, alignment: alignment)
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.horizontal, .vertical])
        .frame(width: bounds.width, height: bounds.height)
        // Nothing of the widget shows outside its bounds. Without this a
        // scroll view at the top of the screen draws on under the bar. Syd,
        // 2026-10-11: "the preview widget scrolling should not bleed into
        // the navigation bar".
        .clipped()
    }

    /// What is chosen, under the preview or beside it. Any row leaves by a
    /// swipe, and a collection also by being unticked in the sheet. Syd,
    /// 2026-10-11: "you can remove any source line with a swipe".
    /// At the foot of the window while a widget has passed over a picture in
    /// a source that is still chosen: one too large to shrink in the memory
    /// a widget is held to. Syd, 2026-10-12: "a note at the bottom of the
    /// apps windows that says that some of the pictures in your choices may
    /// not be able to appear in widgets", there "until that source goes
    /// away". With a warning triangle, so that it is not told from the rest
    /// of the screen by its colour.
    private var skippedNote: some View {
        Label {
            // The words are Syd's, 2026-10-12, in place of the first ones.
            Text("Some of the Photos in this set are not displayable in widgets.")
        } icon: {
            // The same triangle as on the rows it is about.
            SourceRow.skippedMark
        }
        .font(.footnote)
        .foregroundStyle(Self.words)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var lists: some View {
        List {
            // How the photographs sit in every widget. First, directly under
            // the preview, so a change is seen at once; Syd, 2026-10-25, over
            // after the lists and over a menu in the bar. `Plans/Widget
            // Settings.md`, *Where the settings go in the app*.
            Section("Pictures") {
                Picker(
                    "Pictures",
                    selection: Binding(get: { model.framing }, set: { model.framing = $0 })
                ) {
                    ForEach(Framing.allCases, id: \.self) { framing in
                        Text(framing.title).tag(framing)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Section {
                if model.photosAccessIsOff {
                    accessOff
                } else if model.collections.isEmpty {
                    nothing("No collections chosen.")
                }
                ForEach(model.collections) { row in
                    SourceRow(row: row)
                }
                .onDelete { offsets in remove(offsets, from: model.collections) }
            } header: {
                // Syd, 2026-10-11, of 8 points between the line and the
                // heading: "Just a bit more space between text and list".
                VStack(alignment: .leading, spacing: 16) {
                    // A swipe is not something a person is shown. Between the
                    // preview and the lists, scrolling with them, and always
                    // there; the words are Syd's, 2026-10-11. Over the first
                    // heading and not a row of its own, which stood apart
                    // from both: "too much space between the preview, and
                    // the lists".
                    Text("To remove a collection, file, or folder, swipe left on it.")
                        .font(.footnote)
                        .fontWeight(.regular)
                        .textCase(nil)
                        .foregroundStyle(Self.words)
                    // Red, with a warning triangle so that it is not told
                    // from a normal heading by its colour alone, while the
                    // rows under it are red. Syd, 2026-10-11.
                    if model.collectionsAreRefused {
                        HStack(spacing: 4) {
                            Text("Photos")
                            Image(systemName: "exclamationmark.triangle.fill")
                                .accessibilityLabel("No Photos access")
                        }
                        .foregroundStyle(Color.trouble)
                    } else {
                        Text("Photos")
                    }
                }
            }
            Section {
                if model.filesAndFolders.isEmpty {
                    nothing("No files or folders chosen.")
                }
                ForEach(model.filesAndFolders) { row in
                    SourceRow(row: row) { model.include(subfolders: $0, of: row) }
                }
                .onDelete { offsets in remove(offsets, from: model.filesAndFolders) }
            } header: {
                Text("Files and Folders")
            } footer: {
                // What a folder's box is for, under the list and out of the
                // rows' way. Syd, 2026-10-11: "needs some text somewhere
                // explaining what it the checkbox is". The words are his.
                // Only where there is a folder for it to be about.
                if model.filesAndFolders.contains(where: { $0.includesSubfolders != nil }) {
                    Text("Include nested folders when checked.")
                        .foregroundStyle(Self.words)
                }
            }
        }
        // One backdrop for the preview and the lists.
        .scrollContentBackground(.hidden)
    }

    /// The colour of the two lines of words about the lists: that of normal
    /// text, and the same for both. Syd, 2026-10-11: "These should be the
    /// same color. I think that they should be black (in light mode), the
    /// same as normal text". The colour itself and not the first level of
    /// whatever a heading or a footer is drawn in, which is grey.
    private static let words = Color.primary

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
                .foregroundStyle(Color.trouble)
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
            await model.selectedPhotosChanged()
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

extension Color {
    /// The red of a problem that needs to be addressed. Syd is colour blind
    /// and cannot tell the system's red from grey; 2026-10-11: "it's a
    /// bright, light red with a hint of yellow mixed in". Of this one, in a
    /// preview beside grey rows, the same day: "that red is perfect for me".
    static let trouble = Color(red: 1.0, green: 0.39, blue: 0.28)
}

/// The bar's Photos button on a red background: the tinted prominent style,
/// which is how a bar button of the system's own is given one.
private struct Refused: ViewModifier {
    let isRefused: Bool

    init(_ isRefused: Bool) {
        self.isRefused = isRefused
    }

    func body(content: Content) -> some View {
        if isRefused {
            content.buttonStyle(.borderedProminent).tint(Color.trouble)
        } else {
            content
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

    /// The same shape as a picture, for a bar button that is to be an
    /// ordinary one. It carries its own colours: a bar draws a picture it is
    /// left to colour all in one, and the size that is showing would not
    /// stand out.
    static func image(size: CGSize, isShowing: Bool) -> Image {
        Image(size: size) { context in
            let line: CGFloat = 2
            let inside = CGRect(origin: .zero, size: size).insetBy(dx: line / 2, dy: line / 2)
            let shape = Path(
                roundedRect: inside, cornerRadius: min(size.width, size.height) * 0.28, style: .continuous)
            let colour = GraphicsContext.Shading.color(isShowing ? .accentColor : .primary)
            if isShowing {
                context.fill(shape, with: colour)
            }
            context.stroke(shape, with: colour, lineWidth: line)
        }
        .renderingMode(.original)
    }
}

/// One source: what it is, what it is called, and how many pictures it holds.
struct SourceRow: View {
    let row: SettingsModel.Row
    /// Told when a folder's subfolders box is ticked or unticked.
    var includeSubfolders: ((Bool) -> Void)?

    var body: some View {
        HStack {
            Label(name, systemImage: symbol)
                .foregroundStyle(colour)
            // Beside the name of a source with a picture too large for a
            // widget to shrink. Syd, 2026-10-12.
            if row.somePicturesSkipped {
                Self.skippedMark
                    .foregroundStyle(colour)
                    .accessibilityLabel("Some of the Photos in this set are not displayable in widgets")
            }
            Spacer()
            // At the right of the row, as in the collections sheet.
            if let count = row.count {
                Text(count, format: .number)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            // A folder's own option, in its row. Syd, 2026-10-11: "a checkbox
            // in the same line as the entry that toggles it on or off", and
            // "to the right of the count so it does not move around": the
            // count's width changes and the row's edge does not.
            if let includeSubfolders {
                if let included = row.includesSubfolders {
                    Button {
                        includeSubfolders(!included)
                    } label: {
                        Self.box(ticked: included)
                    }
                    // A button in a row with other things in it: without
                    // this the whole row is the button.
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Include subfolders")
                    .accessibilityAddTraits(included ? .isSelected : [])
                } else {
                    // A single file has no box. The room for one is kept, so
                    // that the counts in the list stay in one column.
                    Self.box(ticked: false)
                        .hidden()
                        .accessibilityHidden(true)
                }
            }
        }
    }

    /// A triangle with an exclamation point, in the colour of the words
    /// around it. Syd, 2026-10-12: "I don't think it should be red. This is
    /// not fatal", and "It's just information". The shape is what says it.
    static var skippedMark: some View {
        Image(systemName: "exclamationmark.triangle")
    }

    private static func box(ticked: Bool) -> some View {
        Image(systemName: ticked ? "checkmark.square.fill" : "square")
            .imageScale(.large)
    }

    /// The source's name, with what is wrong beside it when that has a word.
    private var name: String {
        guard let words = row.trouble?.words else { return row.title }
        return "\(row.title) \(words)"
    }

    /// Grey for trouble that is probably temporary, and for a source that
    /// has gone; red for a problem that needs to be addressed. Syd,
    /// 2026-10-11.
    private var colour: AnyShapeStyle {
        switch row.trouble {
        case .removed, .unavailable: AnyShapeStyle(.secondary)
        case .noAccess: AnyShapeStyle(Color.trouble)
        case nil: AnyShapeStyle(.primary)
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
            counts: [String: Int] = [:], failing: [String: any Error] = [:],
            pictures: any PreviewPictures = NoPictures(), skipping: [SourceSpec] = []
        ) -> SettingsModel {
            let folder = URL.temporaryDirectory.appending(path: "pgr-preview-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let preferences = Preferences(
                suiteName: folder.appending(path: "sources").path(percentEncoded: false))
            preferences.setSources(sources)
            // What a widget would have recorded, for the note at the foot.
            let skipped = SkippedPictures(
                suiteName: folder.appending(path: "skipped").path(percentEncoded: false))
            skipping.forEach(skipped.record)
            return SettingsModel(
                sources: ChosenSources(preferences: preferences), library: library,
                preview: .sample(pictures), counts: SampleCounts(counts, failing: failing),
                skipped: skipped)
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
                // One with its box ticked, to see both.
                .folder("/pictures/Stamps", recursive: true),
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
                "A1": 87, "A2": 1203, "/pictures/Raw Coin Images/": 412, "/pictures/Stamps/": 96,
                "/pictures/moon.jpeg": 1,
            ],
            pictures: SamplePictures()))
    }

    #Preview("Some pictures passed over") {
        SettingsView(
            model: .preview(
                [.folder("/pictures/Raw Coin Images"), .folder("/pictures/Holidays")],
                counts: ["/pictures/Raw Coin Images": 32, "/pictures/Holidays": 412],
                skipping: [.folder("/pictures/Raw Coin Images")]))
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
                ], library: SampleLibrary(access: .denied),
                counts: ["/pictures/Raw Coin Images/": 412]))
    }

    #Preview("Sources gone and out of reach") {
        SettingsView(
            model: .preview(
                [
                    SourceSpec(
                        kind: .photosCollection, locator: "A2",
                        description: SourceDescription(title: "Cats", collectionKind: "album")),
                    // One the library no longer holds.
                    SourceSpec(
                        kind: .photosCollection, locator: "A1",
                        description: SourceDescription(title: "Iceland", collectionKind: "album")),
                    .folder("/pictures/Raw Coin Images"),
                    .folder("/pictures/Stamps"),
                    SourceSpec(kind: .file, locator: "/pictures/moon.jpeg"),
                ],
                library: SampleLibrary(
                    access: .authorized,
                    collections: [LibraryCollection(identifier: "A2", title: "Cats", kind: .userAlbum)]),
                counts: ["A2": 1203, "/pictures/Raw Coin Images/": 412],
                failing: [
                    "/pictures/Stamps/": CocoaError(.fileReadNoSuchFile),
                    "/pictures/moon.jpeg": POSIXError(.ETIMEDOUT),
                ],
                pictures: SamplePictures()))
    }
#endif
