import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary
import Testing

@testable import PhotosGoRoundWidgetSettings

@MainActor
@Suite("The source list, read again each time the app comes forward")
struct SourceRefreshTests {
    let preferences = Preferences(suiteName: scratchSuiteName("source-refresh"))

    func model(_ library: SampleLibrary) -> SettingsModel {
        SettingsModel(
            sources: ChosenSources(preferences: preferences), library: library, preview: .sample())
    }

    func spec(_ identifier: String, _ title: String, in folders: [String] = []) -> SourceSpec {
        SourceSpec(
            kind: .photosCollection, locator: identifier,
            description: SourceDescription(title: title, collectionKind: "userAlbum", folders: folders))
    }

    func library(_ collections: [LibraryCollection], folders: [String: [String]] = [:]) -> SampleLibrary {
        SampleLibrary(access: .authorized, collections: collections, folders: folders)
    }

    @Test("What is stored is read again, so a change made elsewhere shows")
    func readAgain() async {
        let cats = LibraryCollection(identifier: "A2", title: "Cats", kind: .userAlbum)
        let model = model(library([cats]))
        preferences.setSources([spec("A2", "Cats")])

        await model.start()

        #expect(model.collections.map(\.title) == ["Cats"])
    }

    @Test("A collection renamed in Photos shows its new name, and the new name is what is stored")
    func renamed() async {
        preferences.setSources([spec("A2", "Cats")])
        let model = model(library([LibraryCollection(identifier: "A2", title: "Kittens", kind: .userAlbum)]))

        await model.start()

        #expect(model.collections.map(\.title) == ["Kittens"])
        #expect(preferences.sources == [spec("A2", "Kittens")])
    }

    @Test("A collection moved into a folder in Photos is stored under that folder")
    func moved() async {
        preferences.setSources([spec("A1", "Iceland")])
        let model = model(
            library(
                [LibraryCollection(identifier: "A1", title: "Iceland", kind: .userAlbum)],
                folders: ["A1": ["Trips"]]))

        await model.start()

        #expect(preferences.sources == [spec("A1", "Iceland", in: ["Trips"])])
    }

    @Test("A collection that is no longer in the library is wrong, and stays in the list")
    func gone() async {
        preferences.setSources([spec("A2", "Cats"), spec("GONE", "Deleted")])
        let model = model(library([LibraryCollection(identifier: "A2", title: "Cats", kind: .userAlbum)]))

        await model.start()

        #expect(model.collections.map(\.title) == ["Cats", "Deleted"])
        #expect(model.collections.map(\.isWrong) == [false, true])
        #expect(preferences.sources.count == 2)
    }

    @Test("A collection the pickers leave out, chosen before they did, is still found")
    func leftOutOfThePickers() async {
        preferences.setSources([spec("RS", "Recently Saved")])
        let model = model(library([LibraryCollection(identifier: "RS", title: "Recently Saved", kind: .recentlySaved)]))

        await model.start()

        #expect(model.collections.map(\.isWrong) == [false])
    }

    @Test("When the library cannot be read, nothing is called wrong and nothing stored is changed")
    func unreadable() async {
        preferences.setSources([spec("A2", "Cats")])
        let model = model(SampleLibrary(access: .authorized, failing: true))

        await model.start()

        #expect(model.collections.map(\.isWrong) == [false])
        #expect(preferences.sources == [spec("A2", "Cats")])
    }

    @Test("With Photos access off the library is not asked, and no collection is singled out")
    func accessOff() async {
        preferences.setSources([spec("A2", "Cats")])
        let model = model(SampleLibrary(access: .denied))

        await model.start()

        #expect(model.photosAccessIsOff)
        #expect(model.collections.map(\.isWrong) == [false])
    }

    @Test("Each time the app comes forward the preview looks at the sources afresh")
    func previewLooksAgain() async {
        let pictures = ScriptedPictures([])
        let model = SettingsModel(
            sources: ChosenSources(preferences: preferences), library: SampleLibrary(access: .authorized),
            preview: .sample(pictures))

        await model.start()
        await model.start()

        #expect(pictures.timesForgotten == 2)
    }

    @Test("After the app comes forward the sheet counts again, so photographs added in Photos show")
    func sheetCountsAgain() async {
        let favorites = LibraryCollection(identifier: "F", title: "Favorites", kind: .favorites)
        let library = SampleLibrary(access: .authorized, collections: [favorites], counts: ["F": 0])
        let model = model(library)
        await model.start()
        #expect(await counted(model.makePicker()) == [0])

        library.replaceCounts(["F": 2])
        await model.start()

        #expect(await counted(model.makePicker()) == [2])
    }

    /// The counts a sheet shows once it has finished counting.
    func counted(_ picker: CollectionPickerModel) async -> [Int?] {
        await picker.load()
        for _ in 0..<200 where picker.isCounting {
            try? await Task.sleep(for: .milliseconds(10))
            await picker.refresh()
        }
        return picker.tree.map { $0.item?.count }
    }

    @Test("A collection that comes back is no longer wrong the next time the app comes forward")
    func comesBack() async {
        preferences.setSources([spec("A2", "Cats")])
        let library = SampleLibrary(access: .authorized)
        let model = model(library)
        await model.start()
        #expect(model.collections.map(\.isWrong) == [true])

        library.replaceCollections([LibraryCollection(identifier: "A2", title: "Cats", kind: .userAlbum)])
        await model.start()

        #expect(model.collections.map(\.isWrong) == [false])
    }
}
