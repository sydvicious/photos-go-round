import Foundation
import PhotosGoRoundAgentAPI

/// Which `Photos-Go-Round.app` is this build's installed one — the app the
/// uninstaller moves to the Trash.
///
/// **Not asked of LaunchServices.** The bundle identifier is the same in all
/// three configurations, because TCC grants hang off it, so "the app with this
/// identifier" can as easily be a Debug build in DerivedData as the Release one
/// in `/Applications`. The agent's own plist is the better witness: it names
/// the agent inside the app that installed it. `Plans/Release DMG.md`, *Which
/// app it trashes*.
public enum InstalledApp {

    /// Where an app keeps its agent, which is how a program path is recognised
    /// as being inside one.
    static let helpers = "/Contents/Helpers/"

    /// The app an agent's program path is inside, or nil when it is not inside
    /// one — an agent `pgr_install` put straight into DerivedData, say.
    public static func containing(program: String) -> URL? {
        guard let range = program.range(of: helpers) else { return nil }
        let app = String(program[..<range.lowerBound])
        guard app.hasSuffix(".app") else { return nil }
        return URL(filePath: app, directoryHint: .isDirectory)
    }

    /// The app this build's LaunchAgent plist points into.
    public static func fromAgentPlist(_ data: Data) -> URL? {
        guard let job = try? PropertyListDecoder().decode(JobDescription.self, from: data),
            let program = job.programArguments.first
        else { return nil }
        return containing(program: program)
    }

    /// Whether the app at this URL carries this build's agent: its embedded
    /// agent's label is this variant's.
    public static func carries(_ variant: BuildVariant, app: URL) -> Bool {
        let info = app.appending(
            path: "Contents/Helpers/\(AgentInstall.executableName).app/Contents/Info.plist")
        guard let values = NSDictionary(contentsOf: info) as? [String: Any],
            let label = values[AgentInstall.labelKey] as? String
        else { return false }
        return label == variant.agentLabel
    }

    /// Whether the uninstaller may move this app to the Trash: **only one in
    /// `/Applications` itself.** Syd, 2026-09-27: "I think you should only
    /// delete the app itself if it is /Applications." A build in DerivedData,
    /// or a copy somebody keeps elsewhere, is theirs.
    public static func isTrashable(
        _ app: URL, applications: URL = URL(filePath: "/Applications", directoryHint: .isDirectory)
    ) -> Bool {
        app.standardizedFileURL.deletingLastPathComponent().path(percentEncoded: false)
            == applications.standardizedFileURL.path(percentEncoded: false)
    }

    /// This build's installed app: the one its agent's plist points into, and
    /// failing that `/Applications/Photos-Go-Round.app` if that is this build.
    /// Nil means there is nothing to trash.
    ///
    /// **Read before `Uninstall` removes the plist.**
    public static func find(
        _ variant: BuildVariant = .current,
        launchAgents: URL = URL.homeDirectory.appending(path: "Library/LaunchAgents"),
        applications: URL = URL(filePath: "/Applications", directoryHint: .isDirectory)
    ) -> URL? {
        let plist = launchAgents.appending(path: "\(variant.agentLabel).plist")
        if let data = try? Data(contentsOf: plist), let app = fromAgentPlist(data),
            FileManager.default.fileExists(atPath: app.path(percentEncoded: false))
        {
            return app
        }
        let standard = applications.appending(path: "Photos-Go-Round.app", directoryHint: .isDirectory)
        return carries(variant, app: standard) ? standard : nil
    }
}
