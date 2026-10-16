import CoreGraphics
import Foundation
import ImageIO
import PhotosGoRoundAgentAPI
import Testing

@testable import PhotosGoRoundWidgetSettings

@Suite("The coloured pictures a SwiftUI preview shows where a photograph goes")
struct SamplePicturesTests {
    let box = CGSize(width: 1014, height: 1062)

    @Test("Each one is a file that reads as a picture, and no two in a row are the same file")
    func files() throws {
        let pictures = SamplePictures()
        let sources = [SourceSpec.folder("/pictures/Coins")]

        let first = try #require(try pictures.next(from: sources, fitting: box))
        let second = try #require(try pictures.next(from: sources, fitting: box))

        #expect(first != second)
        let source = try #require(CGImageSourceCreateWithURL(first as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width > image.height)
    }

    @Test("With nothing chosen there is no picture")
    func nothingChosen() throws {
        #expect(try SamplePictures().next(from: [], fitting: box) == nil)
    }
}
