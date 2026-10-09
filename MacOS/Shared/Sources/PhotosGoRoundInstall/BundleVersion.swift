import Foundation

/// A build's marketing version and build number, and which of two is the later.
///
/// **What a launch compares before it installs over anything.** Syd,
/// 2026-10-08: "you should always use version numbers. if the running thingie
/// has an equal or greater version, leave it alone. If it is lesser, or
/// missing/unreadable, reinstall." `Plans/Leave Running Services Alone.md`.
///
/// **Marketing version first, then build number, each as numbers.** Compared
/// as text, 0.10 would sort below 0.9. A missing component counts as zero, so
/// 0.5 and 0.5.0 are the same version.
///
/// **Unreadable is nil, not zero.** A version or build that is missing, empty
/// or not dotted numbers has no `BundleVersion`, and the caller installs.
public struct BundleVersion: Comparable, Sendable, CustomStringConvertible {

    /// `CFBundleShortVersionString`, as written.
    public let version: String
    /// `CFBundleVersion`, as written.
    public let build: String

    /// Each one's components, with trailing zeros dropped so that 0.5 and
    /// 0.5.0 compare equal.
    private let versionNumbers: [Int]
    private let buildNumbers: [Int]

    public init?(version: String?, build: String?) {
        guard let version, let build,
            let versionNumbers = Self.numbers(version),
            let buildNumbers = Self.numbers(build)
        else { return nil }
        self.version = version
        self.build = build
        self.versionNumbers = versionNumbers
        self.buildNumbers = buildNumbers
    }

    /// From an `Info.plist`'s bytes.
    public init?(infoPlist data: Data) {
        guard
            let values = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any]
        else { return nil }
        self.init(
            version: values["CFBundleShortVersionString"] as? String,
            build: values["CFBundleVersion"] as? String)
    }

    /// The version of the bundle at this URL — an app, an appex or a saver —
    /// or nil when it is not there or does not say. A link is followed, so a
    /// saver linked into an app reads as the app's.
    public static func read(from bundle: URL) -> BundleVersion? {
        guard let data = try? Data(contentsOf: bundle.appending(path: "Contents/Info.plist"))
        else { return nil }
        return BundleVersion(infoPlist: data)
    }

    static func numbers(_ text: String) -> [Int]? {
        var numbers: [Int] = []
        for part in text.split(separator: ".", omittingEmptySubsequences: false) {
            guard !part.isEmpty, part.allSatisfy(\.isASCII), part.allSatisfy(\.isNumber),
                let number = Int(part)
            else { return nil }
            numbers.append(number)
        }
        while numbers.last == 0 { numbers.removeLast() }
        return numbers
    }

    public static func == (left: BundleVersion, right: BundleVersion) -> Bool {
        left.versionNumbers == right.versionNumbers && left.buildNumbers == right.buildNumbers
    }

    public static func < (left: BundleVersion, right: BundleVersion) -> Bool {
        if left.versionNumbers != right.versionNumbers {
            return left.versionNumbers.lexicographicallyPrecedes(right.versionNumbers)
        }
        return left.buildNumbers.lexicographicallyPrecedes(right.buildNumbers)
    }

    /// As the About box writes it: `0.5 (2)`.
    public var description: String { "\(version) (\(build))" }
}
