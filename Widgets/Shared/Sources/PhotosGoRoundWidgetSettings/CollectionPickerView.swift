// The collections sheet: every collection in the library, with a tick box.
// `Plans/PGR Widgets - iOS.md`, *The collections*.
//
// **Done applies; Cancel does not.** Syd, 2026-10-09, chose the Mac picker's
// rule: what is ticked when Done is pressed is the set of Photos sources.
//
// **A folder has a tick box and a section does not**, as in the Mac app's
// picker. A folder's box ticks or clears the albums a person filed in it.

import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary
import SwiftUI

public struct CollectionPickerView: View {
    @State private var model: CollectionPickerModel
    @Environment(\.dismiss) private var dismiss

    private let done: ([SourceSpec]) -> Void

    public init(model: CollectionPickerModel, done: @escaping ([SourceSpec]) -> Void) {
        _model = State(initialValue: model)
        self.done = done
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Choose Collections")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { done(model.sources) }
                            .disabled(!model.canFinish)
                    }
                }
        }
        .task {
            await model.load()
            // The counts arrive behind the names; read again until they are in.
            while model.isCounting, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await model.refresh()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.canFinish {
            if model.tree.isEmpty {
                ContentUnavailableView(
                    "No Collections", systemImage: "photo.on.rectangle",
                    description: Text("There are no albums in your Photos library to choose from."))
            } else {
                list
            }
        } else if let failure = model.failure {
            ContentUnavailableView(
                "Can't Read Photos", systemImage: "exclamationmark.triangle",
                description: Text(failure))
        } else {
            ProgressView("Reading your Photos library…")
        }
    }

    private var list: some View {
        List {
            ForEach(model.tree) { node in
                if let collection = node.item {
                    collectionRow(collection, depth: 0)
                } else {
                    Section(node.title) {
                        ForEach(model.rows(under: node)) { row in
                            if let collection = row.item {
                                collectionRow(collection, depth: row.depth - 1)
                            } else {
                                folderRow(row)
                            }
                        }
                    }
                }
            }
        }
    }

    private func collectionRow(_ collection: LibraryCollection, depth: Int) -> some View {
        Button {
            model.toggle(collection)
        } label: {
            HStack {
                TickBox(state: model.isTicked(collection) ? .all : .none)
                Text(collection.title)
                Spacer()
                if let count = collection.count {
                    Text(count, format: .number).foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, Self.indent * CGFloat(depth))
    }

    /// A folder: its box ticks or clears everything under it, and the rest of
    /// the row opens and shuts it.
    private func folderRow(_ folder: CollectionPickerModel.Node) -> some View {
        HStack {
            Button {
                model.chooseAll(under: folder)
            } label: {
                TickBox(state: model.chosen(under: folder))
            }
            Button {
                model.toggleCollapsed(folder.id)
            } label: {
                HStack {
                    Label(folder.title, systemImage: "folder")
                    Spacer()
                    Image(systemName: model.isCollapsed(folder.id) ? "chevron.right" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
        }
        // Two buttons in one row: without this a tap anywhere presses both.
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
        .padding(.leading, Self.indent * CGFloat(folder.depth - 1))
    }

    private static let indent: CGFloat = 24
}

/// A tick box with a third state, for a folder with some of its albums ticked.
/// SwiftUI's `Toggle` has two.
struct TickBox: View {
    let state: CollectionPickerModel.Chosen

    var body: some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(state == .none ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
            .accessibilityLabel(label)
    }

    private var symbol: String {
        switch state {
        case .none: "square"
        case .some: "minus.square.fill"
        case .all: "checkmark.square.fill"
        }
    }

    private var label: String {
        switch state {
        case .none: "Not chosen"
        case .some: "Partly chosen"
        case .all: "Chosen"
        }
    }
}

#if DEBUG
    extension SampleLibrary {
        /// A small library with albums, a folder of albums, and counts.
        static var preview: SampleLibrary {
            SampleLibrary(
                access: .authorized,
                collections: [
                    LibraryCollection(identifier: "F", title: "Favorites", kind: .favorites),
                    LibraryCollection(identifier: "A1", title: "Iceland", kind: .userAlbum),
                    LibraryCollection(identifier: "A3", title: "Norway", kind: .userAlbum),
                    LibraryCollection(identifier: "A2", title: "Cats", kind: .userAlbum),
                    LibraryCollection(identifier: "A4", title: "Garden", kind: .userAlbum),
                    LibraryCollection(identifier: "S1", title: "Family", kind: .sharedAlbum),
                    LibraryCollection(identifier: "M1", title: "Panoramas", kind: .mediaType),
                ],
                folders: ["A1": ["Trips"], "A3": ["Trips"]],
                counts: ["F": 212, "A1": 87, "A3": 140, "A2": 1203, "A4": 0, "S1": 56, "M1": 9])
        }
    }

    #Preview("A library") {
        CollectionPickerView(
            model: CollectionPickerModel(
                catalog: PhotosCollectionCatalog(library: SampleLibrary.preview),
                chosen: [SourceSpec(kind: .photosCollection, locator: "A2")])
        ) { _ in }
    }

    #Preview("Can't be read") {
        CollectionPickerView(
            model: CollectionPickerModel(
                catalog: PhotosCollectionCatalog(
                    library: SampleLibrary(access: .authorized, failing: true)),
                chosen: [])
        ) { _ in }
    }
#endif
