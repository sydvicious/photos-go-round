import CoreGraphics
import Foundation
import ImageIO
import PhotosGoRoundAgentAPI
import Testing
import UniformTypeIdentifiers

@testable import TinyCache

/// Writing a picture to fill a widget: shrunk until it covers the box, and
/// cropped about the middle to the box's shape. `Plans/Widget Settings.md`,
/// *The crop is made when the picture is written*.
@Suite("Resizing a picture to fill a widget")
struct FillTests {
    static let megabyte: Int64 = 1_048_576

    static func memory(held: Int64, of limit: Int64) -> @Sendable () -> Footprint.Reading? {
        {
            Footprint.Reading(
                footprint: held * megabyte, resident: held * megabyte, lifetimePeak: held * megabyte,
                left: (limit - held) * megabyte)
        }
    }

    let filling = PictureResizer(framing: .fill)

    @Test("A wide picture filling a square box is the box, cut from its middle")
    func wideIntoSquare() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("wide.jpg", width: 2000, height: 1000)
        let resized = scratch.url.appending(path: "resized.jpg")

        try filling.write(original, fitting: CGSize(width: 400, height: 400), to: resized)

        let size = try #require(pixelSize(of: resized))
        #expect(size.width == 400)
        #expect(size.height == 400)
    }

    @Test("A tall picture filling a wide box is the box")
    func tallIntoWide() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("tall.jpg", width: 1000, height: 2000)
        let resized = scratch.url.appending(path: "resized.jpg")

        try filling.write(original, fitting: CGSize(width: 400, height: 200), to: resized)

        let size = try #require(pixelSize(of: resized))
        #expect(size.width == 400)
        #expect(size.height == 200)
    }

    @Test("A picture shrunk in bands is cropped as it is drawn")
    func inBands() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("large.png", width: 3000, height: 2000)
        let resized = scratch.url.appending(path: "resized.jpg")

        let resize = try filling.write(original, fitting: CGSize(width: 200, height: 400), to: resized)

        #expect(resize.writtenWidth == 200)
        #expect(resize.writtenHeight == 400)
        let size = try #require(pixelSize(of: resized))
        #expect(size.width == 200)
        #expect(size.height == 400)
    }

    /// A picture of four by four squares, each its own colour, filling a wide
    /// box and a tall one. What is written is the middle of the picture: its
    /// whole width in the wide box, its whole height in the tall one.
    ///
    /// **Which part, and not only what size.** A HEIC from Photos, shrunk in
    /// one piece, was written at the box's size and showed a small part of
    /// the photograph, much enlarged. On *Claude iPhone*, 2026-10-25.
    @Test(
        "What is written is the middle of the picture, whatever its kind and however it is shrunk",
        arguments: [
            ("photo.heic", 4032, 3024), ("photo.jpg", 4032, 3024), ("photo.png", 800, 600),
            ("photo.png", 3000, 2250),
        ])
    func middleIsWritten(_ name: String, _ width: Int, _ height: Int) throws {
        let scratch = try ScratchFolder()
        let original = scratch.url.appending(path: name)
        try writeGrid(to: original, width: width, height: height)

        // Wide: 4 by 3 covering 2 by 1 keeps rows from a sixth to five
        // sixths of the way down, and every column.
        let wide = scratch.url.appending(path: "wide.jpg")
        try filling.write(original, fitting: CGSize(width: 800, height: 400), to: wide)
        for (across, column) in [(0.125, 0), (0.375, 1), (0.625, 2), (0.875, 3)] {
            for (down, row) in [(0.05, 0), (0.3125, 1), (0.6875, 2), (0.95, 3)] {
                let found = try square(in: wide, across: across, down: down)
                #expect(
                    found == Square(column: column, row: row), "wide, \(across) across and \(down) down: \(found)")
            }
        }

        // Tall: 4 by 3 covering 1 by 2 keeps the middle 3/8 of its width,
        // from 0.31 to 0.69 across, and every row.
        let tall = scratch.url.appending(path: "tall.jpg")
        try filling.write(original, fitting: CGSize(width: 200, height: 400), to: tall)
        for (across, column) in [(0.05, 1), (0.95, 2)] {
            for (down, row) in [(0.125, 0), (0.375, 1), (0.625, 2), (0.875, 3)] {
                let found = try square(in: tall, across: across, down: down)
                #expect(
                    found == Square(column: column, row: row), "tall, \(across) across and \(down) down: \(found)")
            }
        }
    }

    @Test("A picture smaller than the box is cropped to its shape at its own size, not enlarged")
    func smallIsNotEnlarged() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("small.png", width: 120, height: 90)
        let resized = scratch.url.appending(path: "resized.jpg")

        try filling.write(original, fitting: CGSize(width: 400, height: 400), to: resized)

        let size = try #require(pixelSize(of: resized))
        #expect(size.width == 90)
        #expect(size.height == 90)
    }

    @Test("Actual Size writes what Fit does: the whole picture, fitted")
    func actualSizeIsFitted() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("wide.jpg", width: 2000, height: 1000)
        let resized = scratch.url.appending(path: "resized.jpg")

        try PictureResizer(framing: .actualSize).write(
            original, fitting: CGSize(width: 400, height: 400), to: resized)

        let size = try #require(pixelSize(of: resized))
        #expect(size.width == 400)
        #expect(size.height == 200)
    }

    /// Decoded in one piece at 900 by 900: about 10 MB to fit a box 900 by
    /// 100, and 3 MB more to cover it. Syd, 2026-10-25: a picture too large
    /// to cover is fitted instead.
    @Test("One that covering would make too large for what is left is fitted instead")
    func fittedWhenCoveringIsTooLarge() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("square.png", width: 900, height: 900)
        let resized = scratch.url.appending(path: "resized.jpg")
        let resizer = PictureResizer(memory: Self.memory(held: 10, of: 22), framing: .fill)

        let resize = try resizer.write(original, fitting: CGSize(width: 900, height: 100), to: resized)

        #expect(resize.writtenWidth == 100)
        #expect(resize.writtenHeight == 100)
    }

    @Test("Where the kernel tells of no limit, the same picture fills")
    func filledWithNoLimit() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("square.png", width: 900, height: 900)
        let resized = scratch.url.appending(path: "resized.jpg")
        let resizer = PictureResizer(memory: { nil }, framing: .fill)

        let resize = try resizer.write(original, fitting: CGSize(width: 900, height: 100), to: resized)

        #expect(resize.writtenWidth == 900)
        #expect(resize.writtenHeight == 100)
    }

    @Test("The middle of a picture in a box's shape: as large as it can be, and centred")
    func middle() {
        #expect(
            PictureResizer.middle(ofWidth: 1000, height: 500, shapedLike: CGSize(width: 400, height: 400))
                == CGRect(x: 250, y: 0, width: 500, height: 500))
        #expect(
            PictureResizer.middle(ofWidth: 100, height: 300, shapedLike: CGSize(width: 200, height: 100))
                == CGRect(x: 0, y: 125, width: 100, height: 50))
        // Already the box's shape: all of it.
        #expect(
            PictureResizer.middle(ofWidth: 1014, height: 474, shapedLike: CGSize(width: 1014, height: 474))
                == CGRect(x: 0, y: 0, width: 1014, height: 474))
    }

    /// Covering 900 by 100 with 900 by 900: 800,000 pixels beyond the fitted
    /// picture, and the crop, 90,000, drawn into a bitmap of its own.
    @Test(
        "A covering picture decoded in one piece is reckoned at what it holds beyond the fitted one, and its crop")
    func coveringNeedsMore() {
        let resizer = PictureResizer()
        let fitted = PictureResizer.Sized(width: 100, height: 100)
        let covering = PictureResizer.Sized(width: 900, height: 900)
        let crop = PictureResizer.Sized(width: 900, height: 100)
        let fitting = resizer.needs(type: "public.png", storedWidth: 900, storedHeight: 900, fraction: 1)

        #expect(
            resizer.needs(
                type: "public.png", storedWidth: 900, storedHeight: 900, fraction: 1, inBands: false,
                wanted: covering, fitted: fitted, cropped: crop) == fitting + 800_000 * 4 + 90_000 * 4)
        // In bands only the crop is drawn, so it needs what fitting does.
        #expect(
            resizer.needs(
                type: "public.png", storedWidth: 900, storedHeight: 900, fraction: 1, inBands: true,
                wanted: covering, fitted: fitted, cropped: crop) == fitting)
    }

    @Test("The line before a fill says what it is cropped to")
    func saysTheCrop() {
        #expect(
            PictureResizer.starting(
                "public.jpeg", width: 3000, height: 4000, toWidth: 1014, height: 1352, inBands: true,
                fraction: 2, needing: 14 * Self.megabyte, croppedTo: (width: 1014, height: 474))
                == "shrinking public.jpeg 3000x4000 to 1014x1352, cropped to 1014x474, in bands at 1/2, "
                + "reckoned at 14 MB")
    }
}

/// Which of the grid's squares a colour is: red counts the columns and green
/// the rows. Each is one of four levels, kept off black and full colour so
/// that compressing the picture never moves one level into the next.
struct Square: Equatable, CustomStringConvertible {
    let column: Int
    let row: Int

    var description: String { "column \(column), row \(row)" }
}

/// Writes a picture of four by four squares, counted from the top left, each
/// told apart by its red and green. A HEIC, a PNG or a JPEG by its name.
func writeGrid(to file: URL, width: Int, height: Int) throws {
    guard
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { throw PictureNotWritten() }
    let side = (width: Double(width) / 4, height: Double(height) / 4)
    for column in 0..<4 {
        for row in 0..<4 {
            context.setFillColor(
                CGColor(red: level(column), green: level(row), blue: 0.5, alpha: 1))
            // A bitmap counts up from its bottom row.
            context.fill(
                CGRect(
                    x: Double(column) * side.width, y: Double(3 - row) * side.height, width: side.width,
                    height: side.height))
        }
    }
    let type = UTType(filenameExtension: file.pathExtension.lowercased()) ?? .jpeg
    guard
        let image = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(file as CFURL, type.identifier as CFString, 1, nil)
    else { throw PictureNotWritten() }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw PictureNotWritten() }
}

/// The grid square at a point of the picture in `file`, given as fractions of
/// its width and height from the top left.
func square(in file: URL, across: Double, down: Double) throws -> Square {
    guard
        let source = CGImageSourceCreateWithURL(file as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
        let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { throw PictureNotWritten() }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let data = context.data else { throw PictureNotWritten() }
    // A bitmap's first row in memory is its top one.
    let x = min(image.width - 1, Int(across * Double(image.width)))
    let y = min(image.height - 1, Int(down * Double(image.height)))
    let pixel = data.advanced(by: y * image.width * 4 + x * 4).assumingMemoryBound(to: UInt8.self)
    return Square(column: step(pixel[0]), row: step(pixel[1]))
}

/// One of four levels of a colour, from 0.15 to 0.85.
func level(_ step: Int) -> Double { 0.15 + 0.7 * Double(step) / 3 }

/// Which of the four levels a colour, read back, is nearest.
func step(_ value: UInt8) -> Int { Int(((Double(value) / 255 - 0.15) / 0.7 * 3).rounded()) }
