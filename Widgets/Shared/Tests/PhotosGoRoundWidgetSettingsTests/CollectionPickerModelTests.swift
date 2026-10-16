import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary
import Testing

@testable import PhotosGoRoundWidgetSettings

@MainActor
@Suite("Choosing collections: the library as a tree, with what is ticked")
struct CollectionPickerModelTests {
    let favorites = LibraryCollection(identifier: "F", title: "Favorites", kind: .favorites)
    let cats = LibraryCollection(identifier: "A2", title: "Cats", kind: .userAlbum)
    let iceland = LibraryCollection(identifier: "A1", title: "Iceland", kind: .userAlbum)
    let norway = LibraryCollection(identifier: "A3", title: "Norway", kind: .userAlbum)
    let panoramas = LibraryCollection(identifier: "M1", title: "Panoramas", kind: .mediaType)

    var library: SampleLibrary {
        SampleLibrary(
            access: .authorized,
            collections: [favorites, cats, iceland, norway, panoramas],
            folders: ["A1": ["Trips"], "A3": ["Trips"]],
            counts: ["F": 12, "A2": 40, "A1": 7, "A3": 0, "M1": 3])
    }

    func picker(
        _ library: SampleLibrary? = nil, chosen: [SourceSpec] = []
    ) -> CollectionPickerModel {
        CollectionPickerModel(
            catalog: PhotosCollectionCatalog(library: library ?? self.library), chosen: chosen)
    }

    func spec(_ collection: LibraryCollection, in folders: [String] = []) -> SourceSpec {
        SourceSpec(
            kind: .photosCollection, locator: collection.identifier,
            description: SourceDescription(
                title: collection.title, collectionKind: collection.kind.rawValue, folders: folders))
    }

    @Test("Before the library is read there is no tree, and Done has nothing to apply")
    func beforeLoading() {
        let picker = picker()

        #expect(picker.tree.isEmpty)
        #expect(!picker.canFinish)
    }

    @Test("Favorites comes first, by itself; then each section, with its collections inside")
    func tree() async {
        let picker = picker()

        await picker.load()

        #expect(picker.tree.map(\.title) == ["Favorites", "Albums", "Media Types"])
        #expect(picker.tree[0].item?.identifier == "F")
        #expect(picker.tree[1].item == nil)
        #expect(picker.rows(under: picker.tree[1]).map(\.title) == ["Trips", "Iceland", "Norway", "Cats"])
        #expect(picker.rows(under: picker.tree[2]).map(\.title) == ["Panoramas"])
        #expect(picker.canFinish)
    }

    @Test("A row under a section is one step in, and one in a folder is two")
    func depths() async {
        let picker = picker()

        await picker.load()

        #expect(picker.rows(under: picker.tree[1]).map(\.depth) == [1, 2, 2, 1])
    }

    @Test("It opens with what is already chosen ticked")
    func opensWithWhatIsChosen() async {
        let picker = picker(chosen: [spec(cats)])

        await picker.load()

        #expect(picker.ticked == ["A2"])
        #expect(picker.isTicked(cats))
        #expect(!picker.isTicked(iceland))
    }

    @Test("Tapping a collection ticks it, and tapping it again unticks it")
    func ticking() async {
        let picker = picker()
        await picker.load()

        picker.toggle(iceland)
        #expect(picker.ticked == ["A1"])

        picker.toggle(iceland)
        #expect(picker.ticked.isEmpty)
    }

    @Test("A folder is none, some or all, by how many of the collections under it are ticked")
    func folderState() async {
        let picker = picker()
        await picker.load()
        let trips = picker.rows(under: picker.tree[1])[0]

        #expect(picker.chosen(under: trips) == .none)

        picker.toggle(iceland)
        #expect(picker.chosen(under: trips) == .some)

        picker.toggle(norway)
        #expect(picker.chosen(under: trips) == .all)
    }

    @Test("Ticking a folder ticks everything under it; ticking it when all are ticked clears them")
    func tickingAFolder() async {
        let picker = picker(chosen: [spec(cats)])
        await picker.load()
        let trips = picker.rows(under: picker.tree[1])[0]

        picker.chooseAll(under: trips)
        #expect(picker.ticked == ["A1", "A2", "A3"])

        picker.chooseAll(under: trips)
        #expect(picker.ticked == ["A2"])
    }

    @Test("A folder that is shut shows none of its rows")
    func collapsing() async {
        let picker = picker()
        await picker.load()

        picker.toggleCollapsed("albums/Trips")

        #expect(picker.rows(under: picker.tree[1]).map(\.title) == ["Trips", "Cats"])
        #expect(picker.isCollapsed("albums/Trips"))
    }

    @Test("What Done applies is each ticked collection, with its name, kind and folders")
    func sources() async {
        let picker = picker()
        await picker.load()

        picker.toggle(cats)
        picker.toggle(iceland)

        #expect(Set(picker.sources) == [spec(cats), spec(iceland, in: ["Trips"])])
    }

    @Test("A collection that was chosen and is no longer in the library is not applied")
    func goneFromTheLibrary() async {
        let gone = LibraryCollection(identifier: "GONE", title: "Deleted", kind: .userAlbum)
        let picker = picker(chosen: [spec(gone), spec(cats)])

        await picker.load()

        #expect(picker.sources == [spec(cats)])
    }

    @Test("The whole library and Hidden are never offered")
    func neverEverything() async {
        let everything = LibraryCollection(identifier: "ALL", title: "Recents", kind: .wholeLibrary)
        let hidden = LibraryCollection(identifier: "H", title: "Hidden", kind: .hidden)
        let picker = picker(
            SampleLibrary(access: .authorized, collections: [everything, hidden, cats]),
            chosen: [spec(everything)])

        await picker.load()

        #expect(picker.tree.map(\.title) == ["Albums"])
        #expect(picker.rows(under: picker.tree[0]).map(\.title) == ["Cats"])
        #expect(picker.sources.isEmpty)
    }

    @Test("A section with nothing to show under it has no heading")
    func emptySection() async {
        // Favorites is one of Albums, and is drawn by itself at the top.
        let picker = picker(SampleLibrary(access: .authorized, collections: [favorites, panoramas]))

        await picker.load()

        #expect(picker.tree.map(\.title) == ["Favorites", "Media Types"])
    }

    @Test("Each collection shows its count once it has been counted")
    func counts() async {
        let library = library
        let catalog = PhotosCollectionCatalog(library: library)
        let picker = CollectionPickerModel(catalog: catalog, chosen: [])
        await picker.load()

        await catalog.countEverything()
        await picker.refresh()

        #expect(!picker.isCounting)
        #expect(picker.tree[0].item?.count == 12)
        #expect(picker.rows(under: picker.tree[1]).compactMap(\.item?.count) == [7, 0, 40])
    }

    @Test("When the library cannot be read there is no tree, it says why, and Done applies nothing")
    func unreadable() async {
        let picker = picker(SampleLibrary(access: .authorized, failing: true), chosen: [spec(cats)])

        await picker.load()

        #expect(picker.tree.isEmpty)
        #expect(picker.failure != nil)
        #expect(!picker.canFinish)
    }
}
