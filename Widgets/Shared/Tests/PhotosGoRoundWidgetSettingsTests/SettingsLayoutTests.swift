import CoreGraphics
import Testing

@testable import PhotosGoRoundWidgetSettings

@Suite("How the settings screen is laid out: the lists under the preview, or beside it when they do not fit")
struct SettingsLayoutTests {
    @Test("The preview's bounds are as tall as the tallest size when the view is tall enough for them")
    func boundsFit() {
        #expect(SettingsLayout.previewBoundsFit(inViewOfHeight: 700, tallest: 354))
        #expect(SettingsLayout.previewBoundsFit(inViewOfHeight: 354, tallest: 354))
    }

    @Test("In a view too short for them the preview is at the top instead")
    func boundsDoNotFit() {
        #expect(!SettingsLayout.previewBoundsFit(inViewOfHeight: 330, tallest: 354))
    }

    @Test("The lists are under the preview when a heading and one row fit there")
    func listsWithRoom() {
        #expect(SettingsLayout.listsFitUnderPreview(inViewOfHeight: 763, underPreviewOf: 354))
        #expect(SettingsLayout.listsFitUnderPreview(inViewOfHeight: 320, underPreviewOf: 158))
        #expect(SettingsLayout.listsFitUnderPreview(inViewOfHeight: 294, underPreviewOf: 158))
    }

    @Test("With less than that under the preview the lists are beside it")
    func noLists() {
        #expect(!SettingsLayout.listsFitUnderPreview(inViewOfHeight: 390, underPreviewOf: 354))
        #expect(!SettingsLayout.listsFitUnderPreview(inViewOfHeight: 293, underPreviewOf: 158))
    }

    @Test("A preview taller than the view has the lists beside it")
    func previewTallerThanTheView() {
        #expect(!SettingsLayout.listsFitUnderPreview(inViewOfHeight: 330, underPreviewOf: 354))
    }

    @Test("Beside the lists, the preview has room for the widest size and its margins, and never more than half the view")
    func column() {
        #expect(SettingsLayout.previewColumn(inViewOfWidth: 750, widest: 338) == 370)
        #expect(SettingsLayout.previewColumn(inViewOfWidth: 600, widest: 338) == 300)
    }

    @Test("At its smallest, the window shows the bar, a small widget whole, and a heading and one row")
    func smallestWindow() {
        let small = CGSize(width: 158, height: 158)

        let smallest = SettingsLayout.minimumWindow(forSmallWidget: small)

        let view = smallest.height - SettingsLayout.barHeight
        #expect(SettingsLayout.listsFitUnderPreview(inViewOfHeight: view, underPreviewOf: small.height))
        #expect(!SettingsLayout.listsFitUnderPreview(inViewOfHeight: view - 1, underPreviewOf: small.height))
        #expect(smallest.width >= small.width)
    }

    @Test("The smallest window is never narrower than the bar's controls need")
    func smallestWindowWidth() {
        #expect(SettingsLayout.minimumWindow(forSmallWidget: CGSize(width: 120, height: 120)).width == 320)
        #expect(SettingsLayout.minimumWindow(forSmallWidget: CGSize(width: 320, height: 320)).width == 352)
    }
}
