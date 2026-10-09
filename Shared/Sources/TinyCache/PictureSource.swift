// Where a TinyCache's pictures come from. `Plans/Photos-Go-Round Widgets.md`.
//
// **A source is asked, and answers.** No agent stands behind it and nothing is
// fetched ahead: the widget extension asks for a picture when it is about to
// show one, from inside its own process.

import CoreGraphics
import Foundation
import UniformTypeIdentifiers

public protocol PictureSource: Sendable {
    /// Writes one picture, chosen at random, at the largest size that fits
    /// `box`, in pixels. Nil when the source has no pictures, and an error
    /// when it cannot be read at all — so "nothing there" and "not allowed in"
    /// stay different answers.
    ///
    /// **The source writes; it does not hand over a file to be shrunk.** A
    /// folder has an original to shrink. The Photos library can be asked for a
    /// picture at the size wanted, and then no original is ever held.
    func writePicture(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize?
}

/// A source that can say how many pictures it holds, which is what lets
/// several of them be weighed against each other. `SeveralSources`.
public protocol CountedSource: PictureSource {
    /// What its count is remembered under: all that makes it this source and
    /// not another, and the same from one process to the next.
    var countName: String { get }

    /// How many pictures it holds now. An error when it cannot be read at all,
    /// which is not a count of none.
    func pictureCount() throws -> Int

    /// Writes a picture as `writePicture` does, and says how many pictures the
    /// source holds when finding one told it that: a folder is walked whole to
    /// choose from it, and has counted itself by the end. Nil from a source
    /// that chooses without counting.
    func writePictureAndCount(
        fitting box: CGSize, to destination: URL
    ) throws -> (resize: PictureResizer.Resize?, pictures: Int?)
}

extension CountedSource {
    public func writePictureAndCount(
        fitting box: CGSize, to destination: URL
    ) throws -> (resize: PictureResizer.Resize?, pictures: Int?) {
        (try writePicture(fitting: box, to: destination), nil)
    }
}

/// A folder on disk, with every folder inside it unless told otherwise.
public struct FolderSource: CountedSource {
    public let folder: URL

    public let recursive: Bool

    public init(folder: URL, recursive: Bool = true) {
        self.folder = folder
        self.recursive = recursive
    }

    /// A file that will not decode is passed over for another, a few times,
    /// and then given up on: a folder of things that are not pictures has
    /// nothing to show, which is not an error.
    public func writePicture(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize? {
        try writePictureAndCount(fitting: box, to: destination).resize
    }

    public func writePictureAndCount(
        fitting box: CGSize, to destination: URL
    ) throws -> (resize: PictureResizer.Resize?, pictures: Int?) {
        let (originals, held) = try pick(Self.attempts)
        for original in originals {
            do {
                return (try PictureResizer().write(original, fitting: box, to: destination), held)
            } catch PictureResizer.Failure.notAPicture {
                continue
            }
        }
        return (nil, held)
    }

    private static let attempts = 3

    public var countName: String { "folder|\(folder.path(percentEncoded: false))|\(recursive)" }

    /// A walk of the whole folder, as choosing a picture from it is.
    public func pictureCount() throws -> Int {
        guard let files = try files() else { return 0 }
        var count = 0
        for case let file as URL in files where Self.isPicture(file) { count += 1 }
        return count
    }

    /// Everything in the folder, to be walked once.
    private func files() throws -> FileManager.DirectoryEnumerator? {
        let manager = FileManager.default
        // An enumerator over a folder that is missing or forbidden simply ends,
        // which would read as an empty folder. Listing the top level first is
        // what throws.
        _ = try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        return manager.enumerator(
            at: folder, includingPropertiesForKeys: nil,
            options: recursive
                ? [.skipsHiddenFiles, .skipsPackageDescendants]
                : [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])
    }

    /// Up to `count` pictures, chosen at random and none of them twice.
    public func pictures(_ count: Int) throws -> [URL] {
        guard count > 0 else { return [] }
        return try pick(count).chosen
    }

    /// Up to `count` pictures, and how many the folder held to choose from.
    private func pick(_ count: Int) throws -> (chosen: [URL], held: Int) {
        guard let files = try files() else { return ([], 0) }

        // A reservoir: the whole folder is walked, and only `count` paths are
        // held at any moment, however many pictures there are.
        var chosen: [URL] = []
        var seen = 0
        var generator = SystemRandomNumberGenerator()
        for case let file as URL in files where Self.isPicture(file) {
            seen += 1
            if chosen.count < count {
                chosen.append(file)
            } else {
                let slot = Int.random(in: 0..<seen, using: &generator)
                if slot < count { chosen[slot] = file }
            }
        }
        return (chosen.shuffled(using: &generator), seen)
    }

    /// By its name alone. Opening each file to find out would cost a read per
    /// file on every walk; a file that lies about itself is caught when it is
    /// decoded.
    static func isPicture(_ file: URL) -> Bool {
        UTType(filenameExtension: file.pathExtension)?.conforms(to: .image) ?? false
    }
}
