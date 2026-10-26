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
//
// **Filled, the picture is cropped as it is written**, so the file is the
// widget's shape at its pixels and the widget never decodes more than it
// shows. `Plans/Widget Settings.md`, *The crop is made when the picture is
// written*.

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

    /// How the picture written sits in the box it is written for.
    public let framing: Framing

    /// What a filled picture is cropped toward, found in the picture made to
    /// cover the box.
    private let finding: @Sendable (CGImage) -> CropFocus

    /// - Parameters:
    ///   - bandsAbove: A picture of more pixels than this is shrunk in bands.
    ///     A million. Shrunk in one piece, a JPEG of twelve million pixels
    ///     added 24 MB for an iPad's largest widget, measured on a Mac,
    ///     2026-10-12; in bands it added 4 MB.
    ///   - bandBytes: About how many bytes of decoded picture one band may
    ///     be.
    ///   - memory: What the process holds and has left. A test hands over a
    ///     reading of its own.
    ///   - framing: How the picture written sits in its box. Fit and Actual
    ///     Size write the same file; Fill writes one in the box's shape.
    ///   - finding: What a filled picture is cropped toward: its faces, or
    ///     else its subject, by Vision. A test hands over its own.
    public init(
        bandsAbove: Int = 1_000_000, bandBytes: Int = 2 * 1_048_576,
        memory: @escaping @Sendable () -> Footprint.Reading? = { Footprint.now() },
        framing: Framing = .fit,
        finding: @escaping @Sendable (CGImage) -> CropFocus = { CropFocus.found(in: $0) }
    ) {
        self.bandsAbove = bandsAbove
        self.bandBytes = bandBytes
        self.memory = memory
        self.framing = framing
        self.finding = finding
    }

    /// The same resizer, writing for `framing`.
    public func framed(_ framing: Framing) -> PictureResizer {
        PictureResizer(
            bandsAbove: bandsAbove, bandBytes: bandBytes, memory: memory, framing: framing, finding: finding)
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
    /// to: about 12 MB once it has drawn and asked Photos, and from then on,
    /// read on an iPad overnight, 2026-10-16. A fresh one holds 4 MB; it was
    /// 6 MB here until that night. Syd, of counting it so: "1".
    static let heldIdle: Int64 = 12 * 1_048_576

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
    /// - **A JPEG at full colour** is no different: a scan of 9920 by 12925,
    ///   every pixel's colour kept, added about 6 MB at an eighth on an iPad,
    ///   2026-10-15. `Plans/PGR Widgets - iOS.md`, *A scan at full colour*.
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
    /// **Filled, it is shrunk until it covers `box`, and cropped about the
    /// middle to the box's shape.** Syd, 2026-10-08, of fit against fill: "at
    /// some point that will be an option for all of this"; it became one on
    /// 2026-10-25. A picture smaller than the box is still not enlarged: it is
    /// cropped to the box's shape at its own size, and drawn larger where it
    /// is shown.
    ///
    /// **One that covering would make too large is fitted instead**, with
    /// black around it, rather than passed over. Syd, 2026-10-25.
    ///
    /// - Parameters:
    ///   - name: What the log calls the picture: the file's own name unless
    ///     given, as it is for a photograph from Photos, whose file here has
    ///     a name of the cache's.
    ///   - taken: When it was taken, for the log: from its EXIF unless given.
    @discardableResult
    public func write(
        _ original: URL, fitting box: CGSize, to destination: URL, named name: String? = nil, taken: String? = nil
    ) throws -> Resize {
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

        let type = (CGImageSourceGetType(source) as String?) ?? ""
        let inBands = Self.shrinksInBands(type, pixels: storedWidth * storedHeight, above: bandsAbove)
        let reading = memory()
        let named = name ?? original.lastPathComponent
        let taken = taken ?? Self.taken(in: properties)

        // Fitted, and what filling would take instead.
        let fitted = Self.sized(width: width, height: height, scale: Self.fitScale(width, height, box))
        var wanted = fitted
        var fills = false
        if framing == .fill {
            let covering = Self.sized(width: width, height: height, scale: Self.fillScale(width, height, box))
            let coveringNeeds = needs(
                type: type, storedWidth: storedWidth, storedHeight: storedHeight,
                fraction: Self.fraction(of: max(width, height), for: covering.longestSide, type: type),
                inBands: inBands, wanted: covering, fitted: fitted, cropped: Self.cropped(covering, to: box))
            if let reading, let left = reading.left, coveringNeeds > left {
                Log.widget.notice(
                    """
                    \(Log.widgetsTag, privacy: .public) fitted a picture rather than fill: \
                    \(Self.naming(named, taken), privacy: .public)covering \
                    \(Int(box.width))x\(Int(box.height)) needs about \(coveringNeeds / 1_048_576) MB, \
                    \(Footprint.againstLimit(reading), privacy: .public)
                    """)
            } else {
                wanted = covering
                fills = true
            }
        }

        let longestSide = wanted.longestSide
        // Decoded at an eighth, a quarter or a half where the format allows:
        // the smallest that is still no smaller than what is wanted.
        let fraction = Self.fraction(of: max(width, height), for: longestSide, type: type)
        let needed = needs(
            type: type, storedWidth: storedWidth, storedHeight: storedHeight, fraction: fraction,
            inBands: inBands, wanted: wanted, fitted: fitted, cropped: fills ? Self.cropped(wanted, to: box) : nil)
        try refuseIfTooLarge(
            original, type: type, storedWidth: storedWidth, storedHeight: storedHeight, needing: needed,
            with: reading, named: named, taken: taken)

        let wantedWidth = wanted.width
        let wantedHeight = wanted.height
        // Where in the picture, at the size it is drawn, the crop is.
        let crop = fills ? Self.middle(ofWidth: wantedWidth, height: wantedHeight, shapedLike: box) : nil
        // Said before it starts: a picture that ends the extension never
        // reaches the line a fetch writes when it ends. Read on an iPad,
        // 2026-10-12, where two processes were ended with nothing to say
        // which picture did it.
        let starting = Self.starting(
            type, width: Int(width), height: Int(height), toWidth: wantedWidth, height: wantedHeight,
            inBands: inBands, fraction: fraction, needing: needed, named: named, taken: taken,
            croppedTo: crop.map { (width: Int($0.width), height: Int($0.height)) })
        Log.widget.notice(
            """
            \(Log.widgetsTag, privacy: .public) \(starting, privacy: .public)\
            \(reading.map { ", " + Footprint.againstLimit($0) } ?? "", privacy: .public)
            """)

        var image: CGImage
        if inBands {
            let drawn = try self.inBands(
                source, orientation: orientation, fraction: fraction, width: wantedWidth, height: wantedHeight,
                crop: crop)
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
            // Cropped from what came back, which may be a pixel or so from
            // the size asked for.
            if fills {
                // Vision comes on top of the shrink, so it is asked only when
                // both fit in what was left.
                let visionFits = reading?.left.map { needed + Self.visionNeeds <= $0 } ?? true
                if !visionFits {
                    Log.widget.notice(
                        """
                        \(Log.widgetsTag, privacy: .public) not asking Vision: with the shrink it needs about \
                        \((needed + Self.visionNeeds) / 1_048_576) MB\
                        \(reading.map { ", " + Footprint.againstLimit($0) } ?? "", privacy: .public)
                        """)
                }
                let focus = visionFits ? finding(whole) : .middle
                let crop = Self.crop(ofWidth: whole.width, height: whole.height, shapedLike: box, toward: focus)
                Log.widget.notice(
                    """
                    \(Log.widgetsTag, privacy: .public) cropped toward \(focus.said, privacy: .public)\
                    \(memory().map { ", " + Footprint.againstLimit($0) } ?? "", privacy: .public)
                    """)
                guard let cropped = Self.drawn(whole, cutTo: crop) else { throw Failure.notAPicture(original) }
                image = cropped
            }
        }

        try Self.encode(image, to: destination)
        return Resize(
            originalType: type,
            originalWidth: Int(width), originalHeight: Int(height),
            originalBytes: Self.byteCount(of: original),
            writtenWidth: image.width, writtenHeight: image.height,
            writtenBytes: Self.byteCount(of: destination))
    }

    /// A picture's size once it is shrunk, in whole pixels.
    struct Sized: Equatable {
        let width: Int
        let height: Int

        var longestSide: Int { max(width, height) }
        var pixels: Int { width * height }
    }

    static func sized(width: Double, height: Double, scale: Double) -> Sized {
        Sized(
            width: max(1, Int((width * scale).rounded())), height: max(1, Int((height * scale).rounded())))
    }

    /// The scale that fits a picture inside `box`, and never enlarges it.
    static func fitScale(_ width: Double, _ height: Double, _ box: CGSize) -> Double {
        min(1, min(box.width / width, box.height / height))
    }

    /// The scale that has a picture cover `box`, and never enlarges it.
    static func fillScale(_ width: Double, _ height: Double, _ box: CGSize) -> Double {
        min(1, max(box.width / width, box.height / height))
    }

    /// The largest part of a picture `width` by `height` that is the shape of
    /// `box`, about its middle, in whole pixels counted from the top left.
    /// For a picture that covers the box it is the box's size.
    static func middle(ofWidth width: Int, height: Int, shapedLike box: CGSize) -> CGRect {
        guard box.width > 0, box.height > 0 else {
            return CGRect(x: 0, y: 0, width: width, height: height)
        }
        let shape = box.width / box.height
        let croppedWidth = max(1, min(width, Int((Double(height) * shape).rounded())))
        let croppedHeight = max(1, min(height, Int((Double(width) / shape).rounded())))
        return CGRect(
            x: (width - croppedWidth) / 2, y: (height - croppedHeight) / 2, width: croppedWidth,
            height: croppedHeight)
    }

    /// About how much asking Vision adds, beyond the shrink. On Syd's phone,
    /// 2026-10-25, a fill from a HEIC in one piece added 8 to 26 MB between
    /// the line before the shrink and the line after Vision, the most in a
    /// process asking Vision for the first time; the shrink alone is
    /// reckoned at 14 to 21 MB of that. Two processes were ended asking it on
    /// top of a fill reckoned at 32 MB.
    static let visionNeeds: Int64 = 16 * 1_048_576

    /// The size of the middle of a picture `sized` in `box`'s shape.
    static func cropped(_ sized: Sized, to box: CGSize) -> Sized {
        let middle = middle(ofWidth: sized.width, height: sized.height, shapedLike: box)
        return Sized(width: Int(middle.width), height: Int(middle.height))
    }

    /// The part of `image` in `rect`, counted from its top left, drawn into a
    /// bitmap of its own.
    ///
    /// **Drawn, and not cut with `cropping(to:)`.** On iOS a HEIC from Photos,
    /// shrunk in one piece and then cut, came out at the size of the cut but
    /// showed a part of the photograph at its full size: a quarter of its
    /// width, enlarged. On *Claude iPhone*, 2026-10-25; the Mac cut the same
    /// picture right. So the crop costs a bitmap of its size, as `needs` says.
    static func drawn(_ image: CGImage, cutTo rect: CGRect) -> CGImage? {
        let colours =
            image.colorSpace.flatMap { $0.model == .rgb && $0.supportsOutput ? $0 : nil }
            ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard
            let context = CGContext(
                data: nil, width: Int(rect.width), height: Int(rect.height), bitsPerComponent: 8,
                bytesPerRow: 0, space: colours, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        // The rect is counted from the picture's top left, and a bitmap from
        // its bottom left.
        context.draw(
            image,
            in: CGRect(
                x: -rect.minX, y: -(Double(image.height) - rect.maxY), width: Double(image.width),
                height: Double(image.height)))
        return context.makeImage()
    }

    /// What a shrink is reckoned to need, for a picture made to cover as well
    /// as one made to fit.
    ///
    /// **In one piece, a picture made to cover is decoded whole and its crop
    /// drawn into a bitmap of its own**, so it needs what it holds beyond the
    /// fitted one, and the crop. **In bands only the crop is drawn**, which is
    /// no larger than the box, as the largest fitted picture already is.
    ///
    /// **A HEIC holds two copies of what covering adds.** On Syd's phone,
    /// 2026-10-25, one of 5712 by 4284 covering 2263 by 1697 took 34 MB before
    /// its crop was drawn, where one copy came to 32 MB with everything else,
    /// and three extension processes were ended drawing the crop.
    func needs(
        type: String, storedWidth: Double, storedHeight: Double, fraction: Int, inBands: Bool,
        wanted: Sized, fitted: Sized, cropped: Sized? = nil
    ) -> Int64 {
        let fitting = needs(type: type, storedWidth: storedWidth, storedHeight: storedHeight, fraction: fraction)
        guard !inBands, wanted.pixels > fitted.pixels else { return fitting }
        let copies = Self.inOnePiece.contains(type) ? 2 : 1
        return fitting + Int64((wanted.pixels - fitted.pixels) * copies + (cropped?.pixels ?? 0)) * 4
    }

    /// About how much a fetch adds to what the process holds, at its most,
    /// when Photos draws the picture itself: five times the picture asked
    /// for, at four bytes a pixel. Only a RAW photograph is fetched that way
    /// now; every other is taken as a file and weighed as one.
    ///
    /// Measured 2026-10-14: 18.5 MB for an iPad's extra large widget, which
    /// is asked for at 1590 by 757, and about 8 MB for its large, at 757
    /// square; 21 MB and 18 MB for a phone's large and tall widgets. Two
    /// photographs took more than 21 MB for the large widget, which this does
    /// not reckon with. `Plans/PGR Widgets - iOS.md`, *The Photos guard on
    /// the devices*.
    public static func needsFromPhotos(fitting box: CGSize) -> Int64 {
        Int64(box.width * box.height * 4 * 5)
    }

    /// Throws when a fetch from Photos is reckoned to need more than the
    /// process has left, before Photos is asked, and says so in the log.
    ///
    /// **Only ever for now.** What it is reckoned at goes with the widget's
    /// size and not the photograph, so it says nothing about any one
    /// photograph, and nothing is recorded against the source.
    public func refuseFromPhotosIfTooLarge(fitting box: CGSize) throws {
        guard let reading = memory(), let left = reading.left else { return }
        let needed = Self.needsFromPhotos(fitting: box)
        guard needed > left else { return }
        Log.widget.notice(
            """
            \(Log.widgetsTag, privacy: .public) did not ask Photos for now: a photograph at \
            \(Int(box.width))x\(Int(box.height)) needs about \(needed / 1_048_576) MB, \
            \(Footprint.againstLimit(reading), privacy: .public)
            """)
        throw Failure.tooLarge(URL(string: "photos:")!, ever: false)
    }

    /// `shrinking public.jpeg 3264x2448 to 1008x756, in bands at 1/2, reckoned
    /// at 12 MB`: what is about to be shrunk, and the way. The file is not
    /// named: its name is the person's.
    ///
    /// **Named, and when it was taken, since 2026-10-14.** Syd: "it would be
    /// good to log titles if there, and filenames if there. capture dates are
    /// a bonus". Until then the file was never named, its name being the
    /// person's, and a photograph that cost an iPad's widget 19 MB could not
    /// be found among 9,000 favorites. As the agent's record of what it
    /// served names photographs, by his direction of 2026-09-12.
    ///
    /// **And what it is cropped to, when it is filled**: `to 1014x1352,
    /// cropped to 1014x474`.
    static func starting(
        _ type: String, width: Int, height: Int, toWidth: Int, height toHeight: Int,
        inBands: Bool, fraction: Int, needing needed: Int64, named name: String? = nil, taken: String? = nil,
        croppedTo cropped: (width: Int, height: Int)? = nil
    ) -> String {
        let way =
            if !inBands {
                "in one piece"
            } else if fraction > 1 {
                "in bands at 1/\(fraction)"
            } else {
                "in bands at full size"
            }
        let crop = cropped.map { ", cropped to \($0.width)x\($0.height)" } ?? ""
        return "shrinking \(Self.naming(name, taken))\(type) \(width)x\(height) to \(toWidth)x\(toHeight)\(crop), "
            + "\(way), reckoned at \(needed / 1_048_576) MB"
    }

    /// `“DSC_0815.JPG”, taken 2024-09-21 18:03, `, or as much of it as is
    /// known, to stand before the rest of a line.
    static func naming(_ name: String?, _ taken: String?) -> String {
        var said = ""
        if let name { said += "\u{201C}\(name)\u{201D}, " }
        if let taken { said += "taken \(taken), " }
        return said
    }

    /// When a picture was taken, from its EXIF, to the minute:
    /// `2024-09-21 18:03`. Nil when it does not say.
    static func taken(in properties: [CFString: Any]) -> String? {
        guard
            let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
            let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String,
            original.count >= 16
        else { return nil }
        // "2024:09:21 18:03:12"
        let date = original.prefix(10).replacingOccurrences(of: ":", with: "-")
        return "\(date) \(original.dropFirst(11).prefix(5))"
    }

    /// The same, for a moment such as Photos gives, in the device's own time.
    public static func taken(_ date: Date, in timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(
            format: "%04d-%02d-%02d %02d:%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
            parts.hour ?? 0, parts.minute ?? 0)
    }

    /// Throws when shrinking the picture is reckoned to need more than the
    /// process has left, and says so in the log. Where the kernel tells of
    /// no limit, as on a Mac, nothing is refused.
    private func refuseIfTooLarge(
        _ original: URL, type: String, storedWidth: Double, storedHeight: Double, needing needed: Int64,
        with reading: Footprint.Reading?, named name: String?, taken: String?
    ) throws {
        guard let reading, let left = reading.left, let limit = reading.limit else { return }
        guard needed > left else { return }
        let ever = needed > limit - Self.heldIdle
        // Named, as the line before a shrink is: see `starting`.
        Log.widget.notice(
            """
            \(Log.widgetsTag, privacy: .public) passed over a picture too large to shrink: \
            \(Self.naming(name, taken), privacy: .public)\
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
    ///
    /// **With a crop, only the crop is drawn on**: the bitmap is the crop's
    /// size, and the picture is drawn at `width` by `height` across it, so
    /// what falls outside is never kept.
    private func inBands(
        _ source: CGImageSource, orientation: Int, fraction: Int, width: Int, height: Int,
        crop: CGRect? = nil
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
        let kept = crop ?? CGRect(x: 0, y: 0, width: width, height: height)
        guard
            let context = CGContext(
                data: nil, width: Int(kept.width), height: Int(kept.height), bitsPerComponent: 8,
                bytesPerRow: 0, space: colours, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        // The crop is counted from the picture's top left, and a bitmap from
        // its bottom left.
        context.translateBy(x: -kept.minX, y: -(Double(height) - kept.maxY))
        context.concatenate(Self.upright(orientation, width: Double(width), height: Double(height)))

        // Decoded rows for each drawn row, and how many drawn rows a band of
        // `bandBytes` comes to.
        let perRow = Double(picture.height) / drawnHeight
        let decodedRows = max(1, bandBytes / max(1, picture.bytesPerRow))
        let bandRows = Self.bandRows(decodedRows: decodedRows, perRow: perRow, drawnHeight: drawnHeight)
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

    /// How many drawn rows a band is: as many as `decodedRows` of the
    /// picture come to, and never more than half the picture.
    ///
    /// **Never the whole picture in one band.** Drawn in one, the whole
    /// picture is asked for at once, and ImageIO decodes it another way: an
    /// iPad's extension took 18.8 MB for a photograph of 6016 by 4016 at an
    /// eighth, 2026-10-16, whose rows asked for a band at a time cost a
    /// fraction of a megabyte each, and a Mac took 30 MB for a grey scan in
    /// one band and less than 14 MB in two. `Plans/PGR Widgets - iOS.md`,
    /// *The iPad overnight with every source*.
    static func bandRows(decodedRows: Int, perRow: Double, drawnHeight: Double) -> Int {
        min(max(1, Int(Double(decodedRows) / perRow)), max(1, (Int(drawnHeight) + 1) / 2))
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
