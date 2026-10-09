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

/// A folder on disk, with every folder inside it unless told otherwise.
public struct FolderSource: PictureSource {
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
        for original in try pictures(Self.attempts) {
            do {
                return try PictureResizer().write(original, fitting: box, to: destination)
            } catch PictureResizer.Failure.notAPicture {
                continue
            }
        }
        return nil
    }

    private static let attempts = 3

    /// Up to `count` pictures, chosen at random and none of them twice.
    public func pictures(_ count: Int) throws -> [URL] {
        guard count > 0 else { return [] }
        let manager = FileManager.default
        // An enumerator over a folder that is missing or forbidden simply ends,
        // which would read as an empty folder. Listing the top level first is
        // what throws.
        _ = try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        guard
            let files = manager.enumerator(
                at: folder, includingPropertiesForKeys: nil,
                options: recursive
                    ? [.skipsHiddenFiles, .skipsPackageDescendants]
                    : [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])
        else { return [] }

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
        return chosen.shuffled(using: &generator)
    }

    /// By its name alone. Opening each file to find out would cost a read per
    /// file on every walk; a file that lies about itself is caught when it is
    /// decoded.
    static func isPicture(_ file: URL) -> Bool {
        UTType(filenameExtension: file.pathExtension)?.conforms(to: .image) ?? false
    }
}
