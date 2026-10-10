// The preview at the top of the settings screen: a widget at its real size,
// showing the chosen photographs. `Plans/PGR Widgets - iOS.md`, *How the
// preview is drawn*.
//
// **At real size, centered, and cropped where it does not fit.** Syd,
// 2026-10-09: "the preview should be drawn at scale, centered, and cropped on
// either side if the view is not big enough". It is never shrunk to fit. Its
// space is as tall as the largest size, or as tall as leaves the collections
// in sight when the screen is too short for that; a widget taller than its
// space is cropped top and bottom the same way.
//
// **A small slideshow.** Its picture changes by itself every few seconds, and
// on a tap. It stops while the app is not in front.

import PhotosGoRoundWidgetFace
import SwiftUI

public struct WidgetPreviewView: View {
    @Bindable private var model: PreviewModel
    @Environment(\.scenePhase) private var scenePhase

    private let room: CGFloat
    /// How wide the widget's space is, once it has been laid out.
    @State private var width: CGFloat?

    /// - Parameter room: The most height the widget's space may take and still
    ///   leave the collections in sight under it.
    public init(model: PreviewModel, room: CGFloat = .infinity) {
        self.model = model
        self.room = room
    }


    public var body: some View {
        VStack(spacing: 12) {
            WidgetFace(model.content)
                .frame(width: model.size.width, height: model.size.height)
                .clipShape(RoundedRectangle(cornerRadius: Self.corner, style: .continuous))
                // Bigger than the space it is given, either way: it stays
                // centered and loses the same from each side. The space does
                // not follow the size that is showing, so choosing another
                // moves nothing below.
                .frame(maxWidth: .infinity)
                .frame(height: model.space(within: room))
                .clipped()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
                .contentShape(Rectangle())
                .onTapGesture { Task { await model.advance() } }
                .accessibilityLabel("Widget preview")
                .accessibilityHint("Shows the next photograph")
            if model.families.count > 1 {
                Picker("Size", selection: $model.family) {
                    ForEach(model.families) { family in
                        Text(family.title).tag(family)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                // The widget's space runs edge to edge; the control does not.
                .padding(.horizontal)
            }
        }
        // Where it starts: the largest size that fits its space uncropped.
        // Asked whenever the space or the sizes become known; the model acts
        // on it once.
        .onChange(of: Fit(width: width, height: model.space(within: room)), initial: true) { _, fit in
            guard let width = fit.width, fit.height > 0 else { return }
            model.settle(within: CGSize(width: width, height: fit.height))
        }
        // Chosen just now: fetch the first picture at once, without waiting
        // for the slideshow's next turn.
        .onChange(of: model.content) { _, content in
            guard content == .scanning else { return }
            Task { await model.advance() }
        }
        // Started again whenever the app comes forward, the sources change,
        // or another size is chosen; ended when any of those stops being so.
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

    /// The space the widget is drawn in, as far as it is known.
    private struct Fit: Equatable {
        let width: CGFloat?
        let height: CGFloat
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
