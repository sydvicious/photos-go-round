import CoreGraphics
import Testing

@testable import PhotosGoRoundWidgetSettings

@Suite("How the settings screen is laid out, by the shape of its window")
struct SettingsLayoutTests {
    @Test("A window taller than it is wide has the preview on top")
    func tall() {
        #expect(SettingsLayout(for: CGSize(width: 390, height: 763)) == .previewOnTop)
        #expect(SettingsLayout(for: CGSize(width: 820, height: 1100)) == .previewOnTop)
    }

    @Test("A window wider than it is tall has the preview beside the sources, on any device")
    func wide() {
        #expect(SettingsLayout(for: CGSize(width: 763, height: 369)) == .previewBeside)
        #expect(SettingsLayout(for: CGSize(width: 1180, height: 780)) == .previewBeside)
    }

    @Test("Under the preview, the size control, the Photos heading and one row are kept in sight")
    func roomForThePreview() {
        #expect(SettingsLayout.room(inWindowOfHeight: 763) == 583)
        #expect(SettingsLayout.room(inWindowOfHeight: 100) == 0)
    }

    @Test("At its smallest, the window shows a small widget whole, with all of that under it")
    func smallestWindow() {
        let small = CGSize(width: 158, height: 158)

        let smallest = SettingsLayout.minimumWindow(forSmallWidget: small)

        #expect(SettingsLayout.room(inWindowOfHeight: smallest.height) == small.height)
        #expect(smallest.width >= small.width)
    }

    @Test("The smallest window is never narrower than the size control needs")
    func smallestWindowWidth() {
        #expect(SettingsLayout.minimumWindow(forSmallWidget: CGSize(width: 120, height: 120)).width == 320)
        #expect(SettingsLayout.minimumWindow(forSmallWidget: CGSize(width: 320, height: 320)).width == 352)
    }

    @Test("A square window has the preview on top")
    func square() {
        #expect(SettingsLayout(for: CGSize(width: 600, height: 600)) == .previewOnTop)
    }
}
