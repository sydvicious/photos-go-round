// The Photos-Go-Round widget on iOS and iPadOS: one photograph, fitted inside
// the widget, changed on a timeline. `Plans/PGR Widgets - iOS.md`.
//
// **Its one setting is how often it changes**: `PhotoWidgetSettings`.
//
// **It draws what the app's preview draws.** `WidgetFace` is the one view for
// both, so what a person sees in the app is what lands on the Home Screen.

import PhotosGoRoundWidgetFace
import SwiftUI
import WidgetKit

@main
struct PhotosGoRoundWidgets: WidgetBundle {
    var body: some Widget {
        PhotoWidget()
    }
}

/// The face, with a line in the log each time the system has it drawn.
///
/// **While the extension's memory is being measured.** On an iPad,
/// 2026-10-12, the extension went from 6 MB to a peak of 24 MB with no
/// timeline being made and no picture being shrunk, and drawing is what else
/// it does. `Plans/PGR Widgets - iOS.md`, *The iPad with bands from a million
/// pixels*.
private struct DrawnFace: View {
    @Environment(\.widgetFamily) private var family
    let face: WidgetFace.Content

    var body: some View {
        let _ = PhotoTimeline.noteDrawing(face, for: family)
        WidgetFace(face)
    }
}

struct PhotoWidget: Widget {
    nonisolated static let kind = "PhotosGoRoundPhotoWidget"

    /// *PhotosGoRound*, with this build's suffix, from `Info.plist`: Debug,
    /// Release and Claude builds each show under their own name in the
    /// widget gallery.
    private static let displayName =
        Bundle.main.object(forInfoDictionaryKey: "PGRWidgetName") as? String ?? "PhotosGoRound"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: PhotoWidgetSettings.self, provider: PhotoTimeline()) { entry in
            DrawnFace(face: entry.face)
                // The system blanks a placeholder's words. These faces are an
                // icon and a word or two, and are meant to be read.
                .unredacted()
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName(Self.displayName)
        .description("Your photographs, one after another.")
        // "Widgets in every Home Screen size the platform offers."
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .systemExtraLargePortrait,
        ])
        .contentMarginsDisabled()
    }
}
