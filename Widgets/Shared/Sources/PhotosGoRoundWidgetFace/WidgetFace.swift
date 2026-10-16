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
//
// **A photograph greyed over with "Scanning…"**, when Photos has not answered
// for the next one. Syd, 2026-10-11: "put the scanning overlay over whatever
// is showing so the user knows something is wrong".

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
        /// A photograph that has stayed up because Photos did not answer for
        /// the next, with "Scanning…" over it.
        case scanningOver(URL)
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
            case .picture(let file), .scanningOver(let file):
                FittedPicture(file: file)
                    // A new view for each photograph, so one fades into the next.
                    // The same view with and without "Scanning…" over it, so
                    // only the words come and go.
                    .id(file)
                    .transition(.opacity)
                if case .scanningOver = content {
                    greyed(words: "Scanning…")
                        .transition(.opacity)
                }
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
                greyed(words: words)
            }
        }
    }

    /// Grey over whatever is under it, and a word or two.
    @ViewBuilder private func greyed(words: String) -> some View {
        Color.gray.opacity(0.65)
        Text(words)
            .font(.headline)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(8)
    }
}

extension WidgetFace {
    /// The app icon, carried with this view at four sizes.
    ///
    /// **A picture of the icon, because nothing else is big enough.** Syd,
    /// 2026-10-10: "include a full resolution picture of the app icon in the
    /// bundle, and use it". The only icon an iOS app can load of its own is
    /// the 120-pixel one the Home Screen uses, and a widget extension has
    /// none.
    ///
    /// **Made for widgets.** Syd, 2026-10-13: "Make a version of the icon
    /// optimized for widgets". A widget extension is ended at 30 MB, and its
    /// placeholder is this icon. It was one picture of 1024 pixels at 16 bits
    /// a channel: 8 MB decoded, and a copy at the size wanted was made from
    /// it. That took an extension to 25 MB on an iPad, and to 39.9 MB in a
    /// simulator at a phone's sizes. Now it is four pictures at eight bits a
    /// channel, and the one drawn from is read as it is: 4 MB for the
    /// largest, and no second copy. `Plans/PGR Widgets - iOS.md`, *The icon,
    /// made for widgets*.
    ///
    /// **Each is Icon Composer's own drawing at that size.** Run whenever the
    /// icon changes:
    ///
    ///     ./Scripts/make-widget-icons.sh
    ///
    /// **Drawn from a picture no bigger than it need be.** In the widget
    /// gallery on 2026-10-10, on an iPad mini and an iPhone Duo, every preview
    /// showing the icon at its full 1024 pixels was blank, and the one
    /// showing a photograph at the widget's own size was not. Drawn from a
    /// smaller copy, they all drew.
    @MainActor static func icon(side: CGFloat, scale: CGFloat) -> Image? {
        let pixels = iconPixels(for: max(side, 1) * max(scale, 1))
        if let made = icons[pixels] { return made }
        guard let read = iconImage(pixels: pixels) else { return nil }
        let image = Image(decorative: read, scale: 1)
        icons[pixels] = image
        return image
    }

    /// The icon at each size it has been drawn from: four at most.
    @MainActor private static var icons: [Int: Image] = [:]

    // The four below are not the view's: a picture is read off the main
    // actor as well as on it.

    /// The sizes the icon is kept at, in pixels a side.
    /// `Scripts/make-widget-icons.sh` has the same list.
    nonisolated static let iconSizes = [256, 512, 768, 1024]

    /// The size to draw from for an icon wanted at so many pixels a side:
    /// the smallest that is no smaller, and the largest when none is.
    nonisolated static func iconPixels(for wanted: CGFloat) -> Int {
        iconSizes.first { CGFloat($0) >= wanted } ?? iconSizes[iconSizes.count - 1]
    }

    nonisolated static func iconFile(pixels: Int) -> URL? {
        Bundle.module.url(forResource: "PhotosGoRoundIcon-\(pixels)", withExtension: "png")
    }

    /// The icon's picture at one of its sizes, decoded as it is.
    nonisolated static func iconImage(pixels: Int) -> CGImage? {
        guard let file = iconFile(pixels: pixels),
            let source = CGImageSourceCreateWithURL(file as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(
            source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }
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

    #Preview("Scanning, over a photograph") {
        // The icon's own picture stands in for a photograph.
        if let file = WidgetFace.iconFile(pixels: 1024) {
            WidgetFace(.scanningOver(file))
                .frame(width: 338, height: 158)
        }
    }

    #Preview("No Photos found") {
        WidgetFace(.noPhotos)
            .frame(width: 158, height: 158)
    }
#endif
