import Foundation
import Testing

@testable import PhotosGoRoundAgentAPI
@testable import PhotosGoRoundInstall

/// Finding every configuration's installed pieces, and only those.
///
/// **The failure this guards against is a partial uninstall.** Three
/// configurations install under three sets of names, and a command that knew
/// one would leave two running while reporting success.
@Suite("What uninstalling would remove")
struct UninstallTests {

    private let agents = URL(filePath: "/tmp/pgr-test/LaunchAgents")
    private let savers = URL(filePath: "/tmp/pgr-test/Screen Savers")

    private func surroundings(
        loaded: Set<String> = [],
        files: Set<String> = [],
        registered: [WallpaperInstall.Registration] = [],
        running: [AgentInstall.ForeignAgent] = [],
        widgets: [WallpaperInstall.Registration] = [],
        records: [WallpaperInstall.Registration] = []
    ) -> Uninstall.Surroundings {
        Uninstall.Surroundings(
            isJobLoaded: { loaded.contains($0) },
            fileExists: { files.contains($0.path(percentEncoded: false)) },
            registrations: { registered },
            runningAgents: { running },
            widgetRegistrations: { widgets },
            extensionRecords: { records })
    }

    /// **Three of everything, from `BuildVariant` rather than a second list.**
    @Test("Every configuration's agent is looked for, not just this build's")
    func everyAgentLabel() {
        let plan = Uninstall.plan(
            removing: [.agent], launchAgents: agents, screenSavers: savers,
            surroundings: surroundings())
        #expect(plan.agents.count == BuildVariant.allCases.count)
        #expect(Set(plan.agents.map(\.label)) == Set(BuildVariant.allCases.map(\.agentLabel)))
    }

    @Test("Every configuration's saver is looked for")
    func everySaverName() {
        let all = BuildVariant.allCases.map {
            savers.appending(path: "\($0.saverBundleName).saver").path(percentEncoded: false)
        }
        let plan = Uninstall.plan(
            removing: [.saver], launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(files: Set(all)))
        #expect(plan.savers.count == BuildVariant.allCases.count)
    }

    @Test("Only what is actually there is reported")
    func onlyWhatIsPresent() {
        let debug = BuildVariant.debug
        let plan = Uninstall.plan(
            removing: Set(Uninstall.Part.allCases), launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(
                loaded: [debug.agentLabel],
                files: [savers.appending(path: "\(debug.saverBundleName).saver")
                    .path(percentEncoded: false)]))
        #expect(plan.agents.filter(\.isPresent).map(\.label) == [debug.agentLabel])
        #expect(plan.savers.count == 1)
        #expect(plan.describedSteps.contains { $0.contains("boot out \(debug.agentLabel)") })
    }

    /// A plist left behind by a job that is no longer loaded still counts:
    /// launchd will load it again at the next login.
    @Test("A plist with no loaded job is still present")
    func orphanedPlistCounts() {
        let label = BuildVariant.release.agentLabel
        let plan = Uninstall.plan(
            removing: [.agent], launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(
                files: [agents.appending(path: "\(label).plist").path(percentEncoded: false)]))
        let found = plan.agents.first { $0.label == label }
        #expect(found?.isPresent == true)
        #expect(found?.jobIsLoaded == false)
        #expect(plan.describedSteps.contains { $0.contains("remove") && $0.contains(label) })
    }

    /// Apple's wallpaper extensions share the extension point and are never ours
    /// to unregister.
    @Test("Only Photos-Go-Round registrations are taken")
    func onlyOurRegistrations() {
        let ours = WallpaperInstall.Registration(
            identifier: "com.sydpolk.photosgoround.wallpaper.debug.extension", path: "/ours.appex")
        let apple = WallpaperInstall.Registration(
            identifier: "com.apple.wallpaper.extension.image", path: "/system.appex")
        let plan = Uninstall.plan(
            removing: [.wallpaper], launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(registered: [apple, ours]))
        #expect(plan.registrations == [ours])
    }

    // MARK: - The widget extension

    private static func widget(_ variant: BuildVariant) -> WallpaperInstall.Registration {
        .init(
            identifier: variant.widgetExtensionIdentifier,
            path: "/Applications/\(variant.rawValue)/Photos-Go-Round.app/Contents/PlugIns/Photos-Go-Round Widget.appex")
    }

    /// Syd, 2026-10-09: "we also need the uninstaller to remove widgets". The
    /// system drops a widget extension when its app is deleted, and the
    /// uninstaller only moves the app to the Trash; so it is unregistered by
    /// name, as the wallpaper extension is.
    @Test("Every configuration's widget extension is looked for, and nobody else's")
    func everyWidgetAndOnlyOurs() {
        let ours = BuildVariant.allCases.map(Self.widget)
        let weather = WallpaperInstall.Registration(
            identifier: "com.apple.weather.widget", path: "/System/Applications/Weather.app/x.appex")
        let plan = Uninstall.plan(
            removing: [.widget], launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(widgets: [weather] + ours))
        #expect(plan.widgets == ours)
    }

    @Test("Naming one configuration leaves the others' widget extensions alone")
    func oneConfigurationsWidget() {
        let plan = Uninstall.plan(
            removing: [.widget], variants: [.debug], launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(widgets: BuildVariant.allCases.map(Self.widget)))
        #expect(plan.widgets == [Self.widget(.debug)])
    }

    @Test("What it would do to a widget extension is said, by its identifier and its path")
    func widgetStepsAreDescribed() {
        let plan = Uninstall.plan(
            removing: [.widget], variants: [.release], launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(widgets: [Self.widget(.release)]))
        #expect(plan.describedSteps == [
            "widget: unregister com.sydpolk.photosgoround.widget",
            "  /Applications/release/Photos-Go-Round.app/Contents/PlugIns/Photos-Go-Round Widget.appex",
        ])
    }

    @Test("With no widget extension registered, it says so")
    func noWidgetIsSaid() {
        let plan = Uninstall.plan(
            removing: [.widget], launchAgents: agents, screenSavers: savers, surroundings: surroundings())
        #expect(plan.describedSteps == ["widget: nothing is registered"])
    }

    // MARK: - Records of a widget extension whose build is gone

    /// Where a build that has since been deleted had its widget extension.
    private static func deleted(_ variant: BuildVariant) -> WallpaperInstall.Registration {
        .init(
            identifier: variant.widgetExtensionIdentifier,
            path: "/Deleted/\(variant.rawValue)/Photos-Go-Round.app/Contents/PlugIns/Photos-Go-Round Widget.appex")
    }

    /// Syd, 2026-10-09: "I ran the uninstaller, and the widgets are still on my
    /// desktop". The system would not remove them "because LS still has an
    /// extension record for it": the record of a release build's archive, long
    /// since moved away.
    @Test("A record of a widget extension whose bundle is gone is taken")
    func aDeletedBuildsRecordIsTaken() {
        let plan = Uninstall.plan(
            removing: [.widget], launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(records: BuildVariant.allCases.map(Self.deleted)))
        #expect(plan.staleWidgets == BuildVariant.allCases.map(Self.deleted))
    }

    /// A record of a bundle still on disk is a registration, which `pluginkit`
    /// lists and the plan already takes as one.
    @Test("A record of a widget extension that is still there is not called stale")
    func aLiveRecordIsNotStale() {
        let live = Self.widget(.release)
        let plan = Uninstall.plan(
            removing: [.widget], launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(files: [live.path], widgets: [live], records: [live]))
        #expect(plan.staleWidgets.isEmpty)
        #expect(plan.widgets == [live])
    }

    @Test("Nobody else's records are taken, and no other configuration's")
    func onlyOurStaleRecords() {
        let weather = WallpaperInstall.Registration(
            identifier: "com.apple.weather.widget", path: "/Deleted/Weather.app/Contents/PlugIns/x.appex")
        let plan = Uninstall.plan(
            removing: [.widget], variants: [.release], launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(records: [weather] + BuildVariant.allCases.map(Self.deleted)))
        #expect(plan.staleWidgets == [Self.deleted(.release)])
    }

    /// **The order is the fix.** The system asks once, twenty seconds after the
    /// extension is unregistered, whether any record of it is left. Removing a
    /// stale one after that left Syd's five widgets where they were.
    @Test("Stale records are forgotten before the extension is unregistered")
    func staleRecordsGoFirst() {
        let live = Self.widget(.release)
        let plan = Uninstall.plan(
            removing: [.widget], variants: [.release], launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(
                files: [live.path], widgets: [live], records: [live, Self.deleted(.release)]))
        #expect(plan.describedSteps == [
            "widget: forget the record of a deleted com.sydpolk.photosgoround.widget",
            "  /Deleted/release/Photos-Go-Round.app/Contents/PlugIns/Photos-Go-Round Widget.appex",
            "widget: unregister com.sydpolk.photosgoround.widget",
            "  /Applications/release/Photos-Go-Round.app/Contents/PlugIns/Photos-Go-Round Widget.appex",
        ])
    }

    @Test("With only a stale record, it does not say nothing is registered")
    func onlyAStaleRecord() {
        let plan = Uninstall.plan(
            removing: [.widget], variants: [.debug], launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(records: [Self.deleted(.debug)]))
        #expect(plan.describedSteps == [
            "widget: forget the record of a deleted com.sydpolk.photosgoround.widget.debug",
            "  /Deleted/debug/Photos-Go-Round.app/Contents/PlugIns/Photos-Go-Round Widget.appex",
        ])
    }

    @Test("Without the widget part, LaunchServices is not asked")
    func recordsAreNotReadForOtherParts() {
        let plan = Uninstall.plan(
            removing: [.agent, .wallpaper, .saver], launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(records: [Self.deleted(.release)]))
        #expect(plan.staleWidgets.isEmpty)
    }

    @Test("Naming one part leaves the others entirely alone", arguments: Uninstall.Part.allCases)
    func partsAreIndependent(_ part: Uninstall.Part) {
        let plan = Uninstall.plan(
            removing: [part], launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(
                loaded: Set(BuildVariant.allCases.map(\.agentLabel)),
                files: Set(BuildVariant.allCases.map {
                    savers.appending(path: "\($0.saverBundleName).saver").path(percentEncoded: false)
                }),
                registered: [.init(identifier: "com.sydpolk.photosgoround.wallpaper.extension", path: "/x.appex")],
                widgets: [Self.widget(.release)]))
        #expect(plan.agents.isEmpty == (part != .agent))
        #expect(plan.savers.isEmpty == (part != .saver))
        #expect(plan.registrations.isEmpty == (part != .wallpaper))
        #expect(plan.widgets.isEmpty == (part != .widget))
    }

    /// Nothing about a library, a cache or a preference domain appears anywhere
    /// in what an uninstall would do. `Scripts/scrub-data.sh` is what deletes
    /// those, and only for the builds it is named.
    @Test("An uninstall never mentions the library, the cache or preferences")
    func neverTouchesData() {
        let plan = Uninstall.plan(
            removing: Set(Uninstall.Part.allCases), launchAgents: agents, screenSavers: savers,
            surroundings: surroundings(loaded: Set(BuildVariant.allCases.map(\.agentLabel))))
        let said = plan.describedSteps.joined(separator: " ").lowercased()
        for forbidden in ["containers", "caches", "photosgoround.sqlite", "preferences"] {
            #expect(!said.contains(forbidden), "an uninstall should never name \(forbidden)")
        }
    }

    /// **The Help menu removes its own build's pieces and nothing else.** A
    /// Claude build's Uninstall must not take Syd's Debug agent down with it.
    @Test("Naming one configuration leaves the others' agents, savers and registrations alone")
    func oneConfigurationOnly() {
        let launchAgents = URL(filePath: "/tmp/pgr-test/LaunchAgents")
        let savers = URL(filePath: "/tmp/pgr-test/Screen Savers")
        let registrations = BuildVariant.allCases.map {
            WallpaperInstall.Registration(identifier: $0.wallpaperExtensionIdentifier, path: "/x/\($0.rawValue).appex")
        }
        let plan = Uninstall.plan(
            variants: [.claude], launchAgents: launchAgents, screenSavers: savers,
            surroundings: Uninstall.Surroundings(
                isJobLoaded: { _ in true }, fileExists: { _ in true },
                registrations: { registrations }, runningAgents: { [] }))
        #expect(plan.agents.map(\.label) == [BuildVariant.claude.agentLabel])
        #expect(plan.savers == [savers.appending(path: "\(BuildVariant.claude.saverBundleName).saver")])
        #expect(plan.registrations.map(\.identifier) == [BuildVariant.claude.wallpaperExtensionIdentifier])
    }

    /// Found 2026-09-24: `uninstall.sh --variant debug` called Syd's Release
    /// agent hand-started and printed `kill 964`, because every running agent
    /// was reported and launchd was never asked whose each one was.
    @Test("An agent a loaded job owns is not reported as started by hand")
    func launchdOwnedAgentsAreNotForeign() {
        let release = AgentInstall.ForeignAgent(pid: 964, path: "/Applications/Photos-Go-Round.app/Server")
        let byHand = AgentInstall.ForeignAgent(pid: 555, path: "/tmp/hand-built/Photos-Go-Round Server")
        let plan = Uninstall.plan(
            removing: [.agent], variants: [.debug], launchAgents: agents, screenSavers: savers,
            surroundings: Uninstall.Surroundings(
                isJobLoaded: { $0 == BuildVariant.debug.agentLabel }, fileExists: { _ in false },
                registrations: { [] }, runningAgents: { [release, byHand] },
                jobPID: { $0 == BuildVariant.release.agentLabel ? 964 : nil }))
        #expect(plan.foreignAgents == [byHand])
    }
}
