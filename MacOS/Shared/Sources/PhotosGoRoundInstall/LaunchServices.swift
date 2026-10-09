import Foundation

/// `lsregister`, which has no API either.
///
/// **Why an uninstall needs it.** The system removes a placed widget only when
/// LaunchServices has no record left of the widget's extension. Xcode registers
/// an app's extensions when it builds the app, and the record stays when that
/// build is deleted or, for an archive, moved away; `pluginkit` does not list
/// it. Found 2026-10-09, when Syd's widgets outlived the uninstaller:
/// NotificationCenter would not remove them "because LS still has an extension
/// record for it". `Plans/Photos-Go-Round Widgets.md`, *Uninstalling the
/// widgets*.
enum LaunchServices {

    static let lsregister =
        "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    /// Every extension LaunchServices holds a record of. **`Plugin` and not the
    /// whole database**: measured 2026-10-09, under a second against seven.
    static func extensionRecords() -> [WallpaperInstall.Registration] {
        parseExtensionRecords(Shell.run(lsregister, ["-dump", "Plugin"]).output)
    }

    /// A record is the lines between two rules of dashes. Its own fields start
    /// a line; its `Info.plist` is printed beneath them, indented, and is not
    /// read.
    static func parseExtensionRecords(_ dump: String) -> [WallpaperInstall.Registration] {
        var records: [WallpaperInstall.Registration] = []
        var identifier: String?
        var path: String?
        func close() {
            if let identifier, let path { records.append(.init(identifier: identifier, path: path)) }
            identifier = nil
            path = nil
        }
        for line in dump.split(separator: "\n") {
            if line.hasPrefix("----------") {
                close()
            } else if line.hasPrefix("identifier:") {
                identifier = value(of: line)
            } else if line.hasPrefix("path:") {
                // The path is followed by the record's number, as ` (0x1c680)`.
                let whole = value(of: line)
                if let number = whole.range(of: " (0x", options: .backwards), whole.hasSuffix(")") {
                    path = String(whole[..<number.lowerBound])
                } else {
                    path = whole
                }
            }
        }
        close()
        return records
    }

    private static func value(of line: Substring) -> String {
        guard let colon = line.firstIndex(of: ":") else { return "" }
        return line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
    }

    /// What to hand `lsregister -u` so that an extension's record goes: the app
    /// the extension is inside, or the extension itself when it is in none.
    static func registeredBundle(holding path: String) -> String {
        let folder = URL(filePath: path).deletingLastPathComponent()
        let contents = folder.deletingLastPathComponent()
        guard ["PlugIns", "Extensions"].contains(folder.lastPathComponent),
            contents.lastPathComponent == "Contents"
        else { return path }
        return contents.deletingLastPathComponent().path(percentEncoded: false)
            .trimmingSuffix("/")
    }

    /// Removes the record of the bundle at this path, and of the extensions
    /// inside it. **The bundle need not be there**: measured 2026-10-09 on an
    /// app that had been moved away.
    static func forget(_ path: String) {
        Shell.run(lsregister, ["-u", path])
    }
}

extension String {
    fileprivate func trimmingSuffix(_ suffix: String) -> String {
        count > suffix.count && hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}
