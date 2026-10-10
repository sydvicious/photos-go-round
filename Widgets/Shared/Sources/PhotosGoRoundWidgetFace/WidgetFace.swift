// What a widget draws. `Plans/PGR Widgets - iOS.md`.
//
// **One view, for the widget and for the app's preview of it.** Syd,
// 2026-10-09, of the preview: "I really want them to know what the pic
// actually looks like". So the preview draws this and so does a widget, and
// the two cannot drift apart.
//
// **A photograph is fitted inside, whole, with black around it**, as
// everywhere else in Photos-Go-Round.
//
// **Three faces without a photograph**, on iOS and iPadOS. Syd, 2026-10-09:
// the plain app icon with nothing chosen; the icon greyed over with
// "Scanning…" while the first photograph is fetched; and the icon greyed over
// with "No Photos found" when sources are chosen and no picture is to be had.

import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public struct WidgetFace: View {
    public enum Content: Equatable, Sendable {
        /// A photograph, as a file.
        case picture(URL)
        case nothingChosen
        case scanning
        case noPhotos
    }

    private let content: Content

    public init(_ content: Content) {
        self.content = content
    }

    public var body: some View {
        ZStack {
            Color.black
            switch content {
            case .picture(let file):
                FittedPicture(file: file)
                    // A new view for each photograph, so one fades into the next.
                    .id(file)
                    .transition(.opacity)
            case .nothingChosen:
                iconFace(words: nil)
            case .scanning:
                iconFace(words: "Scanning…")
            case .noPhotos:
                iconFace(words: "No Photos found")
            }
        }
        .animation(.easeInOut(duration: 1), value: content)
    }

    /// The icon, plain when there are no words and greyed over when there are.
    private func iconFace(words: String?) -> some View {
        ZStack {
            Self.icon?
                .resizable()
                .scaledToFit()
                .padding(8)
            if let words {
                Color.gray.opacity(0.65)
                Text(words)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(8)
            }
        }
    }
}

extension WidgetFace {
    /// The app icon, at full size, carried with this view.
    ///
    /// **A picture of the icon, because nothing else is big enough.** Syd,
    /// 2026-10-10: "include a full resolution picture of the app icon in the
    /// bundle, and use it". The only icon an iOS app can load of its own is
    /// the 120-pixel one the Home Screen uses, and a widget extension has
    /// none. This one is 1024 pixels, exported from `Artwork/PhotosGoRound.icon`
    /// by Icon Composer's own tool. Run from the repository root whenever the
    /// icon changes:
    ///
    ///     "$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool" \
    ///         "Artwork/PhotosGoRound.icon" --export-image \
    ///         --output-file "Widgets/Shared/Sources/PhotosGoRoundWidgetFace/Resources/PhotosGoRoundIcon.png" \
    ///         --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
    @MainActor static let icon: Image? = {
        guard let file = Bundle.module.url(forResource: "PhotosGoRoundIcon", withExtension: "png")
        else { return nil }
        #if canImport(UIKit)
            return UIImage(contentsOfFile: file.path(percentEncoded: false)).map(Image.init(uiImage:))
        #elseif canImport(AppKit)
            return NSImage(contentsOf: file).map(Image.init(nsImage:))
        #else
            return nil
        #endif
    }()
}

/// One photograph, read once and kept. The file may be cleared away while it
/// is still on screen or fading out, so it is not read again at each drawing.
private struct FittedPicture: View {
    @State private var image: Image?

    init(file: URL) {
        _image = State(initialValue: Self.load(file))
    }

    var body: some View {
        image?
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static func load(_ file: URL) -> Image? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        #if canImport(UIKit)
            return UIImage(data: data).map(Image.init(uiImage:))
        #elseif canImport(AppKit)
            return NSImage(data: data).map(Image.init(nsImage:))
        #else
            return nil
        #endif
    }
}

#if DEBUG
    #Preview("Nothing chosen") {
        WidgetFace(.nothingChosen)
            .frame(width: 338, height: 158)
    }

    #Preview("Scanning") {
        WidgetFace(.scanning)
            .frame(width: 338, height: 158)
    }

    #Preview("No Photos found") {
        WidgetFace(.noPhotos)
            .frame(width: 158, height: 158)
    }
#endif
