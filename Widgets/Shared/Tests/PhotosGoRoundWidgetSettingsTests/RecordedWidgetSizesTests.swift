import CoreGraphics
import Foundation
import Testing

@testable import PhotosGoRoundWidgetSettings

@Suite("The sizes the system has handed the widgets, kept where the app can read them")
struct RecordedWidgetSizesTests {
    let suite = scratchSuiteName("recorded-sizes")

    @Test("With nothing recorded there are no sizes")
    func nothing() {
        let sizes = RecordedWidgetSizes(suiteName: suite)

        #expect(sizes.all.isEmpty)
        #expect(sizes.size(of: .small) == nil)
    }

    @Test("A size recorded under the system's name for a family is read back for that family")
    func roundTrip() {
        let sizes = RecordedWidgetSizes(suiteName: suite)

        sizes.record(CGSize(width: 164, height: 164), forFamily: "systemSmall")
        sizes.record(CGSize(width: 348, height: 740), forFamily: "systemExtraLargePortrait")

        #expect(sizes.size(of: .small) == CGSize(width: 164, height: 164))
        #expect(sizes.size(of: .extraLargePortrait) == CGSize(width: 348, height: 740))
        #expect(sizes.size(of: .medium) == nil)
    }

    @Test("What the extension records, the app reads: another reader of the same store sees it")
    func shared() {
        RecordedWidgetSizes(suiteName: suite).record(CGSize(width: 348, height: 164), forFamily: "systemMedium")

        #expect(RecordedWidgetSizes(suiteName: suite).all == [.medium: CGSize(width: 348, height: 164)])
    }

    @Test("A family the app does not know, and a size of nothing, are not kept")
    func ignored() {
        let sizes = RecordedWidgetSizes(suiteName: suite)

        sizes.record(CGSize(width: 100, height: 40), forFamily: "accessoryRectangular")
        sizes.record(.zero, forFamily: "systemLarge")

        #expect(sizes.all.isEmpty)
    }

    @Test("The latest size handed for a family is the one kept")
    func latest() {
        let sizes = RecordedWidgetSizes(suiteName: suite)
        sizes.record(CGSize(width: 158, height: 158), forFamily: "systemSmall")

        sizes.record(CGSize(width: 164, height: 164), forFamily: "systemSmall")

        #expect(sizes.size(of: .small) == CGSize(width: 164, height: 164))
    }
}
