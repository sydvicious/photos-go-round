// Writing a picture at a widget's size. `Plans/Photos-Go-Round Widgets.md`,
// *Spike: a 1-minute refresh, and the extension's memory*.
//
// **The original is never decoded whole.** A widget extension runs under about
// 30 MB of RAM, and a decoded picture costs width × height × 4 bytes whatever
// its size on disk. `CGImageSourceCreateThumbnailAtIndex` decodes straight to
// the size asked for, so what is held is the widget-sized picture and not the
// original.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct PictureResizer: Sendable {
    public enum Failure: Error, Equatable {
        case notAPicture(URL)
        case notWritten(URL)
    }

    /// What one resize read and what it wrote.
    public struct Resize: Sendable, Equatable {
        /// The original's uniform type identifier, such as `public.tiff`.
        public let originalType: String
        public let originalWidth: Int
        public let originalHeight: Int
        public let originalBytes: Int
        public let writtenWidth: Int
        public let writtenHeight: Int
        public let writtenBytes: Int
    }

    public init() {}

    /// Writes a JPEG of `original` at the largest size that fits inside
    /// `box`, in pixels, with nothing cut off. A picture smaller than that is
    /// written at its own size: enlarging it here would only make a bigger
    /// file of the same picture.
    ///
    /// **Fit, not fill**, as everywhere else in Photos-Go-Round: the whole
    /// photograph, with black around it. Syd, 2026-10-08, of fit against fill:
    /// "at some point that will be an option for all of this".
    @discardableResult
    public func write(_ original: URL, fitting box: CGSize, to destination: URL) throws -> Resize {
        let unread = [kCGImageSourceShouldCache: false] as CFDictionary
        guard
            let source = CGImageSourceCreateWithURL(original as CFURL, unread),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, unread) as? [CFString: Any],
            let storedWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
            let storedHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
            storedWidth > 0, storedHeight > 0
        else { throw Failure.notAPicture(original) }

        // Orientations 5 to 8 are stored on their side, so the picture as seen
        // has the stored width and height exchanged.
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let onItsSide = (5...8).contains(orientation)
        let width = onItsSide ? storedHeight : storedWidth
        let height = onItsSide ? storedWidth : storedHeight

        let scale = min(1, min(box.width / width, box.height / height))
        let longestSide = max(1, Int((max(width, height) * scale).rounded()))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: longestSide,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Failure.notAPicture(original)
        }

        // Written beside the destination and moved into place, so that a file
        // with the destination's name is always a whole picture.
        let manager = FileManager.default
        let partial = destination.deletingLastPathComponent()
            .appending(path: ".\(UUID().uuidString).partial")
        let quality = [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary
        guard
            let written = CGImageDestinationCreateWithURL(
                partial as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw Failure.notWritten(destination) }
        CGImageDestinationAddImage(written, image, quality)
        guard CGImageDestinationFinalize(written) else {
            try? manager.removeItem(at: partial)
            throw Failure.notWritten(destination)
        }
        do {
            try manager.moveItem(at: partial, to: destination)
        } catch {
            try? manager.removeItem(at: partial)
            throw error
        }
        return Resize(
            originalType: (CGImageSourceGetType(source) as String?) ?? "",
            originalWidth: Int(width), originalHeight: Int(height),
            originalBytes: Self.byteCount(of: original),
            writtenWidth: image.width, writtenHeight: image.height,
            writtenBytes: Self.byteCount(of: destination))
    }

    private static func byteCount(of file: URL) -> Int {
        (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
    }
}
