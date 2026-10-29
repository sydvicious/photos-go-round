import CoreGraphics
import Foundation
import PhotosGoRoundAgentAPI
import Testing

@testable import TinyCache

@Suite("A Photos collection as a source of pictures")
struct PhotosSourceTests {
    let box = CGSize(width: 400, height: 400)

    @Test("A picture the library hands back is written as it came, and reported")
    func writesWhatTheLibraryGave() throws {
        let scratch = try ScratchFolder()
        let written = scratch.url.appending(path: "written.jpg")
        let library = FakeLibrary(collections: ["album": (width: 400, height: 300)])

        let resize = try #require(
            try PhotosSource(collection: "album", library: library).writePicture(fitting: box, to: written))

        let size = try #require(pixelSize(of: written))
        #expect(size.width == 400)
        #expect(size.height == 300)
        #expect(resize.originalType == "photos")
        #expect(resize.originalWidth == 4032)
        #expect(resize.originalHeight == 3024)
        #expect(resize.writtenWidth == 400)
        #expect(resize.writtenHeight == 300)
        #expect(resize.writtenBytes == byteCount(of: written))
    }

    @Test("Asked for its first picture, it writes the collection's first and not one picked at random")
    func firstPicture() throws {
        let scratch = try ScratchFolder()
        let written = scratch.url.appending(path: "written.jpg")
        var library = FakeLibrary(collections: ["album": (width: 400, height: 300)])
        library.first = (width: 200, height: 100)

        _ = try #require(
            try PhotosSource(collection: "album", library: library, pick: .first)
                .writePicture(fitting: box, to: written))

        let size = try #require(pixelSize(of: written))
        #expect(size.width == 200)
        #expect(size.height == 100)
    }

    @Test("A collection with no pictures, or one that is gone, has nothing to write")
    func nothingToWrite() throws {
        let scratch = try ScratchFolder()
        let written = scratch.url.appending(path: "written.jpg")
        let library = FakeLibrary(collections: ["empty": nil])

        #expect(try PhotosSource(collection: "empty", library: library).writePicture(fitting: box, to: written) == nil)
        #expect(try PhotosSource(collection: "gone", library: library).writePicture(fitting: box, to: written) == nil)
        #expect(pixelSize(of: written) == nil)
    }

    @Test("A library that refuses is an error, not an empty answer")
    func refusalIsReported() throws {
        let scratch = try ScratchFolder()
        let library = FakeLibrary(collections: ["album": (width: 40, height: 30)], refusing: true)

        #expect(throws: FakeLibrary.Refused.self) {
            try PhotosSource(collection: "album", library: library).writePicture(
                fitting: box, to: scratch.url.appending(path: "written.jpg"))
        }
    }

    @Test("It holds as many pictures as the library says its collection does")
    func countsItsPictures() throws {
        let library = FakeLibrary(
            collections: ["album": (width: 40, height: 30), "empty": nil], counts: ["album": 250])

        #expect(try PhotosSource(collection: "album", library: library).pictureCount() == 250)
        #expect(try PhotosSource(collection: "empty", library: library).pictureCount() == 0)
        #expect(try PhotosSource(collection: "gone", library: library).pictureCount() == 0)
    }

    @Test("Writing a picture does not say how many it holds: that is the library's to answer")
    func writingDoesNotCount() throws {
        let scratch = try ScratchFolder()
        let library = FakeLibrary(collections: ["album": (width: 40, height: 30)], counts: ["album": 250])

        let picked = try PhotosSource(collection: "album", library: library)
            .writePictureAndCount(fitting: box, to: scratch.url.appending(path: "written.jpg"))

        #expect(picked.resize != nil)
        #expect(picked.pictures == nil)
    }

    @Test("A library that refuses cannot be counted, which is not a count of none")
    func refusalIsNotCounted() throws {
        let library = FakeLibrary(collections: ["album": (width: 40, height: 30)], refusing: true)

        #expect(throws: FakeLibrary.Refused.self) {
            try PhotosSource(collection: "album", library: library).pictureCount()
        }
    }

    @Test("Its count is remembered under its collection")
    func countName() throws {
        let library = FakeLibrary()

        #expect(
            PhotosSource(collection: "album", library: library).countName
                == PhotosSource(collection: "album", library: library).countName)
        #expect(
            PhotosSource(collection: "album", library: library).countName
                != PhotosSource(collection: "other", library: library).countName)
    }

    /// A fetch's own line is written when it ends. This one says what was
    /// about to be asked of Photos, so that whatever the memory does next
    /// has a name. `Plans/PGR Widgets - iOS.md`, *The icon, made for widgets*.
    @Test("What is about to be asked of Photos is said in a line: the photograph's size and the size wanted")
    func saidBeforeAsking() {
        #expect(
            SystemPhotoLibraryPictures.asking(width: 3000, height: 2002, fitting: CGSize(width: 1014, height: 1062))
                == "asking Photos for a 3000x2002 photograph at 1014x1062")
    }

    // MARK: A file from Photos, shrunk as a file is

    /// A library that counts how often it is asked for a photograph, and hands
    /// back one of 40 by 30, said to be 4032 by 3024.
    final class CountingLibrary: PhotoLibraryPictures, @unchecked Sendable {
        private let lock = NSLock()
        private var asked = 0
        var timesAsked: Int { lock.withLock { asked } }

        func picture(inCollection identifier: String, fitting box: CGSize, pick: PicturePick) throws -> LibraryPicture? {
            lock.withLock { asked += 1 }
            return LibraryPicture(image: try makeImage(width: 40, height: 30), originalWidth: 4032, originalHeight: 3024)
        }
        func count(inCollection identifier: String) throws -> Int { 3 }
        func selectedPicture(fitting box: CGSize, pick: PicturePick) throws -> LibraryPicture? {
            try picture(inCollection: "", fitting: box, pick: pick)
        }
        func selectedCount() throws -> Int { 3 }
    }

    static let megabyte: Int64 = 1_048_576

    /// A process holding `held` megabytes of a limit of `limit`.
    static func resizer(held: Int64, of limit: Int64) -> PictureResizer {
        PictureResizer(memory: {
            Footprint.Reading(
                footprint: held * megabyte, resident: held * megabyte, left: (limit - held) * megabyte)
        })
    }

    /// Photos decoded the photograph inside the widget's process, at 15 to 21
    /// MB, and more for some. Its file is taken instead and shrunk as a file
    /// is: weighed by its own size and kind, and in bands. `Plans/PGR Widgets
    /// - iOS.md`, *The Photos guard on the devices*.
    @Test("A photograph is taken from Photos as a file, shrunk from it, and the file let go")
    func shrunkFromAFile() throws {
        let scratch = try ScratchFolder()
        let written = scratch.url.appending(path: "written.jpg")
        let library = CountingLibrary()

        let resize = try #require(
            try PhotosSource(collection: "album", library: library).writePicture(fitting: box, to: written))

        #expect(library.timesAsked == 1)
        #expect(resize.originalType == "photos")
        #expect(resize.originalWidth == 4032)
        #expect(resize.originalHeight == 3024)
        #expect(pixelSize(of: written) != nil)
        let left = try FileManager.default.contentsOfDirectory(atPath: scratch.url.path(percentEncoded: false))
        #expect(left == ["written.jpg"])
    }

    @Test("Too large for what is left just now, others are tried, and then it is refused for now")
    func refusedForNow() throws {
        let scratch = try ScratchFolder()
        let library = CountingLibrary()
        let skipped = Collected<Bool>()
        // 2 MB left: the 4 MB a small picture is reckoned at does not fit.
        let source = PhotosSource(
            collection: "album", library: library, resizer: Self.resizer(held: 28, of: 30),
            skipped: { skipped.add(true) })

        do {
            _ = try source.writePicture(fitting: box, to: scratch.url.appending(path: "written.jpg"))
            Issue.record("it was not refused")
        } catch PictureResizer.Failure.tooLarge(_, let ever) {
            #expect(!ever)
        }
        #expect(library.timesAsked == 3)
        #expect(skipped.values.isEmpty)
    }

    @Test("One no widget could ever shrink is passed over, and the collection says so")
    func refusedForGood() throws {
        let scratch = try ScratchFolder()
        let skipped = Collected<Bool>()
        // A limit of 8 MB: 2 MB for a widget holding nothing else.
        let source = PhotosSource(
            collection: "album", library: CountingLibrary(), resizer: Self.resizer(held: 6, of: 8),
            skipped: { skipped.add(true) })

        #expect(try source.writePicture(fitting: box, to: scratch.url.appending(path: "written.jpg")) == nil)
        #expect(!skipped.values.isEmpty)
    }

    @Test("The photographs picked with limited access are taken the same way")
    func selectedPhotosToo() throws {
        let scratch = try ScratchFolder()
        let skipped = Collected<Bool>()
        let source = SelectedPhotosSource(
            library: CountingLibrary(), resizer: Self.resizer(held: 6, of: 8), skipped: { skipped.add(true) })

        #expect(try source.writePicture(fitting: box, to: scratch.url.appending(path: "written.jpg")) == nil)
        #expect(!skipped.values.isEmpty)
    }

    @Test("Asking Photos for a photograph's file is said in a line: its name, when taken, its size and its kind")
    func saidBeforeAskingForAFile() {
        #expect(
            SystemPhotoLibraryPictures.askingForFile(width: 4032, height: 3024, type: "public.heic")
                == "asking Photos for the file of a 4032x3024 photograph, public.heic")
        #expect(
            SystemPhotoLibraryPictures.askingForFile(
                width: 4032, height: 3024, type: "public.heic", named: "IMG_1234.HEIC", taken: "2024-09-21 18:03")
                == "asking Photos for the file of \u{201C}IMG_1234.HEIC\u{201D}, taken 2024-09-21 18:03, "
                + "a 4032x3024 photograph, public.heic")
    }

    /// Photos' edited version is a file Photos wrote, not the camera's or
    /// the scanner's. `Plans/PGR Widgets - iOS.md`, *A scan at full colour*.
    @Test("The line says whether Photos gave its edited version or the original")
    func saysWhichVersion() {
        #expect(
            SystemPhotoLibraryPictures.askingForFile(width: 9920, height: 12925, type: "public.jpeg", edited: true)
                == "asking Photos for the file of a 9920x12925 photograph, public.jpeg, the edited version")
        #expect(
            SystemPhotoLibraryPictures.askingForFile(width: 9920, height: 12925, type: "public.jpeg", edited: false)
                == "asking Photos for the file of a 9920x12925 photograph, public.jpeg, the original")
    }

    @Test("A photograph's name and when it was taken reach the line written before it is shrunk")
    func nameReachesTheShrink() throws {
        let scratch = try ScratchFolder()
        let library = NamedLibrary()

        _ = try PhotosSource(collection: "album", library: library)
            .writePicture(fitting: box, to: scratch.url.appending(path: "written.jpg"))

        #expect(library.handedOver?.name == "IMG_1234.HEIC")
    }

    /// Hands back a file with a name and a day, as Photos does.
    final class NamedLibrary: PhotoLibraryPictures, @unchecked Sendable {
        var handedOver: LibraryPictureFile?
        func picture(inCollection identifier: String, fitting box: CGSize, pick: PicturePick) throws -> LibraryPicture? { nil }
        func count(inCollection identifier: String) throws -> Int { 1 }
        func selectedPicture(fitting box: CGSize, pick: PicturePick) throws -> LibraryPicture? { nil }
        func selectedCount() throws -> Int { 0 }
        func pictureFile(
            inCollection identifier: String, fitting box: CGSize, pick: PicturePick, to file: URL
        ) throws -> LibraryPictureFile? {
            try writePicture(to: file, width: 64, height: 48)
            let handed = LibraryPictureFile(
                originalWidth: 4032, originalHeight: 3024, name: "IMG_1234.HEIC", taken: Date(timeIntervalSince1970: 0))
            handedOver = handed
            return handed
        }
    }

    // MARK: Photographs only in iCloud

    /// Hands its photographs over in turn, each on this device or only in
    /// iCloud, and says how each was asked for. One only in iCloud asked for
    /// from this device alone is not handed over.
    final class CloudLibrary: PhotoLibraryPictures, @unchecked Sendable {
        enum Kept { case onDevice, inICloud }
        private var kept: [Kept]
        var asked: [PhotoReach] = []

        init(_ kept: [Kept]) { self.kept = kept }

        func picture(inCollection identifier: String, fitting box: CGSize, pick: PicturePick) throws -> LibraryPicture? { nil }
        func count(inCollection identifier: String) throws -> Int { kept.count }
        func selectedPicture(fitting box: CGSize, pick: PicturePick) throws -> LibraryPicture? { nil }
        func selectedCount() throws -> Int { 0 }
        func pictureFile(
            inCollection identifier: String, fitting box: CGSize, pick: PicturePick, to file: URL, reach: PhotoReach
        ) throws -> LibraryPictureFile? {
            asked.append(reach)
            let next = kept.isEmpty ? .onDevice : kept.removeFirst()
            if next == .inICloud && reach == .thisDevice { throw PhotoNotOnDevice() }
            try writePicture(to: file, width: 64, height: 48)
            return LibraryPictureFile(originalWidth: 4032, originalHeight: 3024)
        }
        func selectedPictureFile(
            fitting box: CGSize, pick: PicturePick, to file: URL, reach: PhotoReach
        ) throws -> LibraryPictureFile? {
            try pictureFile(inCollection: "", fitting: box, pick: pick, to: file, reach: reach)
        }
    }

    /// iCloud took 30 to 65 seconds for an original on Syd's phone,
    /// 2026-10-25, while one on the device took a tenth of a second. Syd, of
    /// passing over those and waiting longer: "do BOTH".
    @Test("A photograph only in iCloud is passed over for one on this device")
    func onDeviceFirst() throws {
        let scratch = try ScratchFolder()
        let library = CloudLibrary([.inICloud, .inICloud, .onDevice])

        let resize = try PhotosSource(collection: "album", library: library)
            .writePicture(fitting: box, to: scratch.url.appending(path: "written.jpg"))

        #expect(resize != nil)
        #expect(library.asked == [.thisDevice, .thisDevice, .thisDevice])
    }

    @Test("With none found on this device, the next is waited for from iCloud")
    func thenFromICloud() throws {
        let scratch = try ScratchFolder()
        let library = CloudLibrary([.inICloud, .inICloud, .inICloud, .inICloud, .inICloud])

        let resize = try PhotosSource(collection: "album", library: library)
            .writePicture(fitting: box, to: scratch.url.appending(path: "written.jpg"))

        #expect(resize != nil)
        #expect(library.asked == [.thisDevice, .thisDevice, .thisDevice, .thisDevice, .iCloudToo])
    }

    @Test("The first picture, wanted at once, is waited for from iCloud straight away")
    func firstFromICloud() throws {
        let scratch = try ScratchFolder()
        let library = CloudLibrary([.inICloud])

        let resize = try PhotosSource(collection: "album", library: library, pick: .first)
            .writePicture(fitting: box, to: scratch.url.appending(path: "written.jpg"))

        #expect(resize != nil)
        #expect(library.asked == [.iCloudToo])
    }

    @Test("The photographs a person picked are passed over the same way")
    func selectedOnDeviceFirst() throws {
        let scratch = try ScratchFolder()
        let library = CloudLibrary([.inICloud, .onDevice])

        let resize = try SelectedPhotosSource(library: library)
            .writePicture(fitting: box, to: scratch.url.appending(path: "written.jpg"))

        #expect(resize != nil)
        #expect(library.asked == [.thisDevice, .thisDevice])
    }

    /// For a RAW photograph, which Photos still decodes: its file is not
    /// shrunk here.
    @Test("A fetch Photos decodes itself is reckoned at five times the picture asked for, at four bytes a pixel")
    func reckonedFromTheSizeAskedFor() {
        #expect(PictureResizer.needsFromPhotos(fitting: CGSize(width: 1590, height: 757)) == 5 * 1590 * 757 * 4)
    }

    // MARK: Where a photograph came from

    @Test("A photograph says it came from Photos, by its identifier")
    func origin() throws {
        let scratch = try ScratchFolder()

        let resize = try PhotosSource(collection: "album", library: IdentifiedLibrary())
            .writePicture(fitting: box, to: scratch.url.appending(path: "written.jpg"))

        #expect(resize?.origin == .photo("ABC-123/L0/001"))
    }

    @Test("A photograph is written again from its identifier")
    func writtenAgain() throws {
        let scratch = try ScratchFolder()
        let library = IdentifiedLibrary()

        let resize = try PhotosSource(collection: "album", library: library)
            .writePicture(.photo("ABC-123/L0/001"), fitting: box, to: scratch.url.appending(path: "written.jpg"))

        #expect(resize?.origin == .photo("ABC-123/L0/001"))
        #expect(library.identifiersAsked == ["ABC-123/L0/001"])
    }

    @Test("A file is not Photos' to write again")
    func notWrittenAgain() throws {
        let scratch = try ScratchFolder()

        #expect(
            try PhotosSource(collection: "album", library: IdentifiedLibrary())
                .writePicture(.file("/pictures/a.jpg"), fitting: box, to: scratch.url.appending(path: "w.jpg")) == nil)
    }

    /// Hands back photographs that carry their identifier, and can be asked
    /// for one by it.
    final class IdentifiedLibrary: PhotoLibraryPictures, @unchecked Sendable {
        private let lock = NSLock()
        private var asked: [String] = []
        var identifiersAsked: [String] { lock.withLock { asked } }

        func picture(inCollection identifier: String, fitting box: CGSize, pick: PicturePick) throws -> LibraryPicture? { nil }
        func count(inCollection identifier: String) throws -> Int { 1 }
        func selectedPicture(fitting box: CGSize, pick: PicturePick) throws -> LibraryPicture? { nil }
        func selectedCount() throws -> Int { 0 }
        func pictureFile(
            inCollection identifier: String, fitting box: CGSize, pick: PicturePick, to file: URL
        ) throws -> LibraryPictureFile? {
            try writePicture(to: file, width: 64, height: 48)
            return LibraryPictureFile(originalWidth: 64, originalHeight: 48, identifier: "ABC-123/L0/001")
        }
        func selectedPictureFile(fitting box: CGSize, pick: PicturePick, to file: URL) throws -> LibraryPictureFile? {
            nil
        }
        func pictureFile(
            identifiedBy identifier: String, fitting box: CGSize, to file: URL, reach: PhotoReach
        ) throws -> LibraryPictureFile? {
            lock.withLock { asked.append(identifier) }
            try writePicture(to: file, width: 64, height: 48)
            return LibraryPictureFile(originalWidth: 64, originalHeight: 48, identifier: identifier)
        }
    }
}
