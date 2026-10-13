// Writing a picture at a widget's size. `Plans/Photos-Go-Round Widgets.md`,
// *Spike: a 1-minute refresh, and the extension's memory*.
//
// **The original is never decoded whole.** A widget extension runs under about
// 30 MB of RAM, and a decoded picture costs width × height × 4 bytes whatever
// its size on disk. `CGImageSourceCreateThumbnailAtIndex` decodes straight to
// the size asked for, so what is held is the widget-sized picture and not the
// original.
//
// **A very large picture is shrunk in bands.** That call holds an eighth-size
// copy of the picture, twice, and the file's own bytes: for a scan of 679
// million pixels that was 86 MB and more, and on an iPad, 2026-10-12, every
// extension process was ended at 30 MB with a coin scan half read. A band is
// a strip of the picture a couple of megabytes deep, decoded, drawn at the
// widget's size and let go before the next. The same scan then adds about
// 10 MB. `Plans/PGR Widgets - iOS.md`, *A very large picture, in bands*.
//
// **A picture that would not fit is not started on.** Going over the limit is
// not an error the extension is handed: the system ends it. So what a shrink
// needs is reckoned before any of the picture is decoded, and held against
// what the kernel says is left. *The guard*, in the same plan.

import CoreGraphics
import Foundation
import ImageIO
import OSLog
import PhotosGoRoundAgentAPI
import UniformTypeIdentifiers

public struct PictureResizer: Sendable {
    public enum Failure: Error, Equatable {
        case notAPicture(URL)
        case notWritten(URL)
        /// Shrinking it is reckoned to need more memory than the process has
        /// left, so it was not started on. `ever` when it would not fit in
        /// an extension holding nothing else either: no wake could show it.
        case tooLarge(URL, ever: Bool)
    }

    /// What one resize read and what it wrote.
    public struct Resize: Sendable, Equatable {
        /// The original's uniform type identifier, such as `public.tiff`.
        public let originalType: String
        public let originalWidth: Int
        public let originalHeight: Int
        public let originalBytes: Int
        public let writtenWidth: Int
        public let writtenHeight: Int
        public let writtenBytes: Int

        /// `public.tiff 6000x4500, 54.1 MB → 438x328, 41 KB`, for a log. The
        /// original's size in pixels is what a full decode of it costs, at
        /// four bytes each. A photograph from Photos has no bytes to say:
        /// `photos 4032x3024 → 1092x819, 212 KB`.
        public var said: String {
            let bytes =
                originalBytes > 0 ? String(format: ", %.1f MB", Double(originalBytes) / 1_048_576) : ""
            return "\(originalType) \(originalWidth)x\(originalHeight)\(bytes) → "
                + "\(writtenWidth)x\(writtenHeight), \(writtenBytes / 1024) KB"
        }
    }

    /// A picture of more pixels than this is shrunk in bands.
    private let bandsAbove: Int
    /// About how many bytes of decoded picture one band may be.
    private let bandBytes: Int

    /// What the process holds, and what it has left of its limit.
    private let memory: @Sendable () -> Footprint.Reading?

    /// - Parameters:
    ///   - bandsAbove: A picture of more pixels than this is shrunk in bands.
    ///     A million. Shrunk in one piece, a JPEG of twelve million pixels
    ///     added 24 MB for an iPad's largest widget, measured on a Mac,
    ///     2026-10-12; in bands it added 4 MB.
    ///   - bandBytes: About how many bytes of decoded picture one band may
    ///     be.
    ///   - memory: What the process holds and has left. A test hands over a
    ///     reading of its own.
    public init(
        bandsAbove: Int = 1_000_000, bandBytes: Int = 2 * 1_048_576,
        memory: @escaping @Sendable () -> Footprint.Reading? = { Footprint.now() }
    ) {
        self.bandsAbove = bandsAbove
        self.bandBytes = bandBytes
        self.memory = memory
    }

    /// The kinds that are shrunk in one piece whatever their size. In bands a
    /// HEIC of twelve million pixels added 38 MB, and in one piece 10 MB, at
    /// every size tried up to forty-nine million. Measured on a Mac,
    /// 2026-10-12, each in a process of its own.
    private static let inOnePiece: Set<String> = ["public.heic", "public.heif"]

    static func shrinksInBands(_ type: String, pixels: Double, above bandsAbove: Int) -> Bool {
        pixels > Double(bandsAbove) && !inOnePiece.contains(type)
    }

    /// What a widget extension is held to. Read on an iPad, 2026-10-12: every
    /// line gave 30.0 MB, and the system's own line for each process says
    /// `Memory Limits: active 30 inactive 30`.
    public static let widgetLimit: Int64 = 30 * 1_048_576

    /// A resizer that refuses what no widget could shrink, whatever the
    /// process it is in has: it reckons as an extension holding nothing else
    /// does. For the app's preview, which is of a widget and has gigabytes
    /// of its own. Syd, 2026-10-12: "the preview should use the exact same
    /// methodology as the widgets".
    public static var asAWidget: PictureResizer {
        PictureResizer(memory: {
            Footprint.Reading(footprint: heldIdle, resident: heldIdle, left: widgetLimit - heldIdle)
        })
    }

    /// The fraction a picture is decoded at where its format allows: an
    /// eighth, a quarter or a half, whichever is the smallest that leaves it
    /// no smaller than what is wanted, and 1 when none does.
    ///
    /// **A JPEG is decoded at an eighth or at its own size, and never at a
    /// half or a quarter.** ImageIO may give a larger picture than the
    /// fraction asked for, and for some JPEGs it decodes at full size and
    /// makes the result smaller afterwards, so a strip costs sixteen times
    /// what it was cut to cost. Two photographs from an iPhone did that at a
    /// quarter and ended an extension on an iPad, 2026-10-12: 48 MB on a
    /// Mac, where the same file rewritten without loss by `jpegtran` took
    /// 3 MB. What it is about those files is not known; nothing in their
    /// size, tables or markers tells them from one that is given its
    /// fraction. At an eighth the same file is decoded at an eighth. At its
    /// own size there is no fraction to be refused, and a strip is what it
    /// was cut to be.
    static func fraction(of longestSide: Double, for wanted: Int, type: String) -> Int {
        let fractions = type == "public.jpeg" ? [8] : [8, 4, 2]
        return fractions.first { longestSide / Double($0) >= Double(wanted) } ?? 1
    }

    /// What an extension holds with nothing to do, of the 30 MB it is held
    /// to: 4 to 7 MB, read on an iPad, 2026-10-12.
    static let heldIdle: Int64 = 6 * 1_048_576

    /// About how much shrinking a picture adds to what the process holds, at
    /// its most. Each figure is the most measured on a Mac, 2026-10-12, in a
    /// process of its own, and a little over:
    ///
    /// - **A JPEG in bands**, baseline or progressive: 4 to 11 MB, up to 679
    ///   million pixels, and 13 MB for a photograph decoded at its own size
    ///   for a picture 1590 pixels square, which is more than any widget
    ///   asks for. It does not grow with the picture; what it grows with is
    ///   the picture written, which the largest widget keeps under 8 MB.
    /// - **A HEIC in one piece**: 10 to 12 MB, up to 49 million pixels.
    /// - **A PNG or a TIFF in bands**: 10 to 22 MB at 12 and 24 million
    ///   pixels, and 24 MB for the PNG in one piece: the picture at the
    ///   fraction it is decoded at, and a little more again than a JPEG.
    ///   Nothing larger was tried, so this is what any other kind is
    ///   reckoned at too.
    /// - **A picture small enough to shrink in one piece**: two copies of it.
    func needs(type: String, storedWidth: Double, storedHeight: Double, fraction: Int) -> Int64 {
        let megabyte: Int64 = 1_048_576
        let decoded = Int64(storedWidth * storedHeight * 4)
        if Self.inOnePiece.contains(type) { return 14 * megabyte }
        guard Self.shrinksInBands(type, pixels: storedWidth * storedHeight, above: bandsAbove) else {
            return decoded * 2 + 4 * megabyte
        }
        if type == "public.jpeg" { return 14 * megabyte }
        return decoded / Int64(fraction * fraction) + 14 * megabyte
    }

    /// Writes a JPEG of `original` at the largest size that fits inside
    /// `box`, in pixels, with nothing cut off. A picture smaller than that is
    /// written at its own size: enlarging it here would only make a bigger
    /// file of the same picture.
    ///
    /// **Fit, not fill**, as everywhere else in Photos-Go-Round: the whole
    /// photograph, with black around it. Syd, 2026-10-08, of fit against fill:
    /// "at some point that will be an option for all of this".
    @discardableResult
    public func write(_ original: URL, fitting box: CGSize, to destination: URL) throws -> Resize {
        let unread = [kCGImageSourceShouldCache: false] as CFDictionary
        guard
            let source = CGImageSourceCreateWithURL(original as CFURL, unread),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, unread) as? [CFString: Any],
            let storedWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
            let storedHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
            storedWidth > 0, storedHeight > 0
        else { throw Failure.notAPicture(original) }

        // Orientations 5 to 8 are stored on their side, so the picture as seen
        // has the stored width and height exchanged.
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let onItsSide = (5...8).contains(orientation)
        let width = onItsSide ? storedHeight : storedWidth
        let height = onItsSide ? storedWidth : storedHeight

        let scale = min(1, min(box.width / width, box.height / height))
        let longestSide = max(1, Int((max(width, height) * scale).rounded()))
        let type = (CGImageSourceGetType(source) as String?) ?? ""
        // Decoded at an eighth, a quarter or a half where the format allows:
        // the smallest that is still no smaller than what is wanted.
        let fraction = Self.fraction(of: max(width, height), for: longestSide, type: type)
        let reading = memory()
        let needed = needs(type: type, storedWidth: storedWidth, storedHeight: storedHeight, fraction: fraction)
        try refuseIfTooLarge(
            original, type: type, storedWidth: storedWidth, storedHeight: storedHeight, needing: needed,
            with: reading)

        let inBands = Self.shrinksInBands(type, pixels: storedWidth * storedHeight, above: bandsAbove)
        let wantedWidth = max(1, Int((width * scale).rounded()))
        let wantedHeight = max(1, Int((height * scale).rounded()))
        // Said before it starts: a picture that ends the extension never
        // reaches the line a fetch writes when it ends. Read on an iPad,
        // 2026-10-12, where two processes were ended with nothing to say
        // which picture did it.
        let starting = Self.starting(
            type, width: Int(width), height: Int(height), toWidth: wantedWidth, height: wantedHeight,
            inBands: inBands, fraction: fraction, needing: needed)
        Log.widget.notice(
            """
            \(Log.widgetsTag, privacy: .public) \(starting, privacy: .public)\
            \(reading.map { ", " + Footprint.againstLimit($0) } ?? "", privacy: .public)
            """)

        let image: CGImage
        if inBands {
            let drawn = try self.inBands(
                source, orientation: orientation, fraction: fraction, width: wantedWidth, height: wantedHeight)
            guard let drawn else { throw Failure.notAPicture(original) }
            image = drawn
        } else {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: longestSide,
            ]
            guard let whole = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                throw Failure.notAPicture(original)
            }
            image = whole
        }

        try Self.encode(image, to: destination)
        return Resize(
            originalType: type,
            originalWidth: Int(width), originalHeight: Int(height),
            originalBytes: Self.byteCount(of: original),
            writtenWidth: image.width, writtenHeight: image.height,
            writtenBytes: Self.byteCount(of: destination))
    }

    /// `shrinking public.jpeg 3264x2448 to 1008x756, in bands at 1/2, reckoned
    /// at 12 MB`: what is about to be shrunk, and the way. The file is not
    /// named: its name is the person's.
    static func starting(
        _ type: String, width: Int, height: Int, toWidth: Int, height toHeight: Int,
        inBands: Bool, fraction: Int, needing needed: Int64
    ) -> String {
        let way =
            if !inBands {
                "in one piece"
            } else if fraction > 1 {
                "in bands at 1/\(fraction)"
            } else {
                "in bands at full size"
            }
        return "shrinking \(type) \(width)x\(height) to \(toWidth)x\(toHeight), \(way), "
            + "reckoned at \(needed / 1_048_576) MB"
    }

    /// Throws when shrinking the picture is reckoned to need more than the
    /// process has left, and says so in the log. Where the kernel tells of
    /// no limit, as on a Mac, nothing is refused.
    private func refuseIfTooLarge(
        _ original: URL, type: String, storedWidth: Double, storedHeight: Double, needing needed: Int64,
        with reading: Footprint.Reading?
    ) throws {
        guard let reading, let left = reading.left, let limit = reading.limit else { return }
        guard needed > left else { return }
        let ever = needed > limit - Self.heldIdle
        // The file is not named: its name is the person's.
        Log.widget.notice(
            """
            \(Log.widgetsTag, privacy: .public) passed over a picture too large to shrink: \
            \(type, privacy: .public) \(Int(storedWidth))x\(Int(storedHeight)) needs about \
            \(needed / 1_048_576) MB, \(Footprint.againstLimit(reading), privacy: .public)\
            \(ever ? "; no wake could show it" : "", privacy: .public)
            """)
        throw Failure.tooLarge(original, ever: ever)
    }

    /// The picture at `width` by `height`, the right way up, drawn a band at a
    /// time so that no more than a band of it is ever decoded.
    ///
    /// **Decoded at `fraction` of its size where the format allows.** A JPEG
    /// is decoded at that size directly, and never at its own.
    ///
    /// **Each band is cut from the picture and drawn where it belongs.** Asked
    /// for a strip, ImageIO reads and decodes that strip. Asked for the whole
    /// picture, it reads the whole file into memory and decodes all of it.
    /// Measured on a Mac, 2026-10-12, for 33280 by 20395 pixels in a file of
    /// 223 MB: 296 MB drawn whole, 10 MB in bands.
    ///
    /// **A band is cut a little deep and drawn inside its own edges**, so that
    /// its first and last rows are made from the picture on both sides of
    /// them and no seam shows where two bands meet.
    private func inBands(
        _ source: CGImageSource, orientation: Int, fraction: Int, width: Int, height: Int
    ) throws -> CGImage? {
        var decoding: [CFString: Any] = [kCGImageSourceShouldCache: false]
        let onItsSide = (5...8).contains(orientation)
        // The picture as it is stored, at the size it is drawn.
        let drawnWidth = Double(onItsSide ? height : width)
        let drawnHeight = Double(onItsSide ? width : height)
        if fraction > 1 { decoding[kCGImageSourceSubsampleFactor] = fraction }
        guard let picture = CGImageSourceCreateImageAtIndex(source, 0, decoding as CFDictionary) else {
            return nil
        }
        // In the picture's own colours where they can be drawn in.
        let colours =
            picture.colorSpace.flatMap { $0.model == .rgb && $0.supportsOutput ? $0 : nil }
            ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: colours, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.concatenate(Self.upright(orientation, width: Double(width), height: Double(height)))

        // Decoded rows for each drawn row, and how many drawn rows a band of
        // `bandBytes` comes to.
        let perRow = Double(picture.height) / drawnHeight
        let decodedRows = max(1, bandBytes / max(1, picture.bytesPerRow))
        let bandRows = max(1, Int(Double(decodedRows) / perRow))
        // Enough rows beyond a band's edges for the drawing of them.
        let beyond = Int(perRow.rounded(.up)) * 3 + 2

        var top = 0
        while top < Int(drawnHeight) {
            let bottom = min(Int(drawnHeight), top + bandRows)
            let first = max(0, Int(Double(top) * perRow) - beyond)
            let last = min(picture.height, Int((Double(bottom) * perRow).rounded(.up)) + beyond)
            let drew = autoreleasepool { () -> Bool in
                guard
                    let strip = picture.cropping(
                        to: CGRect(x: 0, y: first, width: picture.width, height: last - first))
                else { return false }
                context.saveGState()
                // A bitmap counts upward from its bottom row, and a picture's
                // rows are counted down from its top.
                context.clip(
                    to: CGRect(
                        x: 0, y: drawnHeight - Double(bottom), width: drawnWidth,
                        height: Double(bottom - top)))
                context.draw(
                    strip,
                    in: CGRect(
                        x: 0, y: drawnHeight - Double(last) / perRow, width: drawnWidth,
                        height: Double(last - first) / perRow))
                context.restoreGState()
                return true
            }
            guard drew else { return nil }
            top = bottom
        }
        return context.makeImage()
    }

    /// What turns a picture as it is stored, drawn from the bottom left, the
    /// right way up in a bitmap of `width` by `height`. The orientations are
    /// EXIF's: 1 is as stored, 2 to 4 are mirrored or upside down, and 5 to 8
    /// are on their side.
    static func upright(_ orientation: Int, width: Double, height: Double) -> CGAffineTransform {
        switch orientation {
        case 2: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: width, ty: 0)
        case 3: CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: width, ty: height)
        case 4: CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
        case 5: CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: width, ty: height)
        case 6: CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: height)
        case 7: CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
        case 8: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: width, ty: 0)
        default: .identity
        }
    }

    /// Writes a picture that is already the size wanted, as the Photos library
    /// hands one back. Nothing is decoded and nothing is shrunk; the report's
    /// original is whatever the library says the photograph is.
    @discardableResult
    public func write(
        _ image: CGImage, originalType: String, originalWidth: Int, originalHeight: Int,
        to destination: URL
    ) throws -> Resize {
        try Self.encode(image, to: destination)
        return Resize(
            originalType: originalType, originalWidth: originalWidth, originalHeight: originalHeight,
            originalBytes: 0, writtenWidth: image.width, writtenHeight: image.height,
            writtenBytes: Self.byteCount(of: destination))
    }

    /// Written beside the destination and moved into place, so that a file with
    /// the destination's name is always a whole picture.
    private static func encode(_ image: CGImage, to destination: URL) throws {
        let manager = FileManager.default
        let partial = destination.deletingLastPathComponent()
            .appending(path: ".\(UUID().uuidString).partial")
        let quality = [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary
        guard
            let written = CGImageDestinationCreateWithURL(
                partial as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw Failure.notWritten(destination) }
        CGImageDestinationAddImage(written, image, quality)
        guard CGImageDestinationFinalize(written) else {
            try? manager.removeItem(at: partial)
            throw Failure.notWritten(destination)
        }
        do {
            try manager.moveItem(at: partial, to: destination)
        } catch {
            try? manager.removeItem(at: partial)
            throw error
        }
    }

    private static func byteCount(of file: URL) -> Int {
        (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
    }
}
