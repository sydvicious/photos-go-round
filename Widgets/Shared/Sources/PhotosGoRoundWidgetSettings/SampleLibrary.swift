// A Photos library made of values, for previews and for tests.

#if DEBUG
    import CoreGraphics
    import Foundation
    import ImageIO
    import PhotosGoRoundAgentAPI
    import PhotosGoRoundPhotoLibrary
    import Synchronization

    /// Pictures there are none of, for a preview or a test that draws no photograph.
    struct NoPictures: PreviewPictures {
        func next(from sources: [SourceSpec], fitting box: CGSize) throws -> URL? { nil }
        func forget() {}
    }

    /// Pictures made of colour, a different one each time, for a preview that
    /// is to show something where a photograph goes.
    final class SamplePictures: PreviewPictures {
        private let made = Mutex(0)
        private let folder = URL.temporaryDirectory.appending(path: "pgr-sample-pictures-\(UUID().uuidString)")

        private static let colours: [(CGColor, CGColor)] = [
            (CGColor(red: 0.98, green: 0.62, blue: 0.24, alpha: 1), CGColor(red: 0.80, green: 0.22, blue: 0.42, alpha: 1)),
            (CGColor(red: 0.26, green: 0.66, blue: 0.86, alpha: 1), CGColor(red: 0.16, green: 0.30, blue: 0.62, alpha: 1)),
            (CGColor(red: 0.62, green: 0.82, blue: 0.36, alpha: 1), CGColor(red: 0.12, green: 0.48, blue: 0.40, alpha: 1)),
        ]

        func next(from sources: [SourceSpec], fitting box: CGSize) throws -> URL? {
            guard !sources.isEmpty else { return nil }
            let turn = made.withLock { made in
                made += 1
                return made
            }
            // Four by three and on its side, as most photographs are, so the
            // widget's black bars show where they would.
            let width = 480
            let height = 360
            let space = CGColorSpaceCreateDeviceRGB()
            let pair = Self.colours[turn % Self.colours.count]
            guard
                let context = CGContext(
                    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                let gradient = CGGradient(
                    colorsSpace: space, colors: [pair.0, pair.1] as CFArray, locations: nil)
            else { return nil }
            context.drawLinearGradient(
                gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])

            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appending(path: "\(turn).png")
            guard let image = context.makeImage(),
                let destination = CGImageDestinationCreateWithURL(
                    file as CFURL, "public.png" as CFString, 1, nil)
            else { return nil }
            CGImageDestinationAddImage(destination, image, nil)
            return CGImageDestinationFinalize(destination) ? file : nil
        }

        func forget() {}
    }

    extension PreviewModel {
        /// A preview as an iPhone with a 393-point screen would have it.
        static func sample(_ pictures: any PreviewPictures = NoPictures()) -> PreviewModel {
            PreviewModel(
                pictures: pictures, device: .phone, screen: CGSize(width: 393, height: 852), scale: 3)
        }
    }

    /// Counts made of values, by each source's locator. A source it has no
    /// figure for cannot be counted.
    final class SampleCounts: SourceCounts {
        private let counts: Mutex<[String: Int]>

        init(_ counts: [String: Int]) {
            self.counts = Mutex(counts)
        }

        /// What each source holds from now on.
        func replace(_ counts: [String: Int]) {
            self.counts.withLock { $0 = counts }
        }

        func count(of source: SourceSpec) throws -> Int? {
            guard let count = counts.withLock({ $0[source.locator] }) else {
                throw CocoaError(.fileReadUnknown)
            }
            return count
        }
    }

    final class SampleLibrary: PhotoLibrary {
        private let access: Mutex<LibraryAuthorization>
        private let answer: LibraryAuthorization
        private let listed: Mutex<[LibraryCollection]>
        private let folders: [String: [String]]
        private let counts: Mutex<[String: Int]>
        private let failing: Bool
        private let asked = Mutex(0)

        /// `answer` is what the person says when asked; `failing` makes every
        /// read of the library throw.
        init(
            access: LibraryAuthorization, answer: LibraryAuthorization = .denied,
            collections: [LibraryCollection] = [], folders: [String: [String]] = [:],
            counts: [String: Int] = [:], failing: Bool = false
        ) {
            self.access = Mutex(access)
            self.answer = answer
            self.listed = Mutex(collections)
            self.folders = folders
            self.counts = Mutex(counts)
            self.failing = failing
        }

        /// What the person has since said in the system's settings.
        func setAccess(_ now: LibraryAuthorization) {
            access.withLock { $0 = now }
        }

        /// How many times the person was asked for access.
        var timesAsked: Int { asked.withLock { $0 } }

        var authorization: LibraryAuthorization {
            get async throws { access.withLock { $0 } }
        }

        func requestAuthorization() async -> LibraryAuthorization {
            asked.withLock { $0 += 1 }
            access.withLock { $0 = answer }
            return answer
        }

        func collections() async throws -> [LibraryCollection] {
            if failing { throw CocoaError(.fileReadUnknown) }
            return listed.withLock { $0 }
        }

        /// What the library holds from now on, as if albums had been made or
        /// deleted in Photos.
        func replaceCollections(_ collections: [LibraryCollection]) {
            listed.withLock { $0 = collections }
        }

        func folderPaths() async throws -> [String: [String]] { folders }

        func imageCount(ofCollection identifier: String) async throws -> Int? {
            counts.withLock { $0[identifier] }
        }

        /// How many photographs each collection holds from now on, as if some
        /// had been added or taken away in Photos.
        func replaceCounts(_ counts: [String: Int]) {
            self.counts.withLock { $0 = counts }
        }

        func title(ofCollection identifier: String) async throws -> String? {
            listed.withLock { $0 }.first { $0.identifier == identifier }?.title
        }

        func enumerateImages(
            inCollection identifier: String, _ body: (LibraryAsset) async throws -> Void
        ) async throws -> Bool { true }

        func assetExists(_ identifier: String) async throws -> Bool { false }

        func resources(ofAsset identifier: String) async throws -> [LibraryResource] { [] }

        func write(
            _ resource: LibraryResource, ofAsset identifier: String, to destination: URL
        ) async throws -> Int64 { throw CocoaError(.featureUnsupported) }
    }
#endif
