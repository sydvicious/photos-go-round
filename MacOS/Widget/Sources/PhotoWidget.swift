// The Photos-Go-Round widget: one photograph, fitted inside the widget, changed
// on a timeline. `Plans/Photos-Go-Round Widgets.md`.
//
// **A proof of concept, carried by the existing app.** It moves to the menubar
// app's bundle when there is one.

import AppKit
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
        StaticConfiguration(kind: Settings.kind, provider: PhotoTimeline()) { entry in
            PhotoWidgetView(entry: entry)
        }
        .configurationDisplayName(Settings.displayName)
        .description("Your photographs, one after another.")
        // "Widgets in every size the platform offers."
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .systemExtraLargePortrait,
        ])
        .contentMarginsDisabled()
    }
}

struct PhotoWidgetView: View {
    let entry: PhotoEntry

    var body: some View {
        Group {
            if let picture = entry.picture, let image = Self.load(picture) {
                // The whole photograph, with black around it, as everywhere
                // else in Photos-Go-Round. It is the widget's content, not its
                // background: the system removes a background in some places.
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // One photograph fades into the next. Syd, 2026-10-08: "I
                    // want the fade transition". Each entry's picture is a view
                    // of its own, so the system has one to take away and one
                    // to bring in, and the transition says how.
                    .id(picture)
                    .transition(.opacity)
            } else {
                Text(entry.trouble ?? "Photos-Go-Round")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .animation(.easeInOut(duration: 1), value: entry.date)
        .containerBackground(.black, for: .widget)
    }

    /// Opened when the entry is drawn and not before, so that a timeline of
    /// many entries does not hold many pictures. The log line is how the spike
    /// learns where and when the system draws an entry.
    private static func load(_ picture: URL) -> NSImage? {
        let image = NSImage(contentsOf: picture)
        WidgetLog.note("drew \(picture.lastPathComponent)\(image == nil ? ", unreadable" : "")")
        return image
    }
}
