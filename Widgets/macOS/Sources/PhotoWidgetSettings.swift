// Each widget's own settings: how often it changes, and how its pictures sit
// in it. `Plans/Widget Settings.md`, *On the Mac*.
//
// **The iOS widget's, in a settings type of the Mac's own.** What it offers,
// `ChangeEvery` and `WidgetFraming`, is shared in
// `PhotosGoRoundWidgetSettings`, so the two panels cannot drift apart. Syd,
// 2026-10-25.
//
// **How the pictures sit starts at "As in the app"**, which is set in the
// app's Settings window.
//
// **The names are kept once widgets are out**: a widget whose settings type
// is gone stops reloading.

import AppIntents
import PhotosGoRoundWidgetSettings
import WidgetKit

struct PhotoWidgetSettings: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Photographs"

    @Parameter(title: "Change Every", default: .fiveMinutes) var every: ChangeEvery
    @Parameter(title: "Pictures", default: .asInTheApp) var framing: WidgetFraming
}

/// What lets the system find the choices this extension offers, which are
/// kept in the shared package.
struct PhotoWidgetIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [PhotoWidgetChoices.self] }
}
