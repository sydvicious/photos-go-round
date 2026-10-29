// Each widget's own settings: how often it changes, and how its pictures sit
// in it. `Plans/PGR Widgets - iOS.md`, *Telling one widget from another*, and
// `Plans/Widget Settings.md`, *In Edit Widget*.
//
// **How often is a menu of durations.** Syd, 2026-10-11. Which photographs a
// widget shows is the app's to say, for every widget alike.
//
// **How the pictures sit starts at "As in the app".** The app cannot write a
// placed widget's settings, so the app's setting is every widget's until the
// widget makes a choice of its own. Syd, 2026-10-25.
//
// **A fixed list, so the system draws it as a menu and ticks the one a widget
// is set to.** Syd, 2026-10-11: "a control that brings up a menu should look
// like a menu, not a button", and "The tick is more important than the
// hair-brained scheme to try to have two same-size widgets with the same
// duration showing different pictures". That scheme was a delay made up for
// each line of the menu, which made every line a new value: the system then
// drew a button and ticked nothing.
//
// **So two widgets of one size set alike are one widget.** The system asks
// once for each different setting at each size, and they show the same
// picture.
//
// **The names are kept once widgets are out**: a widget whose settings type
// is gone stops reloading.
//
// **What it offers is shared with the Mac's widget**, in
// `PhotosGoRoundWidgetSettings`: `ChangeEvery` and `WidgetFraming`.

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
