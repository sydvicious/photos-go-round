import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary
import Testing

@testable import PhotosGoRoundWidgetSettings

@MainActor
@Suite("The count on each row: how many pictures the source holds")
struct SourceCountTests {
    let preferences = Preferences(suiteName: scratchSuiteName("source-counts"))

    func model(_ library: SampleLibrary, _ counts: SampleCounts) -> SettingsModel {
        SettingsModel(
            sources: ChosenSources(preferences: preferences), library: library, preview: .sample(),
            counts: counts)
    }

    func spec(_ identifier: String, _ title: String) -> SourceSpec {
        SourceSpec(
            kind: .photosCollection, locator: identifier,
            description: SourceDescription(title: title, collectionKind: "userAlbum"))
    }

    let cats = LibraryCollection(identifier: "A2", title: "Cats", kind: .userAlbum)
    let iceland = LibraryCollection(identifier: "A1", title: "Iceland", kind: .userAlbum)

    @Test("Each chosen collection shows how many photographs it holds")
    func collections() async {
        preferences.setSources([spec("A1", "Iceland"), spec("A2", "Cats")])
        let model = model(
            SampleLibrary(access: .authorized, collections: [iceland, cats]),
            SampleCounts(["A1": 87, "A2": 1203]))

        await model.start()

        #expect(model.collections.map(\.count) == [87, 1203])
    }

    @Test("Until a source has been counted its row shows no count")
    func notYet() {
        preferences.setSources([spec("A2", "Cats")])
        let model = model(
            SampleLibrary(access: .authorized, collections: [cats]), SampleCounts(["A2": 1203]))

        #expect(model.collections.map(\.count) == [nil])
    }

    @Test("An empty collection shows 0, and nothing is wrong with it")
    func empty() async {
        preferences.setSources([spec("A2", "Cats")])
        let model = model(
            SampleLibrary(access: .authorized, collections: [cats]), SampleCounts(["A2": 0]))

        await model.start()

        #expect(model.collections.map(\.count) == [0])
        #expect(model.collections.map(\.isWrong) == [false])
    }

    @Test("A collection that has gone from the library shows no count")
    func gone() async {
        preferences.setSources([spec("A1", "Iceland"), spec("A2", "Cats")])
        let model = model(
            SampleLibrary(access: .authorized, collections: [cats]),
            SampleCounts(["A1": 0, "A2": 1203]))

        await model.start()

        #expect(model.collections.map(\.count) == [nil, 1203])
    }

    @Test("A source that cannot be counted shows no count")
    func cannotBeCounted() async {
        preferences.setSources([spec("A2", "Cats")])
        let model = model(
            SampleLibrary(access: .authorized, collections: [cats]), SampleCounts([:]))

        await model.start()

        #expect(model.collections.map(\.count) == [nil])
    }

    @Test("Each source is counted again when the app comes forward")
    func countedAgain() async {
        preferences.setSources([spec("A2", "Cats")])
        let counts = SampleCounts(["A2": 3])
        let model = model(SampleLibrary(access: .authorized, collections: [cats]), counts)
        await model.start()

        counts.replace(["A2": 5])
        await model.start()

        #expect(model.collections.map(\.count) == [5])
    }

    @Test("With limited access, Selected Photos shows how many were picked")
    func selectedPhotos() async {
        let model = model(
            SampleLibrary(access: .limited),
            SampleCounts([ChosenSources.selectedPhotos.locator: 3]))

        await model.start()

        #expect(model.collections.map(\.count) == [3])
    }

    @Test("With Photos access off no collection shows a count, and a folder still does")
    func accessOff() async {
        preferences.setSources([spec("A2", "Cats"), .folder("/pictures/Coins")])
        let model = model(
            // A folder's locator ends in a slash, whatever it was given as.
            SampleLibrary(access: .denied), SampleCounts(["A2": 1203, "/pictures/Coins/": 40]))

        await model.start()

        #expect(model.collections.map(\.count) == [nil])
        #expect(model.filesAndFolders.map(\.count) == [40])
    }

    @Test("A collection chosen in the sheet is counted without waiting for the app to come forward")
    func chosenInTheSheet() async {
        let model = model(
            SampleLibrary(access: .authorized, collections: [cats]), SampleCounts(["A2": 1203]))
        await model.start()

        model.chooseCollections([spec("A2", "Cats")])
        await model.counting?.value

        #expect(model.collections.map(\.count) == [1203])
    }
}

@Suite("Counting a source the way a widget does")
struct LibrarySourceCountsTests {
    @Test("A folder holds as many pictures as there are in it")
    func folder() throws {
        let pictures = try ScratchFolder()
        try pictures.picture("coin.png", width: 80, height: 60)
        try pictures.picture("moon.png", width: 80, height: 60)

        let count = try LibrarySourceCounts().count(of: .folder(pictures.url.path(percentEncoded: false)))

        #expect(count == 2)
    }

    @Test("A single file counts as 1")
    func file() throws {
        let pictures = try ScratchFolder()
        try pictures.picture("moon.png", width: 80, height: 60)
        let moon = pictures.url.appending(path: "moon.png").path(percentEncoded: false)

        #expect(try LibrarySourceCounts().count(of: SourceSpec(kind: .file, locator: moon)) == 1)
    }

    @Test("A file that is not there cannot be counted")
    func fileGone() throws {
        let pictures = try ScratchFolder()
        let moon = pictures.url.appending(path: "moon.png").path(percentEncoded: false)

        #expect(throws: (any Error).self) {
            try LibrarySourceCounts().count(of: SourceSpec(kind: .file, locator: moon))
        }
    }

    @Test("A source of a kind that is not counted has no count")
    func unknownKind() throws {
        #expect(try LibrarySourceCounts().count(of: SourceSpec(kind: .googleAlbum, locator: "x")) == nil)
    }
}
