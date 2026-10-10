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

public protocol PhotoLibraryPictures: Sendable {
    /// A picture chosen at random from the collection, at the largest size
    /// that fits `box`, in pixels. Nil when the collection is gone or has no
    /// pictures, and an error when the library will not answer at all.
    func picture(inCollection identifier: String, fitting box: CGSize) throws -> LibraryPicture?

    /// How many pictures the collection holds, without fetching any of them.
    /// None when the collection is gone, and an error when the library will
    /// not answer at all.
    func count(inCollection identifier: String) throws -> Int
}

/// One Photos collection. Each is a source of its own, so that an album of one
/// photograph is weighed as one photograph. `SeveralSources`.
public struct PhotosSource: CountedSource {
    private let collection: String
    private let library: any PhotoLibraryPictures

    /// - Parameter collection: A Photos collection by its local identifier,
    ///   which is what a Photos source's locator is in the app's preferences.
    public init(collection: String, library: any PhotoLibraryPictures = SystemPhotoLibraryPictures()) {
        self.collection = collection
        self.library = library
    }

    public var countName: String { "photos|\(collection)" }

    public func pictureCount() throws -> Int {
        try library.count(inCollection: collection)
    }

    public func writePicture(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize? {
        guard let picture = try library.picture(inCollection: collection, fitting: box) else { return nil }
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

    /// The collection's photographs, none of them fetched yet. Nil when the
    /// collection is gone.
    private func pictures(inCollection identifier: String) throws -> PHFetchResult<PHAsset>? {
        // Reading the status never prompts. Asking is the app's to do: the
        // privacy system does not show a prompt on a widget's behalf.
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw Refused(status: Self.name(of: status))
        }
        guard
            let collection = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [identifier], options: nil
            ).firstObject
        else { return nil }
        let imagesOnly = PHFetchOptions()
        imagesOnly.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        return PHAsset.fetchAssets(in: collection, options: imagesOnly)
    }

    public func picture(inCollection identifier: String, fitting box: CGSize) throws -> LibraryPicture? {
        guard let assets = try pictures(inCollection: identifier), assets.count > 0 else { return nil }
        let asset = assets.object(at: Int.random(in: 0..<assets.count))

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
        ) { image, _ in
            found.image = image.flatMap(Self.cgImage)
        }
        guard let image = found.image else { return nil }
        return LibraryPicture(image: image, originalWidth: asset.pixelWidth, originalHeight: asset.pixelHeight)
    }

    /// The synchronous request calls back before it returns, on this thread.
    private final class Found: @unchecked Sendable {
        var image: CGImage?
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
