// Where a TinyCache's pictures come from. `Plans/Photos-Go-Round Widgets.md`.
//
// **A source is asked, and answers.** No agent stands behind it and nothing is
// fetched ahead: the widget extension asks for a picture when it is about to
// show one, from inside its own process.

import Foundation
import UniformTypeIdentifiers

public protocol PictureSource: Sendable {
    /// Up to `count` pictures, chosen at random. Fewer when the source has
    /// fewer, none when it has none, and an error when it cannot be read at
    /// all — so "nothing there" and "not allowed in" stay different answers.
    func pictures(_ count: Int) throws -> [URL]
}

/// A folder on disk, with every folder inside it.
public struct FolderSource: PictureSource {
    public let folder: URL

    public init(folder: URL) {
        self.folder = folder
    }

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
                options: [.skipsHiddenFiles, .skipsPackageDescendants])
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
