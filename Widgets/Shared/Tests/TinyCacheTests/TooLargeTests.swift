import CoreGraphics
import Foundation
import PhotosGoRoundAgentAPI
import Testing

@testable import TinyCache

/// A picture is not started on when shrinking it would take more memory than
/// the extension has left: going over the limit is not an error it is handed,
/// the system ends it. `Plans/PGR Widgets - iOS.md`, *The guard*.
@Suite("A picture too large to shrink is passed over")
struct TooLargeTests {
    static let megabyte: Int64 = 1_048_576

    /// An iPad's extra large widget, in pixels.
    let box = CGSize(width: 1590, height: 756)

    /// What a process holding `held` megabytes of a limit of `limit` reads.
    static func memory(held: Int64, of limit: Int64) -> @Sendable () -> Footprint.Reading? {
        {
            Footprint.Reading(
                footprint: held * megabyte, resident: held * megabyte, lifetimePeak: held * megabyte,
                left: (limit - held) * megabyte)
        }
    }

    // MARK: What a shrink is reckoned to need

    @Test("A JPEG in bands needs the same whatever its size")
    func aJPEGNeedsLittle() {
        let resizer = PictureResizer()
        let small = resizer.needs(type: "public.jpeg", storedWidth: 4000, storedHeight: 3000, fraction: 2)
        let largest = resizer.needs(type: "public.jpeg", storedWidth: 33280, storedHeight: 20395, fraction: 8)

        #expect(small == 14 * Self.megabyte)
        #expect(largest == 14 * Self.megabyte)
    }

    @Test("A PNG or a TIFF needs the picture at the fraction it is decoded at, and a little more again than a JPEG")
    func aPNGNeedsItsDecoding() {
        let resizer = PictureResizer()

        // Four bytes a pixel, at a half each way.
        #expect(
            resizer.needs(type: "public.png", storedWidth: 4000, storedHeight: 3000, fraction: 2)
                == 4000 * 3000 * 4 / 4 + 14 * Self.megabyte)
        #expect(
            resizer.needs(type: "public.tiff", storedWidth: 16000, storedHeight: 12000, fraction: 8)
                == 16000 * 12000 * 4 / 64 + 14 * Self.megabyte)
    }

    @Test("A HEIC is shrunk in one piece, and needs the same whatever its size")
    func aHEICNeedsLittle() {
        let resizer = PictureResizer()

        #expect(!PictureResizer.shrinksInBands("public.heic", pixels: 48_000_000, above: 1_000_000))
        #expect(
            resizer.needs(type: "public.heic", storedWidth: 8064, storedHeight: 6048, fraction: 4)
                == 14 * Self.megabyte)
    }

    @Test("Every other kind is shrunk in bands once it is past a million pixels")
    func whatGoesInBands() {
        #expect(PictureResizer.shrinksInBands("public.jpeg", pixels: 12_000_000, above: 1_000_000))
        #expect(PictureResizer.shrinksInBands("public.png", pixels: 1_000_001, above: 1_000_000))
        #expect(!PictureResizer.shrinksInBands("public.jpeg", pixels: 800_000, above: 1_000_000))
    }

    // MARK: The fraction a picture is decoded at

    /// Two photographs from an iPhone ended an extension on an iPad in the
    /// night of 2026-10-12. Asked for at a quarter, each was decoded at its
    /// full size and made smaller afterwards: 48 MB for a strip that should
    /// have been two. At an eighth the same file is decoded at an eighth, and
    /// at its own size there is nothing to go wrong. `Plans/PGR Widgets -
    /// iOS.md`, *A JPEG at a half or a quarter*.
    @Test("A JPEG is decoded at an eighth where that is enough, and at its own size where it is not: never a half or a quarter")
    func aJPEGAtAnEighthOrWhole() {
        // The largest coin scan, for an iPad's extra large widget.
        #expect(PictureResizer.fraction(of: 33280, for: 1234, type: "public.jpeg") == 8)
        // Exactly enough at an eighth.
        #expect(PictureResizer.fraction(of: 8000, for: 1000, type: "public.jpeg") == 8)
        // The photograph that ended the extension: a quarter would have done.
        #expect(PictureResizer.fraction(of: 3660, for: 756, type: "public.jpeg") == 1)
        // A phone's ordinary photograph: a half would have done.
        #expect(PictureResizer.fraction(of: 4032, for: 1008, type: "public.jpeg") == 1)
    }

    @Test("Any other kind is decoded at the smallest of an eighth, a quarter and a half that is enough")
    func otherKindsAtAnyFraction() {
        #expect(PictureResizer.fraction(of: 4000, for: 1008, type: "public.png") == 2)
        #expect(PictureResizer.fraction(of: 6000, for: 1134, type: "public.tiff") == 4)
        #expect(PictureResizer.fraction(of: 16000, for: 1134, type: "public.png") == 8)
        #expect(PictureResizer.fraction(of: 1500, for: 1008, type: "public.png") == 1)
    }

    // MARK: Said before it starts

    /// A fetch's own line is written when the fetch ends, so a picture that
    /// ends the extension is named only by a line written before.
    @Test("What is about to be shrunk is said in a line: its kind and size, the size wanted, and the way")
    func saidBeforeItStarts() {
        let megabyte: Int64 = 1_048_576

        #expect(
            PictureResizer.starting(
                "public.jpeg", width: 3264, height: 2448, toWidth: 1008, height: 756,
                inBands: true, fraction: 2, needing: 12 * megabyte)
                == "shrinking public.jpeg 3264x2448 to 1008x756, in bands at 1/2, reckoned at 12 MB")
        #expect(
            PictureResizer.starting(
                "public.png", width: 900, height: 700, toWidth: 900, height: 700,
                inBands: false, fraction: 1, needing: 9 * megabyte)
                == "shrinking public.png 900x700 to 900x700, in one piece, reckoned at 9 MB")
        #expect(
            PictureResizer.starting(
                "public.tiff", width: 1500, height: 1200, toWidth: 1008, height: 806,
                inBands: true, fraction: 1, needing: 20 * megabyte)
                == "shrinking public.tiff 1500x1200 to 1008x806, in bands at full size, reckoned at 20 MB")
    }

    // MARK: Refusing

    @Test("A picture that could not be shrunk inside the limit by any wake is refused, and nothing is written")
    func refusedForGood() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("large.png", width: 4000, height: 3000)
        let resized = scratch.url.appending(path: "resized.jpg")
        let resizer = PictureResizer(memory: Self.memory(held: 6, of: 22))

        #expect(throws: PictureResizer.Failure.tooLarge(original, ever: true)) {
            try resizer.write(original, fitting: box, to: resized)
        }
        #expect(byteCount(of: resized) == nil)
    }

    @Test("One that an extension holding less could shrink is refused only for now")
    func refusedForNow() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("large.png", width: 4000, height: 3000)
        let resized = scratch.url.appending(path: "resized.jpg")
        let resizer = PictureResizer(memory: Self.memory(held: 24, of: 36))

        #expect(throws: PictureResizer.Failure.tooLarge(original, ever: false)) {
            try resizer.write(original, fitting: box, to: resized)
        }
    }

    @Test("A JPEG of the same size is shrunk in the same memory")
    func aJPEGIsNotRefused() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("large.jpg", width: 4000, height: 3000)
        let resized = scratch.url.appending(path: "resized.jpg")
        let resizer = PictureResizer(memory: Self.memory(held: 6, of: 22))

        let resize = try resizer.write(original, fitting: box, to: resized)

        #expect(resize.writtenHeight == 756)
    }

    @Test("Where the kernel tells of no limit, nothing is refused")
    func noLimitNoRefusal() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("large.png", width: 4000, height: 3000)
        let resized = scratch.url.appending(path: "resized.jpg")
        let resizer = PictureResizer(memory: {
            Footprint.Reading(footprint: 900 * Self.megabyte, resident: 900 * Self.megabyte)
        })

        #expect(try resizer.write(original, fitting: box, to: resized).writtenHeight == 756)
    }

    // MARK: As a widget would

    /// The app has gigabytes to shrink a picture in, and its preview is of a
    /// widget. Syd, 2026-10-12: "the preview should use the exact same
    /// methodology as the widgets".
    @Test("Judging as a widget would, a picture no widget could shrink is refused, whatever the process has")
    func asAWidgetRefuses() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("large.png", width: 4000, height: 3000)
        let resized = scratch.url.appending(path: "resized.jpg")

        #expect(throws: PictureResizer.Failure.tooLarge(original, ever: true)) {
            try PictureResizer.asAWidget.write(original, fitting: box, to: resized)
        }
    }

    @Test("Judging as a widget would, a picture a widget can shrink is shrunk")
    func asAWidgetShrinks() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("large.jpg", width: 4000, height: 3000)
        let resized = scratch.url.appending(path: "resized.jpg")

        #expect(try PictureResizer.asAWidget.write(original, fitting: box, to: resized).writtenHeight == 756)
    }

    // MARK: Passing over

    @Test("A folder passes a refused picture over for another, and says so when no wake could show it")
    func aFolderPassesOver() throws {
        let scratch = try ScratchFolder()
        let large = try scratch.picture("large.png", width: 4000, height: 3000)
        try scratch.picture("small.jpg", width: 800, height: 600)
        let skipped = Collected<URL>()
        let source = FolderSource(
            folder: scratch.url, resizer: PictureResizer(memory: Self.memory(held: 6, of: 22)),
            skipped: { skipped.add($0) })

        // The two are tried in an order that is drawn each time.
        for turn in 0..<20 {
            let resized = scratch.url.appending(path: "out/resized-\(turn).jpg")
            try FileManager.default.createDirectory(
                at: resized.deletingLastPathComponent(), withIntermediateDirectories: true)
            let resize = try #require(try source.writePicture(fitting: box, to: resized))
            #expect(resize.originalWidth == 800)
        }
        #expect(!skipped.values.isEmpty)
        #expect(Set(skipped.values.map(\.lastPathComponent)) == [large.lastPathComponent])
    }

    @Test("One refused only for now is passed over and nothing is said")
    func aFolderSaysNothingForNow() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("pictures/large.png", width: 4000, height: 3000)
        let skipped = Collected<URL>()
        let source = FolderSource(
            folder: scratch.url.appending(path: "pictures"),
            resizer: PictureResizer(memory: Self.memory(held: 24, of: 36)),
            skipped: { skipped.add($0) })

        #expect(try source.writePicture(fitting: box, to: scratch.url.appending(path: "resized.jpg")) == nil)
        #expect(skipped.values.isEmpty)
    }

    @Test("Gone through for a picture, a folder passes a refused one over too")
    func goingThroughPassesOver() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("pictures/large.png", width: 4000, height: 3000)
        let skipped = Collected<URL>()
        let source = FolderSource(
            folder: scratch.url.appending(path: "pictures"),
            resizer: PictureResizer(memory: Self.memory(held: 6, of: 22)),
            skipped: { skipped.add($0) })

        let resized = scratch.url.appending(path: "resized.jpg")
        #expect(try source.writePictureGoingThrough(fitting: box, to: resized) == nil)
        #expect(skipped.values.count == 1)
    }

    @Test("A file chosen by itself and refused gives no picture, and says so")
    func aFileGivesNone() throws {
        let scratch = try ScratchFolder()
        let large = try scratch.picture("large.png", width: 4000, height: 3000)
        let skipped = Collected<URL>()
        let source = FileSource(
            file: large, resizer: PictureResizer(memory: Self.memory(held: 6, of: 22)),
            skipped: { skipped.add($0) })

        #expect(try source.writePicture(fitting: box, to: scratch.url.appending(path: "resized.jpg")) == nil)
        #expect(skipped.values == [large])
    }
}
