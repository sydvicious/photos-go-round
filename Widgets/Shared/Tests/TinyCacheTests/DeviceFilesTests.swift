import CoreGraphics
import Foundation
import Testing

@testable import TinyCache

/// A widget cannot read a file in iCloud Drive that is not on the device, and
/// its reading does not fetch one: Syd's phone, 2026-10-11. No test can put a
/// file in iCloud Drive, so which files are on the device is told to the
/// source here, and what it asks to be fetched is collected.
@Suite("Files that are not on the device")
struct DeviceFilesTests {
    let box = CGSize(width: 200, height: 200)

    /// Files whose names begin "cloud" are not on the device.
    func device(asking asked: Collected<[String]> = Collected()) -> DeviceFiles {
        DeviceFiles(
            isOnDevice: { !$0.lastPathComponent.hasPrefix("cloud") },
            fetch: { asked.add($0.map(\.lastPathComponent).sorted()) })
    }

    @Test("A folder's pictures are picked from the files that are on the device")
    func picksWhatIsHere() throws {
        let scratch = try ScratchFolder()
        for name in ["here-1.jpg", "here-2.jpg", "cloud-1.jpg", "cloud-2.jpg", "cloud-3.jpg"] {
            try scratch.picture(name)
        }

        let found = try FolderSource(folder: scratch.url, device: device()).pictures(10)

        #expect(Set(found.map(\.lastPathComponent)) == ["here-1.jpg", "here-2.jpg"])
    }

    @Test("Some of the files passed over are asked for, no more than were to be picked")
    func asksForSome() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("here.jpg")
        for number in 1...8 { try scratch.picture("cloud-\(number).jpg") }
        let asked = Collected<[String]>()

        _ = try FolderSource(folder: scratch.url, device: device(asking: asked)).pictures(2)

        let files = try #require(asked.values.first)
        #expect(asked.values.count == 1)
        #expect(files.count == 2)
        #expect(files.allSatisfy { $0.hasPrefix("cloud") })
    }

    @Test("Nothing is asked for when every file is on the device")
    func asksForNothing() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("here-1.jpg")
        try scratch.picture("here-2.jpg")
        let asked = Collected<[String]>()

        _ = try FolderSource(folder: scratch.url, device: device(asking: asked)).pictures(2)

        #expect(asked.values.isEmpty)
    }

    @Test("With none on the device the files are asked for, and tried all the same")
    func noneHere() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("pictures/cloud-1.jpg", width: 800, height: 600)
        let asked = Collected<[String]>()
        let source = FolderSource(folder: scratch.url.appending(path: "pictures"), device: device(asking: asked))

        // The app's reading fetches the file, which here is simply there.
        let resize = try source.writePicture(fitting: box, to: scratch.url.appending(path: "written.heic"))

        #expect(resize != nil)
        #expect(asked.values == [["cloud-1.jpg"]])
    }

    @Test("A folder counts every picture, on the device or not")
    func countsAll() throws {
        let scratch = try ScratchFolder()
        try scratch.picture("here.jpg")
        try scratch.picture("cloud-1.jpg")
        try scratch.picture("cloud-2.jpg")
        let source = FolderSource(folder: scratch.url, device: device())

        #expect(try source.pictureCount() == 3)
        #expect(
            try source.writePictureAndCount(fitting: box, to: scratch.url.appending(path: "written.heic"))
                .pictures == 3)
    }

    @Test("A single file that is not on the device is asked for, and tried all the same")
    func singleFile() throws {
        let scratch = try ScratchFolder()
        let file = try scratch.picture("cloud-moon.jpg")
        let asked = Collected<[String]>()

        let resize = try FileSource(file: file, device: device(asking: asked))
            .writePicture(fitting: box, to: scratch.url.appending(path: "written.heic"))

        #expect(resize != nil)
        #expect(asked.values == [["cloud-moon.jpg"]])
    }

    @Test("A single file that is on the device is not asked for")
    func singleFileHere() throws {
        let scratch = try ScratchFolder()
        let file = try scratch.picture("moon.jpg")
        let asked = Collected<[String]>()

        _ = try FileSource(file: file, device: device(asking: asked))
            .writePicture(fitting: box, to: scratch.url.appending(path: "written.heic"))

        #expect(asked.values.isEmpty)
    }

    // MARK: - Going through the rest

    /// Syd, 2026-10-11: "If a file can't be served, go through the files in
    /// that source sequentially until you find one, or until we determine
    /// that there are zero in that source, and only then, show "No Photos
    /// Found"". When a source is gone through is `SeveralSources`'.
    @Test("Gone through, a folder comes to the one file that gives a picture")
    func goesThroughTheRest() throws {
        let scratch = try ScratchFolder()
        for number in 1...40 { try scratch.text("pictures/broken-\(number).jpg") }
        try scratch.picture("pictures/good.jpg", width: 800, height: 600)
        let source = FolderSource(folder: scratch.url.appending(path: "pictures"), device: device())

        let resize = try source.writePictureGoingThrough(
            fitting: box, to: scratch.url.appending(path: "written.heic"))

        #expect(resize?.writtenWidth == 200)
    }

    @Test("A file that is not on the device is come to once every one that is has given nothing")
    func comesToWhatIsAway() throws {
        let scratch = try ScratchFolder()
        for number in 1...10 { try scratch.text("pictures/here-\(number).jpg") }
        // Read by the app, whose reading fetches it.
        try scratch.picture("pictures/cloud-good.jpg", width: 800, height: 600)
        let source = FolderSource(folder: scratch.url.appending(path: "pictures"), device: device())

        let resize = try source.writePictureGoingThrough(
            fitting: box, to: scratch.url.appending(path: "written.heic"))

        #expect(resize?.writtenWidth == 200)
    }

    /// Syd, 2026-10-11: "I prefer for the widget to try until the system
    /// kills it or it runs out of files". One file that is not on the device
    /// failing to read is no reason to pass over the others like it: one of
    /// them may have come since.
    @Test("Every file that is not on the device is tried, however many before it gave nothing")
    func triesEveryFileThatIsAway() throws {
        let scratch = try ScratchFolder()
        for number in 1...40 { try scratch.text("pictures/cloud-\(number).jpg") }
        try scratch.picture("pictures/cloud-good.jpg", width: 800, height: 600)
        let source = FolderSource(folder: scratch.url.appending(path: "pictures"), device: device())

        let resize = try source.writePictureGoingThrough(
            fitting: box, to: scratch.url.appending(path: "written.heic"))

        #expect(resize?.writtenWidth == 200)
    }

    @Test("Gone through with no file giving a picture, a folder has none")
    func noneAfterAll() throws {
        let scratch = try ScratchFolder()
        for number in 1...10 { try scratch.text("pictures/here-\(number).jpg") }
        for number in 1...10 { try scratch.text("pictures/cloud-\(number).jpg") }
        let source = FolderSource(folder: scratch.url.appending(path: "pictures"), device: device())

        let resize = try source.writePictureGoingThrough(
            fitting: box, to: scratch.url.appending(path: "written.heic"))

        #expect(resize == nil)
    }

    @Test("A pick at random does not go through the folder: it gives up after a few")
    func aPickDoesNotGoThrough() throws {
        let scratch = try ScratchFolder()
        for number in 1...40 { try scratch.text("pictures/broken-\(number).jpg") }
        let source = FolderSource(folder: scratch.url.appending(path: "pictures"), device: device())

        let answer = try source.writePictureAndCount(fitting: box, to: scratch.url.appending(path: "written.heic"))

        #expect(answer.resize == nil)
        #expect(answer.pictures == 40)
    }
}
