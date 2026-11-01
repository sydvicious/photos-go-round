// A sideways swipe on the preview, which shows the next size or the previous.
// Syd, 2026-10-31: "have swiping left and right on the preview change the size
// displayed to the next or previous size". The bar's sizes stay; this is a
// second way through them.
//
// **On iOS it is a swipe past the widget's edge.** The preview scrolls sideways
// when the widget is wider than its bounds, and a swipe scrolls it until its
// edge shows; a swipe on past the edge changes the size. Syd, 2026-11-01, over
// a swipe that changes the size only when the widget fits, and over giving up
// the sideways scrolling.
//
// **On the Mac it is a sideways swipe on the trackpad**, which the Settings
// window has free, since it scrolls only up and down.

import CoreGraphics

public struct SizeSwipe {
    public enum Step: Equatable, Sendable {
        case next, previous
    }

    /// How far a swipe goes, in points, before it changes the size. On iOS
    /// it is how far the widget is pulled past its edge, which the scroll
    /// view's give halves: about 80 points of the finger's travel.
    public static let distance: CGFloat = 40

    /// The step for a swipe that has gone `travel` points sideways, which is
    /// negative for fingers moving left. **Left is the next size**, as it is
    /// the next page in a book or a paged view.
    public static func step(for travel: CGFloat) -> Step? {
        if travel <= -distance { return .next }
        if travel >= distance { return .previous }
        return nil
    }

    private var travel: CGFloat = 0
    private var stepped = false

    public init() {}

    /// One movement of a swipe under way, `delta` points sideways. The step
    /// comes the once it has gone far enough: **one swipe is one size**,
    /// however far it goes.
    public mutating func moved(by delta: CGFloat) -> Step? {
        guard !stepped else { return nil }
        travel += delta
        guard let step = Self.step(for: travel) else { return nil }
        stepped = true
        return step
    }

    /// The swipe is over; the next starts from nothing.
    public mutating func ended() {
        travel = 0
        stepped = false
    }
}
