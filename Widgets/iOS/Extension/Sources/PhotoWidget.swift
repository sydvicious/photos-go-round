// The Photos-Go-Round widget on iOS and iPadOS: one photograph, fitted inside
// the widget, changed on a timeline. `Plans/PGR Widgets - iOS.md`.
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

struct PhotoWidget: Widget {
    static let kind = "PhotosGoRoundPhotoWidget"

    /// *PhotosGoRound*, with this build's suffix, from `Info.plist`: Debug,
    /// Release and Claude builds each show under their own name in the
    /// widget gallery.
    private static let displayName =
        Bundle.main.object(forInfoDictionaryKey: "PGRWidgetName") as? String ?? "PhotosGoRound"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PhotoTimeline()) { entry in
            WidgetFace(entry.face)
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
