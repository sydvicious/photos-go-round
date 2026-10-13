import CoreGraphics
import Foundation
import Testing

@testable import PhotosGoRoundWidgetFace

/// In this test target because it watches what the whole process holds, as
/// the shrinking tests do, and a test target is a process of its own.
@Suite("What the icon takes of a widget's memory", .serialized)
struct IconMemoryTests {
    static let megabyte: Int64 = 1_048_576

    /// A picture of 1024 pixels square is 4 MB at four bytes a pixel. The
    /// one the widgets had was 8 MB decoded, and a copy was made from it.
    @Test("Reading the largest icon a widget draws adds little more than the picture itself")
    func theLargest() throws {
        let (image, rise) = try MemoryRise.during { WidgetFace.iconImage(pixels: 1024) }

        #expect(image?.width == 1024)
        #expect(rise < 6 * Self.megabyte, "it added \(rise / Self.megabyte) MB")
    }
}
