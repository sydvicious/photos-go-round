// The shape that stands for a widget's size in the bar, on iOS, and in the
// Settings window's toolbar, on the Mac. `Plans/PGR Widgets - iOS.md`, *The
// redesign: controls in the nav bar*, and `Plans/Widget Settings.md`, *The
// Mac's Settings window*.

import SwiftUI

/// One size in the bar: a rounded rectangle in the widget's proportions,
/// filled when it is the size the preview is showing.
public struct SizeShape: View {
    let size: CGSize
    let isShowing: Bool

    public init(size: CGSize, isShowing: Bool) {
        self.size = size
        self.isShowing = isShowing
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.28, style: .continuous)
            .fill(isShowing ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear))
            // Dark and thick enough to read as a shape at this size. Syd,
            // 2026-10-10: "darker or thicker".
            .strokeBorder(isShowing ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary), lineWidth: 2)
            .frame(width: size.width, height: size.height)
    }

    /// The same shape as a picture, for a bar button that is to be an
    /// ordinary one. It carries its own colours: a bar draws a picture it is
    /// left to colour all in one, and the size that is showing would not
    /// stand out.
    public static func image(size: CGSize, isShowing: Bool) -> Image {
        Image(size: size) { context in
            let line: CGFloat = 2
            let inside = CGRect(origin: .zero, size: size).insetBy(dx: line / 2, dy: line / 2)
            let shape = Path(
                roundedRect: inside, cornerRadius: min(size.width, size.height) * 0.28, style: .continuous)
            let colour = GraphicsContext.Shading.color(isShowing ? .accentColor : .primary)
            if isShowing {
                context.fill(shape, with: colour)
            }
            context.stroke(shape, with: colour, lineWidth: line)
        }
        .renderingMode(.original)
    }
}
