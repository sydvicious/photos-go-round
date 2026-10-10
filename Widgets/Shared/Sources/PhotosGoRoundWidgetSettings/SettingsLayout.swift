// How the settings screen is laid out, by the shape of its window.
// `Plans/PGR Widgets - iOS.md`, *A window that is resized*.
//
// **By the window, not the device.** An iPhone turns, and an iPad's window can
// be dragged to almost any shape, so the same device has both. Syd,
// 2026-10-10, of an iPhone: "On landscape, the preview moves to the left, with
// the sources on the right"; and of resized iPad windows, choosing this rule
// for every device over one column on an iPad whatever its window's shape.

import CoreGraphics

public enum SettingsLayout: Sendable {
    /// The preview pinned at the top, and the sources scrolling under it.
    case previewOnTop
    /// The preview in a column on the left, and the sources on the right.
    case previewBeside

    /// What the size control and the gap above it take, under the widget.
    public static let controlHeight: CGFloat = 44

    /// What stays in sight under the preview's widget when the preview is on
    /// top: the padding round the preview, the size control, the "Photos"
    /// heading with its Choose button, and one row. Syd, 2026-10-10. These are
    /// heights at the standard text size; with larger type the row is cut off
    /// and the button can still be reached.
    private static let underPreview: CGFloat = 16 + controlHeight + 76 + 44

    /// The most height the preview's widget may take in a window this tall
    /// and still leave that in sight.
    public static func room(inWindowOfHeight height: CGFloat) -> CGFloat {
        max(0, height - underPreview)
    }

    /// The smallest the window may be made: a small widget shown whole, with
    /// all of that under it, and never narrower than the size control needs.
    ///
    /// Syd, 2026-10-10: "The minimum size of the window should be large enough
    /// for a small widget preview to completely show, the size controls, and
    /// the "Photos" title and the "Choose..." button, plus one row, at the
    /// standard text size."
    public static func minimumWindow(forSmallWidget small: CGSize) -> CGSize {
        CGSize(width: max(small.width + 32, 320), height: small.height + underPreview)
    }

    /// - Parameter window: The space the screen has to lay itself out in.
    public init(for window: CGSize) {
        self = window.width > window.height ? .previewBeside : .previewOnTop
    }
}
