import AppKit
import Foundation
import Observation
import PhotosGoRoundAgentAPI
import PhotosGoRoundInstall

/// What the uninstaller found, what it is doing, and what it did.
///
/// **This build's copy, for this user, and nobody else's.** `BuildVariant.current`
/// only, as the app's Help menu does, so a Release uninstaller never takes a
/// Debug agent down. Syd, 2026-09-27: "I am deliberately not addressing other
/// users who might run this; their data is stranded."
@Observable
final class UninstallerModel {

    enum Phase: Equatable {
        case ready
        case working
        /// Something would not stop; the alert offers Force Quit.
        case stuck(Stuck)
        case done
        case failed(String)
    }

    /// What did not stop when asked, and so what Force Quit would end.
    enum Stuck: Equatable {
        case app(pid: Int32)
        case agent(label: String)
        case handStarted(pids: [Int32])

        var explanation: String {
            switch self {
            case .app:
                "Photos-Go-Round did not shut down when it was asked to. Force it to quit, or cancel and quit it yourself."
            case .agent:
                "Photos-Go-Round's background service did not shut down. Force it to quit, or cancel and nothing more is removed."
            case .handStarted:
                "A copy of Photos-Go-Round's background service is still running. Force it to quit, or cancel and nothing more is removed."
            }
        }
    }

    /// One line in the window: a thing that would be removed, and whether it is here.
    struct Item: Identifiable {
        var id: String { name }
        var name: String
        var detail: String
        var isPresent: Bool
    }

    private(set) var phase: Phase = .ready
    private(set) var items: [Item] = []
    private(set) var report: [String] = []

    /// Read before anything is removed: the app is found from the agent's plist,
    /// which the uninstall deletes.
    private let app: URL?
    private let uninstallPlan: Uninstall.Plan
    private let scrubPlan: Scrub.Plan
    /// Where the work has got to, so Force Quit can carry on from there.
    private var next = Step.quitApp

    private enum Step { case quitApp, uninstall, scrub, trash, finished }

    init() {
        let variant = BuildVariant.current
        app = InstalledApp.find(variant)
        uninstallPlan = Uninstall.plan(variants: [variant])
        scrubPlan = Scrub.plan(variants: [variant])
        items = [
            Item(
                name: "The Photos-Go-Round app",
                detail: app?.path(percentEncoded: false) ?? "not found",
                isPresent: app != nil),
            Item(
                name: "Its background service",
                detail: uninstallPlan.agents.contains(where: \.isPresent) ? "installed" : "not installed",
                isPresent: uninstallPlan.agents.contains(where: \.isPresent)),
            Item(
                name: "The wallpaper in System Settings",
                detail: uninstallPlan.registrations.isEmpty ? "not registered" : "registered",
                isPresent: !uninstallPlan.registrations.isEmpty),
            Item(
                name: "The screensaver",
                detail: uninstallPlan.savers.isEmpty ? "not installed" : "installed",
                isPresent: !uninstallPlan.savers.isEmpty),
            Item(
                name: "Its settings, and its record of the photos you chose",
                detail: scrubPlan.found.isEmpty ? "none found" : "\(scrubPlan.found.count) items",
                isPresent: !scrubPlan.found.isEmpty),
        ]
    }

    var isStuck: Bool {
        if case .stuck = phase { return true }
        return false
    }

    func uninstall() {
        guard phase == .ready else { return }
        phase = .working
        Task { await carryOn() }
    }

    /// Ends whatever did not stop, then carries on from where it stopped.
    func forceQuit() {
        guard case .stuck(let stuck) = phase else { return }
        switch stuck {
        case .app(let pid):
            kill(pid, SIGKILL)
        case .agent(let label):
            if let pid = Launchctl.pid(of: label) { kill(pid, SIGKILL) }
            Launchctl.bootout(label)
        case .handStarted(let pids):
            for pid in pids { kill(pid, SIGKILL) }
        }
        report.append("forced to quit: \(stuck)")
        phase = .working
        Task { await carryOn() }
    }

    /// Cancelling at the Force Quit alert stops here; what was removed stays removed.
    func cancelForceQuit() {
        report.append("stopped: something would not quit, so nothing more was removed")
        phase = .done
    }

    private func carryOn() async {
        while true {
            switch next {
            case .quitApp:
                if let pid = await quitApp() {
                    phase = .stuck(.app(pid: pid))
                    return
                }
                next = .uninstall

            case .uninstall:
                let plan = uninstallPlan
                do {
                    report += try await Task.detached { try Uninstall.apply(plan) }.value
                } catch {
                    phase = .failed(String(describing: error))
                    return
                }
                next = .scrub

            case .scrub:
                let plan = scrubPlan
                do {
                    report += try await Task.detached { try Scrub.apply(plan) }.value
                } catch AgentInstall.Failure.stillLoaded(let label) {
                    phase = .stuck(.agent(label: label))
                    return
                } catch Scrub.Failure.stillRunning(let pids) {
                    phase = .stuck(.handStarted(pids: pids))
                    return
                } catch {
                    phase = .failed(String(describing: error))
                    return
                }
                next = .trash

            case .trash:
                if let app {
                    do {
                        try FileManager.default.trashItem(at: app, resultingItemURL: nil)
                        report.append("moved \(app.path(percentEncoded: false)) to the Trash")
                    } catch {
                        report.append("could not move \(app.path(percentEncoded: false)) to the Trash: \(error.localizedDescription)")
                    }
                }
                next = .finished

            case .finished:
                phase = .done
                return
            }
        }
    }

    /// Asks this build's app to quit, and waits a few seconds for it. Returns
    /// the pid of one that is still running, or nil when none is.
    ///
    /// **Only the app at this build's path.** Every build shares the bundle
    /// identifier, so a running Debug app must not be asked to quit.
    private func quitApp() async -> Int32? {
        guard let app else { return nil }
        let target = app.standardizedFileURL.path(percentEncoded: false)
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: Storage.identifier)
            .filter { $0.bundleURL?.standardizedFileURL.path(percentEncoded: false) == target }
        guard !running.isEmpty else { return nil }
        for instance in running { instance.terminate() }
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(250))
            if running.allSatisfy(\.isTerminated) { break }
        }
        let left = running.first { !$0.isTerminated }
        if left == nil { report.append("quit Photos-Go-Round") }
        return left?.processIdentifier
    }
}
