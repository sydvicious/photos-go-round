import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@testable import TinyCache

/// A folder of its own for one test, removed when the test lets go of it.
final class ScratchFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: "TinyCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    /// Writes a picture of the given size at `path` inside the folder, making
    /// the folders on the way.
    @discardableResult
    func picture(_ path: String, width: Int = 64, height: Int = 48) throws -> URL {
        let file = url.appending(path: path)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writePicture(to: file, width: width, height: height)
        return file
    }

    /// Writes a file that is not a picture, whatever its name says.
    @discardableResult
    func text(_ path: String) throws -> URL {
        let file = url.appending(path: path)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not a picture".utf8).write(to: file)
        return file
    }
}

struct PictureNotWritten: Error {}

func writePicture(to file: URL, width: Int, height: Int) throws {
    guard
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { throw PictureNotWritten() }
    context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let type = file.pathExtension.lowercased() == "png" ? UTType.png : UTType.jpeg
    guard
        let image = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            file as CFURL, type.identifier as CFString, 1, nil)
    else { throw PictureNotWritten() }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw PictureNotWritten() }
}

/// The size in pixels of the picture in `file`, or nil if it isn't one.
func pixelSize(of file: URL) -> (width: Int, height: Int)? {
    guard
        let source = CGImageSourceCreateWithURL(file as CFURL, nil),
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
        let width = properties[kCGImagePropertyPixelWidth] as? Int,
        let height = properties[kCGImagePropertyPixelHeight] as? Int
    else { return nil }
    return (width, height)
}

/// The size of `file` on disk, in bytes, or nil if it isn't there.
func byteCount(of file: URL) -> Int? {
    (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
}

/// Collects what a cache reports, from whatever thread it reports on.
final class Collected<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var held: [Value] = []

    var values: [Value] { lock.withLock { held } }

    func add(_ value: Value) { lock.withLock { held.append(value) } }
}

/// A source that writes the pictures it was given, in turn, and counts how
/// often it is asked.
final class StubSource: PictureSource, @unchecked Sendable {
    struct Failed: Error {}

    private let lock = NSLock()
    private var files: [URL]
    private var next = 0
    private var asked = 0
    private var failing = false

    init(_ files: [URL]) {
        self.files = files
    }

    /// How many times it has been asked for a picture.
    var timesAsked: Int { lock.withLock { asked } }

    func fail() { lock.withLock { failing = true } }

    func writePicture(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize? {
        let file: URL? = try lock.withLock {
            asked += 1
            if failing { throw Failed() }
            guard !files.isEmpty else { return nil }
            defer { next += 1 }
            return files[next % files.count]
        }
        guard let file else { return nil }
        return try PictureResizer().write(file, fitting: box, to: destination)
    }
}

/// A CGImage of the given size, as a library would hand one back.
func makeImage(width: Int, height: Int) throws -> CGImage {
    guard
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
        let image = context.makeImage()
    else { throw PictureNotWritten() }
    return image
}

/// A Photos library with the collections it was given: an identifier, and the
/// size of the pictures in it, or nil for a collection with none.
struct FakeLibrary: PhotoLibraryPictures {
    struct Refused: Error {}

    var collections: [String: (width: Int, height: Int)?] = [:]
    var refusing = false

    func picture(inCollection identifier: String, fitting box: CGSize) throws -> LibraryPicture? {
        if refusing { throw Refused() }
        guard let size = collections[identifier] ?? nil else { return nil }
        return LibraryPicture(
            image: try makeImage(width: size.width, height: size.height),
            originalWidth: 4032, originalHeight: 3024)
    }
}
