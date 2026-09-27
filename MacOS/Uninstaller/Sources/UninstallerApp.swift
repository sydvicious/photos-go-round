import AppKit
import SwiftUI

// Takes Photos-Go-Round off this Mac, for the person running it, from the DMG.
//
// **An app, not a script**, because a script cannot be notarized and
// Gatekeeper refuses one that comes off a downloaded disk image. It runs the
// same `Uninstall` and `Scrub` as `pgr_install` and the scripts, so there is one
// implementation of each. `Plans/Release DMG.md`.
//
// **It installs nothing when it launches**, unlike `Photos-Go-Round.app`: it
// does not link the app's launch-time install, so opening it cannot restart the
// agent it is about to remove.
@main
struct UninstallerApp: App {
    @NSApplicationDelegateAdaptor private var delegate: UninstallerDelegate
    @State private var model = UninstallerModel()

    var body: some Scene {
        Window("Uninstall Photos-Go-Round", id: "uninstall") {
            UninstallerView(model: model)
                .frame(width: 480)
                .fixedSize(horizontal: false, vertical: true)
        }
        .windowResizability(.contentSize)
    }
}

/// One window, so closing it is quitting.
final class UninstallerDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
