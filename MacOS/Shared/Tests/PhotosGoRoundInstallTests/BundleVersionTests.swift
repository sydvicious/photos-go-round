import Foundation
import Testing

@testable import PhotosGoRoundInstall

/// Which of two builds is the later one — what a launch asks before it
/// installs over anything. `Plans/Leave Running Services Alone.md`, Phase 1.
@Suite("Comparing one build's version with another's")
struct BundleVersionTests {

    private func version(_ version: String, _ build: String) throws -> BundleVersion {
        try #require(BundleVersion(version: version, build: build))
    }

    @Test("A higher marketing version is greater, whatever the build numbers")
    func marketingVersionFirst() throws {
        #expect(try version("0.6", "1") > version("0.5", "9"))
    }

    /// Compared as text, 0.10 would sort below 0.9.
    @Test("Components compare as numbers, so 0.10 is above 0.9")
    func componentsAreNumbers() throws {
        #expect(try version("0.10", "1") > version("0.9", "1"))
    }

    @Test("At one marketing version the build number decides")
    func buildNumberSecond() throws {
        #expect(try version("0.5", "3") > version("0.5", "2"))
        #expect(try version("0.5", "10") > version("0.5", "9"))
    }

    @Test("The same version and build are equal")
    func sameIsEqual() throws {
        #expect(try version("0.5", "2") == version("0.5", "2"))
        #expect(try !(version("0.5", "2") < version("0.5", "2")))
    }

    @Test("A missing component counts as zero")
    func missingComponentIsZero() throws {
        #expect(try version("0.5", "2") == version("0.5.0", "2"))
        #expect(try version("0.5", "2") < version("0.5.1", "1"))
    }

    @Test(
        "A version or build that is missing, empty or not numbers is unreadable",
        arguments: [
            (nil, "2"), ("0.5", nil), ("", "2"), ("0.5", ""), ("0.5b", "2"), ("0.5", "two"),
            ("0..5", "2"), ("-1", "2"),
        ] as [(String?, String?)])
    func unreadable(_ version: String?, _ build: String?) {
        #expect(BundleVersion(version: version, build: build) == nil)
    }

    private func infoPlist(_ values: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0)
    }

    @Test("Both numbers are read from an Info.plist")
    func readFromInfoPlist() throws {
        let data = try infoPlist(["CFBundleShortVersionString": "0.5", "CFBundleVersion": "2"])
        #expect(try BundleVersion(infoPlist: data) == version("0.5", "2"))
    }

    @Test("An Info.plist without both numbers, or that is not a plist, is unreadable")
    func unreadableInfoPlist() throws {
        #expect(BundleVersion(infoPlist: try infoPlist(["CFBundleVersion": "2"])) == nil)
        #expect(BundleVersion(infoPlist: try infoPlist(["CFBundleShortVersionString": "0.5"])) == nil)
        #expect(BundleVersion(infoPlist: Data("not a plist".utf8)) == nil)
    }

    /// The log line and the About box agree on how a build is written.
    @Test("It is written as the version, then the build in brackets")
    func description() throws {
        #expect(try version("0.5", "2").description == "0.5 (2)")
    }

    // MARK: - The wallpaper's record

    /// `pkd` keeps no version for a registration, so the install writes down
    /// which one it registered. Phase 2.
    @Test("A registered wallpaper's version is recorded, read back, and withdrawn")
    func wallpaperRecord() throws {
        let name = scratchSuiteName("wallpaper-record")
        defer { discardScratchSuite(name) }
        let defaults = try #require(UserDefaults(suiteName: name))

        #expect(WallpaperInstall.recordedVersion(in: defaults) == nil)

        WallpaperInstall.record(try version("0.5", "2"), in: defaults)
        #expect(try WallpaperInstall.recordedVersion(in: defaults) == version("0.5", "2"))

        WallpaperInstall.record(nil, in: defaults)
        #expect(WallpaperInstall.recordedVersion(in: defaults) == nil)
    }

    @Test("A record somebody wrote that is not numbers reads as none")
    func wallpaperRecordMalformed() throws {
        let name = scratchSuiteName("wallpaper-record-malformed")
        defer { discardScratchSuite(name) }
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.set("latest", forKey: WallpaperInstall.recordedVersionKey)
        defaults.set("2", forKey: WallpaperInstall.recordedBuildKey)

        #expect(WallpaperInstall.recordedVersion(in: defaults) == nil)
    }
}
