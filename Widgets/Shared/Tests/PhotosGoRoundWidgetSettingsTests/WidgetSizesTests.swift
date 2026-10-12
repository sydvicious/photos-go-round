import CoreGraphics
import Testing

@testable import PhotosGoRoundWidgetSettings

@Suite("How big a widget is, on which device")
struct WidgetSizesTests {
    @Test("Each device offers four sizes, and the fourth is tall on a phone and wide on an iPad")
    func families() {
        #expect(WidgetSizes.families(on: .phone) == [.small, .medium, .large, .extraLargePortrait])
        #expect(WidgetSizes.families(on: .pad) == [.small, .medium, .large, .extraLarge])
    }

    @Test("A phone's tall size is as wide as its large, and as tall as a large and a medium and the gap between two mediums")
    func tallOnAPhone() {
        // A large is two mediums and the gap between them: 354 is 158 twice
        // and 38. So the tall size is 354, 38 and 158.
        #expect(
            WidgetSizes.size(of: .extraLargePortrait, on: .phone, screen: CGSize(width: 393, height: 852))
                == CGSize(width: 338, height: 550))
        #expect(
            WidgetSizes.size(of: .extraLargePortrait, on: .phone, screen: CGSize(width: 430, height: 932))
                == CGSize(width: 364, height: 594))
    }

    @Test("The reckoning gives what the iPhone Duo's widgets were handed")
    func tallAsHanded() {
        // 2026-10-10: medium 402 by 190 and large 402 by 426 with a tall size
        // of 402 by 662, and 334 by 158 and 334 by 354 with one of 334 by 550.
        #expect(
            WidgetSizes.tall(large: CGSize(width: 402, height: 426), medium: CGSize(width: 402, height: 190))
                == CGSize(width: 402, height: 662))
        #expect(
            WidgetSizes.tall(large: CGSize(width: 334, height: 354), medium: CGSize(width: 334, height: 158))
                == CGSize(width: 334, height: 550))
    }

    @Test("An iPad has no tall size")
    func noTallOnAnIPad() {
        #expect(
            WidgetSizes.size(of: .extraLargePortrait, on: .pad, screen: CGSize(width: 820, height: 1180)) == nil)
    }

    @Test("A phone in Apple's table gets that row's sizes")
    func phoneRow() {
        let screen = CGSize(width: 393, height: 852)

        #expect(WidgetSizes.size(of: .small, on: .phone, screen: screen) == CGSize(width: 158, height: 158))
        #expect(WidgetSizes.size(of: .medium, on: .phone, screen: screen) == CGSize(width: 338, height: 158))
        #expect(WidgetSizes.size(of: .large, on: .phone, screen: screen) == CGSize(width: 338, height: 354))
    }

    @Test("The largest phone in the table")
    func largestPhone() {
        let screen = CGSize(width: 430, height: 932)

        #expect(WidgetSizes.size(of: .large, on: .phone, screen: screen) == CGSize(width: 364, height: 382))
    }

    @Test("A screen is the same screen on its side")
    func onItsSide() {
        let screen = CGSize(width: 852, height: 393)

        #expect(WidgetSizes.size(of: .medium, on: .phone, screen: screen) == CGSize(width: 338, height: 158))
    }

    @Test("A phone newer than the table gets the row for the nearest screen")
    func nearestRow() {
        // The iPhone 17's screen, which the table as read does not list.
        let screen = CGSize(width: 402, height: 874)

        #expect(WidgetSizes.size(of: .large, on: .phone, screen: screen) == CGSize(width: 338, height: 354))
    }

    @Test("A phone has no extra-large widget")
    func noExtraLargeOnAPhone() {
        #expect(WidgetSizes.size(of: .extraLarge, on: .phone, screen: CGSize(width: 393, height: 852)) == nil)
    }

    @Test("An iPad gets its own row, and an extra large")
    func padRow() {
        let screen = CGSize(width: 820, height: 1180)

        #expect(WidgetSizes.size(of: .small, on: .pad, screen: screen) == CGSize(width: 136, height: 136))
        #expect(WidgetSizes.size(of: .medium, on: .pad, screen: screen) == CGSize(width: 300, height: 136))
        #expect(WidgetSizes.size(of: .large, on: .pad, screen: screen) == CGSize(width: 300, height: 300))
        #expect(WidgetSizes.size(of: .extraLarge, on: .pad, screen: screen) == CGSize(width: 628, height: 300))
    }

    @Test("Each size has a name a person would call it")
    func names() {
        #expect(WidgetFamily.allCases.map(\.title) == ["Small", "Medium", "Large", "Extra Large", "Extra Large Portrait"])
    }
}
