import Foundation
import PhotosGoRoundAgentAPI
import Testing

@testable import PhotosGoRoundWidgetSettings

@MainActor
@Suite("What the settings screen's two lists show")
struct SettingsModelTests {
    let preferences = Preferences(suiteName: scratchSuiteName("settings-model"))
    var model: SettingsModel { SettingsModel(sources: ChosenSources(preferences: preferences)) }

    func album(_ identifier: String, _ title: String) -> SourceSpec {
        SourceSpec(
            kind: .photosCollection, locator: identifier,
            description: SourceDescription(title: title, collectionKind: "album"))
    }

    @Test("With nothing chosen there are no rows")
    func nothingChosen() {
        let model = model

        #expect(model.collections.isEmpty)
        #expect(model.filesAndFolders.isEmpty)
    }

    @Test("A collection's row is called what the collection is called")
    func collectionTitle() {
        preferences.setSources([album("A1", "Iceland")])

        #expect(model.collections.map(\.title) == ["Iceland"])
    }

    @Test("A collection stored without its name is called by its identifier")
    func collectionWithoutAName() {
        preferences.setSources([SourceSpec(kind: .photosCollection, locator: "A9")])

        #expect(model.collections.map(\.title) == ["A9"])
    }

    @Test("A folder's row is called by the folder's own name, and a file's by the file's")
    func fileAndFolderTitles() {
        preferences.setSources([
            .folder("/pictures/Raw Coin Images"), SourceSpec(kind: .file, locator: "/pictures/moon.jpeg"),
        ])

        #expect(model.filesAndFolders.map(\.title) == ["Raw Coin Images", "moon.jpeg"])
    }

    @Test("A row says whether it is a collection, a folder or a file")
    func kinds() {
        preferences.setSources([
            album("A1", "Iceland"), .folder("/pictures/coins"),
            SourceSpec(kind: .file, locator: "/pictures/moon.jpeg"),
        ])
        let model = model

        #expect(model.collections.map(\.kind) == [.collection])
        #expect(model.filesAndFolders.map(\.kind) == [.folder, .file])
    }

    @Test("Each row is told apart by its source's locator")
    func identity() {
        preferences.setSources([album("A1", "Iceland"), .folder("/pictures/coins")])
        let model = model

        #expect(model.collections.map(\.id) == ["A1"])
        #expect(model.filesAndFolders.map(\.id) == ["/pictures/coins/"])
    }

    @Test("Done in the sheet changes the collection rows")
    func choosing() {
        preferences.setSources([album("A1", "Iceland"), .folder("/pictures/coins")])
        let model = model

        model.chooseCollections([album("A2", "Cats")])

        #expect(model.collections.map(\.title) == ["Cats"])
        #expect(model.filesAndFolders.map(\.title) == ["coins"])
    }

    @Test("Removing a row removes its source, from the list and from what is stored")
    func removing() {
        preferences.setSources([album("A1", "Iceland"), album("A2", "Cats")])
        let model = model

        model.remove(model.collections[0])

        #expect(model.collections.map(\.title) == ["Cats"])
        #expect(preferences.sources == [album("A2", "Cats")])
    }

    @Test("Reading again shows what something else has written since")
    func reload() {
        let model = model
        preferences.setSources([.folder("/pictures/coins")])

        model.reload()

        #expect(model.filesAndFolders.map(\.title) == ["coins"])
    }
}
