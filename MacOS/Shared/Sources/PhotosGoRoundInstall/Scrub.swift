import Foundation
import PhotosGoRoundAgentAPI

/// Deleting a build's data: its library, its cache and its preferences, current
/// and retired alike.
///
/// **Moved here from `Scripts/scrub-data.sh`, 2026-09-27**, because the
/// uninstaller on the DMG has to do the same thing and nothing written in shell
/// ships. Syd, 2026-09-19: "there should not be multiple versions of the build
/// scripts." The script is a wrapper round `pgr_install scrub` now, the shape
/// `uninstall.sh` took. `Plans/Release DMG.md`.
///
/// **Names come from the variant, never from a path.** Everything here is
/// spelled from `Storage` and `BuildVariant`; nothing is taken from an
/// argument, `PGR_CONTAINER` or `PGR_BUILD_ROOT` — the one operation whose
/// whole job is deleting things is not one typo away from deleting something
/// else.
///
/// **It deletes data, not installs.** The LaunchAgent, the wallpaper
/// registration and the screensaver link are `Uninstall`'s. An agent that is
/// running is stopped first, and left stopped with its plist in place.
public enum Scrub {

    public struct Plan: Equatable, Sendable {
        public var variants: [BuildVariant]
        /// The names that are each a container, a cache and a preference
        /// domain: every variant's library, and the retired `.dev` one beside it.
        public var libraries: [String]
        /// Every preference domain whose settings go, libraries' included,
        /// whether or not a file is on disk: `cfprefsd` can hold one without.
        public var domains: [String]
        /// What of those is actually on disk, one path each.
        public var found: [URL]
        /// The remembered pictures, inside sandbox containers macOS protects.
        /// Tried, and reported when macOS refuses.
        public var protected: [URL]

        public var describedSteps: [String] {
            var steps = found.isEmpty
                ? ["nothing in the library, cache or preferences"]
                : found.map { "delete \($0.path(percentEncoded: false))" }
            steps.append("and the remembered pictures, if macOS allows:")
            steps += protected.map { "  \($0.path(percentEncoded: false))" }
            return steps
        }
    }

    public enum Failure: Error, Equatable, CustomStringConvertible {
        /// An agent started by hand still has one of these libraries open.
        case stillRunning([Int32])

        public var description: String {
            switch self {
            case .stillRunning(let pids):
                "an agent started by hand did not stop (pid \(pids.map(String.init).joined(separator: ", "))); nothing was deleted"
            }
        }
    }

    /// A build's library and the retired development library beside it.
    public static func libraries(for variant: BuildVariant) -> [String] {
        let build = Storage.name(for: variant)
        return [build, build + ".dev"]
    }

    /// The screensaver's and the wallpaper's own domains, current and retired.
    public static func surfaceDomains(for variant: BuildVariant) -> [String] {
        let build = Storage.name(for: variant)
        return ["screensaver", "wallpaper"].flatMap { surface in
            ["", ".dev", ".prod"].map { "\(build).\(surface)\($0)" }
        }
    }

    /// The saver's cache inside `legacyScreenSaver`'s container, and the
    /// wallpaper extension's Application Support inside its own — where each
    /// keeps the last picture it showed.
    public static func protectedPaths(for variant: BuildVariant, home: URL) -> [URL] {
        let containers = home.appending(path: "Library/Containers")
        return [
            containers.appending(
                path: "com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Caches/\(variant.saverIdentifier)"),
            containers.appending(
                path: "\(variant.wallpaperExtensionIdentifier)/Data/Library/Application Support"),
        ]
    }

    static func container(_ name: String, home: URL) -> URL {
        home.appending(path: "Library/Containers/\(name)")
    }

    static func cache(_ name: String, home: URL) -> URL {
        home.appending(path: "Library/Caches/\(name)")
    }

    static func plist(_ domain: String, home: URL) -> URL {
        home.appending(path: "Library/Preferences/\(domain).plist")
    }

    /// **Not following a link**, as `Uninstall.Surroundings.live` does not.
    public static let onDisk: @Sendable (URL) -> Bool = {
        (try? FileManager.default.attributesOfItem(atPath: $0.path(percentEncoded: false))) != nil
    }

    public static func plan(
        variants: [BuildVariant],
        home: URL = URL.homeDirectory,
        fileExists: @Sendable (URL) -> Bool = onDisk
    ) -> Plan {
        let libraries = variants.flatMap(libraries(for:))
        let surfaces = variants.flatMap(surfaceDomains(for:))
        let candidates =
            libraries.flatMap { [container($0, home: home), cache($0, home: home), plist($0, home: home)] }
            + surfaces.map { plist($0, home: home) }
        return Plan(
            variants: variants,
            libraries: libraries,
            domains: libraries + surfaces,
            found: candidates.filter(fileExists),
            protected: variants.flatMap { protectedPaths(for: $0, home: home) })
    }

    /// Stops the builds' agents, then deletes. Returns what it did, a line at
    /// a time.
    ///
    /// **Stopped first**, because a live agent holds the database's WAL open
    /// and republishes its port, and deleting underneath it leaves a
    /// half-deleted library and a running process disagreeing about what
    /// exists.
    @discardableResult
    public static func apply(_ plan: Plan, home: URL = URL.homeDirectory) throws -> [String] {
        var done: [String] = []

        for variant in plan.variants {
            done += try AgentInstall.stop(variant)
        }

        let started = handStarted(plan.libraries)
        if !started.isEmpty {
            for pid in started { kill(pid, SIGTERM) }
            var left = started
            for _ in 0..<20 {
                Thread.sleep(forTimeInterval: 0.25)
                left = handStarted(plan.libraries)
                if left.isEmpty { break }
            }
            if !left.isEmpty { throw Failure.stillRunning(left) }
            done.append("stopped the agent started by hand: \(started.map(String.init).joined(separator: ", "))")
        }

        for name in plan.libraries {
            for directory in [container(name, home: home), cache(name, home: home)]
            where onDisk(directory) {
                try FileManager.default.removeItem(at: directory)
                done.append("deleted \(directory.path(percentEncoded: false))")
            }
        }
        for domain in plan.domains {
            UserDefaults.standard.removePersistentDomain(forName: domain)
            let file = plist(domain, home: home)
            if onDisk(file) {
                try FileManager.default.removeItem(at: file)
                done.append("deleted \(file.path(percentEncoded: false))")
            }
        }
        // `cfprefsd` caches a domain it has read and hands the stale copy back
        // to the next process that asks. Deleting the file is not enough.
        _ = Shell.killall("cfprefsd")

        // **Tried, never forced.** Each is inside a sandbox container; macOS
        // may ask, or refuse. A refusal is reported and the rest stands.
        for path in plan.protected where onDisk(path) {
            do {
                try FileManager.default.removeItem(at: path)
                done.append("deleted \(path.path(percentEncoded: false))")
            } catch {
                done.append("macOS would not let this delete \(path.path(percentEncoded: false))")
            }
        }

        done.append("deleted the data; the agents are stopped until the next login or pgr_install start")
        return done
    }

    /// Agents launchd does not own that have one of these libraries' containers
    /// open — a `run-server.sh`, say. **Matched on the container, not the
    /// name**, so an agent serving another build's library is never one.
    static func handStarted(_ libraries: [String]) -> [Int32] {
        Launchctl.agentsOutsideLaunchd(named: AgentInstall.executableName).map(\.pid).filter { pid in
            let open = Shell.run("/usr/sbin/lsof", ["-p", String(pid)]).output
            return libraries.contains { open.contains("/Library/Containers/\($0)/") }
        }
    }
}
