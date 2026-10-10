import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary
import Testing

@testable import PhotosGoRoundWidgetSettings

@MainActor
@Suite("Photos access, and what the app does when it starts")
struct PhotosAccessTests {
    let preferences = Preferences(suiteName: scratchSuiteName("photos-access"))

    func model(_ library: SampleLibrary) -> SettingsModel {
        SettingsModel(
            sources: ChosenSources(preferences: preferences), library: library, preview: .sample())
    }

    @Test("The first time, the app asks by itself, and the sheet comes up once access is given")
    func firstLaunchGranted() async {
        let library = SampleLibrary(access: .notDetermined, answer: .authorized)
        let model = model(library)

        await model.start()

        #expect(library.timesAsked == 1)
        #expect(model.photosAccess == .authorized)
        #expect(model.showsCollectionPicker)
    }

    @Test("When access is refused no sheet comes up, and the list says access is off")
    func firstLaunchRefused() async {
        let library = SampleLibrary(access: .notDetermined, answer: .denied)
        let model = model(library)

        await model.start()

        #expect(library.timesAsked == 1)
        #expect(!model.showsCollectionPicker)
        #expect(model.photosAccessIsOff)
    }

    @Test("Once access has been given the app does not ask again, and no sheet comes up by itself")
    func laterLaunches() async {
        let library = SampleLibrary(access: .authorized)
        let model = model(library)

        await model.start()

        #expect(library.timesAsked == 0)
        #expect(model.photosAccess == .authorized)
        #expect(!model.showsCollectionPicker)
        #expect(!model.photosAccessIsOff)
    }

    @Test("Access turned off later: nothing is asked, nothing is removed, and the list says it is off")
    func turnedOffLater() async {
        let cats = SourceSpec(
            kind: .photosCollection, locator: "A2",
            description: SourceDescription(title: "Cats", collectionKind: "userAlbum"))
        preferences.setSources([cats])
        let library = SampleLibrary(access: .denied)
        let model = model(library)

        await model.start()

        #expect(library.timesAsked == 0)
        #expect(model.photosAccessIsOff)
        #expect(model.collections.map(\.title) == ["Cats"])
        #expect(preferences.sources == [cats])
    }

    @Test("Access a parent or a profile has restricted is off as well")
    func restricted() async {
        let model = model(SampleLibrary(access: .restricted))

        await model.start()

        #expect(model.photosAccessIsOff)
    }

    @Test("Before the app has found out, access is not said to be off")
    func beforeStarting() {
        #expect(!model(SampleLibrary(access: .denied)).photosAccessIsOff)
    }

    @Test("Choosing collections closes the sheet")
    func doneClosesTheSheet() async {
        let model = model(SampleLibrary(access: .notDetermined, answer: .authorized))
        await model.start()

        model.chooseCollections([])

        #expect(!model.showsCollectionPicker)
    }
}
