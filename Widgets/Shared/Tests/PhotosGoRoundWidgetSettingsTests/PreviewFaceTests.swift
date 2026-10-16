import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary
import Testing

@testable import PhotosGoRoundWidgetSettings

@MainActor
@Suite("What the preview's face says when Photos access is off")
struct PreviewFaceTests {
    let preferences = Preferences(suiteName: scratchSuiteName("preview-face"))

    func model(
        _ access: LibraryAuthorization, _ pictures: any PreviewPictures = NoPictures()
    ) -> SettingsModel {
        SettingsModel(
            sources: ChosenSources(preferences: preferences), library: SampleLibrary(access: access),
            preview: .sample(pictures))
    }

    let cats = SourceSpec(
        kind: .photosCollection, locator: "A2",
        description: SourceDescription(title: "Cats", collectionKind: "userAlbum"))

    @Test("With access off and nothing chosen, the face says there is no access")
    func nothingChosen() async {
        let model = model(.denied)

        await model.start()

        #expect(model.face == .noAccess)
    }

    @Test("With access off and a collection chosen, which gives no picture, it says so too")
    func noPicture() async {
        preferences.setSources([cats])
        let model = model(.restricted)
        await model.start()

        await model.preview.advance()

        #expect(model.preview.content == .noPhotos)
        #expect(model.face == .noAccess)
    }

    @Test("A folder's picture still shows with Photos access off")
    func folderPicture() async {
        preferences.setSources([.folder("/pictures/Coins")])
        let model = model(.denied, ScriptedPictures([.picture("coin.jpg")]))
        await model.start()

        await model.preview.advance()

        #expect(model.face == .picture(URL(filePath: "/pictures/coin.jpg")))
    }

    @Test("With access given, the face is the preview's own")
    func accessGiven() async {
        let model = model(.authorized)

        await model.start()

        #expect(model.face == .nothingChosen)
    }
}
