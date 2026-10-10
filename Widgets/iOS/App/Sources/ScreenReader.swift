// Finds the window the app is in, and through it the screen. `UIScreen.main`
// is deprecated: an app is to ask the window it is shown in, and it has no
// window until its first view is on screen.

import SwiftUI
import UIKit

/// An invisible view that reports its window once it is in one.
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
            guard let window, window.windowScene != nil else { return }
            found?(window)
        }
    }
}
