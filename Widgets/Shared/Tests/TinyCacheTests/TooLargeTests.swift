import CoreGraphics
import Foundation
import ImageIO
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

    /// A scan of 9920 by 12925 at full colour ended an iPad's extension
    /// at an eighth, with 21.9 MB left, 2026-10-14, where a Mac takes 6 MB.
    /// Reckoned as decoded at a quarter until a device is measured.
    /// `Plans/PGR Widgets - iOS.md`, *A scan at full colour*.
    @Test("A JPEG at full colour, at an eighth, needs the picture decoded at a quarter")
    func aFullColourJPEGNeedsAQuarter() {
        let resizer = PictureResizer()
        let scan = resizer.needs(
            type: "public.jpeg", storedWidth: 9920, storedHeight: 12925, fraction: 8, fullColour: true)
        let photograph = resizer.needs(
            type: "public.jpeg", storedWidth: 4032, storedHeight: 3024, fraction: 8, fullColour: true)
        let atItsOwnSize = resizer.needs(
            type: "public.jpeg", storedWidth: 2922, storedHeight: 3660, fraction: 1, fullColour: true)

        #expect(scan == 9920 * 12925 * 4 / 16)
        #expect(photograph == 14 * Self.megabyte)
        #expect(atItsOwnSize == 14 * Self.megabyte)
    }

    @Test("So that scan is passed over for good in an iPad's widget")
    func theScanIsPassedOver() {
        let resizer = PictureResizer()
        let needed = resizer.needs(
            type: "public.jpeg", storedWidth: 9920, storedHeight: 12925, fraction: 8, fullColour: true)

        #expect(needed > PictureResizer.widgetLimit - PictureResizer.heldIdle)
    }

    // MARK: Reading a JPEG's colour

    /// The start of a baseline JPEG, as far as its first scan: a frame
    /// header with three components sampled as given.
    static func jpegHeader(sampling: [(Int, Int)], progressive: Bool = false) -> Data {
        var bytes: [UInt8] = [0xFF, 0xD8]
        // An APP0 of no interest, to be stepped over.
        bytes += [0xFF, 0xE0, 0x00, 0x06, 0x4A, 0x46, 0x49, 0x46]
        // A restart interval, to be stepped over.
        bytes += [0xFF, 0xDD, 0x00, 0x04, 0x04, 0xD8]
        bytes += [0xFF, progressive ? 0xC2 : 0xC0, 0x00, UInt8(8 + 3 * sampling.count), 0x08, 0x32, 0x7D, 0x26, 0xC0]
        bytes.append(UInt8(sampling.count))
        for (index, (across, down)) in sampling.enumerated() {
            bytes += [UInt8(index + 1), UInt8(across << 4 | down), 0x00]
        }
        bytes += [0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00]
        return Data(bytes)
    }

    static func written(_ data: Data) throws -> URL {
        let file = FileManager.default.temporaryDirectory.appending(path: "header-\(UUID().uuidString).jpeg")
        try data.write(to: file)
        return file
    }

    @Test("A JPEG with every component sampled alike is at full colour")
    func fullColourIsRead() throws {
        let file = try Self.written(Self.jpegHeader(sampling: [(1, 1), (1, 1), (1, 1)]))
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(PictureResizer.isFullColourJPEG(file))
    }

    @Test("A JPEG's sampling is said as each component's, across by down")
    func samplingIsSaid() throws {
        let half = try Self.written(Self.jpegHeader(sampling: [(2, 2), (1, 1), (1, 1)]))
        let png = try Self.written(Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        defer {
            try? FileManager.default.removeItem(at: half)
            try? FileManager.default.removeItem(at: png)
        }

        #expect(PictureResizer.jpegSampling(half) == "2x2 1x1 1x1")
        #expect(PictureResizer.jpegSampling(png) == nil)
    }

    @Test("A JPEG with its colour sampled at a half is not")
    func subsampledColourIsRead() throws {
        let file = try Self.written(Self.jpegHeader(sampling: [(2, 2), (1, 1), (1, 1)]))
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(!PictureResizer.isFullColourJPEG(file))
    }

    @Test("A progressive JPEG's frame is read as well")
    func progressiveIsRead() throws {
        let file = try Self.written(Self.jpegHeader(sampling: [(1, 1), (1, 1), (1, 1)], progressive: true))
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(PictureResizer.isFullColourJPEG(file))
    }

    @Test("A file that is not a JPEG is not at full colour, nor is a grey one")
    func otherFilesAreNot() throws {
        let png = try Self.written(Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        let grey = try Self.written(Self.jpegHeader(sampling: [(1, 1)]))
        defer {
            try? FileManager.default.removeItem(at: png)
            try? FileManager.default.removeItem(at: grey)
        }

        #expect(!PictureResizer.isFullColourJPEG(png))
        #expect(!PictureResizer.isFullColourJPEG(grey))
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
    /// A grey scan of 9920 by 12925 ended an iPad's extension at an eighth
    /// twice, 2026-10-14, and took 42 MB on a Mac; at its own size, a strip
    /// at a time, 11 to 13 MB. `Plans/PGR Widgets - iOS.md`, *A scan at
    /// full colour*.
    @Test("A grey JPEG is decoded at its own size, however large")
    func aGreyJPEGWhole() {
        #expect(PictureResizer.fraction(of: 12925, for: 340, type: "public.jpeg", grey: true) == 1)
        #expect(PictureResizer.fraction(of: 12925, for: 340, type: "public.jpeg", grey: false) == 8)
    }

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

    /// Syd, 2026-10-14: "it would be good to log titles if there, and
    /// filenames if there. capture dates are a bonus". The log could not say
    /// which photograph cost an iPad's widget 19 MB, and so it could not be
    /// found among 9,000 favorites.
    @Test("With a name and the day it was taken, the line says both, before the rest")
    func saidWithItsName() {
        #expect(
            PictureResizer.starting(
                "public.jpeg", width: 4000, height: 6000, toWidth: 227, height: 340,
                inBands: true, fraction: 8, needing: 14 * 1_048_576,
                named: "DSC_0815.JPG", taken: "2024-09-21 18:03")
                == "shrinking \u{201C}DSC_0815.JPG\u{201D}, taken 2024-09-21 18:03, public.jpeg 4000x6000 to 227x340, "
                + "in bands at 1/8, reckoned at 14 MB")
        #expect(
            PictureResizer.starting(
                "public.jpeg", width: 4000, height: 6000, toWidth: 227, height: 340,
                inBands: true, fraction: 8, needing: 14 * 1_048_576, named: "DSC_0815.JPG")
                == "shrinking \u{201C}DSC_0815.JPG\u{201D}, public.jpeg 4000x6000 to 227x340, "
                + "in bands at 1/8, reckoned at 14 MB")
    }

    @Test("When a picture was taken is read from its EXIF, to the minute")
    func takenFromEXIF() {
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2024:09:21 18:03:12"]
        ]

        #expect(PictureResizer.taken(in: properties) == "2024-09-21 18:03")
        #expect(PictureResizer.taken(in: [:]) == nil)
    }

    @Test("When a photograph from Photos was taken is said the same way, in the device's own time")
    func takenFromADate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
        let date = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 9, day: 21, hour: 18, minute: 3)))

        #expect(PictureResizer.taken(date, in: calendar.timeZone) == "2024-09-21 18:03")
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
