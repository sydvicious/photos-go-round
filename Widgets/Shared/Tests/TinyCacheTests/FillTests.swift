import CoreGraphics
import Foundation
import PhotosGoRoundAgentAPI
import Testing

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

    @Test("A covering picture decoded in one piece is reckoned at what it holds beyond the fitted one")
    func coveringNeedsMore() {
        let resizer = PictureResizer()
        let fitted = PictureResizer.Sized(width: 100, height: 100)
        let covering = PictureResizer.Sized(width: 900, height: 900)
        let fitting = resizer.needs(type: "public.png", storedWidth: 900, storedHeight: 900, fraction: 1)

        #expect(
            resizer.needs(
                type: "public.png", storedWidth: 900, storedHeight: 900, fraction: 1, inBands: false,
                wanted: covering, fitted: fitted) == fitting + 800_000 * 4)
        // In bands only the crop is drawn, so it needs what fitting does.
        #expect(
            resizer.needs(
                type: "public.png", storedWidth: 900, storedHeight: 900, fraction: 1, inBands: true,
                wanted: covering, fitted: fitted) == fitting)
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
