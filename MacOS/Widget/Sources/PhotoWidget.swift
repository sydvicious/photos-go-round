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
            } else if let trouble = entry.trouble {
                Text(trouble)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                WaitingView()
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

/// What a widget shows while it waits for its first photograph: the app's icon,
/// greyed over, and the word. Syd, 2026-10-09: "I want the app icon with a grey
/// overlay, with 'Scanning...' in the widgets while they wait for their first
/// pictures."
///
/// It is what the system shows in a widget's place while the first timeline is
/// being built, which with Photos allowed to download can take a while. Nothing
/// has gone wrong when this is up; when something has, the widget says what.
struct WaitingView: View {
    var body: some View {
        ZStack {
            if let icon = Self.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            }
            Color.gray.opacity(0.65)
            Text("Scanning…")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The system draws a placeholder with its text and pictures blanked
        // out. This one is the icon and one word, and is meant to be read.
        .unredacted()
    }

    /// The icon of the app that carries this extension, asked of the system by
    /// the app's own path, so the widget shows whatever icon the app has.
    @MainActor private static let icon: NSImage? = {
        // …/Photos-Go-Round.app/Contents/PlugIns/Photos-Go-Round Widget.appex
        let app = Bundle.main.bundleURL
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard app.pathExtension == "app" else { return nil }
        return NSWorkspace.shared.icon(forFile: app.path(percentEncoded: false))
    }()
}
