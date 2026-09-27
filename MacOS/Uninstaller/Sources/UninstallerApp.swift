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
                .windowDismissBehavior(.disabled)
                .background(WindowPlacer())
        }
        .windowResizability(.contentSize)
        // Never where it was last time: a restored frame would win over the placement.
        .restorationBehavior(.disabled)
        .commands {
            // **Only Cancel, Uninstall and OK end it.** Syd, 2026-09-27: "the
            // uninstaller's quit menu should be disabled. You have to hit
            // 'Cancel' or 'Uninstall'." So Quit is shown disabled, the window
            // has no working close button, and a Quit from anywhere else — the
            // Dock, a logout — is refused until one of the buttons is pressed.
            CommandGroup(replacing: .appTermination) {
                Button("Quit Uninstall Photos-Go-Round") {}
                    .keyboardShortcut("q")
                    .disabled(true)
            }
        }
    }
}

final class UninstallerDelegate: NSObject, NSApplicationDelegate {
    /// Set by the window's own buttons, and nothing else.
    static var mayQuit = false

    static func quit() {
        mayQuit = true
        NSApp.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Self.mayQuit ? .terminateNow : .terminateCancel
    }
}

/// Puts the window where the HIG puts a new one: its middle on the middle of
/// its screen across, and a little above the middle down — 40% of the space
/// left over above it, 60% below. Syd, 2026-09-27: "I just want it to appear
/// close to the apple hig standard", then "the vertical center should be
/// aligned with the center of the display."
///
/// **Done here, in AppKit, once the window exists.** `defaultWindowPlacement`
/// with a unit point put it well left of centre, and `center()` from
/// `onAppear` ran before SwiftUI had placed it.
private struct WindowPlacer: NSViewRepresentable {
    func makeNSView(context: Context) -> PlacingView { PlacingView() }
    func updateNSView(_ view: PlacingView, context: Context) {}

    final class PlacingView: NSView {
        private var placed = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard !placed, let window else { return }
            placed = true
            forgetPosition(window)
            DispatchQueue.main.async {
                // Again after SwiftUI's own setup, which names the frame for saving.
                self.forgetPosition(window)
                guard let visible = (window.screen ?? NSScreen.main)?.visibleFrame else { return }
                let size = window.frame.size
                let origin = NSPoint(
                    x: visible.midX - size.width / 2,
                    y: visible.minY + (visible.height - size.height) * 0.6)
                window.setFrameOrigin(origin)
            }
        }

        /// **Nothing about where the window was is kept.** Syd, 2026-09-27: "can
        /// you disable saving the window position at all for the uninstaller
        /// app?" No frame autosave — SwiftUI had written `NSWindow Frame
        /// uninstall` to the app's defaults — and no state restoration.
        private func forgetPosition(_ window: NSWindow) {
            window.setFrameAutosaveName("")
            window.isRestorable = false
        }
    }
}
