// The preview on the settings screen: a widget at its real size, showing the
// chosen photographs. `Plans/PGR Widgets - iOS.md`, *How the preview is drawn*
// and *The redesign: controls in the nav bar*.
//
// **At real size, and nothing more.** Syd, 2026-10-09: "the preview should be
// drawn at scale". It is never shrunk to fit. This view is exactly the widget;
// the screen it is on gives it its bounds, and lets it be scrolled when they
// are smaller than it is.
//
// **Which size is in the bar, not here.** Syd, 2026-10-10.
//
// **A small slideshow.** Its picture changes by itself every few seconds, and
// on a tap. It stops while the app is not in front.

import PhotosGoRoundWidgetFace
import SwiftUI

public struct WidgetPreviewView: View {
    private let model: PreviewModel
    @Environment(\.scenePhase) private var scenePhase

    private let face: WidgetFace.Content?
    private let viewport: CGSize
    private let onNoAccess: () -> Void

    /// - Parameters:
    ///   - face: What to draw in place of the preview's own face, when the
    ///     screen knows better: that Photos access is off.
    ///   - viewport: The bounds the screen has for the preview, which decide
    ///     the size it starts on.
    ///   - onNoAccess: A tap on the face that says Photos access is off.
    public init(
        model: PreviewModel, face: WidgetFace.Content? = nil,
        viewport: CGSize = CGSize(width: CGFloat.infinity, height: .infinity),
        onNoAccess: @escaping () -> Void = {}
    ) {
        self.model = model
        self.face = face
        self.viewport = viewport
        self.onNoAccess = onNoAccess
    }

    public var body: some View {
        let face = face ?? model.content
        WidgetFace(face)
            .frame(width: model.size.width, height: model.size.height)
            .clipShape(RoundedRectangle(cornerRadius: Self.corner, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture {
                if face == .noAccess {
                    onNoAccess()
                } else {
                    Task { await model.advance() }
                }
            }
            .accessibilityLabel("Widget preview")
            .accessibilityHint(face == .noAccess ? "Opens Settings" : "Shows the next photograph")
            .accessibilityAddTraits(.isButton)
            // Where it starts: the largest size that fits its bounds with no
            // scrolling. Asked whenever the bounds or the sizes become known;
            // the model leaves a size the person chose alone.
            .onChange(of: Fit(viewport: viewport, known: model.boundsHeight), initial: true) { _, fit in
                guard fit.known > 0 else { return }
                model.settle(within: fit.viewport)
            }
            // Chosen just now: fetch the first picture at once, without
            // waiting for the slideshow's next turn.
            .onChange(of: model.content) { _, content in
                guard content == .scanning else { return }
                Task { await model.advance() }
            }
            // Started again whenever the app comes forward, the sources
            // change, or another size is chosen; ended when any of those stops
            // being so.
            .task(
                id: Running(
                    active: scenePhase == .active, size: model.size,
                    nothingChosen: model.content == .nothingChosen)
            ) {
                guard scenePhase == .active else { return }
                while !Task.isCancelled {
                    await model.advance()
                    try? await Task.sleep(for: Self.every)
                }
            }
    }

    /// The preview's bounds, and whether the sizes are known yet.
    private struct Fit: Equatable {
        let viewport: CGSize
        let known: CGFloat
    }

    /// What the slideshow's task is keyed on.
    private struct Running: Equatable {
        let active: Bool
        /// The size being shown, which changes when another is chosen and
        /// when the screen first becomes known.
        let size: CGSize
        /// Whether nothing is chosen, so that choosing something starts it.
        let nothingChosen: Bool
    }

    /// How long each photograph stays up. To be settled when it is seen
    /// running; a widget's own change is every five minutes.
    private static let every = Duration.seconds(5)

    /// About what the system rounds a widget's corners by.
    private static let corner: CGFloat = 24
}

#if DEBUG
    #Preview("Nothing chosen") {
        WidgetPreviewView(model: .sample())
    }
#endif
