import Foundation
import PhotosGoRoundAgentAPI

/// The LaunchAgent plist, as a value.
///
/// **A `Codable` rather than a heredoc**, which is what `plutil -lint` used to
/// guard against: an encoder cannot emit malformed XML, so the check it replaced
/// has nothing left to check.
public struct JobDescription: Codable, Equatable, Sendable {

    /// What launchd knows the job by. One job per label per user, which is why
    /// each build configuration has its own. `BuildVariant.swift`.
    public var label: String
    public var programArguments: [String]
    public var runAtLoad: Bool
    public var keepAlive: KeepAlive
    public var processType: String
    /// The app this job belongs to, which is what System Settings files it
    /// under.
    ///
    /// **Without it the job is listed under the signing certificate's name.**
    /// Checked 2026-09-23 with `sfltool dumpbtm`: macOS tracks this per-user
    /// plist as a legacy agent, enabled and allowed, with `Parent Identifier:
    /// Sydney Polk` — so *Allow in the Background* showed it under Syd's name,
    /// and nothing called Photos-Go-Round was anywhere in Login Items. This key
    /// names the app, and the plist stays per user in `~/Library/LaunchAgents`,
    /// as decided 2026-09-10.
    ///
    /// **It has not changed the listing yet.** Checked the same night: macOS
    /// read the key — `dumpbtm` shows `Assoc. Bundle IDs: [
    /// com.sydpolk.photosgoround ]` — and still filed the item under `Sydney
    /// Polk`, across a logout, for a build signed with an Apple Development
    /// certificate. Kept because it is the documented way to name the owning
    /// app and costs nothing; whether a Developer ID build honours it is not
    /// known.
    ///
    /// The app's identifier is the same in every build configuration, so every
    /// configuration's agent is filed under the one app.
    ///
    /// **Optional only so an older plist still decodes.** Every plist this
    /// writes carries it. One written before this key existed read as a
    /// different job, which made the next app launch write it again; since
    /// 2026-10-08 it is the version, which such a plist does not record.
    public var associatedBundleIdentifiers: [String]?
    /// Where the install records the version it installed, and nothing else.
    ///
    /// **Recorded here, not read from the bundle later.** An app replaced at
    /// the same path has the new version on disk under an agent still running
    /// the old code, so the bundle would always read as equal. This plist is
    /// written by the install and removed by the uninstall, so the record
    /// cannot outlive what it describes. `Plans/Leave Running Services
    /// Alone.md`, *Why the version is recorded at install*.
    ///
    /// **`EnvironmentVariables` because launchd defines the key**, so nothing
    /// unknown goes into the plist. The agent does not read them.
    ///
    /// **Nil in a plist written before versions were recorded**, which is how
    /// such an install reads as having no version and is installed again.
    public var environmentVariables: [String: String]?

    static let versionKey = "PGR_INSTALLED_VERSION"
    static let buildKey = "PGR_INSTALLED_BUILD"

    /// The version this job was installed with, or nil when it records none
    /// or what it records is not a version.
    public var version: BundleVersion? {
        BundleVersion(
            version: environmentVariables?[Self.versionKey],
            build: environmentVariables?[Self.buildKey])
    }

    /// Restart it when it fails, and leave it alone when it exits cleanly.
    public struct KeepAlive: Codable, Equatable, Sendable {
        public var successfulExit: Bool

        enum CodingKeys: String, CodingKey {
            case successfulExit = "SuccessfulExit"
        }
    }

    enum CodingKeys: String, CodingKey {
        case label = "Label"
        case programArguments = "ProgramArguments"
        case runAtLoad = "RunAtLoad"
        case keepAlive = "KeepAlive"
        case processType = "ProcessType"
        case associatedBundleIdentifiers = "AssociatedBundleIdentifiers"
        case environmentVariables = "EnvironmentVariables"
    }

    /// **`Adaptive`, not `Background`, since 2026-09-17.** macOS throttles a
    /// Background job's disk I/O, and this agent reads the disk to answer a
    /// person waiting on a picture. Measured over four restarts with
    /// `Background`: about two minutes between the process starting and its
    /// first line of code, then a cache walk of 16 to 39 seconds that takes
    /// 137 ms on a quiet machine, and one-row writes holding the database's
    /// write lock for hundreds of milliseconds — all of it disk, none of it the
    /// agent's own work. Adaptive lets the system lift the throttle when the
    /// process is doing user-visible work. `TODO.md`, *The agent takes about two
    /// minutes from launch to listening after a restart*.
    public static let adaptive = "Adaptive"

    /// The program and nothing else: the agent's build decides its storage,
    /// and there is no choice left to pass. It passed `--prod` for a Release
    /// build until 2026-09-24, when each build got one set of assets.
    public init(label: String, program: URL, version: BundleVersion? = nil) {
        self.label = label
        self.programArguments = [program.path(percentEncoded: false)]
        self.runAtLoad = true
        self.keepAlive = KeepAlive(successfulExit: false)
        self.processType = Self.adaptive
        self.associatedBundleIdentifiers = [Storage.identifier]
        self.environmentVariables = version.map {
            [Self.versionKey: $0.version, Self.buildKey: $0.build]
        }
    }

    public func encodedPlist() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        return try encoder.encode(self)
    }

    public func write(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encodedPlist().write(to: url, options: .atomic)
    }
}
