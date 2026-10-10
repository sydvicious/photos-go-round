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

    /// A picture chosen at random from the photographs the person picked for
    /// the app, when its access is limited to a selection. Nil when nothing is
    /// picked, and nil with any other access: this is never a way to the whole
    /// library.
    func selectedPicture(fitting box: CGSize) throws -> LibraryPicture?

    /// How many photographs the person picked for the app. None with access
    /// that is not limited to a selection.
    func selectedCount() throws -> Int
}

/// The photographs a person picked for the app, when they gave it limited
/// access. `Plans/PGR Widgets - iOS.md`, *Limited access*.
public struct SelectedPhotosSource: CountedSource {
    private let library: any PhotoLibraryPictures

    public init(library: any PhotoLibraryPictures = SystemPhotoLibraryPictures()) {
        self.library = library
    }

    /// A collection's is `photos|` and its identifier, which this cannot be.
    public var countName: String { "photos-selected" }

    public func pictureCount() throws -> Int {
        try library.selectedCount()
    }

    public func writePicture(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize? {
        guard let picture = try library.selectedPicture(fitting: box) else { return nil }
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

    public func selectedCount() throws -> Int {
        try selected()?.count ?? 0
    }

    public func selectedPicture(fitting box: CGSize) throws -> LibraryPicture? {
        guard let assets = try selected(), assets.count > 0 else { return nil }
        return Self.picture(of: assets.object(at: Int.random(in: 0..<assets.count)), fitting: box)
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

    public func picture(inCollection identifier: String, fitting box: CGSize) throws -> LibraryPicture? {
        guard let assets = try pictures(inCollection: identifier), assets.count > 0 else { return nil }
        return Self.picture(of: assets.object(at: Int.random(in: 0..<assets.count)), fitting: box)
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
