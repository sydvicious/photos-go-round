// Which of a folder's files are on the device, and asking for the ones that
// are not. `Plans/PGR Widgets - iOS.md`, *The files and folders*.
//
// **A widget cannot read a file in iCloud Drive that is not on the device.**
// Syd's phone, 2026-10-11: the extension opened the folder through the app's
// bookmark and listed it, and every file iCloud had not downloaded failed to
// open, at once. The app reads the same files, and its reading fetches them.
//
// So a source picks from what is on the device, and asks for some of what is
// not, so that more is there next time. What is fetched is iCloud Drive's own
// and the system's to take away again; nothing is copied.
//
// Both halves are handed to a source, so that a test can say which files are
// on the device: none can put one in iCloud Drive.

import Foundation
import OSLog
import PhotosGoRoundAgentAPI

public struct DeviceFiles: Sendable {
    /// Whether the file's contents are on the device. A file that is not in
    /// iCloud Drive always is.
    public var isOnDevice: @Sendable (URL) -> Bool

    /// Asks for these files to be fetched. Nobody waits for them.
    public var fetch: @Sendable ([URL]) -> Void

    public init(isOnDevice: @escaping @Sendable (URL) -> Bool, fetch: @escaping @Sendable ([URL]) -> Void) {
        self.isOnDevice = isOnDevice
        self.fetch = fetch
    }

    /// What iCloud Drive says, and asking it.
    public static let system = DeviceFiles(
        isOnDevice: { file in
            // A location kept from one wake to the next would go on giving
            // the answer it got the first time.
            var file = file
            file.removeAllCachedResourceValues()
            let status = try? file.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                .ubiquitousItemDownloadingStatus
            return status != .notDownloaded
        },
        fetch: { files in
            var asked = 0
            var refusal: NSError?
            for file in files {
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: file)
                    asked += 1
                } catch {
                    refusal = refusal ?? (error as NSError)
                }
            }
            // Whether a widget may ask at all is found out here.
            let refused =
                refusal.map { "; the first refusal: \($0.localizedDescription) (\($0.domain) \($0.code))" } ?? ""
            Log.widget.notice(
                """
                \(Log.widgetsTag, privacy: .public) asked iCloud for \(asked) of \(files.count) files that \
                are not on the device\(refused, privacy: .public)
                """)
        })
}
