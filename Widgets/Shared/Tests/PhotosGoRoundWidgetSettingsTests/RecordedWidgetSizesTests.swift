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

        #expect(RecordedWidgetSizes(suiteName: suite).all == [.medium: [CGSize(width: 348, height: 164)]])
    }

    @Test("A family the app does not know, and a size of nothing, are not kept")
    func ignored() {
        let sizes = RecordedWidgetSizes(suiteName: suite)

        sizes.record(CGSize(width: 100, height: 40), forFamily: "accessoryRectangular")
        sizes.record(.zero, forFamily: "systemLarge")

        #expect(sizes.all.isEmpty)
    }

    @Test("Every size a family has been handed is kept, the latest last, and none twice")
    func everySize() {
        let sizes = RecordedWidgetSizes(suiteName: suite)
        let cover = CGSize(width: 196, height: 196)
        let inner = CGSize(width: 200, height: 200)

        sizes.record(cover, forFamily: "systemSmall")
        sizes.record(inner, forFamily: "systemSmall")
        sizes.record(cover, forFamily: "systemSmall")

        #expect(sizes.all == [.small: [inner, cover]])
        #expect(sizes.size(of: .small) == cover)
    }
}

@Suite("Which of the sizes a family has been handed belongs to the screen the app is on")
struct ChosenWidgetSizesTests {
    // The iPhone Duo's two screens, from its simulator's profile, and what its
    // widgets were handed on 2026-10-10. The system handed both sets at once
    // and did not say which screen each was for. Syd's picture of the cover
    // screen that day shows a large and a medium widget about 334 points
    // wide, beside a column the system keeps at the right for the clock and
    // the dock, and his picture of the inner screen shows the tall size 402
    // points wide. So the narrower set is the cover's, and the wider the
    // inner screen's.
    let cover = CGSize(width: 466, height: 678)
    let inner = CGSize(width: 669, height: 951)
    let onTheCover: [WidgetFamily: CGSize] = [
        .small: CGSize(width: 158, height: 158), .medium: CGSize(width: 334, height: 158),
        .large: CGSize(width: 334, height: 354), .extraLargePortrait: CGSize(width: 334, height: 550),
    ]
    let onTheInner: [WidgetFamily: CGSize] = [
        .small: CGSize(width: 190, height: 190), .medium: CGSize(width: 402, height: 190),
        .large: CGSize(width: 402, height: 426), .extraLargePortrait: CGSize(width: 402, height: 662),
    ]

    /// Every size handed, those in `first` before those in `second`.
    func both(_ first: [WidgetFamily: CGSize], _ second: [WidgetFamily: CGSize]) -> [WidgetFamily: [CGSize]] {
        var all: [WidgetFamily: [CGSize]] = [:]
        for (family, size) in first { all[family, default: []].append(size) }
        for (family, size) in second { all[family, default: []].append(size) }
        return all
    }

    @Test("With one size for each family there is nothing to choose")
    func oneEach() {
        let chosen = RecordedWidgetSizes.chosen(
            from: both(onTheCover, [:]), for: cover, on: .phone)

        #expect(chosen == onTheCover)
    }

    @Test("On the Duo's cover screen, the sizes that leave room for the side column are the ones, whichever was handed last")
    func smallerScreen() {
        #expect(RecordedWidgetSizes.chosen(from: both(onTheCover, onTheInner), for: cover, on: .phone) == onTheCover)
        #expect(RecordedWidgetSizes.chosen(from: both(onTheInner, onTheCover), for: cover, on: .phone) == onTheCover)
    }

    @Test("On its inner screen, the wider sizes are the ones")
    func innerScreen() {
        #expect(RecordedWidgetSizes.chosen(from: both(onTheCover, onTheInner), for: inner, on: .phone) == onTheInner)
        #expect(RecordedWidgetSizes.chosen(from: both(onTheInner, onTheCover), for: inner, on: .phone) == onTheInner)
    }

    @Test("On its inner screen turned on its side, the narrower sizes are the ones: the wider do not fit its height")
    func innerScreenOnItsSide() {
        // Syd's picture of the inner screen on its side, 2026-10-10: large,
        // medium and small widgets at 334 by 354, 334 by 158 and 158 square.
        let turned = CGSize(width: inner.height, height: inner.width)

        #expect(RecordedWidgetSizes.chosen(from: both(onTheCover, onTheInner), for: turned, on: .phone) == onTheCover)
        #expect(RecordedWidgetSizes.chosen(from: both(onTheInner, onTheCover), for: turned, on: .phone) == onTheCover)
    }

    @Test("Without the tall size, how tall a set is comes from its large and medium")
    func tallFromTheOthers() {
        var all = both(onTheCover, onTheInner)
        all[.extraLargePortrait] = nil
        let turned = CGSize(width: inner.height, height: inner.width)

        #expect(RecordedWidgetSizes.chosen(from: all, for: turned, on: .phone)[.large] == onTheCover[.large])
        #expect(RecordedWidgetSizes.chosen(from: all, for: inner, on: .phone)[.large] == onTheInner[.large])
    }

    @Test("When no size leaves that room, the narrowest is the one")
    func noneLeavesRoom() {
        let narrow = CGSize(width: 393, height: 852)
        let chosen = RecordedWidgetSizes.chosen(from: both(onTheCover, onTheInner), for: narrow, on: .phone)

        #expect(chosen[.medium] == onTheCover[.medium])
    }

    @Test("A phone with one screen has one set, and it is the one, however much of the width it takes")
    func oneScreen() {
        let handed: [WidgetFamily: CGSize] = [
            .small: CGSize(width: 164, height: 164), .medium: CGSize(width: 350, height: 164),
            .large: CGSize(width: 350, height: 365),
        ]

        let chosen = RecordedWidgetSizes.chosen(
            from: both(handed, [:]), for: CGSize(width: 402, height: 874), on: .phone)

        #expect(chosen == handed)
    }

    @Test("A phone on its side is still the same screen")
    func phoneOnItsSide() {
        let turned = CGSize(width: cover.height, height: cover.width)

        #expect(RecordedWidgetSizes.chosen(from: both(onTheCover, onTheInner), for: turned, on: .phone) == onTheCover)
    }

    @Test("On an iPad the smaller sizes are for upright and the larger for on its side")
    func padTurned() {
        let upright: [WidgetFamily: CGSize] = [
            .small: CGSize(width: 155, height: 155), .medium: CGSize(width: 342, height: 155),
            .large: CGSize(width: 342, height: 342), .extraLarge: CGSize(width: 715.5, height: 342),
        ]
        let onItsSide: [WidgetFamily: CGSize] = [
            .small: CGSize(width: 170, height: 170), .medium: CGSize(width: 378.5, height: 170),
            .large: CGSize(width: 378.5, height: 378.5), .extraLarge: CGSize(width: 795, height: 378.5),
        ]
        let all = both(onItsSide, upright)

        #expect(RecordedWidgetSizes.chosen(from: all, for: CGSize(width: 834, height: 1194), on: .pad) == upright)
        #expect(RecordedWidgetSizes.chosen(from: all, for: CGSize(width: 1194, height: 834), on: .pad) == onItsSide)
    }

    @Test("Before the screen is known, the latest size handed is the one")
    func noScreen() {
        #expect(RecordedWidgetSizes.chosen(from: both(onTheCover, onTheInner), for: nil, on: .phone) == onTheInner)
    }

    @Test("A family handed sizes for only one of the screens keeps the one it has")
    func onlyOne() {
        var all = both(onTheCover, onTheInner)
        all[.extraLargePortrait] = [onTheInner[.extraLargePortrait]!]

        let chosen = RecordedWidgetSizes.chosen(from: all, for: cover, on: .phone)

        #expect(chosen[.extraLargePortrait] == onTheInner[.extraLargePortrait])
        #expect(chosen[.small] == onTheCover[.small])
    }
}
