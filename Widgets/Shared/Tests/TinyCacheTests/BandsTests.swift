import CoreGraphics
import Foundation
import Testing

@testable import TinyCache

/// A picture of more than a million pixels is shrunk a band at a time, so
/// that no more than a band of it is ever decoded. `Plans/PGR Widgets -
/// iOS.md`, *A very large picture, in bands*. What that takes of a widget's
/// memory is `ShrinkingMemoryTests`, in a test target of its own.
@Suite("Shrinking a picture in bands")
struct BandsTests {
    /// Every picture in bands, a few rows at a time, however small it is.
    let banded = PictureResizer(bandsAbove: 0, bandBytes: 16 * 1024)
    /// No picture in bands.
    let whole = PictureResizer(bandsAbove: .max)

    /// Drawn in one band, the whole picture is asked for at once, and an
    /// iPad's extension took 18.8 MB for a photograph of 6016 by 4016 at an
    /// eighth, 2026-10-16, where the rows of the same picture asked for in
    /// several bands take a fraction of a megabyte each. On a Mac a grey
    /// scan took 30 MB in one band and less than 14 MB in two.
    /// `Plans/PGR Widgets - iOS.md`, *The iPad overnight with every source*.
    @Test("A picture in bands is never drawn in one band")
    func neverOneBand() {
        // A grey scan of 9920 by 12925 at an eighth, 1240 bytes a row, for
        // a small widget: a band of 2 MB is more rows than the picture has.
        #expect(PictureResizer.bandRows(decodedRows: 1691, perRow: 1615.0 / 340, drawnHeight: 340) == 170)
        // The photograph of 6016 by 4016 at an eighth, for a small widget.
        #expect(PictureResizer.bandRows(decodedRows: 697, perRow: 502.0 / 227, drawnHeight: 227) == 114)
        // A band already smaller than half the picture is left as it is.
        #expect(PictureResizer.bandRows(decodedRows: 422, perRow: 1615.0 / 757, drawnHeight: 757) == 197)
        // One drawn row is still a band.
        #expect(PictureResizer.bandRows(decodedRows: 1, perRow: 10, drawnHeight: 1) == 1)
    }

    @Test("In bands, a picture comes out the size it does whole")
    func theSameSize() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.picture("wide.jpg", width: 2000, height: 1000)
        let resized = scratch.url.appending(path: "resized.jpg")

        let resize = try banded.write(original, fitting: CGSize(width: 400, height: 400), to: resized)

        #expect(resize.writtenWidth == 400)
        #expect(resize.writtenHeight == 200)
        let size = try #require(pixelSize(of: resized))
        #expect(size.width == 400)
        #expect(size.height == 200)
    }

    @Test("Where one band meets the next there is no seam")
    func noSeams() throws {
        let scratch = try ScratchFolder()
        // One flat colour: any row that is not that colour is a seam.
        let original = try scratch.picture("flat.jpg", width: 1500, height: 1100)
        let resized = scratch.url.appending(path: "resized.jpg")

        try banded.write(original, fitting: CGSize(width: 300, height: 300), to: resized)

        let (bytes, width, height) = try pixels(of: resized)
        let first = Array(bytes[0..<3])
        var worst = 0
        for pixel in 0..<(width * height) {
            for channel in 0..<3 {
                worst = max(worst, abs(Int(bytes[pixel * 4 + channel]) - Int(first[channel])))
            }
        }
        #expect(worst <= 3)
    }

    @Test(
        "A picture stored on its side or mirrored comes out the same way up in bands as it does whole",
        arguments: 1...8)
    func theSameWayUp(orientation: Int) throws {
        let scratch = try ScratchFolder()
        let original = try scratch.cornered("stored.jpg", width: 400, height: 200, orientation: orientation)
        let inBands = scratch.url.appending(path: "bands.jpg")
        let asWhole = scratch.url.appending(path: "whole.jpg")
        let box = CGSize(width: 200, height: 200)

        let bands = try banded.write(original, fitting: box, to: inBands)
        let one = try whole.write(original, fitting: box, to: asWhole)

        #expect(bands.writtenWidth == one.writtenWidth)
        #expect(bands.writtenHeight == one.writtenHeight)
        #expect(try corners(of: inBands) == corners(of: asWhole))
    }

    /// Orientation 6 is a phone held upright: the stored picture is turned a
    /// quarter clockwise to be seen, so its top left ends at the top right.
    @Test("A picture from a phone held upright is turned a quarter clockwise")
    func aQuarterClockwise() throws {
        let scratch = try ScratchFolder()
        let original = try scratch.cornered("stored.jpg", width: 400, height: 200, orientation: 6)
        let resized = scratch.url.appending(path: "resized.jpg")

        let resize = try banded.write(original, fitting: CGSize(width: 200, height: 200), to: resized)

        #expect(resize.writtenWidth == 100)
        #expect(resize.writtenHeight == 200)
        #expect(
            try corners(of: resized)
                == Corners(topLeft: .blue, topRight: .red, bottomLeft: .white, bottomRight: .green))
    }
}
