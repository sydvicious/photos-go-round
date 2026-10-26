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

import AppIntents
import PhotosGoRoundAgentAPI
import WidgetKit

struct PhotoWidgetSettings: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Photographs"

    @Parameter(title: "Change Every", default: .fiveMinutes) var every: ChangeEvery
    @Parameter(title: "Pictures", default: .asInTheApp) var framing: WidgetFraming
}

/// The durations offered, each by its length in seconds. Syd, 2026-10-08.
///
/// **Not one minute.** Each change of picture is a reload, and the system put
/// a 1-minute widget's reload five minutes on. Syd, 2026-10-08: "One minute
/// is dropped if the system won't honour it"; dropped 2026-10-11.
enum ChangeEvery: Int, AppEnum, CaseIterable {
    case fiveMinutes = 300
    case tenMinutes = 600
    case thirtyMinutes = 1800
    case oneHour = 3600
    case twoHours = 7200
    case fourHours = 14400
    case eightHours = 28800
    case oneDay = 86400

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Duration"

    static let caseDisplayRepresentations: [ChangeEvery: DisplayRepresentation] = [
        .fiveMinutes: "5 minutes",
        .tenMinutes: "10 minutes",
        .thirtyMinutes: "30 minutes",
        .oneHour: "1 hour",
        .twoHours: "2 hours",
        .fourHours: "4 hours",
        .eightHours: "8 hours",
        .oneDay: "24 hours",
    ]

    /// How long a picture stays up.
    var seconds: TimeInterval { TimeInterval(rawValue) }
}

/// How a widget's pictures sit in it: as the app says, or a choice of its
/// own. Each of its own is stored by `Framing`'s name for it.
enum WidgetFraming: String, AppEnum, CaseIterable {
    case asInTheApp = "as-in-the-app"
    case fit
    case fill
    case actualSize = "actual-size"

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Pictures"

    static let caseDisplayRepresentations: [WidgetFraming: DisplayRepresentation] = [
        .asInTheApp: "As in the app",
        .fit: "Fit",
        .fill: "Fill",
        .actualSize: "Actual Size",
    ]

    /// What the widget does, given what the app is set to.
    func resolved(app: Framing) -> Framing {
        Framing(rawValue: rawValue) ?? app
    }
}
