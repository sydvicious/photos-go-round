// The Photos-Go-Round widget: one photograph, fitted to the widget or filling
// it, changed on a timeline. `Plans/Photos-Go-Round Widgets.md`.
//
// **A proof of concept, carried by the existing app.** It moves to the menubar
// app's bundle when there is one.
//
// **Its settings are how often it changes, and how its pictures sit in it**,
// as on iOS: `PhotoWidgetSettings`. `Plans/Widget Settings.md`, *On the Mac*.
//
// **It draws what the iOS widget draws.** `WidgetFace` is the one view for
// both, and for the iOS app's preview.

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
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Settings.kind, intent: PhotoWidgetSettings.self, provider: PhotoTimeline()) {
            entry in
            WidgetFace(entry.face, enlarges: entry.enlarges)
                // The system blanks a placeholder's words. These faces are an
                // icon and a word or two, and are meant to be read.
                .unredacted()
                // The widget's content, not its background: the system
                // removes a background in some places.
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName(Settings.displayName)
        .description("Your photographs, one after another.")
        // "Widgets in every Home Screen size the platform offers."
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .systemExtraLargePortrait,
        ])
        .contentMarginsDisabled()
    }
}
