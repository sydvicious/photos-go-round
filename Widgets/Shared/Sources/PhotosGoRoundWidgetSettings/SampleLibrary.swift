// A Photos library made of values, for previews and for tests.

#if DEBUG
    import Foundation
    import PhotosGoRoundPhotoLibrary
    import Synchronization

    final class SampleLibrary: PhotoLibrary {
        private let access: Mutex<LibraryAuthorization>
        private let answer: LibraryAuthorization
        private let listed: [LibraryCollection]
        private let folders: [String: [String]]
        private let counts: [String: Int]
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
            self.listed = collections
            self.folders = folders
            self.counts = counts
            self.failing = failing
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
            return listed
        }

        func folderPaths() async throws -> [String: [String]] { folders }

        func imageCount(ofCollection identifier: String) async throws -> Int? { counts[identifier] }

        func title(ofCollection identifier: String) async throws -> String? {
            listed.first { $0.identifier == identifier }?.title
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
