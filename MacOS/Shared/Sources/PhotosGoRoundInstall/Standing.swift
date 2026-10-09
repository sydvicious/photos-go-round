import Foundation

/// Whether what an app carries is already what this Mac has installed.
///
/// **The question an archived app asks at every launch**, before it installs
/// anything. A relaunch of an unchanged app must change nothing on the system,
/// so each product answers this first and an install follows only from
/// `.missing` or `.differs`. `Plans/Release App Installer.md`, Phase 3.
///
/// **Decided by version number, since 2026-10-08.** Syd: "you should always use
/// version numbers. if the running thingie has an equal or greater version,
/// leave it alone. If it is lesser, or missing/unreadable, reinstall." It was
/// decided by content, path and the age of a file until then, on the argument
/// that a rebuild keeps its version; a rebuild that keeps its version and build
/// is now left alone, and that is the rule. `Plans/Leave Running Services
/// Alone.md`.
///
/// **The installed version is the one recorded when it was installed**, for the
/// agent and the wallpaper: an app replaced at the same path has the new
/// version on disk under an agent still running the old code. `BundleVersion`,
/// `JobDescription.version`, `WallpaperInstall.recordedVersion`.
public enum Standing: Equatable, Sendable, CustomStringConvertible {
    /// Installed at the version carried, and running if it is a thing that
    /// runs. Nothing to do.
    case current
    /// Not installed at all.
    case missing
    /// Installed, but lesser, or with no version that can be read, or unable
    /// to run — and why, for the log line. Installed again.
    case differs(String)
    /// Installed at the version carried or a greater one, and not running.
    /// The agent's: a loaded job with no process. Started, not installed.
    case stopped
    /// Installed at a greater version — and which, for the log line. Left
    /// alone. Syd, 2026-10-05: "if the services are NEWER, leave them alone".
    case newer(String)

    public var needsInstall: Bool {
        switch self {
        case .missing, .differs: true
        case .current, .stopped, .newer: false
        }
    }

    public var description: String {
        switch self {
        case .current: "same, nothing to do"
        case .missing: "not installed"
        case .differs(let why): "differs: \(why)"
        case .stopped: "installed, and not running"
        case .newer(let why): "newer, left alone: \(why)"
        }
    }

    /// How an installed version stands against the carried one, when both can
    /// be read and nothing else is wrong.
    static func comparing(installed: BundleVersion, carried: BundleVersion) -> Standing {
        let both = "version \(installed), and this app carries \(carried)"
        if installed < carried { return .differs(both) }
        if installed > carried { return .newer(both) }
        return .current
    }
}
