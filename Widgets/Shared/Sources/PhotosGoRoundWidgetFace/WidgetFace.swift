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
// **Four faces without a photograph**, on iOS and iPadOS. Syd, 2026-10-09:
// the plain app icon with nothing chosen; the icon greyed over with
// "Scanning…" while the first photograph is fetched; and the icon greyed over
// with "No Photos found" when sources are chosen and no picture is to be had.
// And, 2026-10-10, with "No Photos Access" when Photos access is off.

import ImageIO
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
        /// Photos access is off, and there is no picture from anywhere else.
        case noAccess
    }

    private let content: Content
    @Environment(\.displayScale) private var displayScale

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
            case .noAccess:
                iconFace(words: "No Photos Access")
            }
        }
        .animation(.easeInOut(duration: 1), value: content)
    }

    /// The icon, plain when there are no words and greyed over when there are.
    private func iconFace(words: String?) -> some View {
        ZStack {
            GeometryReader { space in
                // No bigger than it is drawn. See `icon(side:scale:)`.
                Self.icon(side: min(space.size.width, space.size.height) - 16, scale: displayScale)?
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
    ///
    /// **Drawn from a copy no bigger than it is shown.** In the widget
    /// gallery on 2026-10-10, on an iPad mini and an iPhone Duo, every preview
    /// showing this icon at its full 1024 pixels was blank, and the one
    /// showing a photograph at the widget's own size was not. With the
    /// copy, they all drew. Claude's reading of why, from memory and not
    /// from a log: the system leaves a widget blank when its pictures come to
    /// more pixels than it allows. A widget extension is also held to a few
    /// tens of megabytes, and the full picture is four of them.
    @MainActor static func icon(side: CGFloat, scale: CGFloat) -> Image? {
        // In steps of 64 pixels, so a few sizes are made and kept, not one
        // for every size a window is dragged through.
        let wanted = (max(side, 1) * max(scale, 1) / 64).rounded(.up) * 64
        let pixels = Int(min(max(wanted, 64), 1024))
        if let made = icons[pixels] { return made }
        guard let file = Bundle.module.url(forResource: "PhotosGoRoundIcon", withExtension: "png"),
            let source = CGImageSourceCreateWithURL(file as CFURL, nil),
            let small = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceThumbnailMaxPixelSize: pixels,
                ] as CFDictionary)
        else { return nil }
        let image = Image(decorative: small, scale: 1)
        icons[pixels] = image
        return image
    }

    /// The icon at each size it has been asked for.
    @MainActor private static var icons: [Int: Image] = [:]
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
