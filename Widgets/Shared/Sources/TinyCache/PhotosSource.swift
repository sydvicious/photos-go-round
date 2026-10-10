// The Photos library as a source. `Plans/Photos-Go-Round Widgets.md`, *Next:
// the app's sources, then Photos*.
//
// **Photos is asked for the picture at the size wanted**, so nothing here ever
// holds an original. That is the difference from a folder, where shrinking one
// 300-megapixel scan cost the widget extension about 100 MB, and it is why the
// Photos library is the source that fits under an iPhone's ceiling.
//
// **The library is behind a protocol**, as the kit's is: PhotoKit cannot be
// exercised in a test without a real library and a permission, so the choosing
// and the writing are tested against a fake and the PhotoKit binding is kept
// thin enough to read in one sitting.

import CoreGraphics
import Foundation
import OSLog
import Photos

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

/// Which of a source's pictures is wanted.
public enum PicturePick: Sendable {
    /// One chosen at random, each with the same chance.
    case any
    /// The first the library lists.
    case first
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
}

/// The photographs a person picked for the app, when they gave it limited
/// access. `Plans/PGR Widgets - iOS.md`, *Limited access*.
public struct SelectedPhotosSource: CountedSource {
    private let library: any PhotoLibraryPictures
    private let pick: PicturePick

    public init(library: any PhotoLibraryPictures = SystemPhotoLibraryPictures(), pick: PicturePick = .any) {
        self.library = library
        self.pick = pick
    }

    /// A collection's is `photos|` and its identifier, which this cannot be.
    public var countName: String { "photos-selected" }

    public func pictureCount() throws -> Int {
        try library.selectedCount()
    }

    public func writePicture(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize? {
        guard let picture = try library.selectedPicture(fitting: box, pick: pick) else { return nil }
        return try PictureResizer().write(
            picture.image, originalType: "photos",
            originalWidth: picture.originalWidth, originalHeight: picture.originalHeight,
            to: destination)
    }
}

/// One Photos collection. Each is a source of its own, so that an album of one
/// photograph is weighed as one photograph. `SeveralSources`.
public struct PhotosSource: CountedSource {
    private let collection: String
    private let library: any PhotoLibraryPictures
    private let pick: PicturePick

    /// - Parameters:
    ///   - collection: A Photos collection by its local identifier, which is
    ///     what a Photos source's locator is in the app's preferences.
    ///   - pick: Which of its pictures it writes: any, for a widget's turn, or
    ///     the first, for a picture that is wanted at once.
    public init(
        collection: String, library: any PhotoLibraryPictures = SystemPhotoLibraryPictures(),
        pick: PicturePick = .any
    ) {
        self.collection = collection
        self.library = library
        self.pick = pick
    }

    public var countName: String { "photos|\(collection)" }

    public func pictureCount() throws -> Int {
        try library.count(inCollection: collection)
    }

    public func writePicture(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize? {
        guard let picture = try library.picture(inCollection: collection, fitting: box, pick: pick) else {
            return nil
        }
        return try PictureResizer().write(
            picture.image, originalType: "photos",
            originalWidth: picture.originalWidth, originalHeight: picture.originalHeight,
            to: destination)
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

    public init() {}

    public func count(inCollection identifier: String) throws -> Int {
        try pictures(inCollection: identifier)?.count ?? 0
    }

    public func selectedCount() throws -> Int {
        try selected()?.count ?? 0
    }

    public func selectedPicture(fitting box: CGSize, pick: PicturePick) throws -> LibraryPicture? {
        guard let assets = try selected(), assets.count > 0 else { return nil }
        return Self.picture(of: assets.object(at: Self.index(pick, among: assets.count)), fitting: box)
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
        return Self.picture(of: assets.object(at: Self.index(pick, among: assets.count)), fitting: box)
    }

    private static func picture(of asset: PHAsset, fitting box: CGSize) -> LibraryPicture? {
        let options = PHImageRequestOptions()
        // The caller is a widget building a timeline, on a thread it may block.
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
            Self.log.error(
                """
                \(Self.logTag, privacy: .public) Photos gave no picture for a \
                \(asset.pixelWidth)x\(asset.pixelHeight) photograph \
                asked for at \(Int(box.width))x\(Int(box.height)): \
                \(found.why ?? "no reason given", privacy: .public)
                """)
            return nil
        }
        return LibraryPicture(image: image, originalWidth: asset.pixelWidth, originalHeight: asset.pixelHeight)
    }

    private static let log = Logger(subsystem: "com.sydpolk.photosgoround", category: "widget")

    /// At the start of each line logged here, so the lines can be found by
    /// typing it into a console's filter. Syd, 2026-10-10.
    public static let logTag = "[PGR-Widgets]"

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
