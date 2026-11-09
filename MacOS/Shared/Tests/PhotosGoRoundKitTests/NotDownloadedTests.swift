import Foundation
import Testing

@testable import PhotosGoRoundKit
@testable import PhotosGoRoundAgentAPI

/// A photograph in iCloud Drive that is not on the Mac yet.
///
/// **The agent may not download one by reading it.** Copying an evicted file
/// fails at once with `EDEADLK`, "Resource deadlock avoided", rather than
/// blocking while iCloud brings it down. Measured 2026-11-09: four of those in
/// 0.2 seconds benched a new iCloud Drive folder, and nothing from it was shown
/// for a minute. Syd chose that day to have the folder source ask iCloud for
/// the file and call it *not here yet*, over turning on downloads for the whole
/// agent: a file on its way down is not a source that has stopped answering.
@Suite("Not downloaded yet")
struct NotDownloadedTests {

    /// What `copyItem` throws for an evicted file the process may not
    /// download: a Cocoa write error over the POSIX one.
    private static let refused = CocoaError(
        .fileWriteUnknown,
        userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(EDEADLK))])

    // MARK: - The folder source

    @Test("A copy refused for an evicted file asks iCloud for it, and says not yet")
    func refusedCopyAsksForTheFile() throws {
        let folder = TemporaryFolder(name: "pgr-evicted-src")
        let cache = TemporaryFolder(name: "pgr-evicted-dst")
        folder.write("a.png", bytes: 2048)
        let file = folder.url.appending(path: "a.png")
        let asked = Asked()

        #expect(throws: SourceProviderError.notDownloadedYet(externalID: "a.png")) {
            try FolderSourceProvider.copy(
                file, to: cache.url.appending(path: "a.png"), externalID: "a.png",
                copying: { _, _ in throw Self.refused },
                downloading: { asked.add($0) })
        }
        #expect(asked.urls == [file])
    }

    @Test("Any other copy failure is passed on, and iCloud is not asked")
    func otherFailuresPassThrough() throws {
        let folder = TemporaryFolder(name: "pgr-evicted-src")
        let cache = TemporaryFolder(name: "pgr-evicted-dst")
        folder.write("a.png", bytes: 2048)
        let asked = Asked()
        let other = CocoaError(.fileWriteNoPermission)

        #expect(throws: other) {
            try FolderSourceProvider.copy(
                folder.url.appending(path: "a.png"), to: cache.url.appending(path: "a.png"),
                externalID: "a.png",
                copying: { _, _ in throw other },
                downloading: { asked.add($0) })
        }
        #expect(asked.urls.isEmpty)
    }

    // MARK: - The cache

    @Test("A fetch of a file not downloaded yet says not yet, and keeps the photograph")
    func fetchSaysNotYet() async throws {
        let fixture = try await Fixture(photos: ["a.png"])
        let card = try #require(try fixture.firstPhoto())

        let answer = await fixture.cache.fetch(card)

        guard case .notYet = answer else { Issue.record("\(answer)"); return }
        #expect(!answer.didLand)
        #expect(fixture.pooled == 1, "a file on its way down was taken out of the library")
        #expect(fixture.provider.checks == 0, "its source was asked whether a file it has is gone")
    }

    // MARK: - The bench

    @Test("Not yet is not held against the source; a failure is")
    func notYetIsNotAFailure() {
        #expect(!PhotoCache.FetchAnswer.notYet(because: "downloading").countsAgainstSource)
        #expect(PhotoCache.FetchAnswer.failed(because: "unreadable").countsAgainstSource)
        #expect(!PhotoCache.FetchAnswer.landed.countsAgainstSource)
    }

    // MARK: - Fixture

    /// The URLs iCloud was asked for.
    final class Asked: @unchecked Sendable {
        private let lock = NSLock()
        private var asked: [URL] = []

        func add(_ url: URL) {
            lock.lock()
            asked.append(url)
            lock.unlock()
        }

        var urls: [URL] {
            lock.lock()
            defer { lock.unlock() }
            return asked
        }
    }

    private struct Fixture {
        let folder: TemporaryFolder
        let cacheRoot: TemporaryFolder
        let library: TestLibrary
        let cache: PhotoCache
        let provider: EvictedProvider

        init(photos: [String]) async throws {
            folder = TemporaryFolder(name: "pgr-evicted-src")
            cacheRoot = TemporaryFolder(name: "pgr-evicted-dst")
            for name in photos { folder.write(name, bytes: 2048) }

            library = try TestLibrary()
            let bytes = PhotoStore(root: cacheRoot.url.appending(path: "cache"))
            let access = UnsandboxedFileAccess()
            provider = EvictedProvider(wrapping: FolderSourceProvider(fileAccess: access))
            let store = SourceStore(
                database: library.database, fileAccess: access,
                providers: [provider, FileSourceProvider(fileAccess: access)], bytes: bytes)
            cache = PhotoCache(
                database: library.database, root: cacheRoot.url.appending(path: "cache"),
                sources: store, store: bytes)
            try await cache.prepare()

            let source = try store.add(kind: .folder, locator: folder.path)
            _ = await store.refresh(source)
            try library.database.run("UPDATE photo SET storage = 'materialized';")
            provider.reset()
        }

        func firstPhoto() throws -> DeckCard? {
            let first = try library.database.first(
                "SELECT id FROM photo ORDER BY id LIMIT 1;"
            ) { try $0.int64("id") }
            guard let id = first else { return nil }
            return try library.deck.card(photoID: id)
        }

        var pooled: Int {
            (try? library.database.scalarInt("SELECT COUNT(*) FROM photo;")) ?? 0
        }
    }
}

/// A folder whose every file is in iCloud and not on the Mac: enumerated as
/// usual, and never copied.
final class EvictedProvider: SourceProvider, @unchecked Sendable {
    private let inner: any SourceProvider
    private let counting: CountingProvider

    init(wrapping inner: any SourceProvider) {
        self.inner = inner
        counting = CountingProvider(wrapping: inner)
    }

    var kind: SourceKind { inner.kind }

    /// Times the source was asked whether a photograph is still there.
    var checks: Int { counting.checks }

    func reset() { counting.reset() }

    func enumerate(
        _ source: Source, into sink: (DiscoveredPhoto) async throws -> Void
    ) async throws -> SourceReachability {
        try await inner.enumerate(source, into: sink)
    }

    func existence(of externalID: String, in source: Source) async -> PhotoExistence {
        await counting.existence(of: externalID, in: source)
    }

    func availability(of source: Source) async -> SourceAvailability {
        await inner.availability(of: source)
    }

    func materialize(
        externalID: String, from source: Source, to destination: URL
    ) async throws -> MaterializedFile {
        throw SourceProviderError.notDownloadedYet(externalID: externalID)
    }
}
