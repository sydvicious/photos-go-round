import CoreGraphics
import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundWidgetFace
import Synchronization
import Testing

@testable import PhotosGoRoundWidgetSettings
@testable import TinyCache

/// A Photos library that answers from a script, and counts the pictures asked
/// of it. With the script used up it gives a picture.
final class ScriptedLibrary: PhotoLibraryPictures {
    enum Answer { case picture, timeout }

    private let script: Mutex<[Answer]>
    private let asked = Mutex(0)

    var timesAsked: Int { asked.withLock { $0 } }

    init(_ script: [Answer]) {
        self.script = Mutex(script)
    }

    func picture(
        inCollection identifier: String, fitting box: CGSize, pick: PicturePick
    ) throws -> LibraryPicture? {
        asked.withLock { $0 += 1 }
        switch script.withLock({ $0.isEmpty ? Answer.picture : $0.removeFirst() }) {
        case .picture:
            return LibraryPicture(
                image: try makeImage(width: 40, height: 30), originalWidth: 4032, originalHeight: 3024)
        case .timeout:
            throw TimedOut(after: .seconds(15))
        }
    }

    func count(inCollection identifier: String) throws -> Int { 3 }

    func selectedPicture(fitting box: CGSize, pick: PicturePick) throws -> LibraryPicture? { nil }

    func selectedCount() throws -> Int { 0 }
}

@Suite("What a widget shows each time the system wakes it")
struct WidgetPicturesTests {
    let box = CGSize(width: 200, height: 200)
    let album = SourceSpec(kind: .photosCollection, locator: "A1")
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    // MARK: Caches no widget has any more

    func folders(in root: ScratchFolder) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: root.url.path(percentEncoded: false)).sorted()
    }

    @Test("A cache whose setting no widget has is cleared away, and the others are left")
    func clearsAway() throws {
        let root = try ScratchFolder()
        for name in ["systemSmall", "systemSmall-300", "systemSmall-1800", "systemLarge-300"] {
            try root.picture("\(name)/492x492/sources-1/shown/0000000001-AAAA.jpg")
        }

        let cleared = WidgetPictures.clearAway(in: root.url, keeping: ["systemSmall-1800", "systemLarge-300"])

        #expect(cleared.sorted() == ["systemSmall", "systemSmall-300"])
        #expect(try folders(in: root) == ["systemLarge-300", "systemSmall-1800"])
    }

    @Test("With no widget known of, nothing is cleared away: the list could not be had")
    func clearsNothingWithoutAList() throws {
        let root = try ScratchFolder()
        try root.picture("systemSmall-300/492x492/sources-1/shown/0000000001-AAAA.jpg")

        #expect(WidgetPictures.clearAway(in: root.url, keeping: []).isEmpty)
        #expect(try folders(in: root) == ["systemSmall-300"])
    }

    @Test("A file beside the caches is left alone, and so is a folder that is not there")
    func clearsOnlyFolders() throws {
        let root = try ScratchFolder()
        try root.picture("systemSmall-300/492x492/sources-1/shown/0000000001-AAAA.jpg")
        _ = try root.text("notes.txt")

        #expect(WidgetPictures.clearAway(in: root.url, keeping: ["systemLarge-300"]) == ["systemSmall-300"])
        #expect(try folders(in: root) == ["notes.txt"])
        #expect(WidgetPictures.clearAway(in: root.url.appending(path: "none"), keeping: ["x"]).isEmpty)
    }

    // MARK: When Photos does not answer

    @Test("When Photos does not answer and nothing has been shown, it says it is scanning, and asks once")
    func timedOutWithNothing() throws {
        let cache = try ScratchFolder()
        let library = ScriptedLibrary([.timeout])
        let widget = WidgetPictures(directory: cache.url, library: library)

        #expect(widget.turn(from: [album], fitting: box, at: start) == .scanning)

        #expect(library.timesAsked == 1)
        #expect(widget.wait(at: start) == 5)
    }

    @Test("When Photos does not answer, the picture already showing stays, with Scanning… over it")
    func timedOutWithAPicture() throws {
        let cache = try ScratchFolder()
        let widget = WidgetPictures(directory: cache.url, library: ScriptedLibrary([.picture, .timeout]))

        let shown = widget.turn(from: [album], fitting: box, at: start)
        let held = widget.turn(from: [album], fitting: box, at: start + 300)

        #expect(isPicture(shown))
        #expect(scanningOver(held) == file(shown))
        #expect(widget.wait(at: start + 300) == 5)
    }

    @Test("Scanning… stays over the picture through the wait, and goes when Photos answers")
    func scanningOverUntilAnswered() throws {
        let cache = try ScratchFolder()
        let widget = WidgetPictures(directory: cache.url, library: ScriptedLibrary([.picture, .timeout]))
        let shown = widget.turn(from: [album], fitting: box, at: start)
        _ = widget.turn(from: [album], fitting: box, at: start + 300)

        #expect(scanningOver(widget.turn(from: [album], fitting: box, at: start + 302)) == file(shown))
        #expect(isPicture(widget.turn(from: [album], fitting: box, at: start + 305)))
    }

    @Test("It asks nothing more until the wait is over, and then makes a new request")
    func waitsBeforeAskingAgain() throws {
        let cache = try ScratchFolder()
        let library = ScriptedLibrary([.timeout, .picture])
        let widget = WidgetPictures(directory: cache.url, library: library)

        #expect(widget.turn(from: [album], fitting: box, at: start) == .scanning)
        #expect(widget.turn(from: [album], fitting: box, at: start + 2) == .scanning)
        #expect(library.timesAsked == 1)

        #expect(isPicture(widget.turn(from: [album], fitting: box, at: start + 5)))
        #expect(library.timesAsked == 2)
        #expect(widget.wait(at: start + 5) == nil)
    }

    @Test("Each time in a row that Photos does not answer, the wait doubles")
    func waitDoubles() throws {
        let cache = try ScratchFolder()
        let widget = WidgetPictures(
            directory: cache.url, library: ScriptedLibrary([.timeout, .timeout, .timeout]))

        _ = widget.turn(from: [album], fitting: box, at: start)
        _ = widget.turn(from: [album], fitting: box, at: start + 5)
        #expect(widget.wait(at: start + 5) == 10)

        _ = widget.turn(from: [album], fitting: box, at: start + 15)
        #expect(widget.wait(at: start + 15) == 20)
    }

    @Test("Fetching one ahead starts the wait when Photos does not answer, and asks nothing during it")
    func makeReadyWaits() throws {
        let cache = try ScratchFolder()
        let library = ScriptedLibrary([.picture, .timeout])
        let widget = WidgetPictures(directory: cache.url, library: library)
        #expect(isPicture(widget.turn(from: [album], fitting: box, at: start)))

        widget.makeReady(from: [album], fitting: box, at: start)
        #expect(library.timesAsked == 2)
        #expect(widget.wait(at: start) == 5)

        widget.makeReady(from: [album], fitting: box, at: start + 1)
        #expect(library.timesAsked == 2)
    }

    @Test("Whoever is measuring is told what each fetch read and wrote: the wake's own, and the one made ahead")
    func tellsOfEachFetch() throws {
        let cache = try ScratchFolder()
        let fetched = Mutex<[PictureResizer.Resize]>([])
        let widget = WidgetPictures(
            directory: cache.url, library: ScriptedLibrary([]),
            onFetch: { resize in fetched.withLock { $0.append(resize) } })

        #expect(isPicture(widget.turn(from: [album], fitting: box, at: start)))
        #expect(fetched.withLock { $0.count } == 1)

        widget.makeReady(from: [album], fitting: box, at: start)
        let all = fetched.withLock { $0 }
        #expect(all.count == 2)
        #expect(all.map(\.originalWidth) == [4032, 4032])
        #expect(all.map(\.writtenWidth) == [40, 40])

        // The one made ahead is what the next wake shows, with nothing fetched.
        #expect(isPicture(widget.turn(from: [album], fitting: box, at: start + 300)))
        #expect(fetched.withLock { $0.count } == 2)
    }

    // MARK: -

    func folder(_ scratch: ScratchFolder) -> SourceSpec {
        .folder(scratch.url.path(percentEncoded: false))
    }

    func counts(in cache: ScratchFolder) -> Bool {
        FileManager.default.fileExists(
            atPath: cache.url.appending(path: "counts.json").path(percentEncoded: false))
    }

    func isPicture(_ face: WidgetFace.Content) -> Bool {
        if case .picture = face { return true }
        return false
    }

    /// The file of a picture that has "Scanning…" over it, by name.
    func scanningOver(_ face: WidgetFace.Content) -> String? {
        if case .scanningOver(let file) = face { return file.lastPathComponent }
        return nil
    }

    /// The picture's file by name: the same file can be spelled two ways as a
    /// path, through `/var` and through `/private/var`.
    func file(_ face: WidgetFace.Content) -> String? {
        if case .picture(let file) = face { return file.lastPathComponent }
        return nil
    }

    @Test("With nothing chosen it shows the plain icon")
    func nothingChosen() throws {
        let cache = try ScratchFolder()

        #expect(WidgetPictures(directory: cache.url).turn(from: [], fitting: box) == .nothingChosen)
    }

    @Test("Its first picture is the first source's own, and nothing is counted to get it")
    func firstTurn() throws {
        let empty = try ScratchFolder()
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        try pictures.picture("coin.png", width: 800, height: 600)

        let face = WidgetPictures(directory: cache.url).turn(from: [folder(empty), folder(pictures)], fitting: box)

        #expect(isPicture(face))
        #expect(!counts(in: cache))
    }

    @Test("After the first, each picture is picked by how many each source holds")
    func laterTurns() throws {
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        try pictures.picture("coin.png", width: 800, height: 600)
        let widget = WidgetPictures(directory: cache.url)
        let first = widget.turn(from: [folder(pictures)], fitting: box)

        let second = widget.turn(from: [folder(pictures)], fitting: box)

        #expect(isPicture(second))
        #expect(file(second) != file(first))
        #expect(counts(in: cache))
    }

    @Test("With sources chosen and no picture in any of them it says No Photos found")
    func noPhotos() throws {
        let empty = try ScratchFolder()
        let cache = try ScratchFolder()

        #expect(WidgetPictures(directory: cache.url).turn(from: [folder(empty)], fitting: box) == .noPhotos)
    }

    @Test("A library that refuses is No Photos Access, and any other failure is No Photos found")
    func failures() {
        #expect(WidgetPictures.face(for: SystemPhotoLibraryPictures.Refused(status: "denied")) == .noAccess)
        #expect(WidgetPictures.face(for: CocoaError(.fileReadUnknown)) == .noPhotos)
    }

    @Test("What it showed last can be had at once, for the gallery, without asking any source")
    func last() throws {
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        try pictures.picture("coin.png", width: 800, height: 600)
        let widget = WidgetPictures(directory: cache.url)
        #expect(widget.last(from: [folder(pictures)], fitting: box) == .scanning)
        #expect(widget.last(from: [], fitting: box) == .nothingChosen)

        let shown = widget.turn(from: [folder(pictures)], fitting: box)

        #expect(file(shown) != nil)
        #expect(file(widget.last(from: [folder(pictures)], fitting: box)) == file(shown))
    }

    @Test("A picture made ready ahead of time is the next one shown, with nothing fetched then")
    func madeReady() throws {
        let pictures = try ScratchFolder()
        let cache = try ScratchFolder()
        let coin = try pictures.picture("coin.png", width: 800, height: 600)
        let widget = WidgetPictures(directory: cache.url)
        _ = widget.turn(from: [folder(pictures)], fitting: box)

        widget.makeReady(from: [folder(pictures)], fitting: box)
        try FileManager.default.removeItem(at: coin)

        #expect(isPicture(widget.turn(from: [folder(pictures)], fitting: box)))
    }

    /// Two sizes of widget, each with a cache of its own under one folder,
    /// as the extension keeps them.
    func sizes(in root: ScratchFolder) -> (small: WidgetPictures, large: WidgetPictures) {
        (
            WidgetPictures(directory: root.url.appending(path: "systemSmall"), among: root.url),
            WidgetPictures(directory: root.url.appending(path: "systemLarge"), among: root.url)
        )
    }

    @Test("In the gallery, a size with no picture of its own shows the last one another size showed")
    func anotherSizesPicture() throws {
        let pictures = try ScratchFolder()
        let root = try ScratchFolder()
        try pictures.picture("coin.png", width: 800, height: 600)
        let (small, large) = sizes(in: root)
        let shown = small.turn(from: [folder(pictures)], fitting: box)

        let borrowed = large.last(from: [folder(pictures)], fitting: CGSize(width: 600, height: 600))

        #expect(file(shown) != nil)
        #expect(file(borrowed) == file(shown))
    }

    @Test("Of the other sizes' pictures it takes the one made for the biggest widget")
    func theBiggest() throws {
        let pictures = try ScratchFolder()
        let root = try ScratchFolder()
        try pictures.picture("coin.png", width: 800, height: 600)
        let (small, large) = sizes(in: root)
        let medium = WidgetPictures(directory: root.url.appending(path: "systemMedium"), among: root.url)
        _ = small.turn(from: [folder(pictures)], fitting: box)
        let wide = medium.turn(from: [folder(pictures)], fitting: CGSize(width: 400, height: 200))

        let borrowed = large.last(from: [folder(pictures)], fitting: CGSize(width: 600, height: 600))

        #expect(file(borrowed) == file(wide))
    }

    @Test("A picture from other sources than are chosen now is not shown")
    func otherSources() throws {
        let pictures = try ScratchFolder()
        let others = try ScratchFolder()
        let root = try ScratchFolder()
        try pictures.picture("coin.png", width: 800, height: 600)
        let (small, large) = sizes(in: root)
        _ = small.turn(from: [folder(pictures)], fitting: box)

        #expect(large.last(from: [folder(others)], fitting: CGSize(width: 600, height: 600)) == .scanning)
    }

    @Test("In the gallery, with no picture from any size, it shows the plain icon and not Scanning")
    func galleryWithNothing() throws {
        let pictures = try ScratchFolder()
        let root = try ScratchFolder()
        try pictures.picture("coin.png", width: 800, height: 600)
        let (small, large) = sizes(in: root)

        #expect(large.last(from: [folder(pictures)], fitting: box, inGallery: true) == .nothingChosen)

        let shown = small.turn(from: [folder(pictures)], fitting: box)
        #expect(file(large.last(from: [folder(pictures)], fitting: box, inGallery: true)) == file(shown))
    }

    @Test("Its own last picture comes before another size's")
    func itsOwnFirst() throws {
        let pictures = try ScratchFolder()
        let root = try ScratchFolder()
        try pictures.picture("coin.png", width: 800, height: 600)
        let (small, large) = sizes(in: root)
        _ = small.turn(from: [folder(pictures)], fitting: box)
        let own = large.turn(from: [folder(pictures)], fitting: CGSize(width: 600, height: 600))

        #expect(file(large.last(from: [folder(pictures)], fitting: CGSize(width: 600, height: 600))) == file(own))
    }
}
