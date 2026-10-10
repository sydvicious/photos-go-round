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
/// often it is asked, for a picture and for how many it holds.
final class StubSource: CountedSource, @unchecked Sendable {
    struct Failed: Error {}

    let countName: String

    private let lock = NSLock()
    private var files: [URL]
    private let declared: Int?
    private let found: Int?
    private var next = 0
    private var asked = 0
    private var counted = 0
    private var failing = false
    private var failingToWrite = false

    /// - Parameters:
    ///   - declared: What it says it holds, when that is not how many
    ///     files it was given: a source can turn out to hold less than it said.
    ///   - found: What writing a picture says it holds, for a source that
    ///     finds that out on the way. Nil for one that does not.
    init(
        _ files: [URL], named name: String = UUID().uuidString, counting declared: Int? = nil,
        finding found: Int? = nil
    ) {
        self.files = files
        self.countName = name
        self.declared = declared
        self.found = found
    }

    /// How many times it has been asked for a picture.
    var timesAsked: Int { lock.withLock { asked } }

    /// How many times it has been asked how many pictures it holds.
    var timesCounted: Int { lock.withLock { counted } }

    /// Fails at everything from now on.
    func fail() { lock.withLock { failing = true } }

    /// Says how many it holds, and fails when asked for one of them.
    func failToWrite() { lock.withLock { failingToWrite = true } }

    func pictureCount() throws -> Int {
        try lock.withLock {
            counted += 1
            if failing { throw Failed() }
            return declared ?? files.count
        }
    }

    func writePictureAndCount(
        fitting box: CGSize, to destination: URL
    ) throws -> (resize: PictureResizer.Resize?, pictures: Int?) {
        (try writePicture(fitting: box, to: destination), found)
    }

    func writePicture(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize? {
        let file: URL? = try lock.withLock {
            asked += 1
            if failing || failingToWrite { throw Failed() }
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
/// size of the pictures in it, or nil for a collection with none. A collection
/// with pictures holds one of them unless `counts` says otherwise.
struct FakeLibrary: PhotoLibraryPictures {
    struct Refused: Error {}

    var collections: [String: (width: Int, height: Int)?] = [:]
    var counts: [String: Int] = [:]
    var refusing = false
    /// The size of the photographs the person picked for the app, when access
    /// is limited to some, and how many of them there are.
    var selected: (width: Int, height: Int)?
    var selectedHolds = 1
    /// The size of the first photograph, in a collection or among the picked,
    /// when it is to be told apart from one picked at random.
    var first: (width: Int, height: Int)?

    func selectedCount() throws -> Int {
        if refusing { throw Refused() }
        return selected == nil ? 0 : selectedHolds
    }

    func selectedPicture(fitting box: CGSize, pick: PicturePick) throws -> LibraryPicture? {
        if refusing { throw Refused() }
        guard var selected else { return nil }
        if pick == .first, let first { selected = first }
        return LibraryPicture(
            image: try makeImage(width: selected.width, height: selected.height),
            originalWidth: 4032, originalHeight: 3024)
    }

    func count(inCollection identifier: String) throws -> Int {
        if refusing { throw Refused() }
        guard (collections[identifier] ?? nil) != nil else { return 0 }
        return counts[identifier] ?? 1
    }

    func picture(
        inCollection identifier: String, fitting box: CGSize, pick: PicturePick
    ) throws -> LibraryPicture? {
        if refusing { throw Refused() }
        guard var size = collections[identifier] ?? nil else { return nil }
        if pick == .first, let first { size = first }
        return LibraryPicture(
            image: try makeImage(width: size.width, height: size.height),
            originalWidth: 4032, originalHeight: 3024)
    }
}
