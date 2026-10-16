import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary
import Testing

@testable import PhotosGoRoundWidgetSettings

@MainActor
@Suite("When a source goes wrong: what its row says, and what the person is told")
struct SourceTroubleTests {
    let preferences = Preferences(suiteName: scratchSuiteName("source-trouble"))

    /// A model is a run of the app: a new one is the app launched again.
    func model(_ library: SampleLibrary, _ counts: SampleCounts = SampleCounts([:])) -> SettingsModel {
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
    // Spelled as they are stored, with the folder's stroke at the end.
    let coins = SourceSpec.folder("/pictures/Coins/")
    let stamps = SourceSpec.folder("/pictures/Stamps/")
    let moon = SourceSpec(kind: .file, locator: "/pictures/moon.jpeg")

    /// A library that holds Cats and nothing else.
    var library: SampleLibrary { SampleLibrary(access: .authorized, collections: [cats]) }

    static let gone = CocoaError(.fileReadNoSuchFile)
    static let timedOut = POSIXError(.ETIMEDOUT)

    // MARK: - The rows

    @Test("A collection the library no longer holds is removed, and one it holds is not")
    func collectionGone() async {
        preferences.setSources([spec("A2", "Cats"), spec("GONE", "Deleted")])
        let model = model(library, SampleCounts(["A2": 3]))

        await model.start()

        #expect(model.collections.map(\.trouble) == [nil, .removed])
    }

    @Test("A folder or a file that is no longer there is removed")
    func fileGone() async {
        preferences.setSources([coins, moon, stamps])
        let counts = SampleCounts([coins.locator: 4], failing: [moon.locator: Self.gone, stamps.locator: Self.gone])
        let model = model(library, counts)

        await model.start()

        #expect(model.filesAndFolders.map(\.trouble) == [nil, .removed, .removed])
    }

    @Test("A file or folder that cannot be opened, with nothing to say why, is removed")
    func cannotTell() async {
        preferences.setSources([coins])
        let model = model(library, SampleCounts([:], failing: [coins.locator: CocoaError(.fileReadNoPermission)]))

        await model.start()

        #expect(model.filesAndFolders.map(\.trouble) == [.removed])
    }

    @Test(
        "A file or folder that cannot be reached just now is unavailable",
        arguments: [
            POSIXError(.ETIMEDOUT) as any Error, POSIXError(.ENETDOWN), POSIXError(.EHOSTUNREACH),
            URLError(.notConnectedToInternet), CocoaError(.ubiquitousFileUnavailable),
            CocoaError(.ubiquitousFileUbiquityServerNotAvailable),
            // What the file system says, under what Foundation says of it.
            CocoaError(.fileReadUnknown, userInfo: [NSUnderlyingErrorKey: POSIXError(.ETIMEDOUT)]),
        ])
    func cannotReach(_ error: any Error) async {
        preferences.setSources([coins])
        let model = model(library, SampleCounts([:], failing: [coins.locator: error]))

        await model.start()

        #expect(model.filesAndFolders.map(\.trouble) == [.unavailable])
    }

    @Test("When the library cannot be read, every collection is unavailable and none is removed")
    func libraryUnread() async {
        preferences.setSources([spec("A2", "Cats"), spec("GONE", "Deleted")])
        let model = model(SampleLibrary(access: .authorized, failing: true))

        await model.start()

        #expect(model.collections.map(\.trouble) == [.unavailable, .unavailable])
    }

    @Test("With Photos access off, every collection is refused")
    func accessOff() async {
        preferences.setSources([spec("A2", "Cats"), spec("GONE", "Deleted"), coins])
        let model = model(SampleLibrary(access: .denied), SampleCounts([coins.locator: 4]))

        await model.start()

        #expect(model.collections.map(\.trouble) == [.noAccess, .noAccess])
        #expect(model.filesAndFolders.map(\.trouble) == [nil])
    }

    @Test("A folder that is back is drawn as usual again the next time the app comes forward")
    func comesBack() async {
        preferences.setSources([coins])
        let counts = SampleCounts([:], failing: [coins.locator: Self.gone])
        let model = model(library, counts)
        await model.start()
        #expect(model.filesAndFolders.map(\.trouble) == [.removed])

        counts.replace([coins.locator: 4])
        await model.start()

        #expect(model.filesAndFolders.map(\.trouble) == [nil])
        #expect(model.filesAndFolders.map(\.count) == [4])
    }

    @Test("Each grey has its word beside the name, and the red has none")
    func words() {
        #expect(SettingsModel.Row.Trouble.removed.words == "(removed)")
        #expect(SettingsModel.Row.Trouble.unavailable.words == "(unavailable)")
        #expect(SettingsModel.Row.Trouble.noAccess.words == nil)
    }

    @Test("Nothing is taken out of what is stored for being gone")
    func nothingRemoved() async {
        let stored = [spec("A2", "Cats"), spec("GONE", "Deleted"), coins]
        preferences.setSources(stored)
        let model = model(library, SampleCounts(["A2": 3], failing: [coins.locator: Self.gone]))

        await model.start()
        await model.start()

        #expect(preferences.sources == stored)
    }

    // MARK: - The heading and the bar's button

    @Test("The Photos heading and button are red only when the collections' rows are")
    func heading() async {
        preferences.setSources([spec("A2", "Cats")])
        let off = model(SampleLibrary(access: .denied))
        await off.start()
        #expect(off.collectionsAreRefused)

        // Grey rows change neither.
        preferences.setSources([spec("GONE", "Deleted")])
        let grey = model(library)
        await grey.start()
        #expect(!grey.collectionsAreRefused)

        // And with nothing chosen there are no rows to be red.
        preferences.setSources([])
        let none = model(SampleLibrary(access: .denied))
        await none.start()
        #expect(!none.collectionsAreRefused)
    }

    // MARK: - The alert for what has gone

    @Test("At launch, files and folders that have gone are said to be, in the words for them")
    func filesAlert() async {
        preferences.setSources([spec("A2", "Cats"), coins])
        let model = model(library, SampleCounts(["A2": 3], failing: [coins.locator: Self.gone]))

        await model.start()

        #expect(model.goneMessage == "Some files and/or folders are no longer available.")
    }

    @Test("Collections that have gone have words of their own")
    func collectionsAlert() async {
        preferences.setSources([spec("GONE", "Deleted"), coins])
        let model = model(library, SampleCounts([coins.locator: 4]))

        await model.start()

        #expect(model.goneMessage == "Some collections are no longer available.")
    }

    @Test("When both lists have lost something, one alert covers both")
    func bothAlert() async {
        preferences.setSources([spec("GONE", "Deleted"), coins])
        let model = model(library, SampleCounts([:], failing: [coins.locator: Self.gone]))

        await model.start()

        #expect(model.goneMessage == "Some collections, files and/or folders are no longer available.")
    }

    @Test("With nothing gone there is no alert, and none for what is only unavailable")
    func noAlert() async {
        preferences.setSources([spec("A2", "Cats"), coins])
        let model = model(library, SampleCounts(["A2": 3], failing: [coins.locator: Self.timedOut]))

        await model.start()

        #expect(model.goneMessage == nil)
    }

    @Test("Brought forward again in the same run, with the same things gone, the app does not say so twice")
    func onceInARun() async {
        preferences.setSources([coins])
        let model = model(library, SampleCounts([:], failing: [coins.locator: Self.gone]))
        await model.start()
        model.goneMessage = nil

        await model.start()

        #expect(model.goneMessage == nil)
    }

    @Test("Something found gone when the app is brought forward later is said then")
    func goneLater() async {
        preferences.setSources([coins, spec("A2", "Cats")])
        let library = self.library
        let model = model(library, SampleCounts([:], failing: [coins.locator: Self.gone]))
        await model.start()
        model.goneMessage = nil

        library.replaceCollections([])
        await model.start()

        // Of what has gone since, which is a collection.
        #expect(model.goneMessage == "Some collections are no longer available.")
    }

    @Test("What is still gone is said again at the next launch")
    func everyLaunch() async {
        preferences.setSources([coins])
        let counts = SampleCounts([:], failing: [coins.locator: Self.gone])
        let first = model(library, counts)
        await first.start()
        first.goneMessage = nil

        let second = model(library, counts)
        await second.start()

        #expect(second.goneMessage == "Some files and/or folders are no longer available.")
    }

    // MARK: - The alert for Photos access

    @Test("The alert's words are Syd's")
    func accessWords() {
        #expect(
            SettingsModel.noAccessMessage
                == "PhotosGoRound needs access to Photos to continue serving your pictures.")
    }

    @Test("At launch with access off and collections chosen, the alert comes by itself")
    func accessAlert() async {
        preferences.setSources([spec("A2", "Cats")])
        let model = model(SampleLibrary(access: .denied))

        await model.start()

        #expect(model.showsNoAccess)
    }

    @Test("With no Photos sources chosen it does not come at all")
    func noAccessAlertWithoutPhotosSources() async {
        preferences.setSources([coins])
        let model = model(SampleLibrary(access: .denied), SampleCounts([coins.locator: 4]))

        await model.start()

        #expect(!model.showsNoAccess)
    }

    @Test("Nor when access is refused at the first launch, with nothing chosen yet")
    func refusedAtFirstLaunch() async {
        let model = model(SampleLibrary(access: .notDetermined, answer: .denied))

        await model.start()

        #expect(!model.showsNoAccess)
    }

    @Test("It comes once in a run, however often the app is brought forward with access off")
    func accessAlertOnce() async {
        preferences.setSources([spec("A2", "Cats")])
        let model = model(SampleLibrary(access: .denied))
        await model.start()
        model.showsNoAccess = false

        await model.start()
        await model.start()

        #expect(!model.showsNoAccess)
    }

    @Test("Access found off when the app is brought forward later brings it up then")
    func accessTurnedOffLater() async {
        preferences.setSources([spec("A2", "Cats")])
        let library = self.library
        let model = model(library)
        await model.start()
        #expect(!model.showsNoAccess)

        library.setAccess(.denied)
        await model.start()

        #expect(model.showsNoAccess)
    }

    @Test("Turned back on and off again in one run, it comes again")
    func accessOffAgain() async {
        preferences.setSources([spec("A2", "Cats")])
        let library = SampleLibrary(access: .denied, collections: [cats])
        let model = model(library)
        await model.start()
        model.showsNoAccess = false
        library.setAccess(.authorized)
        await model.start()

        library.setAccess(.denied)
        await model.start()

        #expect(model.showsNoAccess)
    }

    @Test("It comes again at the next launch, until access is back or the Photos sources are gone")
    func accessAlertEveryLaunch() async {
        preferences.setSources([spec("A2", "Cats")])
        let first = model(SampleLibrary(access: .denied))
        await first.start()
        first.showsNoAccess = false

        let second = model(SampleLibrary(access: .denied))
        await second.start()
        #expect(second.showsNoAccess)

        // Every Photos source swiped away is the other way it ends.
        second.remove(second.collections[0])
        let third = model(SampleLibrary(access: .denied))
        await third.start()
        #expect(!third.showsNoAccess)
    }

    // MARK: - Taking a row out

    @Test("A collection's row can be taken out, with Photos access off as well")
    func collectionSwiped() async {
        preferences.setSources([spec("A2", "Cats"), spec("GONE", "Deleted"), coins])
        let model = model(SampleLibrary(access: .denied), SampleCounts([coins.locator: 4]))
        await model.start()

        model.remove(model.collections[1])

        #expect(model.collections.map(\.title) == ["Cats"])
        #expect(preferences.sources == [spec("A2", "Cats"), coins])
    }

    @Test("Selected Photos can be taken out, and the widgets stop showing from it")
    func selectionSwiped() async {
        preferences.setSources([coins])
        let model = model(SampleLibrary(access: .limited), SampleCounts([coins.locator: 4]))
        await model.start()
        #expect(model.collections.map(\.title) == ["Selected Photos"])

        model.remove(model.collections[0])

        #expect(model.collections.isEmpty)
        #expect(ChosenSources(preferences: preferences).shown == [coins])
    }

    @Test("Once taken out, the app does not put Selected Photos back by itself")
    func selectionStaysOut() async {
        let model = model(SampleLibrary(access: .limited))
        await model.start()
        model.remove(model.collections[0])

        await model.start()
        #expect(model.collections.isEmpty)

        // Nor at the next launch.
        let next = self.model(SampleLibrary(access: .limited))
        await next.start()
        #expect(next.collections.isEmpty)
        #expect(ChosenSources(preferences: preferences).shown.isEmpty)
    }

    @Test("The Photos button brings Selected Photos back")
    func selectionBack() async {
        let model = model(SampleLibrary(access: .limited))
        await model.start()
        model.remove(model.collections[0])

        await model.selectedPhotosChanged()

        #expect(model.collections.map(\.title) == ["Selected Photos"])
        #expect(preferences.sources == [ChosenSources.selectedPhotos])
    }

    @Test("Taken out, it stays out through access made full or turned off and then limited again")
    func selectionStaysOutThroughAccess() async {
        let library = SampleLibrary(access: .limited)
        let model = model(library)
        await model.start()
        model.remove(model.collections[0])

        for other in [LibraryAuthorization.authorized, .denied] {
            library.setAccess(other)
            await model.start()
            library.setAccess(.limited)
            await model.start()

            #expect(model.collections.isEmpty)
            #expect(ChosenSources(preferences: preferences).shown.isEmpty)
        }

        // And the Photos button still brings it back.
        await model.selectedPhotosChanged()
        #expect(model.collections.map(\.title) == ["Selected Photos"])
    }

    @Test("With Selected Photos taken out and full access given, the albums are back in the list")
    func albumsBackWithFullAccess() async {
        preferences.setSources([spec("A2", "Cats")])
        let library = SampleLibrary(access: .limited, collections: [cats])
        let model = model(library, SampleCounts(["A2": 3]))
        await model.start()
        model.remove(model.collections[0])

        library.setAccess(.authorized)
        await model.start()

        #expect(model.collections.map(\.title) == ["Cats"])
        #expect(model.collections.map(\.count) == [3])
        #expect(ChosenSources(preferences: preferences).shown == [spec("A2", "Cats")])
    }

    @Test("With Selected Photos taken out, the albums chosen with full access stay out of sight")
    func albumsStayOutOfSight() async {
        preferences.setSources([spec("A2", "Cats")])
        let model = model(SampleLibrary(access: .limited, collections: [cats]))
        await model.start()

        model.remove(model.collections[0])

        #expect(model.collections.isEmpty)
        #expect(preferences.sources.map(\.locator).contains("A2"))
    }
}
