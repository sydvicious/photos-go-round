import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary
import Testing

@testable import PhotosGoRoundWidgetSettings

@MainActor
@Suite("Limited Photos access: the photographs the person picked are one source")
struct LimitedAccessTests {
    let preferences = Preferences(suiteName: scratchSuiteName("limited-access"))

    func model(_ library: SampleLibrary) -> SettingsModel {
        SettingsModel(
            sources: ChosenSources(preferences: preferences), library: library, preview: .sample())
    }

    let cats = SourceSpec(
        kind: .photosCollection, locator: "A2",
        description: SourceDescription(title: "Cats", collectionKind: "userAlbum"))

    @Test("With limited access the list is one row, Selected Photos")
    func oneRow() async {
        let model = model(SampleLibrary(access: .limited))

        await model.start()

        #expect(model.collections.map(\.title) == ["Selected Photos"])
        #expect(model.collections.map(\.kind) == [.selectedPhotos])
        #expect(!model.photosAccessIsOff)
    }

    @Test("The selection is stored as a source, which is what a widget reads")
    func stored() async {
        let model = model(SampleLibrary(access: .limited))

        await model.start()

        #expect(preferences.sources == [ChosenSources.selectedPhotos])
    }

    @Test("Choosing Select Photos at the first prompt gives that row, and no sheet")
    func atTheFirstPrompt() async {
        let library = SampleLibrary(access: .notDetermined, answer: .limited)
        let model = model(library)

        await model.start()

        #expect(model.collections.map(\.title) == ["Selected Photos"])
        #expect(!model.showsCollectionPicker)
    }

    @Test("Albums chosen with full access are kept, out of sight, while access is limited")
    func albumsKept() async {
        preferences.setSources([cats])
        let model = model(SampleLibrary(access: .limited))

        await model.start()

        #expect(model.collections.map(\.title) == ["Selected Photos"])
        #expect(preferences.sources == [cats, ChosenSources.selectedPhotos])
    }

    @Test("When access is no longer limited the selection is no longer a source, and the albums are back")
    func noLongerLimited() async {
        preferences.setSources([cats])
        let library = SampleLibrary(
            access: .limited,
            collections: [LibraryCollection(identifier: "A2", title: "Cats", kind: .userAlbum)])
        let model = model(library)
        await model.start()

        library.setAccess(.authorized)
        await model.start()

        #expect(model.collections.map(\.title) == ["Cats"])
        #expect(model.collections.map(\.isWrong) == [false])
        #expect(preferences.sources == [cats])
    }

    @Test("The selection is added once, however often the app comes forward")
    func addedOnce() async {
        let model = model(SampleLibrary(access: .limited))

        await model.start()
        await model.start()

        #expect(preferences.sources == [ChosenSources.selectedPhotos])
    }

    @Test("Selected Photos cannot be taken out of the list by hand")
    func notRemovable() async {
        let model = model(SampleLibrary(access: .limited))
        await model.start()
        let row = model.collections[0]
        #expect(!row.isRemovable)

        model.remove(row)

        #expect(model.collections.map(\.title) == ["Selected Photos"])
    }

    @Test("What the Photos button brings up goes by the access there is")
    func chooser() async {
        let full = model(SampleLibrary(access: .authorized))
        await full.start()
        #expect(full.chooser == .collections)

        let limited = model(SampleLibrary(access: .limited))
        await limited.start()
        #expect(limited.chooser == .selectedPhotos)

        let none = model(SampleLibrary(access: .denied))
        await none.start()
        #expect(none.chooser == .settings)

        let restricted = model(SampleLibrary(access: .restricted))
        await restricted.start()
        #expect(restricted.chooser == .settings)
    }

    @Test("Before the app has found out about access, there is nothing to choose with")
    func chooserBeforeStarting() {
        #expect(model(SampleLibrary(access: .authorized)).chooser == .nothing)
    }
}
