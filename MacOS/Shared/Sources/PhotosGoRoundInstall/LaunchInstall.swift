import Foundation
import PhotosGoRoundAgentAPI

/// What an app does with the products in its own wrapper: at launch, install
/// each that differs from what this Mac has; from the Help menu, install or
/// uninstall one on demand.
///
/// **Every build carries all three; only Release installs at launch.** Syd,
/// 2026-09-21: "the Release installs the binaries by default, and the other two
/// don't, but the binaries are always in the app bundle and you can always
/// install/uninstall via the menu." And "the menu always installs" — so
/// `install(_:from:)` does not ask whether anything differs.
///
/// **Nothing is copied out of the bundle.** The agent's plist and the saver's
/// symlink point into it, and the extension is registered where it sits. So an
/// app replaced at the same path leaves all three pointing at the new one, and
/// what is left is Syd's list, 2026-09-21: the wallpaper unregistered and
/// registered again with `WallpaperAgent` tickled, the screensaver untouched,
/// the agent stopped and started. `Plans/Release App Installer.md`, Phase 4.
///
/// **That list is done only when the app that replaced it is of a greater
/// version**, since 2026-10-08: each install records the version it installed,
/// and a launch compares. `Plans/Leave Running Services Alone.md`.
public enum LaunchInstall {

    public enum Product: String, CaseIterable, Sendable {
        case agent, wallpaper, saver

        /// For the words beside the spinner.
        public var noun: String {
            switch self {
            case .agent: "the agent"
            case .wallpaper: "the wallpaper extension"
            case .saver: "the screensaver"
            }
        }
    }

    /// **Agent first, and answering before the others.** The wallpaper and
    /// the screensaver fetch their pictures from it. Syd, 2026-09-21: "the
    /// agent has to be up and running first". The other two in no order that
    /// matters.
    public static let order: [Product] = [.agent, .wallpaper, .saver]

    /// Whether a build of this configuration installs what it carries at
    /// launch. Debug and Claude builds install only from the Help menu.
    public static func installsAtLaunch(_ variant: BuildVariant) -> Bool {
        variant == .release
    }

    /// Where each product sits in an archived app, when it is there at all.
    public struct Carried: Equatable, Sendable {
        public var agent: URL?
        public var wallpaper: URL?
        public var saver: URL?

        public init(agent: URL? = nil, wallpaper: URL? = nil, saver: URL? = nil) {
            self.agent = agent
            self.wallpaper = wallpaper
            self.saver = saver
        }

        public subscript(product: Product) -> URL? {
            switch product {
            case .agent: agent
            case .wallpaper: wallpaper
            case .saver: saver
            }
        }

        public var isEmpty: Bool { agent == nil && wallpaper == nil && saver == nil }
    }

    /// The saver's name varies by configuration — `… (Debug).saver` — so it is
    /// found by prefix rather than spelled.
    static let saverPrefix = "Photos-Go-Round Screensaver"

    /// What `app` carries, found where the embed phases put it.
    public static func carried(
        in app: URL,
        directoryExists: (URL) -> Bool = Self.directoryExists,
        contents: (URL) -> [String] = Self.contents
    ) -> Carried {
        let inside = app.appending(path: "Contents")
        let agent = inside.appending(path: "Helpers/Photos-Go-Round Server.app")
        // **Not `Contents/Extensions`.** Xcode registers every app it builds
        // with LaunchServices, which registers whatever sits there with `pkd`,
        // and nothing turns that off. Syd, 2026-09-21: registered "only if you
        // say 'install wallpaper'". Measured the same day: from here a build
        // registers nothing and `pluginkit -a` still registers it.
        let wallpaper = inside.appending(path: "Library/Wallpaper/Photos-Go-Round Wallpaper.appex")
        let resources = inside.appending(path: "Resources")
        let saver = contents(resources)
            .filter { $0.hasPrefix(saverPrefix) && $0.hasSuffix(".saver") }
            .sorted()
            .first
            .map { resources.appending(path: $0) }
        return Carried(
            agent: directoryExists(agent) ? agent : nil,
            wallpaper: directoryExists(wallpaper) ? wallpaper : nil,
            saver: saver.flatMap { directoryExists($0) ? $0 : nil })
    }

    /// What is done per product, so a test can stand in for all of it.
    public struct Steps: Sendable {
        public var standing: @Sendable (Product, URL) throws -> Standing
        public var install: @Sendable (Product, URL) throws -> [String]
        public var restartAgent: @Sendable (URL) throws -> [String]
        public var uninstall: @Sendable (Product) throws -> [String]
        /// Blocks until this build's agent answers, or gives up and says false.
        public var agentAnswers: @Sendable () -> Bool
        /// Whether a wallpaper extension of this build is running at all.
        public var wallpaperIsRunning: @Sendable (URL) -> Bool
        /// Whether the wallpaper somebody chose is this appex's extension.
        public var wallpaperIsChosen: @Sendable (URL) -> Bool

        public init(
            standing: @escaping @Sendable (Product, URL) throws -> Standing,
            install: @escaping @Sendable (Product, URL) throws -> [String],
            restartAgent: @escaping @Sendable (URL) throws -> [String] = { _ in [] },
            uninstall: @escaping @Sendable (Product) throws -> [String] = { _ in [] },
            agentAnswers: @escaping @Sendable () -> Bool = { true },
            wallpaperIsRunning: @escaping @Sendable (URL) -> Bool = { _ in true },
            wallpaperIsChosen: @escaping @Sendable (URL) -> Bool = { _ in false }
        ) {
            self.standing = standing
            self.install = install
            self.restartAgent = restartAgent
            self.uninstall = uninstall
            self.agentAnswers = agentAnswers
            self.wallpaperIsRunning = wallpaperIsRunning
            self.wallpaperIsChosen = wallpaperIsChosen
        }

        public static let live = Steps(
            standing: { product, bundle in
                switch product {
                case .agent: try AgentInstall.standing(of: bundle)
                case .wallpaper: try WallpaperInstall.standing(of: bundle)
                case .saver: try SaverInstall.standing(of: bundle)
                }
            },
            install: { product, bundle in
                switch product {
                case .agent: try AgentInstall.apply(AgentInstall.plan(for: bundle))
                case .wallpaper: try WallpaperInstall.apply(WallpaperInstall.plan(for: bundle))
                case .saver: try SaverInstall.applyLink(SaverInstall.plan(for: bundle))
                }
            },
            restartAgent: { bundle in try AgentInstall.restart(AgentInstall.plan(for: bundle)) },
            uninstall: { product in
                let part: Uninstall.Part =
                    switch product {
                    case .agent: .agent
                    case .wallpaper: .wallpaper
                    case .saver: .saver
                    }
                // This build's own, never another configuration's.
                return try Uninstall.apply(
                    Uninstall.plan(removing: [part], variants: [BuildVariant.current]))
            },
            // The app's own preferences: this build's, which are the installed
            // agent's too — each build has exactly one set.
            agentAnswers: {
                AgentProbe.answers(preferences: MacHostEnvironment().preferences)
            },
            wallpaperIsRunning: { appex in
                WallpaperInstall.isRunning(appex, running: WallpaperInstall.runningExtensions())
            },
            wallpaperIsChosen: { appex in
                guard let identifier = PluginKit.identifier(ofBundleAt: appex.path(percentEncoded: false))
                else { return false }
                return WallpaperInstall.isChosen(
                    identifier, store: try? Data(contentsOf: WallpaperInstall.store))
            })
    }

    /// What happened to one product.
    public struct Outcome: Equatable, Sendable {
        public enum Result: Equatable, Sendable {
            case notCarried
            case current
            case installed
            /// The agent, installed and with no process, started.
            case restarted
            /// Nothing asked of it at launch: one of a greater version than
            /// this app carries, or a Debug or Claude build's wallpaper or
            /// saver.
            case leftAlone
            case uninstalled
            case failed(String)
        }
        public var product: Product
        public var result: Result
    }

    /// What a launch does.
    ///
    /// **One rule for all three, since 2026-10-08.** Syd, 2026-10-05: "Don't
    /// reinstall or relaunch any of the services if they are already running
    /// when running the app", and 2026-10-08: "if the running thingie has an
    /// equal or greater version, leave it alone. If it is lesser, or
    /// missing/unreadable, reinstall." `Standing` is that judgement, and
    /// `Plans/Leave Running Services Alone.md` the plan.
    ///
    /// 1. **The agent**, every build: installed when it is missing, lesser or
    ///    unable to run; started when it is installed and has no process; left
    ///    alone otherwise. It was restarted on every launch from 2026-09-21,
    ///    which on 2026-09-24 took a healthy agent down and the Photos albums
    ///    with it.
    /// 2. **Nothing more until it answers** — Syd, 2026-09-21: "the agent has
    ///    to be up and running first". One that never does fails the other two
    ///    with that reason.
    /// 3. **The wallpaper**, every build: registered again when the one
    ///    registered is lesser, has no version recorded, or is registered only
    ///    from a bundle that is gone. When it is not registered at all, a
    ///    Release build registers it, and any build does if it is still the
    ///    chosen wallpaper, since a rebuild can make `pkd` drop the
    ///    registration — "yes, re-register it in any build". And when it is
    ///    chosen with no extension running, which is what a rebuild at the
    ///    same version leaves: a grey desktop, measured 2026-09-21.
    /// 4. **The screensaver, Release only**: linked when nothing is at its
    ///    name, or what is there is lesser or cannot be read.
    ///
    /// **Blocks** — ten seconds on launchd, thirty on `pkd`, ninety for the
    /// agent to answer (`AgentProbe.patience`) — so the caller runs it off the
    /// cooperative pool. `report`
    /// gets a line per product at least, whatever was done: "saver: already
    /// there, left alone" answers "did the app touch my saver?" later.
    @discardableResult
    public static func run(
        _ carried: Carried,
        variant: BuildVariant = .current,
        steps: Steps = .live,
        progress: (String) -> Void = { _ in },
        report: (String) -> Void
    ) -> [Outcome] {
        let release = installsAtLaunch(variant)
        var outcomes: [Outcome] = []
        func outcome(_ product: Product, _ result: Outcome.Result) {
            outcomes.append(Outcome(product: product, result: result))
        }
        func attempt(_ product: Product, _ work: () throws -> Outcome.Result) {
            do { outcome(product, try work()) } catch {
                report("\(product.rawValue): failed — \(error)")
                outcome(product, .failed("\(error)"))
            }
        }
        func install(_ product: Product, _ bundle: URL) throws -> Outcome.Result {
            progress("Installing \(product.noun)…")
            for line in try steps.install(product, bundle) { report("\(product.rawValue): \(line)") }
            return .installed
        }

        // 1. The agent.
        if let agent = carried.agent {
            attempt(.agent) {
                let standing = try steps.standing(.agent, agent)
                report("agent: \(standing)")
                switch standing {
                case .missing, .differs:
                    return try install(.agent, agent)
                case .stopped:
                    progress("Starting the agent…")
                    for line in try steps.restartAgent(agent) { report("agent: \(line)") }
                    return .restarted
                case .current:
                    return .current
                case .newer:
                    return .leftAlone
                }
            }
        } else {
            report("agent: not carried")
            outcome(.agent, .notCarried)
        }

        // 2. Nothing more until it answers.
        var agentIsUp = true
        if carried.agent != nil, carried.wallpaper != nil || carried.saver != nil {
            progress("Waiting for the agent…")
            agentIsUp = steps.agentAnswers()
            report(agentIsUp ? "agent: answering" : "agent: not answering")
        }

        for product in [Product.wallpaper, .saver] {
            guard let bundle = carried[product] else {
                report("\(product.rawValue): not carried")
                outcome(product, .notCarried)
                continue
            }
            guard agentIsUp else {
                report("\(product.rawValue): not installed — the agent is not answering")
                outcome(product, .failed("the agent is not answering"))
                continue
            }
            attempt(product) {
                switch product {
                // 3. The wallpaper.
                case .wallpaper:
                    let standing = try steps.standing(.wallpaper, bundle)
                    report("wallpaper: \(standing)")
                    switch standing {
                    // Every build: registered, and lesser or unable to run.
                    case .differs:
                        return try install(.wallpaper, bundle)
                    case .missing:
                        // Every build: gone altogether, and still what was chosen.
                        if steps.wallpaperIsChosen(bundle) {
                            report("wallpaper: not registered, but it is the chosen wallpaper")
                            return try install(.wallpaper, bundle)
                        }
                        guard release else {
                            report("wallpaper: a \(variant.description) registers it from the Help menu")
                            return .leftAlone
                        }
                        return try install(.wallpaper, bundle)
                    case .current, .newer, .stopped:
                        // Every build: chosen, and nothing running to show it.
                        if steps.wallpaperIsChosen(bundle), !steps.wallpaperIsRunning(bundle) {
                            report("wallpaper: it is the chosen wallpaper, and no extension is running")
                            return try install(.wallpaper, bundle)
                        }
                        return standing == .current ? .current : .leftAlone
                    }
                // 4. The screensaver.
                case .saver:
                    guard release else {
                        report("saver: a \(variant.description) links it from the Help menu")
                        return .leftAlone
                    }
                    let standing = try steps.standing(.saver, bundle)
                    report("saver: \(standing)")
                    switch standing {
                    case .missing, .differs: return try install(.saver, bundle)
                    case .current: return .current
                    case .newer, .stopped: return .leftAlone
                    }
                case .agent:
                    return .notCarried
                }
            }
        }
        return outcomes
    }

    /// The Help menu's Install: always installs, whatever is there.
    @discardableResult
    public static func install(
        _ product: Product, from carried: Carried, steps: Steps = .live, report: (String) -> Void
    ) -> Outcome {
        guard let bundle = carried[product] else {
            report("\(product.rawValue): not carried")
            return Outcome(product: product, result: .notCarried)
        }
        do {
            for line in try steps.install(product, bundle) { report("\(product.rawValue): \(line)") }
            return Outcome(product: product, result: .installed)
        } catch {
            report("\(product.rawValue): failed — \(error)")
            return Outcome(product: product, result: .failed("\(error)"))
        }
    }

    /// The Help menu's Uninstall: this build's own, never another's.
    @discardableResult
    public static func uninstall(
        _ product: Product, steps: Steps = .live, report: (String) -> Void
    ) -> Outcome {
        do {
            for line in try steps.uninstall(product) { report(line) }
            return Outcome(product: product, result: .uninstalled)
        } catch {
            report("\(product.rawValue): uninstall failed — \(error)")
            return Outcome(product: product, result: .failed("\(error)"))
        }
    }

    public static func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let there = FileManager.default.fileExists(
            atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
        return there && isDirectory.boolValue
    }

    public static func contents(_ url: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: url.path(percentEncoded: false))) ?? []
    }
}
