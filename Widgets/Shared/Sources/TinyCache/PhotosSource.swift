// The Photos library as a source. `Plans/Photos-Go-Round Widgets.md`, *Next:
// the app's sources, then Photos*.
//
// **Photos is asked for the photograph's file, and it is shrunk as a file is.**
// Asked for a picture at the size wanted, Photos decoded the photograph inside
// the widget's own process: 15 to 21 MB a fetch on the iPad and the phone, more
// for some, and twice an iPad's extension was ended in the middle of one. The
// file is written to the widget's cache instead, a little at a time, weighed by
// `PictureResizer` from its own size and kind, shrunk in bands, and let go.
// `Plans/PGR Widgets - iOS.md`, *The Photos guard on the devices*.
//
// **Except a RAW photograph**, which `ImageIO` is not trusted to shrink in
// bands: Photos is asked to draw that one at the size wanted, as before, and
// the fetch is weighed by what it is reckoned to cost.
//
// **The library is behind a protocol**, as the kit's is: PhotoKit cannot be
// exercised in a test without a real library and a permission, so the choosing
// and the writing are tested against a fake and the PhotoKit binding is kept
// thin enough to read in one sitting.

import CoreGraphics
import Foundation
import OSLog
import Photos
import PhotosGoRoundAgentAPI
import UniformTypeIdentifiers

#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

/// One picture as the library handed it back, with what the library says the
/// photograph itself is.
public struct LibraryPicture: @unchecked Sendable {
    public let image: CGImage
    public let originalWidth: Int
    public let originalHeight: Int

    public init(image: CGImage, originalWidth: Int, originalHeight: Int) {
        self.image = image
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
    }
}

/// What a library says of the photograph it wrote to a file: its size as Photos
/// has it, and its name and when it was taken, which is what the log reports.
public struct LibraryPictureFile: Sendable {
    public let originalWidth: Int
    public let originalHeight: Int
    /// The name of the photograph's file as it was taken, when Photos knows.
    public let name: String?
    public let taken: Date?

    public init(originalWidth: Int, originalHeight: Int, name: String? = nil, taken: Date? = nil) {
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
        self.name = name
        self.taken = taken
    }
}

/// Which of a source's pictures is wanted.
public enum PicturePick: Sendable {
    /// One chosen at random, each with the same chance.
    case any
    /// The first the library lists.
    case first
}

/// Where Photos may look for a photograph's file. `PhotosSource`.
public enum PhotoReach: Sendable, Equatable {
    /// On this device alone. A photograph kept only in iCloud is not handed
    /// over; its download is started, and nobody waits for it.
    case thisDevice
    /// In iCloud too, and waited for.
    case iCloudToo
}

/// The photograph is kept only in iCloud, and was asked for from this device
/// alone. Its download has been started.
public struct PhotoNotOnDevice: Error, Equatable {
    public init() {}
}

public protocol PhotoLibraryPictures: Sendable {
    /// A picture from the collection, at the largest size that fits `box`, in
    /// pixels. Nil when the collection is gone or has no pictures, and an
    /// error when the library will not answer at all.
    func picture(
        inCollection identifier: String, fitting box: CGSize, pick: PicturePick
    ) throws -> LibraryPicture?

    /// How many pictures the collection holds, without fetching any of them.
    /// None when the collection is gone, and an error when the library will
    /// not answer at all.
    func count(inCollection identifier: String) throws -> Int

    /// A picture from the photographs the person picked for the app, when its
    /// access is limited to a selection. Nil when nothing is picked, and nil
    /// with any other access: this is never a way to the whole library.
    func selectedPicture(fitting box: CGSize, pick: PicturePick) throws -> LibraryPicture?

    /// How many photographs the person picked for the app. None with access
    /// that is not limited to a selection.
    func selectedCount() throws -> Int

    /// A photograph from the collection, written to `file` as it is kept, for
    /// it to be shrunk from there. Nil when the collection is gone or empty.
    func pictureFile(
        inCollection identifier: String, fitting box: CGSize, pick: PicturePick, to file: URL
    ) throws -> LibraryPictureFile?

    /// The same, from the photographs the person picked for the app.
    func selectedPictureFile(fitting box: CGSize, pick: PicturePick, to file: URL) throws -> LibraryPictureFile?

    /// A photograph from the collection, looked for only as far as `reach`.
    /// Throws `PhotoNotOnDevice` for one only in iCloud asked for from this
    /// device alone.
    func pictureFile(
        inCollection identifier: String, fitting box: CGSize, pick: PicturePick, to file: URL, reach: PhotoReach
    ) throws -> LibraryPictureFile?

    /// The same, from the photographs the person picked for the app.
    func selectedPictureFile(
        fitting box: CGSize, pick: PicturePick, to file: URL, reach: PhotoReach
    ) throws -> LibraryPictureFile?
}

/// A library that hands back pictures and not files, as a test's does, writes
/// the picture it hands back, and keeps every one on this device.
extension PhotoLibraryPictures {
    public func pictureFile(
        inCollection identifier: String, fitting box: CGSize, pick: PicturePick, to file: URL, reach: PhotoReach
    ) throws -> LibraryPictureFile? {
        try pictureFile(inCollection: identifier, fitting: box, pick: pick, to: file)
    }

    public func selectedPictureFile(
        fitting box: CGSize, pick: PicturePick, to file: URL, reach: PhotoReach
    ) throws -> LibraryPictureFile? {
        try selectedPictureFile(fitting: box, pick: pick, to: file)
    }

    public func pictureFile(
        inCollection identifier: String, fitting box: CGSize, pick: PicturePick, to file: URL
    ) throws -> LibraryPictureFile? {
        try written(picture(inCollection: identifier, fitting: box, pick: pick), to: file)
    }

    public func selectedPictureFile(fitting box: CGSize, pick: PicturePick, to file: URL) throws -> LibraryPictureFile? {
        try written(selectedPicture(fitting: box, pick: pick), to: file)
    }

    fileprivate func written(_ picture: LibraryPicture?, to file: URL) throws -> LibraryPictureFile? {
        guard let picture else { return nil }
        try PictureResizer().write(
            picture.image, originalType: "photos", originalWidth: picture.originalWidth,
            originalHeight: picture.originalHeight, to: file)
        return LibraryPictureFile(originalWidth: picture.originalWidth, originalHeight: picture.originalHeight)
    }
}

/// A photograph from Photos written to a file beside `destination`, shrunk from
/// it as a file is, and the file let go.
///
/// **As a folder does with a file, a few are tried.** One refused for being
/// too large for what is left just now is passed over for another, as is one
/// that is not a picture. One no widget could ever shrink is passed over too,
/// and `skipped` is told, for the app's note.
///
/// **Refused for now every time, it is refused for now**: whoever asked keeps
/// the picture showing and asks again next time.
///
/// **A photograph on this device first.** One kept only in iCloud took 30 to
/// 65 seconds to come down on Syd's phone, 2026-10-25, and one on the device a
/// tenth of a second. So each is asked for from this device alone, and one
/// only in iCloud is passed over, its download started for a later wake,
/// without using up an attempt. After `inICloudAtMost` of those, the next is
/// asked for from iCloud too, and waited for. Syd, the same day, of passing
/// over and of waiting longer: "do BOTH". A picture wanted at once is waited
/// for straight away.
private func photograph(
    attempts: Int, fitting box: CGSize, to destination: URL, resizer: PictureResizer,
    skipped: (@Sendable () -> Void)?, waitsAtOnce: Bool,
    fetch: (URL, PhotoReach) throws -> LibraryPictureFile?
) throws -> PictureResizer.Resize? {
    let inICloudAtMost = 4
    var forNow: PictureResizer.Failure?
    var inICloud = 0
    var attempt = 0
    while attempt < max(attempts, 1) {
        // Hidden, so that a cache listing its pictures never takes it for one.
        let file = destination.deletingLastPathComponent().appending(path: ".photograph-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: file) }
        let reach: PhotoReach = waitsAtOnce || inICloud >= inICloudAtMost ? .iCloudToo : .thisDevice
        let fetched: LibraryPictureFile?
        do {
            fetched = try fetch(file, reach)
        } catch is PhotoNotOnDevice {
            inICloud += 1
            continue
        }
        guard let photograph = fetched else { return nil }
        attempt += 1
        do {
            let resize = try resizer.write(
                file, fitting: box, to: destination, named: photograph.name,
                taken: photograph.taken.map { PictureResizer.taken($0) })
            return PictureResizer.Resize(
                originalType: "photos", originalWidth: photograph.originalWidth,
                originalHeight: photograph.originalHeight, originalBytes: resize.originalBytes,
                writtenWidth: resize.writtenWidth, writtenHeight: resize.writtenHeight,
                writtenBytes: resize.writtenBytes)
        } catch PictureResizer.Failure.tooLarge(let file, let ever) {
            if ever { skipped?() } else { forNow = .tooLarge(file, ever: false) }
        } catch PictureResizer.Failure.notAPicture {
            continue
        }
    }
    if let forNow { throw forNow }
    return nil
}

/// The photographs a person picked for the app, when they gave it limited
/// access. `Plans/PGR Widgets - iOS.md`, *Limited access*.
public struct SelectedPhotosSource: CountedSource {
    private let library: any PhotoLibraryPictures
    private let pick: PicturePick
    private let resizer: PictureResizer
    private let skipped: (@Sendable () -> Void)?

    /// - Parameters:
    ///   - resizer: What shrinks the photograph, and says whether there is
    ///     room to. A test hands over one with a memory limit of its own.
    ///   - skipped: Told when a photograph is passed over because no widget
    ///     could shrink it.
    public init(
        library: any PhotoLibraryPictures = SystemPhotoLibraryPictures(), pick: PicturePick = .any,
        resizer: PictureResizer = PictureResizer(), skipped: (@Sendable () -> Void)? = nil
    ) {
        self.library = library
        self.pick = pick
        self.resizer = resizer
        self.skipped = skipped
    }

    /// A collection's is `photos|` and its identifier, which this cannot be.
    public var countName: String { "photos-selected" }

    public func pictureCount() throws -> Int {
        try library.selectedCount()
    }

    public func writePicture(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize? {
        try photograph(
            attempts: pick == .first ? 1 : 3, fitting: box, to: destination, resizer: resizer, skipped: skipped,
            waitsAtOnce: pick == .first
        ) { file, reach in
            try library.selectedPictureFile(fitting: box, pick: pick, to: file, reach: reach)
        }
    }
}

/// One Photos collection. Each is a source of its own, so that an album of one
/// photograph is weighed as one photograph. `SeveralSources`.
public struct PhotosSource: CountedSource {
    private let collection: String
    private let library: any PhotoLibraryPictures
    private let pick: PicturePick
    private let resizer: PictureResizer
    private let skipped: (@Sendable () -> Void)?

    /// - Parameters:
    ///   - collection: A Photos collection by its local identifier, which is
    ///     what a Photos source's locator is in the app's preferences.
    ///   - pick: Which of its pictures it writes: any, for a widget's turn, or
    ///     the first, for a picture that is wanted at once.
    ///   - resizer: What shrinks the photograph, and says whether there is
    ///     room to. A test hands over one with a memory limit of its own.
    ///   - skipped: Told when a photograph is passed over because no widget
    ///     could shrink it.
    public init(
        collection: String, library: any PhotoLibraryPictures = SystemPhotoLibraryPictures(),
        pick: PicturePick = .any, resizer: PictureResizer = PictureResizer(),
        skipped: (@Sendable () -> Void)? = nil
    ) {
        self.collection = collection
        self.library = library
        self.pick = pick
        self.resizer = resizer
        self.skipped = skipped
    }

    public var countName: String { "photos|\(collection)" }

    public func pictureCount() throws -> Int {
        try library.count(inCollection: collection)
    }

    public func writePicture(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize? {
        try photograph(
            attempts: pick == .first ? 1 : 3, fitting: box, to: destination, resizer: resizer, skipped: skipped,
            waitsAtOnce: pick == .first
        ) { file, reach in
            try library.pictureFile(inCollection: collection, fitting: box, pick: pick, to: file, reach: reach)
        }
    }
}

/// The real library, through PhotoKit.
public struct SystemPhotoLibraryPictures: PhotoLibraryPictures {
    /// Photos has not said yes. The status is in the message because the
    /// widget shows this on its face, and "not determined" and "denied" call
    /// for different things from the person looking at it.
    public struct Refused: Error, LocalizedError, Equatable {
        public let status: String
        public var errorDescription: String? { "Photos access is \(status)." }
    }

    /// How long Photos has to hand over one picture.
    private let limit: Duration

    public init(limit: Duration = TimeLimit.forAPicture) {
        self.limit = limit
    }

    public func count(inCollection identifier: String) throws -> Int {
        try pictures(inCollection: identifier)?.count ?? 0
    }

    public func selectedCount() throws -> Int {
        try selected()?.count ?? 0
    }

    public func selectedPicture(fitting box: CGSize, pick: PicturePick) throws -> LibraryPicture? {
        guard let assets = try selected(), assets.count > 0 else { return nil }
        return try picture(of: assets.object(at: Self.index(pick, among: assets.count)), fitting: box)
    }

    private static func index(_ pick: PicturePick, among count: Int) -> Int {
        switch pick {
        case .any: Int.random(in: 0..<count)
        case .first: 0
        }
    }

    /// The photographs the person picked for the app. Nil unless access is
    /// limited to a selection: with limited access "every photograph" is the
    /// selection, and with full access it is the whole library, which is
    /// never shown.
    private func selected() throws -> PHFetchResult<PHAsset>? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw Refused(status: Self.name(of: status))
        }
        guard status == .limited else { return nil }
        return PHAsset.fetchAssets(with: Self.imagesOnly)
    }

    private static var imagesOnly: PHFetchOptions {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        return options
    }

    /// The collection's photographs, none of them fetched yet. Nil when the
    /// collection is gone.
    private func pictures(inCollection identifier: String) throws -> PHFetchResult<PHAsset>? {
        // Reading the status never prompts. Asking is the app's to do: the
        // privacy system does not show a prompt on a widget's behalf.
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw Refused(status: Self.name(of: status))
        }
        // With a selection, the selection is the source. A smart album can
        // still be fetched then, holding the picked photographs that are in
        // it, and those would be counted twice.
        guard status == .authorized else { return nil }
        guard
            let collection = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [identifier], options: nil
            ).firstObject
        else { return nil }
        return PHAsset.fetchAssets(in: collection, options: Self.imagesOnly)
    }

    public func picture(
        inCollection identifier: String, fitting box: CGSize, pick: PicturePick
    ) throws -> LibraryPicture? {
        guard let assets = try pictures(inCollection: identifier), assets.count > 0 else { return nil }
        return try picture(of: assets.object(at: Self.index(pick, among: assets.count)), fitting: box)
    }

    /// `asking Photos for a 3000x2002 photograph at 1014x1062`.
    static func asking(width: Int, height: Int, fitting box: CGSize) -> String {
        "asking Photos for a \(width)x\(height) photograph at \(Int(box.width))x\(Int(box.height))"
    }

    public func pictureFile(
        inCollection identifier: String, fitting box: CGSize, pick: PicturePick, to file: URL
    ) throws -> LibraryPictureFile? {
        try pictureFile(inCollection: identifier, fitting: box, pick: pick, to: file, reach: .iCloudToo)
    }

    public func selectedPictureFile(fitting box: CGSize, pick: PicturePick, to file: URL) throws -> LibraryPictureFile? {
        try selectedPictureFile(fitting: box, pick: pick, to: file, reach: .iCloudToo)
    }

    public func pictureFile(
        inCollection identifier: String, fitting box: CGSize, pick: PicturePick, to file: URL, reach: PhotoReach
    ) throws -> LibraryPictureFile? {
        guard let assets = try pictures(inCollection: identifier), assets.count > 0 else { return nil }
        return try self.file(
            of: assets.object(at: Self.index(pick, among: assets.count)), fitting: box, to: file, reach: reach)
    }

    public func selectedPictureFile(
        fitting box: CGSize, pick: PicturePick, to file: URL, reach: PhotoReach
    ) throws -> LibraryPictureFile? {
        guard let assets = try selected(), assets.count > 0 else { return nil }
        return try self.file(
            of: assets.object(at: Self.index(pick, among: assets.count)), fitting: box, to: file, reach: reach)
    }

    /// The photograph's file as Photos keeps it, written to `file`: the edited
    /// one when it has been edited, which is what Photos shows, and the
    /// original when not. From iCloud when it is not on this device and
    /// `reach` allows; when it does not, its download is started and
    /// `PhotoNotOnDevice` thrown.
    ///
    /// **A RAW photograph is drawn by Photos instead**, at the size wanted,
    /// and weighed first by what that is reckoned to cost. `ImageIO` is not
    /// trusted to shrink a RAW file in bands; nothing has measured it. It is
    /// waited for from iCloud whatever `reach` says.
    private func file(
        of asset: PHAsset, fitting box: CGSize, to file: URL, reach: PhotoReach
    ) throws -> LibraryPictureFile? {
        guard let resource = Self.resource(of: asset) else { return nil }
        if UTType(resource.uniformTypeIdentifier)?.conforms(to: .rawImage) == true {
            try PictureResizer().refuseFromPhotosIfTooLarge(fitting: box)
            return try written(picture(of: asset, fitting: box), to: file)
        }
        let name = resource.filename
        let asking = Self.askingForFile(
            width: asset.pixelWidth, height: asset.pixelHeight, type: resource.uniformTypeIdentifier,
            named: name, taken: asset.creationDate.map { PictureResizer.taken($0) },
            edited: resource.type == .fullSizePhoto)
        Log.widget.notice(
            """
            \(Log.widgetsTag, privacy: .public) \(asking, privacy: .public)\
            \(reach == .thisDevice ? ", from this device" : ", from iCloud too", privacy: .public)\
            \(Footprint.now().map { ", " + Footprint.againstLimit($0) } ?? "", privacy: .public)
            """)
        do {
            // Looked up again on the thread that writes it, which a resource
            // cannot be handed to.
            try TimeLimit.run(within: limit) {
                guard let resource = Self.resource(of: asset) else { throw CocoaError(.fileNoSuchFile) }
                try Self.write(resource, to: file, fromICloud: reach == .iCloudToo)
            }
        } catch let error as PHPhotosError where error.code == .networkAccessRequired && reach == .thisDevice {
            Self.startDownload(of: asset, named: name ?? "\(asset.pixelWidth)x\(asset.pixelHeight)")
            throw PhotoNotOnDevice()
        } catch let late as TimedOut {
            Log.widget.error(
                """
                \(Log.widgetsTag, privacy: .public) Photos did not answer in time for the file of a \
                \(asset.pixelWidth)x\(asset.pixelHeight) photograph: \
                \(late.localizedDescription, privacy: .public)
                """)
            throw late
        }
        return LibraryPictureFile(
            originalWidth: asset.pixelWidth, originalHeight: asset.pixelHeight, name: name,
            taken: asset.creationDate)
    }

    /// The edited photograph when there is one, and the original when not.
    private static func resource(of asset: PHAsset) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.first { $0.type == .fullSizePhoto } ?? resources.first { $0.type == .photo }
    }

    /// `asking Photos for the file of “IMG_1234.HEIC”, taken 2024-09-21 18:03,
    /// a 4032x3024 photograph, public.heic`.
    ///
    /// Named, and when it was taken, since 2026-10-14: see
    /// `PictureResizer.starting`.
    ///
    /// **And whether it is Photos' edited version or the original**, since
    /// 2026-10-14: the edited version is a file Photos wrote. `Plans/PGR
    /// Widgets - iOS.md`, *A scan at full colour*.
    static func askingForFile(
        width: Int, height: Int, type: String, named name: String? = nil, taken: String? = nil,
        edited: Bool? = nil
    ) -> String {
        let version = edited.map { $0 ? ", the edited version" : ", the original" } ?? ""
        return "asking Photos for the file of \(PictureResizer.naming(name, taken))a \(width)x\(height) photograph, "
            + "\(type)\(version)"
    }

    /// Starts bringing the photograph down from iCloud, for a later wake, and
    /// waits for none of it: it was 30 to 65 seconds on Syd's phone,
    /// 2026-10-25. A download given up on that night went on and finished,
    /// and the photograph was on the device from then on. What comes is let
    /// go a piece at a time; the line it ends with says how long it took.
    private static func startDownload(of asset: PHAsset, named name: String) {
        guard let resource = resource(of: asset) else { return }
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        let started = Date.now
        Log.widget.notice(
            "\(Log.widgetsTag, privacy: .public) “\(name, privacy: .public)” is only in iCloud; bringing it down")
        PHAssetResourceManager.default().requestData(for: resource, options: options) { _ in } completionHandler: {
            error in
            let after = Int(Date.now.timeIntervalSince(started).rounded())
            if let error {
                Log.widget.error(
                    """
                    \(Log.widgetsTag, privacy: .public) “\(name, privacy: .public)” did not come down from \
                    iCloud, after \(after) seconds: \(error.localizedDescription, privacy: .public)
                    """)
            } else {
                Log.widget.notice(
                    """
                    \(Log.widgetsTag, privacy: .public) “\(name, privacy: .public)” came down from iCloud, \
                    after \(after) seconds
                    """)
            }
        }
    }

    /// Writes the resource to `file` a little at a time, so that it is never
    /// in memory whole. On a thread that may block: `TimeLimit` runs this on
    /// one. Without `fromICloud`, one kept only in iCloud fails with
    /// `networkAccessRequired`.
    private static func write(_ resource: PHAssetResource, to file: URL, fromICloud: Bool) throws {
        let options = PHAssetResourceRequestOptions()
        // From iCloud when the photograph is not on this device. Syd,
        // 2026-10-08: "I do want the pics downloaded in Photos."
        options.isNetworkAccessAllowed = fromICloud
        let done = DispatchSemaphore(value: 0)
        let outcome = Written()
        PHAssetResourceManager.default().writeData(for: resource, toFile: file, options: options) { error in
            outcome.error = error
            done.signal()
        }
        done.wait()
        if let error = outcome.error { throw error }
    }

    /// What writing a resource came to. Set once, before the wait ends.
    private final class Written: @unchecked Sendable {
        var error: (any Error)?
    }

    /// The request, with a time limit on it: Photos can leave one unanswered
    /// for good. `TimeLimit`.
    private func picture(of asset: PHAsset, fitting box: CGSize) throws -> LibraryPicture? {
        // Said before it starts, with the memory: a fetch's own line is
        // written when it ends, and in a simulator, 2026-10-13, an extension
        // went from 15.9 MB to 26.2 MB somewhere before the first of these
        // ended.
        let asking = Self.asking(width: asset.pixelWidth, height: asset.pixelHeight, fitting: box)
        Log.widget.notice(
            """
            \(Log.widgetsTag, privacy: .public) \(asking, privacy: .public)\
            \(Footprint.now().map { ", " + Footprint.againstLimit($0) } ?? "", privacy: .public)
            """)
        do {
            return try TimeLimit.run(within: limit) { Self.request(asset, fitting: box) }
        } catch let late as TimedOut {
            Log.widget.error(
                """
                \(Log.widgetsTag, privacy: .public) Photos did not answer in time for a \
                \(asset.pixelWidth)x\(asset.pixelHeight) photograph \
                asked for at \(Int(box.width))x\(Int(box.height)): \
                \(late.localizedDescription, privacy: .public)
                """)
            throw late
        }
    }

    private static func request(_ asset: PHAsset, fitting box: CGSize) -> LibraryPicture? {
        let options = PHImageRequestOptions()
        // On a thread that may block: `TimeLimit` runs this on one.
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        // From iCloud when the photograph is not on this device. Syd,
        // 2026-10-08: "I do want the pics downloaded in Photos." What a
        // download costs a widget's wake, in time, is not yet measured.
        options.isNetworkAccessAllowed = true

        let found = Found()
        PHImageManager.default().requestImage(
            for: asset, targetSize: box, contentMode: .aspectFit, options: options
        ) { image, info in
            found.image = image.flatMap(Self.cgImage)
            if found.image == nil {
                found.why = image == nil ? Self.reason(info) : "it gave a picture that could not be read"
            }
        }
        guard let image = found.image else {
            // Photos lists the photograph and will not hand it over. Without
            // this line all that shows is "No Photos found", as on the iPhone
            // Duo simulator on 2026-10-10.
            Log.widget.error(
                """
                \(Log.widgetsTag, privacy: .public) Photos gave no picture for a \
                \(asset.pixelWidth)x\(asset.pixelHeight) photograph \
                asked for at \(Int(box.width))x\(Int(box.height)): \
                \(found.why ?? "no reason given", privacy: .public)
                """)
            return nil
        }
        return LibraryPicture(image: image, originalWidth: asset.pixelWidth, originalHeight: asset.pixelHeight)
    }

    /// What Photos says about a request that came back with no picture.
    private static func reason(_ info: [AnyHashable: Any]?) -> String {
        var parts: [String] = []
        if let error = info?[PHImageErrorKey] as? any Error {
            parts.append(String(describing: error))
        }
        if info?[PHImageCancelledKey] as? Bool == true {
            parts.append("the request was cancelled")
        }
        if info?[PHImageResultIsInCloudKey] as? Bool == true {
            parts.append("the photograph is in iCloud")
        }
        return parts.isEmpty ? "no reason given" : parts.joined(separator: "; ")
    }

    /// The synchronous request calls back before it returns, on this thread.
    private final class Found: @unchecked Sendable {
        var image: CGImage?
        var why: String?
    }

    #if canImport(AppKit)
        private static func cgImage(_ image: NSImage) -> CGImage? {
            image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
    #elseif canImport(UIKit)
        private static func cgImage(_ image: UIImage) -> CGImage? { image.cgImage }
    #endif

    private static func name(of status: PHAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "not determined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .authorized: "authorized"
        case .limited: "limited"
        @unknown default: "unknown (\(status.rawValue))"
        }
    }
}
