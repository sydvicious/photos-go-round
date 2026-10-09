import Foundation
import Synchronization
import PhotosGoRoundAgentAPI
import Testing

@testable import PhotosGoRoundInstall

/// What an app does at launch with what its wrapper carries.
@Suite("What the app installs when it launches")
struct LaunchInstallTests {

    private let app = URL(filePath: "/Applications/Photos-Go-Round.app")
    private var agent: URL { app.appending(path: "Contents/Helpers/Photos-Go-Round Server.app") }
    private var appex: URL { app.appending(path: "Contents/Library/Wallpaper/Photos-Go-Round Wallpaper.appex") }
    private var resources: URL { app.appending(path: "Contents/Resources") }

    // MARK: - Finding what is carried

    /// A wrapper whose copy phases did not run — or an app nobody embedded into.
    @Test("An empty wrapper carries nothing")
    func ordinaryBuildCarriesNothing() {
        let carried = LaunchInstall.carried(
            in: app, directoryExists: { _ in false }, contents: { _ in ["AppIcon.icns"] })
        #expect(carried.isEmpty)
    }

    @Test(
        "A build carries all three, the saver under its configuration's name",
        arguments: [
            "Photos-Go-Round Screensaver.saver",
            "Photos-Go-Round Screensaver (Debug).saver",
            "Photos-Go-Round Screensaver (Claude).saver",
        ])
    func archiveCarriesAll(saverName: String) {
        let saver = resources.appending(path: saverName)
        let present = Set([agent, appex, saver].map { $0.path(percentEncoded: false) })
        let carried = LaunchInstall.carried(
            in: app,
            directoryExists: { present.contains($0.path(percentEncoded: false)) },
            contents: { _ in ["AppIcon.icns", saverName, "Assets.car"] })
        #expect(carried == .init(agent: agent, wallpaper: appex, saver: saver))
    }

    // MARK: - Running

    /// Records what the steps were asked, and answers as told.
    private final class Recorder: Sendable {
        let asked = Mutex<[String]>([])
        func note(_ line: String) { asked.withLock { $0.append(line) } }
        var lines: [String] { asked.withLock { $0 } }
    }

    private func steps(
        _ recorder: Recorder,
        standing: @escaping @Sendable (LaunchInstall.Product) throws -> Standing,
        install: @escaping @Sendable (LaunchInstall.Product) throws -> [String] = { _ in ["done"] },
        agentAnswers: Bool = true,
        wallpaperIsRunning: Bool = true,
        wallpaperIsChosen: Bool = false
    ) -> LaunchInstall.Steps {
        LaunchInstall.Steps(
            standing: { product, _ in
                recorder.note("standing \(product.rawValue)")
                return try standing(product)
            },
            install: { product, _ in
                recorder.note("install \(product.rawValue)")
                return try install(product)
            },
            restartAgent: { _ in
                recorder.note("restart agent")
                return ["restarted"]
            },
            uninstall: { product in
                recorder.note("uninstall \(product.rawValue)")
                return ["gone"]
            },
            agentAnswers: {
                recorder.note("wait for agent")
                return agentAnswers
            },
            wallpaperIsRunning: { _ in
                recorder.note("check running wallpaper")
                return wallpaperIsRunning
            },
            wallpaperIsChosen: { _ in
                recorder.note("check chosen wallpaper")
                return wallpaperIsChosen
            })
    }

    private var everything: LaunchInstall.Carried {
        .init(agent: agent, wallpaper: appex, saver: resources.appending(path: "Photos-Go-Round Screensaver.saver"))
    }

    private func launch(
        _ variant: BuildVariant, _ recorder: Recorder, carried: LaunchInstall.Carried? = nil,
        standing: @escaping @Sendable (LaunchInstall.Product) throws -> Standing,
        install: @escaping @Sendable (LaunchInstall.Product) throws -> [String] = { _ in ["done"] },
        agentAnswers: Bool = true, wallpaperIsRunning: Bool = true,
        wallpaperIsChosen: Bool = false,
        report: (String) -> Void = { _ in }
    ) -> [LaunchInstall.Outcome.Result] {
        LaunchInstall.run(
            carried ?? everything, variant: variant,
            steps: steps(
                recorder, standing: standing, install: install, agentAnswers: agentAnswers,
                wallpaperIsRunning: wallpaperIsRunning, wallpaperIsChosen: wallpaperIsChosen),
            report: report
        ).map(\.result)
    }

    /// A relaunch over its own install changes nothing — the agent included.
    /// It was restarted on every launch until 2026-10-08; on 2026-09-24 that
    /// took a healthy agent down and the Photos albums went unavailable. Syd,
    /// 2026-10-05: "Don't reinstall or relaunch any of the services if they are
    /// already running when running the app."
    @Test("A launch over its own install changes nothing, and does not restart the agent", arguments: BuildVariant.allCases)
    func relaunchChangesNothing(_ variant: BuildVariant) {
        let recorder = Recorder()
        let results = launch(variant, recorder, standing: { _ in .current })
        #expect(!recorder.lines.contains("restart agent"))
        #expect(!recorder.lines.contains { $0.hasPrefix("install") })
        #expect(results[0] == .current)
    }

    @Test("Release over its own install asks each product its standing, and nothing more")
    func releaseRelaunch() {
        let recorder = Recorder()
        let results = launch(.release, recorder, standing: { _ in .current })
        #expect(
            recorder.lines == [
                "standing agent", "wait for agent", "standing wallpaper", "check chosen wallpaper",
                "standing saver",
            ])
        #expect(results == [.current, .current, .current])
    }

    // MARK: - The agent's standing

    /// Not running is acted on: started, with nothing installed over it.
    @Test("An agent with no process is started, and not installed again")
    func stoppedAgentIsStarted() {
        let recorder = Recorder()
        let results = launch(
            .release, recorder, standing: { $0 == .agent ? .stopped : .current })
        #expect(recorder.lines.prefix(3) == ["standing agent", "restart agent", "wait for agent"])
        #expect(!recorder.lines.contains("install agent"))
        #expect(results[0] == .restarted)
    }

    /// Syd, 2026-10-05: "don't keep the older versions".
    @Test("An agent of a lesser version is installed over, though it is running")
    func lesserAgentIsInstalled() {
        let recorder = Recorder()
        let results = launch(
            .debug, recorder,
            standing: { $0 == .agent ? .differs("version 0.4 (7), and this app carries 0.5 (2)") : .current })
        #expect(recorder.lines.prefix(2) == ["standing agent", "install agent"])
        #expect(results[0] == .installed)
    }

    /// Syd, 2026-10-05: "if the services are NEWER, leave them alone".
    @Test("Services of a greater version are left alone, all three")
    func newerIsLeftAlone() {
        let recorder = Recorder()
        let results = launch(
            .release, recorder, standing: { _ in .newer("version 0.6 (1), and this app carries 0.5 (2)") })
        #expect(!recorder.lines.contains("restart agent"))
        #expect(!recorder.lines.contains { $0.hasPrefix("install") })
        #expect(results == [.leftAlone, .leftAlone, .leftAlone])
    }

    @Test("Release on a clean Mac installs all three, the agent first")
    func releaseFirstLaunch() {
        let recorder = Recorder()
        let results = launch(.release, recorder, standing: { _ in .missing })
        #expect(
            recorder.lines == [
                "standing agent", "install agent", "wait for agent",
                "standing wallpaper", "check chosen wallpaper", "install wallpaper",
                "standing saver", "install saver",
            ])
        #expect(results == [.installed, .installed, .installed])
    }

    /// Syd, 2026-09-21: "the Release installs the binaries by default, and the
    /// other two don't" — except the agent, which every build installs.
    @Test("A Debug or Claude launch installs the agent and leaves the other two", arguments: [BuildVariant.debug, .claude])
    func developmentLaunch(_ variant: BuildVariant) {
        let recorder = Recorder()
        let results = launch(variant, recorder, standing: { _ in .missing })
        #expect(
            recorder.lines == [
                "standing agent", "install agent", "wait for agent",
                "standing wallpaper", "check chosen wallpaper",
            ])
        #expect(results == [.installed, .leftAlone, .leftAlone])
    }

    /// **The second grey desktop, 2026-09-21.** A rebuild made `pkd` drop the
    /// registration altogether, not just the running extension. Syd: "yes,
    /// re-register it in any build".
    @Test("Any build registers its wallpaper again when it is gone but still chosen", arguments: BuildVariant.allCases)
    func goneButChosenIsRegistered(_ variant: BuildVariant) {
        let recorder = Recorder()
        let results = launch(
            variant, recorder, standing: { $0 == .wallpaper ? .missing : .current },
            wallpaperIsChosen: true)
        #expect(recorder.lines.contains("install wallpaper"))
        #expect(results[1] == .installed)
    }

    /// An app replaced where it sits: registered, and for the old version.
    @Test("Any build registers its wallpaper again when the one registered is of a lesser version", arguments: BuildVariant.allCases)
    func lesserWallpaperIsRegisteredAgain(_ variant: BuildVariant) {
        let recorder = Recorder()
        let results = launch(
            variant, recorder,
            standing: { $0 == .wallpaper ? .differs("version 0.4 (7), and this app carries 0.5 (2)") : .current })
        #expect(recorder.lines.contains("install wallpaper"))
        #expect(results[1] == .installed)
    }

    /// **What turned the desktop grey, 2026-09-21.** A ⌘R rebuilt the app; `pkd`
    /// dropped the running extension because its bundle changed, and
    /// `WallpaperAgent` never started it again. The version is the same, so
    /// only this catches it. Syd, 2026-10-08: "chose but not running check".
    @Test("Any build registers the wallpaper again when it is chosen and no extension is running", arguments: BuildVariant.allCases)
    func chosenButNotRunningIsRegisteredAgain(_ variant: BuildVariant) {
        let recorder = Recorder()
        let results = launch(
            variant, recorder, standing: { _ in .current }, wallpaperIsRunning: false,
            wallpaperIsChosen: true)
        #expect(recorder.lines.contains("check running wallpaper"))
        #expect(recorder.lines.contains("install wallpaper"))
        #expect(results[1] == .installed)
    }

    @Test("A chosen wallpaper whose extension is running is left as it is")
    func chosenAndRunningIsLeft() {
        let recorder = Recorder()
        let results = launch(.release, recorder, standing: { _ in .current }, wallpaperIsChosen: true)
        #expect(!recorder.lines.contains("install wallpaper"))
        #expect(results[1] == .current)
    }

    /// Nobody chose it, so nothing should be showing, and nothing is wrong.
    @Test("A wallpaper that is not chosen is not asked whether it is running")
    func notChosenIsNotAskedWhetherItRuns() {
        let recorder = Recorder()
        let results = launch(.release, recorder, standing: { _ in .current }, wallpaperIsRunning: false)
        #expect(!recorder.lines.contains("check running wallpaper"))
        #expect(results[1] == .current)
    }

    /// A plain relaunch, nothing rebuilt: the wallpaper is left as it is.
    @Test("A Debug relaunch with its wallpaper current does nothing to it")
    func developmentRelaunchLeavesCurrentWallpaper() {
        let recorder = Recorder()
        let results = launch(.debug, recorder, standing: { _ in .current })
        #expect(!recorder.lines.contains("install wallpaper"))
        #expect(results == [.current, .current, .leftAlone])
    }

    /// Syd, 2026-10-08, of the version rule: "this goes for the screensaver as
    /// well". Until then a launch linked it "if not there" and left anything
    /// else.
    @Test("A Release launch links the saver again when the one there is of a lesser version")
    func lesserSaverIsLinkedAgain() {
        let recorder = Recorder()
        let results = launch(
            .release, recorder,
            standing: { $0 == .saver ? .differs("version 0.4 (7), and this app carries 0.5 (2)") : .current })
        #expect(recorder.lines.contains("install saver"))
        #expect(results[2] == .installed)
    }

    @Test("Nothing carried asks nothing of the Mac")
    func nothingCarriedAsksNothing() {
        let recorder = Recorder()
        let results = launch(.release, recorder, carried: .init(), standing: { _ in .missing })
        #expect(recorder.lines.isEmpty)
        #expect(results == [.notCarried, .notCarried, .notCarried])
    }

    struct Refused: Error, CustomStringConvertible {
        var description: String { "pkd said no" }
    }

    @Test("One product failing does not stop the others")
    func aFailureIsContained() {
        let results = launch(
            .release, Recorder(), standing: { _ in .missing },
            install: { product in
                if product == .wallpaper { throw Refused() }
                return ["done"]
            })
        #expect(results == [.installed, .failed("pkd said no"), .installed])
    }

    /// The log is the diagnostic: every product gets a line, done or not.
    @Test("Every product reports a line")
    func everyProductReports() {
        let reported = Recorder()
        _ = launch(
            .debug, Recorder(), carried: .init(agent: agent),
            standing: { _ in .differs("the job is not loaded") }, report: { reported.note($0) })
        #expect(
            reported.lines == [
                "agent: differs: the job is not loaded", "agent: done", "wallpaper: not carried",
                "saver: not carried",
            ])
    }

    // MARK: - The agent first

    /// Syd, 2026-09-21: "the agent has to be up and running first".
    @Test("An agent that never answers fails the other two, and they are not installed")
    func noAgentNoSurfaces() {
        let recorder = Recorder()
        let results = launch(.release, recorder, standing: { _ in .missing }, agentAnswers: false)
        #expect(recorder.lines == ["standing agent", "install agent", "wait for agent"])
        #expect(
            results == [
                .installed, .failed("the agent is not answering"), .failed("the agent is not answering"),
            ])
    }

    @Test("Without an agent carried, nothing waits for one")
    func noAgentCarriedNoWait() {
        let recorder = Recorder()
        _ = launch(
            .release, recorder, carried: .init(saver: resources.appending(path: "Photos-Go-Round Screensaver.saver")),
            standing: { _ in .missing }, agentAnswers: false)
        #expect(recorder.lines == ["standing saver", "install saver"])
    }

    // MARK: - Which builds install at launch

    /// Syd, 2026-09-21: "the Release installs the binaries by default, and the
    /// other two don't".
    @Test("Only Release installs at launch", arguments: BuildVariant.allCases)
    func onlyReleaseAtLaunch(_ variant: BuildVariant) {
        #expect(LaunchInstall.installsAtLaunch(variant) == (variant == .release))
    }

    // MARK: - The Help menu

    /// Syd, 2026-09-21: "the menu always installs".
    @Test("The menu's Install installs without asking whether anything differs")
    func menuAlwaysInstalls() {
        let recorder = Recorder()
        let outcome = LaunchInstall.install(
            .wallpaper, from: everything, steps: steps(recorder, standing: { _ in .current }),
            report: { _ in })
        #expect(recorder.lines == ["install wallpaper"])
        #expect(outcome.result == .installed)
    }

    @Test("The menu's Install of something not carried does nothing")
    func menuInstallNotCarried() {
        let recorder = Recorder()
        let outcome = LaunchInstall.install(
            .agent, from: .init(), steps: steps(recorder, standing: { _ in .missing }), report: { _ in })
        #expect(recorder.lines.isEmpty)
        #expect(outcome.result == .notCarried)
    }

    @Test("The menu's Uninstall removes the one product it names")
    func menuUninstalls() {
        let recorder = Recorder()
        let outcome = LaunchInstall.uninstall(
            .saver, steps: steps(recorder, standing: { _ in .current }), report: { _ in })
        #expect(recorder.lines == ["uninstall saver"])
        #expect(outcome.result == .uninstalled)
    }

    @Test("The spinner's words follow what is being done")
    func progressIsAnnounced() {
        let announced = Recorder()
        LaunchInstall.run(
            everything, variant: .release,
            steps: steps(Recorder(), standing: { $0 == .saver ? .missing : .current }),
            progress: { announced.note($0) },
            report: { _ in })
        #expect(
            announced.lines == ["Waiting for the agent…", "Installing the screensaver…"])
    }

    @Test("The spinner says the agent is starting only when it is")
    func startingIsAnnounced() {
        let announced = Recorder()
        LaunchInstall.run(
            .init(agent: agent), variant: .release,
            steps: steps(Recorder(), standing: { _ in .stopped }),
            progress: { announced.note($0) },
            report: { _ in })
        #expect(announced.lines == ["Starting the agent…"])
    }
}
