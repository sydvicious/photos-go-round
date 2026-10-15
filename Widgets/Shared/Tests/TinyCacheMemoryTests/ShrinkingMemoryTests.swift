import CoreGraphics
import Foundation
import Testing

@testable import TinyCache

/// A widget extension is ended at 30 MB, and holds 4 to 7 MB with nothing to
/// do. Read on an iPad, 2026-10-12: `Plans/PGR Widgets - iOS.md`, *What the
/// iPad's first night showed*.
///
/// **In a test target of its own, and one at a time.** Each watches what the
/// whole process holds, and a test target is a process: beside the other
/// tests of `TinyCache`, which make pictures of their own while these run, a
/// JPEG that adds 4 MB read as 53.
@Suite("What shrinking a picture takes of a widget's memory", .serialized)
struct ShrinkingMemoryTests {
    static let megabyte: Int64 = 1_048_576

    /// An iPad's extra large widget, in pixels.
    let box = CGSize(width: 1590, height: 756)

    struct Kind: CustomTestStringConvertible, Sendable {
        let name: String, width: Int, height: Int
        var progressive = false
        var grey = false
        var testDescription: String {
            "\(width)x\(height) \(name)\(progressive ? ", progressive" : "")\(grey ? ", grey" : "")"
        }
    }

    /// **What the guard goes by.** A picture is started on when what it is
    /// reckoned to need is no more than the extension has left, so a kind
    /// that took more than it is reckoned at would end the extension.
    ///
    /// A case run after another reads low: the process keeps some of what
    /// the last one took. Each figure in `PictureResizer.needs` was measured
    /// in a process of its own.
    @Test(
        "No kind of picture takes more memory to shrink than it is reckoned to need",
        arguments: [
            // Decoded at its own size, a strip at a time: an eighth would be
            // too small for the widget. First, because a case run after
            // another reads low.
            Kind(name: "jpg", width: 6000, height: 4500),
            Kind(name: "jpg", width: 4000, height: 3000),
            Kind(name: "jpg", width: 12000, height: 9000),
            Kind(name: "jpg", width: 12000, height: 9000, progressive: true),
            // The largest of the coin scans.
            Kind(name: "jpg", width: 33280, height: 20395),
            // A scan in grey, one channel, the size of those that ended an
            // iPad's extension, 2026-10-14. `Plans/PGR Widgets - iOS.md`, *A
            // scan at full colour*.
            Kind(name: "jpg", width: 9920, height: 12925, grey: true),
            Kind(name: "heic", width: 8064, height: 6048),
            Kind(name: "png", width: 4000, height: 3000),
            Kind(name: "tiff", width: 4000, height: 3000),
        ])
    func everyKind(_ kind: Kind) throws {
        let scratch = try ScratchFolder()
        let original = try scratch.largePicture(
            "large.\(kind.name)", width: kind.width, height: kind.height, progressive: kind.progressive,
            grey: kind.grey)
        let resized = scratch.url.appending(path: "resized.jpg")
        let resizer = PictureResizer()

        let (resize, rise) = try MemoryRise.during {
            try resizer.write(original, fitting: box, to: resized)
        }

        #expect(resize.originalWidth == kind.width)
        #expect(resize.writtenHeight == 756)
        let reckoned = resizer.needs(
            type: resize.originalType, storedWidth: Double(kind.width), storedHeight: Double(kind.height),
            fraction: PictureResizer.fraction(
                of: Double(max(kind.width, kind.height)), for: max(resize.writtenWidth, resize.writtenHeight),
                type: resize.originalType))
        #expect(
            rise <= reckoned,
            "it added \(rise / Self.megabyte) MB and is reckoned at \(reckoned / Self.megabyte) MB")
    }

    /// **The two photographs that ended an extension on an iPad, 2026-10-12.**
    /// From an iPhone, cropped there, each asked for at a quarter of its size:
    /// ImageIO decoded the strip at full size and made it smaller afterwards,
    /// 48 MB where 3 MB was meant. A JPEG is decoded at an eighth or at its
    /// own size since. `Plans/PGR Widgets - iOS.md`, *A JPEG at a half or a
    /// quarter*.
    ///
    /// **They are the photographs themselves**, because nothing made for a
    /// test does it: the same picture written again without loss takes
    /// 3 MB. Syd, 2026-10-13: "you can just copy the pictures you just
    /// optimized for into the test repo and right tests with them". Their
    /// EXIF, XMP and Photoshop segments and the second picture an iPhone
    /// adds are taken out, which changes nothing of what they do: where they
    /// were taken was in the first, and this repository is public.
    @Test(
        "Each photograph that ended an extension is shrunk inside what a JPEG is reckoned to need",
        arguments: ["iphone-cropped-2922x3660", "iphone-cropped-2680x3345"])
    func thePhotographsThatEndedAnExtension(_ name: String) throws {
        let original = try #require(
            Bundle.module.url(forResource: name, withExtension: "jpeg", subdirectory: "Photographs"))
        let scratch = try ScratchFolder()
        let resized = scratch.url.appending(path: "resized.jpg")
        let resizer = PictureResizer()

        let (resize, rise) = try MemoryRise.during {
            try resizer.write(original, fitting: box, to: resized)
        }

        #expect(resize.writtenHeight == 756)
        let reckoned = resizer.needs(
            type: resize.originalType, storedWidth: Double(resize.originalWidth),
            storedHeight: Double(resize.originalHeight), fraction: 1)
        #expect(
            rise <= reckoned,
            "it added \(rise / Self.megabyte) MB and is reckoned at \(reckoned / Self.megabyte) MB")
    }
}
