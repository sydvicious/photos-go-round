import Foundation
import ImageIO
import Testing

@testable import PhotosGoRoundWidgetFace

/// A widget extension is ended at 30 MB, and the icon is what it draws for a
/// placeholder. Drawn from one picture of 1024 pixels at 16 bits a channel,
/// it took an extension to 25 MB on an iPad and 39.9 MB at a phone's sizes.
/// `Plans/PGR Widgets - iOS.md`, *The icon, made for widgets*.
@Suite("The app icon as the widgets draw it")
struct WidgetIconTests {
    @Test("It is kept at four sizes, each the size its name says and eight bits a channel")
    func keptSmallAndShallow() throws {
        #expect(WidgetFace.iconSizes == [256, 512, 768, 1024])
        for pixels in WidgetFace.iconSizes {
            let file = try #require(WidgetFace.iconFile(pixels: pixels), "no icon of \(pixels) pixels")
            let source = try #require(CGImageSourceCreateWithURL(file as CFURL, nil))
            let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])

            #expect(properties[kCGImagePropertyPixelWidth] as? Int == pixels)
            #expect(properties[kCGImagePropertyPixelHeight] as? Int == pixels)
            #expect(properties[kCGImagePropertyDepth] as? Int == 8)
        }
    }

    @Test("It is drawn from the smallest that is no smaller than what is wanted")
    func theSmallestThatWillDo() {
        #expect(WidgetFace.iconPixels(for: 1) == 256)
        #expect(WidgetFace.iconPixels(for: 256) == 256)
        #expect(WidgetFace.iconPixels(for: 257) == 512)
        // A large widget on an iPad: 362 points at two pixels a point.
        #expect(WidgetFace.iconPixels(for: 724) == 768)
        // The tall extra large widget on a phone: 332 points at three.
        #expect(WidgetFace.iconPixels(for: 996) == 1024)
    }

    @Test("Wanted larger than the largest, it is drawn from the largest")
    func neverLargerThanTheLargest() {
        #expect(WidgetFace.iconPixels(for: 4000) == 1024)
    }

    @Test("Read for drawing, it is the size asked for and four bytes a pixel")
    func readAtItsOwnSize() throws {
        let image = try #require(WidgetFace.iconImage(pixels: 768))

        #expect(image.width == 768)
        #expect(image.height == 768)
        #expect(image.bitsPerPixel == 32)
    }
}
