import Foundation
import PhotosGoRoundAgentAPI
import Testing
import TinyCache

@testable import PhotosGoRoundWidgetSettings

@Suite("Which sources have had a picture passed over, kept where the app can read it")
struct SkippedPicturesTests {
    let suite = scratchSuiteName("skipped-pictures")
    let coins = SourceSpec.folder("/pictures/coins")
    let moon = SourceSpec(kind: .file, locator: "/pictures/moon.png")

    @Test("With nothing recorded, no source has had one passed over")
    func nothing() {
        #expect(!SkippedPictures(suiteName: suite).holds(anyOf: [coins, moon]))
        #expect(!SkippedPictures(suiteName: suite).holds(coins))
    }

    @Test("Each source is asked after by itself")
    func oneSource() {
        SkippedPictures(suiteName: suite).record(moon)

        #expect(SkippedPictures(suiteName: suite).holds(moon))
        #expect(!SkippedPictures(suiteName: suite).holds(coins))
    }

    @Test("A source recorded is found again, by another reader of the same preferences")
    func roundTrip() {
        SkippedPictures(suiteName: suite).record(coins)
        SkippedPictures(suiteName: suite).record(coins)

        #expect(SkippedPictures(suiteName: suite).holds(anyOf: [moon, coins]))
        #expect(!SkippedPictures(suiteName: suite).holds(anyOf: [moon]))
    }

    @Test("A folder is the same source with its subfolders or without")
    func subfoldersDoNotMatter() {
        SkippedPictures(suiteName: suite).record(coins)

        #expect(SkippedPictures(suiteName: suite).holds(anyOf: [.folder("/pictures/coins", recursive: true)]))
    }

    @Test("A source that is no longer chosen takes its record with it")
    func goesWithItsSource() {
        let skipped = SkippedPictures(suiteName: suite)
        skipped.record(coins)
        skipped.record(moon)

        skipped.keep(only: [moon])

        #expect(!skipped.holds(anyOf: [coins]))
        #expect(skipped.holds(anyOf: [moon]))
    }
}

@MainActor
@Suite("The note that some pictures may not appear in widgets")
struct SkippedNoteTests {
    let preferences = Preferences(suiteName: scratchSuiteName("skipped-note"))
    let skipped = SkippedPictures(suiteName: scratchSuiteName("skipped-note-record"))
    let coins = SourceSpec.folder("/pictures/coins")
    let scans = SourceSpec.folder("/pictures/scans")

    var model: SettingsModel {
        SettingsModel(
            sources: ChosenSources(preferences: preferences), library: SampleLibrary(access: .authorized),
            preview: .sample(), skipped: skipped)
    }

    @Test("With nothing passed over there is no note")
    func noNote() {
        preferences.setSources([coins])

        #expect(!model.somePicturesSkipped)
    }

    @Test("Once a widget has passed over a picture in a chosen source, the note is there")
    func note() {
        preferences.setSources([coins, scans])
        skipped.record(coins)

        #expect(model.somePicturesSkipped)
    }

    @Test("The row of a source that has had a picture passed over is marked, and no other row is")
    func theRowIsMarked() {
        preferences.setSources([coins, scans])
        skipped.record(coins)

        let marked = model.filesAndFolders.filter(\.somePicturesSkipped).map(\.source.locator)

        #expect(marked == [coins.locator])
    }

    @Test("A row is marked as soon as it is looked for")
    func theRowIsMarkedWhenLookedFor() {
        preferences.setSources([coins, scans])
        let model = model
        #expect(model.filesAndFolders.allSatisfy { !$0.somePicturesSkipped })

        skipped.record(scans)
        model.lookForSkipped()

        #expect(model.filesAndFolders.filter(\.somePicturesSkipped).map(\.source.locator) == [scans.locator])
    }

    @Test("It is found when the app is brought forward again")
    func foundOnStarting() async {
        preferences.setSources([coins])
        let model = model
        #expect(!model.somePicturesSkipped)

        skipped.record(coins)
        await model.start()

        #expect(model.somePicturesSkipped)
    }

    @Test("It is found as soon as it is looked for, as when the preview has passed a picture over")
    func foundWhenLookedFor() {
        preferences.setSources([coins])
        let model = model
        #expect(!model.somePicturesSkipped)

        skipped.record(coins)
        model.lookForSkipped()

        #expect(model.somePicturesSkipped)
    }

    @Test("It stays until that source goes away, and then it goes for good")
    func untilTheSourceGoes() throws {
        preferences.setSources([coins, scans])
        skipped.record(coins)
        let model = model

        model.remove(try #require(model.filesAndFolders.first { $0.source.locator == scans.locator }))
        #expect(model.somePicturesSkipped)

        model.remove(try #require(model.filesAndFolders.first { $0.source.locator == coins.locator }))
        #expect(!model.somePicturesSkipped)
        #expect(!skipped.holds(anyOf: [coins]))
    }
}
