import Foundation
import Testing

@testable import PhotosGoRoundInstall

/// Whether what the app carries is already installed — the question a launch
/// asks before installing anything.
///
/// **By version number, since 2026-10-08.** Equal or greater is left alone;
/// lesser, missing or unreadable is installed. `Plans/Leave Running Services
/// Alone.md`.
///
/// Every fact about the Mac is answered by the test, so nothing here looks at
/// launchd, `pkd` or a bundle on disk.
@Suite("Whether what the app carries is already installed")
struct StandingTests {

    /// What the app in these tests carries, in all three products.
    private static let carried = BundleVersion(version: "0.5", build: "2")!
    private static let lesser = BundleVersion(version: "0.4", build: "7")!
    private static let lowerBuild = BundleVersion(version: "0.5", build: "1")!
    private static let greater = BundleVersion(version: "0.6", build: "1")!

    // MARK: - Agent

    private let server = URL(filePath: "/Applications/Photos-Go-Round.app/Contents/Helpers/Photos-Go-Round Server.app")
    private var binary: URL { server.appending(path: "Contents/MacOS/Photos-Go-Round Server") }
    private let label = "com.sydpolk.photosgoround.server"
    private let agents = URL(filePath: "/tmp/pgr-test/LaunchAgents")
    private var plist: URL { agents.appending(path: "\(label).plist") }

    private var agentSurroundings: AgentInstall.Surroundings {
        let label = label
        return AgentInstall.Surroundings(
            directoryExists: { _ in true },
            isExecutable: { _ in true },
            labelInBundle: { _ in label },
            versionInBundle: { _ in Self.carried },
            isJobLoaded: { _ in true },
            runningAgents: { [] })
    }

    private func installed(
        job: JobDescription?, loaded: Bool = true, pid: Int32? = 501, programExists: Bool = true
    ) -> AgentInstall.Installed {
        AgentInstall.Installed(
            job: { _ in job }, isJobLoaded: { _ in loaded }, pid: { _ in pid },
            programExists: { _ in programExists })
    }

    private func job(_ version: BundleVersion?, program: URL? = nil) -> JobDescription {
        JobDescription(label: label, program: program ?? binary, version: version)
    }

    private func agentStanding(_ installed: AgentInstall.Installed) throws -> Standing {
        try AgentInstall.standing(
            of: server, launchAgents: agents, surroundings: agentSurroundings, installed: installed)
    }

    @Test("No job description is an agent not installed")
    func noPlistIsMissing() throws {
        #expect(try agentStanding(installed(job: nil)) == .missing)
    }

    /// The launch that used to restart a healthy agent: 2026-09-24, 17:08.
    @Test("A job of the same version, loaded and running, is current")
    func theSameVersionIsCurrent() throws {
        #expect(try agentStanding(installed(job: job(Self.carried))) == .current)
    }

    /// Every install made before versions were recorded.
    @Test("A job that records no version differs")
    func noVersionRecordedDiffers() throws {
        #expect(try agentStanding(installed(job: job(nil))) == .differs("the job records no version"))
    }

    /// Syd, 2026-10-05: "don't keep the older versions" — though it is running.
    @Test("A job of a lesser version differs, and says both", arguments: [StandingTests.lesser, StandingTests.lowerBuild])
    func aLesserVersionDiffers(_ has: BundleVersion) throws {
        #expect(
            try agentStanding(installed(job: job(has)))
                == .differs("version \(has), and this app carries 0.5 (2)"))
    }

    /// Syd, 2026-10-05: "if the services are NEWER, leave them alone".
    @Test("A job of a greater version is newer, and says both")
    func aGreaterVersionIsNewer() throws {
        #expect(
            try agentStanding(installed(job: job(Self.greater)))
                == .newer("version 0.6 (1), and this app carries 0.5 (2)"))
    }

    /// Another copy of the app — a second archive somewhere else — wrote it.
    /// Syd, 2026-10-08, of one at the same version and build: "leave them
    /// alone".
    @Test("Another copy's job at the same version is current")
    func anotherCopyAtTheSameVersionIsCurrent() throws {
        let elsewhere = URL(filePath: "/Volumes/Disk Image/Photos-Go-Round.app/Contents/Helpers/Photos-Go-Round Server.app/Contents/MacOS/Photos-Go-Round Server")
        #expect(try agentStanding(installed(job: job(Self.carried, program: elsewhere))) == .current)
    }

    /// A disk image ejected, or the other copy thrown away: nothing can run.
    @Test("A job whose program is gone differs, and names it")
    func programGoneDiffers() throws {
        let standing = try agentStanding(installed(job: job(Self.greater), programExists: false))
        #expect(standing == .differs("the job's program is gone: \(binary.path(percentEncoded: false))"))
    }

    @Test("A job description launchd has not loaded differs")
    func notLoadedDiffers() throws {
        #expect(
            try agentStanding(installed(job: job(Self.carried), loaded: false))
                == .differs("the job is not loaded"))
    }

    /// Not running is acted on, and by starting it rather than installing.
    @Test("A loaded job with no process is stopped, whether its version is the same or greater", arguments: [StandingTests.carried, StandingTests.greater])
    func noProcessIsStopped(_ has: BundleVersion) throws {
        #expect(try agentStanding(installed(job: job(has), pid: nil)) == .stopped)
    }

    @Test("A bundle that is not an agent is refused before anything is compared")
    func brokenBundleThrows() {
        let broken = AgentInstall.Surroundings(
            directoryExists: { _ in true }, isExecutable: { _ in true },
            labelInBundle: { _ in nil },
            versionInBundle: { _ in Self.carried },
            isJobLoaded: { _ in true }, runningAgents: { [] })
        #expect(throws: AgentInstall.Failure.noLabel(server)) {
            try AgentInstall.standing(
                of: server, launchAgents: agents, surroundings: broken,
                installed: installed(job: nil))
        }
    }

    // MARK: - Saver

    private let savers = URL(filePath: "/tmp/pgr-test/Screen Savers")
    private let saver = URL(filePath: "/Applications/Photos-Go-Round.app/Contents/Resources/Photos-Go-Round Screensaver.saver")
    private let otherSaver = "/Volumes/Disk Image/Photos-Go-Round.app/Contents/Resources/Photos-Go-Round Screensaver.saver"

    /// `there` is what sits at the saver's name, and `has` the version read
    /// through it — nil for a link whose target is gone.
    private func saverStanding(
        _ there: SaverInstall.Installed, has: BundleVersion? = nil,
        carries: BundleVersion? = StandingTests.carried
    ) throws -> Standing {
        let saverPath = saver.path(percentEncoded: false)
        return try SaverInstall.standing(
            of: saver, into: savers,
            surroundings: SaverInstall.Surroundings(
                directoryExists: { $0.path(percentEncoded: false) == saverPath },
                isRunning: { _ in false },
                versionAt: { $0.path(percentEncoded: false) == saverPath ? carries : has }),
            installed: { _ in there })
    }

    @Test("Nothing in Screen Savers is not installed")
    func saverMissing() throws {
        #expect(try saverStanding(.nothing) == .missing)
    }

    /// A link to this app's saver, a link into another copy, and a copy
    /// `pgr_install saver` laid down are all judged by the version in them.
    @Test("A saver there at the same version is current, however it got there")
    func saverSameVersion() throws {
        let here = saver.path(percentEncoded: false)
        for there in [SaverInstall.Installed.link(to: here), .link(to: otherSaver), .bundle] {
            #expect(try saverStanding(there, has: Self.carried) == .current)
        }
    }

    @Test("A saver there at a lesser version differs, and says both")
    func saverLesser() throws {
        #expect(
            try saverStanding(.link(to: otherSaver), has: Self.lesser)
                == .differs("version 0.4 (7), and this app carries 0.5 (2)"))
    }

    @Test("A saver there at a greater version is newer")
    func saverGreater() throws {
        #expect(
            try saverStanding(.bundle, has: Self.greater)
                == .newer("version 0.6 (1), and this app carries 0.5 (2)"))
    }

    /// The other copy of the app was thrown away, and the link dangles.
    @Test("A link whose saver cannot be read differs, and names where it points")
    func saverLinkUnreadable() throws {
        #expect(
            try saverStanding(.link(to: otherSaver), has: nil)
                == .differs("linked to \(otherSaver), where no version can be read"))
    }

    @Test("A copy with no version that can be read differs")
    func saverCopyUnreadable() throws {
        #expect(try saverStanding(.bundle, has: nil) == .differs("a copy with no version that can be read"))
    }

    @Test("A carried saver with no version is refused")
    func saverCarriesNoVersion() {
        #expect(throws: SaverInstall.Failure.noVersion(saver)) {
            try saverStanding(.nothing, carries: nil)
        }
    }

    // MARK: - The saver on disk

    /// A real directory in a temporary folder, so `installed(at:)` reads the
    /// filesystem rather than being told.
    @Test("A link, a dangling link, a real bundle and nothing are told apart")
    func installedReadsTheDisk() throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "pgr-standing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let bundle = folder.appending(path: "real.saver")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        let link = folder.appending(path: "link.saver")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: bundle)
        let dangling = folder.appending(path: "dangling.saver")
        try FileManager.default.createSymbolicLink(
            at: dangling, withDestinationURL: folder.appending(path: "gone.saver"))

        #expect(SaverInstall.installed(at: bundle) == .bundle)
        #expect(SaverInstall.installed(at: link) == .link(to: bundle.path(percentEncoded: false)))
        // **The case `fileExists` gets wrong**: it follows the link and says
        // there is nothing, and then no link can be made over it.
        #expect(SaverInstall.installed(at: dangling) == .link(to: folder.appending(path: "gone.saver").path(percentEncoded: false)))
        #expect(SaverInstall.installed(at: folder.appending(path: "absent.saver")) == .nothing)
    }

    @Test("Linking replaces a dangling link and names the saver it was given")
    func applyLinkOverADanglingLink() throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "pgr-standing-\(UUID().uuidString)")
        let savers = folder.appending(path: "Screen Savers")
        try FileManager.default.createDirectory(at: savers, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appending(path: "App.app/Contents/Resources/Photos-Go-Round Screensaver.saver")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let destination = savers.appending(path: "Photos-Go-Round Screensaver.saver")
        try FileManager.default.createSymbolicLink(
            at: destination, withDestinationURL: folder.appending(path: "Deleted.app/x.saver"))

        let plan = try SaverInstall.plan(
            for: source, into: savers,
            surroundings: .init(directoryExists: { _ in true }, isRunning: { _ in false }))
        try SaverInstall.applyLink(plan)
        #expect(SaverInstall.installed(at: destination) == .link(to: source.path(percentEncoded: false)))
    }

    /// A saver made by this test, read through a link to it: the version a
    /// launch compares is the one in the saver the link names.
    @Test("A saver's version is read through a link to it")
    func versionIsReadThroughALink() throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "pgr-standing-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let bundle = folder.appending(path: "real.saver")
        try FileManager.default.createDirectory(
            at: bundle.appending(path: "Contents"), withIntermediateDirectories: true)
        try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleShortVersionString": "0.5", "CFBundleVersion": "2"],
            format: .xml, options: 0
        ).write(to: bundle.appending(path: "Contents/Info.plist"))
        let link = folder.appending(path: "link.saver")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: bundle)
        let dangling = folder.appending(path: "dangling.saver")
        try FileManager.default.createSymbolicLink(
            at: dangling, withDestinationURL: folder.appending(path: "gone.saver"))

        #expect(BundleVersion.read(from: link) == Self.carried)
        #expect(BundleVersion.read(from: dangling) == nil)
    }

    // MARK: - Wallpaper

    private let appex = URL(filePath: "/Applications/Photos-Go-Round.app/Contents/Library/Wallpaper/Photos-Go-Round Wallpaper.appex")
    private let otherAppex = "/Volumes/Disk Image/Photos-Go-Round.app/Contents/Library/Wallpaper/Photos-Go-Round Wallpaper.appex"
    private let identifier = "com.sydpolk.photosgoround.wallpaper.extension"

    private var registeredHere: WallpaperInstall.Registration {
        .init(identifier: identifier, path: appex.path(percentEncoded: false))
    }

    /// `gone` are paths whose bundles are no longer there.
    private func wallpaperStanding(
        _ registered: [WallpaperInstall.Registration], recorded: BundleVersion? = StandingTests.carried,
        carries: BundleVersion? = StandingTests.carried, gone: Set<String> = []
    ) throws -> Standing {
        let identifier = identifier
        return try WallpaperInstall.standing(
            of: appex,
            surroundings: WallpaperInstall.Surroundings(
                directoryExists: { _ in true },
                identifierAt: { gone.contains($0) ? nil : identifier },
                registrations: { registered },
                versionAt: { _ in carries },
                recordedVersion: { _ in recorded }))
    }

    @Test("Registered at the version this app carries is current, from this appex or another copy's")
    func wallpaperCurrent() throws {
        #expect(try wallpaperStanding([registeredHere]) == .current)
        #expect(try wallpaperStanding([.init(identifier: identifier, path: otherAppex)]) == .current)
    }

    /// Every registration made before versions were recorded.
    @Test("Registered with no version recorded differs")
    func wallpaperNoVersionRecorded() throws {
        #expect(
            try wallpaperStanding([registeredHere], recorded: nil)
                == .differs("registered, with no version recorded"))
    }

    /// **An app replaced at the same path.** The registration still names the
    /// right place and was made for the old bundle. Syd, 2026-09-21:
    /// "unregister the extension, re-register the extension, tickle Wallpaper
    /// agent".
    @Test("Registered at a lesser version differs, and says both")
    func wallpaperLesser() throws {
        #expect(
            try wallpaperStanding([registeredHere], recorded: Self.lesser)
                == .differs("version 0.4 (7), and this app carries 0.5 (2)"))
    }

    @Test("Registered at a greater version is newer")
    func wallpaperGreater() throws {
        #expect(
            try wallpaperStanding([registeredHere], recorded: Self.greater)
                == .newer("version 0.6 (1), and this app carries 0.5 (2)"))
    }

    @Test("Not registered at all is not installed")
    func wallpaperMissing() throws {
        #expect(try wallpaperStanding([]) == .missing)
    }

    /// Whatever version was recorded for it, nothing is there to run.
    @Test("Registered only from a bundle that is gone differs, and names where")
    func wallpaperBundleGone() throws {
        let standing = try wallpaperStanding(
            [.init(identifier: identifier, path: otherAppex)], recorded: Self.greater, gone: [otherAppex])
        #expect(standing == .differs("registered from \(otherAppex), which is gone"))
    }

    /// Debug and Claude builds register beside Release, and are not this one.
    @Test("Another configuration's registration does not count as this one's")
    func otherConfigurationIsNotOurs() throws {
        let debug = WallpaperInstall.Registration(
            identifier: "com.sydpolk.photosgoround.wallpaper.debug.extension",
            path: "/elsewhere/Photos-Go-Round Wallpaper.appex")
        #expect(try wallpaperStanding([debug]) == .missing)
    }

    @Test("A carried appex with no version is refused")
    func wallpaperCarriesNoVersion() {
        #expect(throws: WallpaperInstall.Failure.noVersion(appex)) {
            try wallpaperStanding([registeredHere], carries: nil)
        }
    }

    // MARK: - The chosen wallpaper

    /// The shape `WallpaperAgent`'s store had on 2026-09-21, reduced to the
    /// keys that lead to a choice.
    private func store(_ provider: String, under key: String = "AllSpacesAndDisplays") -> Data {
        var root: [String: Any] = ["Spaces": [String: Any](), "Displays": [String: Any]()]
        root[key] = ["Desktop": ["Content": ["Choices": [["Provider": provider, "Files": [Any]()]]]]]
        return try! PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)
    }

    @Test("This extension chosen for all displays, or as the system default, is chosen", arguments: ["AllSpacesAndDisplays", "SystemDefault", "Spaces"])
    func chosenAnywhere(_ key: String) {
        #expect(WallpaperInstall.isChosen(identifier, store: store(identifier, under: key)))
    }

    @Test("Another wallpaper, or another configuration's extension, is not this one chosen")
    func otherChoicesAreNot() {
        #expect(!WallpaperInstall.isChosen(identifier, store: store("com.apple.wallpaper.choice.image")))
        #expect(
            !WallpaperInstall.isChosen(
                identifier, store: store("com.sydpolk.photosgoround.wallpaper.debug.extension")))
    }

    /// A registration nobody asked for is the worse mistake.
    @Test("A store that is missing or unreadable counts as not chosen")
    func unreadableStoreIsNotChosen() {
        #expect(!WallpaperInstall.isChosen(identifier, store: nil))
        #expect(!WallpaperInstall.isChosen(identifier, store: Data("not a plist".utf8)))
    }

    // MARK: - The running extension

    /// Whether an extension of this build is running at all — what a launch
    /// asks of a wallpaper that is chosen. Syd, 2026-10-08: "chose but not
    /// running check".
    private func isRunning(_ running: [WallpaperInstall.Running]) -> Bool {
        let identifier = identifier
        return WallpaperInstall.isRunning(
            appex, running: running,
            surroundings: WallpaperInstall.Surroundings(
                directoryExists: { _ in true },
                identifierAt: { $0.contains("Debug") ? "com.sydpolk.photosgoround.wallpaper.debug.extension" : identifier },
                registrations: { [] }))
    }

    @Test("No extension process is not running")
    func noneRunning() {
        #expect(!isRunning([]))
    }

    @Test("An extension running from this appex, or from another copy's, is running")
    func runningHereOrElsewhere() {
        #expect(isRunning([.init(pid: 7, appex: appex.path(percentEncoded: false))]))
        #expect(isRunning([.init(pid: 8, appex: otherAppex)]))
    }

    /// Syd's Debug extension running beside a Release app is not the Release
    /// app's wallpaper running.
    @Test("Another configuration's running extension does not count")
    func otherConfigurationIsNotRunning() {
        #expect(!isRunning([.init(pid: 9, appex: "/Users/x/DerivedData/Debug/Photos-Go-Round Wallpaper.appex")]))
    }
}
