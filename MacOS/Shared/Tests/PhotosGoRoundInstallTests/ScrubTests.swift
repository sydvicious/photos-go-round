import Foundation
import Testing

@testable import PhotosGoRoundAgentAPI
@testable import PhotosGoRoundInstall

/// Which of a build's data a scrub would delete, and only that build's.
///
/// **The failure this guards against is deleting the wrong library.** Every
/// name is spelled from the variant, so a scrub of one build must never name
/// another build's container, cache or domain.
@Suite("What scrubbing would delete")
struct ScrubTests {

    private let home = URL(filePath: "/tmp/pgr-test/home")

    private func path(_ relative: String) -> String {
        home.appending(path: relative).path(percentEncoded: false)
    }

    @Test("A build's library is its current name and the retired .dev one")
    func libraries() {
        #expect(Scrub.libraries(for: .debug) == [
            "com.sydpolk.photosgoround.debug", "com.sydpolk.photosgoround.debug.dev",
        ])
        #expect(Scrub.libraries(for: .release) == [
            "com.sydpolk.photosgoround", "com.sydpolk.photosgoround.dev",
        ])
    }

    @Test("The surfaces' domains are current, .dev and .prod, for both surfaces")
    func surfaceDomains() {
        let domains = Scrub.surfaceDomains(for: .claude)
        #expect(domains.count == 6)
        #expect(domains.contains("com.sydpolk.photosgoround.claude.screensaver"))
        #expect(domains.contains("com.sydpolk.photosgoround.claude.wallpaper.prod"))
    }

    @Test("Only what is on disk is found, and every domain is still forgotten")
    func onlyWhatIsPresent() {
        let present: Set<String> = [
            path("Library/Containers/com.sydpolk.photosgoround.debug"),
            path("Library/Preferences/com.sydpolk.photosgoround.debug.wallpaper.plist"),
        ]
        let plan = Scrub.plan(
            variants: [.debug], home: home,
            fileExists: { present.contains($0.path(percentEncoded: false)) })
        #expect(Set(plan.found.map { $0.path(percentEncoded: false) }) == present)
        #expect(plan.domains.count == 2 + 6)
    }

    /// **One build's scrub names nothing of another's.**
    @Test("Scrubbing one build names nothing of the others")
    func onlyThisBuild() {
        let plan = Scrub.plan(variants: [.release], home: home, fileExists: { _ in true })
        let named = plan.domains + plan.found.map { $0.path(percentEncoded: false) }
            + plan.protected.map { $0.path(percentEncoded: false) }
        #expect(!named.contains { $0.contains(".debug") || $0.contains(".claude") })
    }

    @Test("The remembered pictures are the saver's cache and the extension's Application Support")
    func protectedPaths() {
        let paths = Scrub.protectedPaths(for: .debug, home: home).map { $0.path(percentEncoded: false) }
        #expect(paths == [
            path("Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Caches/com.sydpolk.photosgoround.saver.debug"),
            path("Library/Containers/com.sydpolk.photosgoround.wallpaper.debug.extension/Data/Library/Application Support"),
        ])
    }
}
