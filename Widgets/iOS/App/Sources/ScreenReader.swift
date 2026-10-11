// Finds the window the app is in, and through it the screen. `UIScreen.main`
// is deprecated: an app is to ask the window it is shown in, and it has no
// window until its first view is on screen.

import SwiftUI
import UIKit

/// An invisible view that reports its window once it is in one, and again
/// each time it is laid out.
///
/// **Again, because the screen can change under a running app.** The iPhone
/// Duo has two, and unfolding it moves the app from one to the other without
/// giving it a new window. Reported once, the app went on previewing the
/// cover's widgets on the inner screen; Syd's pictures, 2026-10-10.
struct ScreenReader: UIViewRepresentable {
    let found: (UIWindow) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = Reporter()
        view.found = found
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {}

    private final class Reporter: UIView {
        var found: ((UIWindow) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        /// Its size follows the app's, so this comes with every change of
        /// screen, of orientation and of an iPad window's size.
        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        private func report() {
            guard let window, window.windowScene != nil else { return }
            found?(window)
        }
    }
}
