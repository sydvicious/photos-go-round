import CoreGraphics
import Testing

@testable import PhotosGoRoundWidgetSettings

/// Syd, 2026-10-31: "have swiping left and right on the preview change the
/// size displayed to the next or previous size".
@Suite("A sideways swipe on the preview: the next size or the previous")
struct SizeSwipeTests {
    @Test("Fingers moving left bring the next size, as turning a page does; moving right, the previous")
    func direction() {
        #expect(SizeSwipe.step(for: -SizeSwipe.distance) == .next)
        #expect(SizeSwipe.step(for: SizeSwipe.distance) == .previous)
    }

    @Test("A swipe shorter than the distance changes nothing")
    func tooShort() {
        #expect(SizeSwipe.step(for: 0) == nil)
        #expect(SizeSwipe.step(for: -(SizeSwipe.distance - 1)) == nil)
        #expect(SizeSwipe.step(for: SizeSwipe.distance - 1) == nil)
    }

    @Test("Movements add up, and the step comes once they have gone far enough")
    func addsUp() {
        var swipe = SizeSwipe()
        #expect(swipe.moved(by: -SizeSwipe.distance / 2) == nil)
        #expect(swipe.moved(by: -SizeSwipe.distance / 2) == .next)
    }

    @Test("One swipe is one step, however far it goes")
    func oncePerSwipe() {
        var swipe = SizeSwipe()
        #expect(swipe.moved(by: SizeSwipe.distance) == .previous)
        #expect(swipe.moved(by: SizeSwipe.distance * 3) == nil)
        #expect(swipe.moved(by: -SizeSwipe.distance * 5) == nil)
    }

    @Test("Once a swipe ends, the next one starts from nothing")
    func endsAndStartsOver() {
        var swipe = SizeSwipe()
        #expect(swipe.moved(by: -SizeSwipe.distance) == .next)
        swipe.ended()
        #expect(swipe.moved(by: SizeSwipe.distance / 2) == nil)
        swipe.ended()
        #expect(swipe.moved(by: -SizeSwipe.distance / 2) == nil)
        #expect(swipe.moved(by: -SizeSwipe.distance / 2) == .next)
    }

    @Test("Back and forth within one swipe counts where it has got to")
    func backAndForth() {
        var swipe = SizeSwipe()
        #expect(swipe.moved(by: -SizeSwipe.distance * 0.8) == nil)
        #expect(swipe.moved(by: SizeSwipe.distance * 0.8) == nil)
        #expect(swipe.moved(by: SizeSwipe.distance) == .previous)
    }
}
