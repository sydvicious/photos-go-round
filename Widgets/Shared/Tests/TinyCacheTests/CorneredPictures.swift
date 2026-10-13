import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The four corners of a picture, each a colour of its own, so that which
/// way up it came out can be read back.
enum Corner: String, CaseIterable {
    case red, green, blue, white

    var colour: (red: Double, green: Double, blue: Double) {
        switch self {
        case .red: (0.9, 0.1, 0.1)
        case .green: (0.1, 0.8, 0.1)
        case .blue: (0.1, 0.1, 0.9)
        case .white: (0.95, 0.95, 0.95)
        }
    }
}

/// Which colour each corner of a picture is: top left, top right, bottom
/// left, bottom right, as the file's own pixels have them.
struct Corners: Equatable, CustomStringConvertible {
    let topLeft: Corner, topRight: Corner, bottomLeft: Corner, bottomRight: Corner

    var description: String {
        "\(topLeft.rawValue) \(topRight.rawValue) / \(bottomLeft.rawValue) \(bottomRight.rawValue)"
    }
}

extension ScratchFolder {
    /// Writes a picture whose stored pixels are red at the top left, green at
    /// the top right, blue at the bottom left and white at the bottom right,
    /// marked as stored in the given EXIF orientation.
    @discardableResult
    func cornered(_ path: String, width: Int, height: Int, orientation: Int = 1) throws -> URL {
        let file = url.appending(path: path)
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw PictureNotWritten() }
        let halfWidth = Double(width) / 2, halfHeight = Double(height) / 2
        // A bitmap's own space has its first row at the top of the picture
        // and counts upward, so "top" is the larger y.
        let quarters: [(Corner, Double, Double)] = [
            (.red, 0, halfHeight), (.green, halfWidth, halfHeight), (.blue, 0, 0), (.white, halfWidth, 0),
        ]
        for (corner, x, y) in quarters {
            let colour = corner.colour
            context.setFillColor(CGColor(red: colour.red, green: colour.green, blue: colour.blue, alpha: 1))
            context.fill(CGRect(x: x, y: y, width: halfWidth, height: halfHeight))
        }
        guard
            let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(
                file as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw PictureNotWritten() }
        CGImageDestinationAddImage(
            destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PictureNotWritten() }
        return file
    }
}

/// The pixels of the picture in `file`, as stored: four bytes each, from the
/// top row down.
func pixels(of file: URL) throws -> (bytes: [UInt8], width: Int, height: Int) {
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
    let count = image.width * image.height * 4
    return (Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: count)), image.width, image.height)
}

/// Which colour each corner of the picture in `file` is nearest.
func corners(of file: URL) throws -> Corners {
    let (bytes, width, height) = try pixels(of: file)
    func nearest(_ x: Int, _ y: Int) -> Corner {
        let at = (y * width + x) * 4
        let seen = (Double(bytes[at]) / 255, Double(bytes[at + 1]) / 255, Double(bytes[at + 2]) / 255)
        return Corner.allCases.min { one, other in
            func distance(_ corner: Corner) -> Double {
                let colour = corner.colour
                return abs(colour.red - seen.0) + abs(colour.green - seen.1) + abs(colour.blue - seen.2)
            }
            return distance(one) < distance(other)
        }!
    }
    return Corners(
        topLeft: nearest(width / 4, height / 4), topRight: nearest(width * 3 / 4, height / 4),
        bottomLeft: nearest(width / 4, height * 3 / 4), bottomRight: nearest(width * 3 / 4, height * 3 / 4))
}
