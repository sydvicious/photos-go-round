import Foundation
import PhotosGoRoundAgentAPI
import Testing
import TinyCache

@testable import PhotosGoRoundWidgetSettings

@MainActor
@Suite("What the settings screen's two lists show")
struct SettingsModelTests {
    let preferences = Preferences(suiteName: scratchSuiteName("settings-model"))
    var model: SettingsModel {
        SettingsModel(
            sources: ChosenSources(preferences: preferences), library: SampleLibrary(access: .authorized),
            preview: .sample())
    }

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

    @Test("The preview is told what is chosen, at the start and after each change")
    func previewFollows() {
        let model = model
        #expect(model.preview.content == .nothingChosen)

        model.chooseCollections([album("A2", "Cats")])
        #expect(model.preview.content == .scanning)

        model.remove(model.collections[0])
        #expect(model.preview.content == .nothingChosen)
    }

    @Test("A source that is switched off is not among what the preview shows")
    func previewSkipsWhatIsOff() {
        var cats = album("A2", "Cats")
        cats.enabled = false
        preferences.setSources([cats])

        #expect(model.preview.content == .nothingChosen)
    }

    @Test("Reading again shows what something else has written since")
    func reload() {
        let model = model
        preferences.setSources([.folder("/pictures/coins")])

        model.reload()

        #expect(model.filesAndFolders.map(\.title) == ["coins"])
    }

    // MARK: - Adding files and folders

    func model(leaving bookmarks: BookmarkedSources) -> SettingsModel {
        SettingsModel(
            sources: ChosenSources(preferences: preferences), library: SampleLibrary(access: .authorized),
            preview: .sample(), bookmarks: bookmarks)
    }

    func bookmarks(in scratch: ScratchFolder) -> BookmarkedSources {
        BookmarkedSources(directory: scratch.url.appending(path: "shared", directoryHint: .isDirectory))
    }

    @Test("A folder chosen in the Files browser gets a folder's row, and a file a file's")
    func addingFilesAndFolders() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("Coins/coin.png")
        let moon = try scratch.picture("moon.png")
        let model = model

        model.add([scratch.url.appending(path: "Coins"), moon])

        #expect(model.filesAndFolders.map(\.kind) == [.folder, .file])
        #expect(model.filesAndFolders.map(\.title) == ["Coins", "moon.png"])
    }

    @Test("A folder that is added starts without the folders inside it")
    func addedFolderIsNotRecursive() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("Coins/coin.png")
        let model = model

        model.add([scratch.url.appending(path: "Coins")])

        #expect(preferences.sources.map(\.recursive) == [false])
    }

    @Test("The preview is told about what is added")
    func previewFollowsAdding() throws {
        let scratch = try ScratchFolder()
        let moon = try scratch.picture("moon.png")
        let model = model

        model.add([moon])

        #expect(model.preview.content == .scanning)
    }

    @Test("A bookmark is left for each one added, where a widget can open it")
    func addingLeavesBookmarks() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("Coins/coin.png")
        let moon = try scratch.picture("moon.png")
        let bookmarks = bookmarks(in: scratch)
        let model = model(leaving: bookmarks)

        model.add([scratch.url.appending(path: "Coins"), moon])

        let locators = preferences.sources.map(\.locator)
        #expect(locators.count == 2)
        #expect(locators.allSatisfy { bookmarks.location(of: $0) != nil })
    }

    @Test("Removing a file or folder removes the bookmark left for it")
    func removingForgetsTheBookmark() throws {
        let scratch = try ScratchFolder()
        let moon = try scratch.picture("moon.png")
        let bookmarks = bookmarks(in: scratch)
        let model = model(leaving: bookmarks)
        model.add([moon])
        let locator = try #require(preferences.sources.first?.locator)

        model.remove(model.filesAndFolders[0])

        #expect(preferences.sources.isEmpty)
        #expect(bookmarks.location(of: locator) == nil)
    }
}
