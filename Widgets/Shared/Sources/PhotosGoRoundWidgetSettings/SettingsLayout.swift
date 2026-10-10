// How the settings screen is laid out: the preview, and the lists under it
// when there is room. `Plans/PGR Widgets - iOS.md`, *The redesign: controls in
// the nav bar*.
//
// **The preview first.** Syd, 2026-10-10: "Preview in largest size that will
// hit the view", and under it, "if there is vertical space below the preview",
// the lists. So the widget may take the whole view, and the lists have what is
// left. When that is not a heading and one row, the preview is at the left
// and the lists are beside it.

import CoreGraphics

public enum SettingsLayout: Sendable {
    /// What the bar takes of a window, at the standard text size. From
    /// memory, not measured.
    public static let barHeight: CGFloat = 44

    /// The gap under the preview's widget. There is none above it: its top
    /// is the view's.
    public static let previewPadding: CGFloat = 16

    /// What the lists need under the preview to be shown at all: the "Photos"
    /// heading and one row, at the standard text size.
    private static let listsMinimum: CGFloat = 76 + 44

    /// Whether the view is tall enough for the preview's bounds, which are as
    /// tall as the tallest size with the widget centered in them. When it is
    /// not, the widget is at the top of the view instead. Syd, 2026-10-10:
    /// "if the veritcal bounds won't fit, align the preview at the top".
    public static func previewBoundsFit(inViewOfHeight height: CGFloat, tallest: CGFloat) -> Bool {
        tallest <= height
    }

    /// Whether the lists go under the preview: whether, in a view this tall
    /// under a preview this tall, there is room for a heading and one row.
    /// When there is not, the preview is at the left and the lists beside it.
    /// Syd, 2026-10-10: "Go back to the preview on the left if the bottom
    /// text does not fit".
    public static func listsFitUnderPreview(
        inViewOfHeight height: CGFloat, underPreviewOf preview: CGFloat
    ) -> Bool {
        height - previewPadding - preview >= listsMinimum
    }

    /// How wide the preview's column is when it is at the left: room for the
    /// widest size and its margins, and never more than half the view.
    public static func previewColumn(inViewOfWidth width: CGFloat, widest: CGFloat) -> CGFloat {
        min(width / 2, widest + 32)
    }

    /// The smallest the window may be made: the bar, a small widget shown
    /// whole, and the heading and one row under it; and never narrower than
    /// the bar's controls need.
    ///
    /// Syd, 2026-10-10, asked twice whether the redesign changes it: as it
    /// was, and "the smallest iPad window does not change".
    public static func minimumWindow(forSmallWidget small: CGSize) -> CGSize {
        CGSize(
            width: max(small.width + 32, 320),
            height: barHeight + small.height + previewPadding + listsMinimum)
    }
}
