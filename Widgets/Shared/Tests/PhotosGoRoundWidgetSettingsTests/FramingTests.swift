import CoreGraphics
import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundWidgetFace
import Testing

@testable import PhotosGoRoundWidgetSettings

/// How the photographs sit in every widget: Fit, Fill or Actual Size, as the
/// app sets it. `Plans/Widget Settings.md`, *Fit or fill*.
@MainActor
@Suite("Fit, Fill and Actual Size, as the app sets them")
struct FramingTests {
    let suite = scratchSuiteName("framing")
    var preferences: Preferences { Preferences(suiteName: suite) }
    var chosen: ChosenSources { ChosenSources(preferences: preferences) }

    let cats = SourceSpec(kind: .photosCollection, locator: "A2")
    let phone = CGSize(width: 393, height: 852)

    func picture(_ name: String) -> WidgetFace.Content { .picture(URL(filePath: "/pictures/\(name)")) }

    // MARK: What is kept

    @Test("With nothing chosen, the widgets fit")
    func fitByDefault() {
        #expect(chosen.framing == .fit)
    }

    @Test("What is chosen is kept, with the sources")
    func kept() {
        chosen.frame(.fill)
        #expect(chosen.framing == .fill)
        chosen.frame(.actualSize)
        #expect(chosen.framing == .actualSize)
    }

    @Test("What cannot be read is taken as Fit", arguments: ["crop", "", "FILL"])
    func unreadable(_ stored: String) {
        UserDefaults(suiteName: suite)?.set(stored, forKey: Preferences.Key.widgetFraming.rawValue)
        #expect(chosen.framing == .fit)
    }

    @Test("A number where a name belongs is taken as Fit")
    func notAName() {
        UserDefaults(suiteName: suite)?.set(2, forKey: Preferences.Key.widgetFraming.rawValue)
        #expect(chosen.framing == .fit)
    }

    /// A widget's own choice in Edit Widget is stored by these names, and
    /// read back through `Framing`; the names are kept once widgets are out.
    @Test(
        "Each is stored by the name a widget's own choice carries",
        arguments: [(Framing.fit, "fit"), (.fill, "fill"), (.actualSize, "actual-size")])
    func storedNames(_ framing: Framing, _ name: String) {
        #expect(framing.rawValue == name)
        #expect(Framing(rawValue: name) == framing)
    }

    @Test("A widget following the app is not one of the three")
    func asInTheApp() {
        #expect(Framing(rawValue: "as-in-the-app") == nil)
    }

    @Test("Only Actual Size draws a small picture at its own size")
    func enlarges() {
        #expect(Framing.fit.enlarges)
        #expect(Framing.fill.enlarges)
        #expect(!Framing.actualSize.enlarges)
    }

    // MARK: Where the pictures are kept

    @Test("Filled pictures are kept apart; Fit and Actual Size share the folder there was before")
    func folders() {
        let box = CGSize(width: 1014, height: 474)
        #expect(CachedPreviewPictures.sizedName(box, .fit) == "1014x474")
        #expect(CachedPreviewPictures.sizedName(box, .actualSize) == "1014x474")
        #expect(CachedPreviewPictures.sizedName(box, .fill) == "1014x474-fill")
    }

    // MARK: The preview

    @Test("Changing to Fill starts the preview over")
    func fillStartsOver() async {
        let preview = PreviewModel(
            pictures: ScriptedPictures([.picture("a.jpg")]), device: .phone, screen: phone, scale: 3)
        preview.show([cats])
        await preview.advance()
        #expect(preview.content == picture("a.jpg"))

        preview.use(framing: .fill)

        #expect(preview.framing == .fill)
        #expect(preview.content == .scanning)
    }

    @Test("Changing from Fit to Actual Size keeps the picture: only its drawing changes")
    func actualSizeKeepsThePicture() async {
        let preview = PreviewModel(
            pictures: ScriptedPictures([.picture("a.jpg")]), device: .phone, screen: phone, scale: 3)
        preview.show([cats])
        await preview.advance()

        preview.use(framing: .actualSize)

        #expect(preview.framing == .actualSize)
        #expect(preview.content == picture("a.jpg"))
    }

    @Test("With nothing chosen, a change of framing shows nothing new")
    func nothingChosen() {
        let preview = PreviewModel(
            pictures: ScriptedPictures([]), device: .phone, screen: phone, scale: 3)

        preview.use(framing: .fill)

        #expect(preview.content == .nothingChosen)
    }
}
