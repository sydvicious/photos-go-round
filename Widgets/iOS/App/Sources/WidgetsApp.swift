// Photos-Go-Round Widgets on iOS and iPadOS: the app that carries the widgets,
// and where a person says which photographs they show.
// `Plans/PGR Widgets - iOS.md`.

import PhotosGoRoundAgentAPI
import PhotosGoRoundWidgetSettings
import SwiftUI

@main
struct WidgetsApp: App {
    @State private var model = SettingsModel(sources: ChosenSources(preferences: Self.shared))

    var body: some Scene {
        WindowGroup {
            SettingsView(model: model)
        }
    }

    /// The App Group's preferences, which the widget extension reads too. The
    /// group's name is in `Info.plist` because it differs by configuration.
    private static var shared: Preferences {
        Preferences(suiteName: Bundle.main.object(forInfoDictionaryKey: "PGRWidgetAppGroup") as? String)
    }
}
