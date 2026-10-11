// Where a TinyCache's pictures come from. `Plans/Photos-Go-Round Widgets.md`.
//
// **A source is asked, and answers.** No agent stands behind it and nothing is
// fetched ahead: the widget extension asks for a picture when it is about to
// show one, from inside its own process.

import CoreGraphics
import Foundation
import OSLog
import PhotosGoRoundAgentAPI
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

    /// Writes the first of its pictures that can be written, going through
    /// all of them in turn. For when no source gave a picture to a pick at
    /// random: `SeveralSources`. Nil when it has none to give, and from a
    /// source that cannot go through what it holds.
    func writePictureGoingThrough(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize?
}

extension CountedSource {
    public func writePictureAndCount(
        fitting box: CGSize, to destination: URL
    ) throws -> (resize: PictureResizer.Resize?, pictures: Int?) {
        (try writePicture(fitting: box, to: destination), nil)
    }

    public func writePictureGoingThrough(
        fitting box: CGSize, to destination: URL
    ) throws -> PictureResizer.Resize? {
        nil
    }
}

/// A folder on disk, with every folder inside it unless told otherwise.
public struct FolderSource: CountedSource {
    public let folder: URL

    public let recursive: Bool

    /// Which files are on the device, and asking for the ones that are not.
    private let device: DeviceFiles

    public init(folder: URL, recursive: Bool = true, device: DeviceFiles = .system) {
        self.folder = folder
        self.recursive = recursive
        self.device = device
    }

    /// A file that gives no picture is passed over for another, a few times,
    /// and then the pick is given up on: a folder of things that are not
    /// pictures has nothing to show, which is not an error. Whoever asked
    /// may then have the folder gone through, below.
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
                noteNoPicture(from: original)
                continue
            }
        }
        return (nil, held)
    }

    /// Every picture in the folder, in the folder's own order, until one
    /// gives a picture. Nil when all have been gone through.
    ///
    /// Syd, 2026-10-11: "If a file can't be served, go through the files in
    /// that source sequentially until you find one, or until we determine
    /// that there are zero in that source, and only then, show "No Photos
    /// Found"". When that is done is `SeveralSources`'.
    ///
    /// **The files on the device first, then the rest, every one.** One that
    /// is not on the device is read by the app, whose reading fetches it. A
    /// widget's reading does not, and fails at once; the others like it are
    /// tried all the same, since one may have come since it was asked for.
    /// Syd, 2026-10-11: "I prefer for the widget to try until the system
    /// kills it or it runs out of files".
    public func writePictureGoingThrough(
        fitting box: CGSize, to destination: URL
    ) throws -> PictureResizer.Resize? {
        var passedOver = 0
        for onDevice in [true, false] {
            guard let files = try files() else { break }
            for case let file as URL in files
            where Self.isPicture(file) && device.isOnDevice(file) == onDevice {
                do {
                    let resize = try PictureResizer().write(file, fitting: box, to: destination)
                    Self.noteGoingThrough(passedOver, found: true)
                    return resize
                } catch PictureResizer.Failure.notAPicture {
                    passedOver += 1
                }
            }
        }
        Self.noteGoingThrough(passedOver, found: false)
        return nil
    }

    /// One line for the whole going-through, however many files it passed.
    private static func noteGoingThrough(_ passedOver: Int, found: Bool) {
        Log.widget.notice(
            """
            \(Log.widgetsTag, privacy: .public) went through a folder for a picture: \(passedOver) \
            files gave none, and \(found ? "then one did" : "none did", privacy: .public)
            """)
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
            // Read with the listing, where asking each file afterwards would
            // be a trip to the disk apiece.
            at: folder, includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey],
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
    ///
    /// **From the files that are on the device.** A widget cannot read one
    /// that iCloud Drive has not fetched. As many of those as were to be
    /// picked are asked for, so that more are there next time. With none on
    /// the device they are what is tried: the app's reading fetches a file,
    /// and a widget's finds out that it cannot. `DeviceFiles`.
    ///
    /// The count is of all of them, wherever they are.
    private func pick(_ count: Int) throws -> (chosen: [URL], held: Int) {
        guard let files = try files() else { return ([], 0) }

        // Two reservoirs: the whole folder is walked, and only `count` paths
        // of each kind are held at any moment, however many pictures there
        // are.
        var here = Reservoir(holding: count)
        var away = Reservoir(holding: count)
        for case let file as URL in files where Self.isPicture(file) {
            if device.isOnDevice(file) {
                here.take(file)
            } else {
                away.take(file)
            }
        }
        if away.seen > 0 { device.fetch(away.chosen) }
        return (here.seen > 0 ? here.shuffled() : away.shuffled(), here.seen + away.seen)
    }

    /// Up to so many files, each one that went by having had the same chance.
    private struct Reservoir {
        private(set) var chosen: [URL] = []
        private(set) var seen = 0
        private let limit: Int
        private var generator = SystemRandomNumberGenerator()

        init(holding limit: Int) {
            self.limit = limit
        }

        mutating func take(_ file: URL) {
            seen += 1
            if chosen.count < limit {
                chosen.append(file)
            } else {
                let slot = Int.random(in: 0..<seen, using: &generator)
                if slot < limit { chosen[slot] = file }
            }
        }

        mutating func shuffled() -> [URL] {
            chosen.shuffled(using: &generator)
        }
    }

    /// By its name alone. Opening each file to find out would cost a read per
    /// file on every walk; a file that lies about itself is caught when it is
    /// decoded.
    static func isPicture(_ file: URL) -> Bool {
        UTType(filenameExtension: file.pathExtension)?.conforms(to: .image) ?? false
    }
}

/// One image file, chosen by itself. It is one picture, and every pick from
/// it is that picture.
public struct FileSource: CountedSource {
    public let file: URL

    /// Whether the file is on the device, and asking for it when it is not.
    private let device: DeviceFiles

    public init(file: URL, device: DeviceFiles = .system) {
        self.file = file
        self.device = device
    }

    /// A file that will not decode has nothing to show, as a folder of such
    /// files has not. One that is not there is an error: it cannot be read,
    /// which is not the same as holding nothing.
    ///
    /// One that iCloud Drive has not fetched is asked for and tried all the
    /// same: the app's reading fetches it, and a widget has it next time.
    public func writePicture(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize? {
        _ = try file.checkResourceIsReachable()
        if !device.isOnDevice(file) { device.fetch([file]) }
        do {
            return try PictureResizer().write(file, fitting: box, to: destination)
        } catch PictureResizer.Failure.notAPicture {
            noteNoPicture(from: file)
            return nil
        }
    }

    public var countName: String { "file|\(file.path(percentEncoded: false))" }

    public func pictureCount() throws -> Int {
        _ = try file.checkResourceIsReachable()
        return 1
    }
}

/// Says in the log why a file with a picture's name gave no picture. A file
/// in iCloud Drive that is not on the device reads differently in an app and
/// in its widget, and "would not decode" covers both that and a bad file.
/// The file is not named: its name is the person's.
private func noteNoPicture(from file: URL) {
    var file = file
    file.removeAllCachedResourceValues()
    let status =
        (try? file.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?
        .ubiquitousItemDownloadingStatus?.rawValue ?? "not an iCloud file"
    let reading: String
    do {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        reading = "\(try handle.read(upToCount: 16)?.count ?? 0) bytes came back"
    } catch {
        let error = error as NSError
        reading = "\(error.localizedDescription) (\(error.domain) \(error.code))"
    }
    Log.widget.notice(
        """
        \(Log.widgetsTag, privacy: .public) a file gave no picture: download status \
        \(status, privacy: .public); reading it, \(reading, privacy: .public)
        """)
}
