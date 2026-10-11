import Foundation
import PhotosGoRoundAgentAPI
import Testing

@testable import PhotosGoRoundWidgetSettings

@Suite("The sources a person has chosen, as the settings screen's two lists")
struct ChosenSourcesTests {
    /// A store of its own for each test, in a throwaway preference domain.
    let preferences = Preferences(suiteName: scratchSuiteName("chosen-sources"))
    var chosen: ChosenSources { ChosenSources(preferences: preferences) }

    func album(_ identifier: String, _ title: String, in folders: [String] = []) -> SourceSpec {
        SourceSpec(
            kind: .photosCollection, locator: identifier,
            description: SourceDescription(title: title, collectionKind: "album", folders: folders))
    }

    let coins = SourceSpec.folder("/pictures/coins")
    let oneFile = SourceSpec(kind: .file, locator: "/pictures/moon.jpeg")

    @Test("With nothing chosen both lists are empty")
    func nothingChosen() {
        #expect(chosen.collections.isEmpty)
        #expect(chosen.filesAndFolders.isEmpty)
    }

    @Test("Photos collections are in one list, files and folders in the other")
    func twoLists() {
        let iceland = album("A1", "Iceland", in: ["Trips", "2019"])
        preferences.setSources([coins, iceland, oneFile])

        #expect(chosen.collections == [iceland])
        #expect(chosen.filesAndFolders == [coins, oneFile])
    }

    @Test("What is ticked when Done is pressed is the set of Photos sources")
    func doneReplacesTheCollections() {
        let iceland = album("A1", "Iceland")
        let cats = album("A2", "Cats")
        let garden = album("A3", "Garden")
        preferences.setSources([iceland, cats])

        chosen.chooseCollections([cats, garden])

        #expect(chosen.collections == [cats, garden])
    }

    @Test("Done leaves the files and folders as they were")
    func doneLeavesFilesAndFolders() {
        let iceland = album("A1", "Iceland")
        preferences.setSources([coins, iceland, oneFile])

        chosen.chooseCollections([album("A2", "Cats")])

        #expect(chosen.filesAndFolders == [coins, oneFile])
    }

    @Test("Done with nothing ticked removes every collection, and only the collections")
    func doneWithNothingTicked() {
        preferences.setSources([coins, album("A1", "Iceland"), album("A2", "Cats")])

        chosen.chooseCollections([])

        #expect(chosen.collections.isEmpty)
        #expect(chosen.filesAndFolders == [coins])
    }

    @Test("A collection that stays ticked keeps its place; new ones go after it")
    func ordering() {
        let iceland = album("A1", "Iceland")
        let cats = album("A2", "Cats")
        let garden = album("A3", "Garden")
        preferences.setSources([iceland, cats])

        chosen.chooseCollections([garden, cats, iceland])

        #expect(chosen.collections == [iceland, cats, garden])
    }

    @Test("A collection ticked twice is chosen once")
    func tickedTwice() {
        let cats = album("A2", "Cats")

        chosen.chooseCollections([cats, cats])

        #expect(chosen.collections == [cats])
    }

    @Test("A collection switched off stays switched off when it is still ticked")
    func keepsWhatWasStored() {
        var cats = album("A2", "Cats")
        cats.enabled = false
        preferences.setSources([cats])

        chosen.chooseCollections([album("A2", "Cats")])

        #expect(chosen.collections == [cats])
    }

    @Test("Removing a source takes that one out and leaves the rest")
    func removing() {
        let cats = album("A2", "Cats")
        preferences.setSources([coins, cats, oneFile])

        chosen.remove(coins)

        #expect(preferences.sources == [cats, oneFile])
    }

    @Test("What is chosen is what another reader of the same preferences sees")
    func sharedWithTheWidget() {
        let cats = album("A2", "Cats")
        preferences.setSources([coins])

        chosen.chooseCollections([cats])

        #expect(preferences.sources == [coins, cats])
    }

    @Test("What is added goes after everything else, in the order it was given")
    func adding() {
        let cats = album("A2", "Cats")
        preferences.setSources([coins, cats])
        let stamps = SourceSpec.folder("/pictures/stamps")

        chosen.add([oneFile, stamps])

        #expect(preferences.sources == [coins, cats, oneFile, stamps])
    }

    @Test("What is already chosen is not added again, and keeps what was stored about it")
    func addingWhatIsThere() {
        let withSubfolders = SourceSpec.folder("/pictures/coins", recursive: true)
        preferences.setSources([withSubfolders])

        chosen.add([coins, oneFile, oneFile])

        #expect(preferences.sources == [withSubfolders, oneFile])
    }

    @Test("A folder's subfolders option is stored, and the folder keeps its place")
    func includingSubfolders() {
        let cats = album("A2", "Cats")
        preferences.setSources([coins, cats, oneFile])

        chosen.include(subfolders: true, of: coins)

        #expect(preferences.sources == [SourceSpec.folder("/pictures/coins", recursive: true), cats, oneFile])
    }

    @Test("It can be switched off again, and only a folder has it")
    func subfoldersOffAndOnlyFolders() {
        preferences.setSources([SourceSpec.folder("/pictures/coins", recursive: true), oneFile])

        chosen.include(subfolders: false, of: coins)
        chosen.include(subfolders: true, of: oneFile)

        #expect(preferences.sources == [coins, oneFile])
    }
}
