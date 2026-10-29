// What each widget offers in Edit Widget, on iOS and on the Mac alike: how
// often it changes, and how its pictures sit in it. `Plans/Widget
// Settings.md`, *In Edit Widget* and *On the Mac*.
//
// **Here, so both extensions offer the same.** Each extension has a settings
// type of its own whose parameters are these, and their names, cases and
// wording cannot drift apart. Syd, 2026-10-25, over a copy in each extension.
//
// **The system finds them through `PhotoWidgetChoices`**, which each
// extension's own `AppIntentsPackage` includes.
//
// **The names are kept once widgets are out**: a widget whose stored setting
// is of a kind that is gone takes the default. `Plans/PGR Widgets - iOS.md`,
// *The trial, and what was built*.

import AppIntents
import Foundation
import PhotosGoRoundAgentAPI

/// What lets the system find the choices below, which are kept in a package
/// and not in an extension.
public struct PhotoWidgetChoices: AppIntentsPackage {}

/// The durations offered, each by its length in seconds. Syd, 2026-10-08.
///
/// **Not one minute.** Each change of picture is a reload, and the system put
/// a 1-minute widget's reload five minutes on. Syd, 2026-10-08: "One minute
/// is dropped if the system won't honour it"; dropped 2026-10-11.
public enum ChangeEvery: Int, AppEnum, CaseIterable, Sendable {
    case fiveMinutes = 300
    case tenMinutes = 600
    case thirtyMinutes = 1800
    case oneHour = 3600
    case twoHours = 7200
    case fourHours = 14400
    case eightHours = 28800
    case oneDay = 86400

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Duration"

    public static let caseDisplayRepresentations: [ChangeEvery: DisplayRepresentation] = [
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
    public var seconds: TimeInterval { TimeInterval(rawValue) }
}

/// How a widget's pictures sit in it: as the app says, or a choice of its
/// own. Each of its own is stored by `Framing`'s name for it.
public enum WidgetFraming: String, AppEnum, CaseIterable, Sendable {
    case asInTheApp = "as-in-the-app"
    case fit
    case fill
    case actualSize = "actual-size"

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Pictures"

    public static let caseDisplayRepresentations: [WidgetFraming: DisplayRepresentation] = [
        .asInTheApp: "As in the app",
        .fit: "Fit",
        .fill: "Fill",
        .actualSize: "Actual Size",
    ]

    /// What the widget does, given what the app is set to.
    public func resolved(app: Framing) -> Framing {
        Framing(rawValue: rawValue) ?? app
    }
}

extension WidgetPictures {
    /// One cache for each setting at each size, which is as near as there is
    /// to one for each widget: `systemSmall-300`, and `systemSmall-300-fill`
    /// for a widget whose pictures fill it.
    ///
    /// - Parameter family: The widget's size, as WidgetKit names it.
    public static func folder(forFamily family: String, every: ChangeEvery, framing: Framing) -> String {
        "\(family)-\(every.rawValue)" + CachedPreviewPictures.suffix(for: framing)
    }
}
