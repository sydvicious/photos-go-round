// Photos-Go-Round Widgets on iOS and iPadOS: the app that carries the widgets,
// and where a person says which photographs they show.
// `Plans/PGR Widgets - iOS.md`.

import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary
import PhotosGoRoundWidgetSettings
import PhotosUI
import SwiftUI

@main
struct WidgetsApp: App {
    @State private var model = SettingsModel(
        sources: ChosenSources(preferences: Self.shared), library: SystemPhotoLibrary(),
        preview: PreviewModel(
            pictures: Self.pictures,
            device: Self.device,
            // Not known until there is a window; `ScreenReader` supplies it.
            screen: nil, scale: 1),
        // The same thing counts for the rows and picks for the preview, so
        // a source is counted once.
        counts: Self.pictures)

    var body: some Scene {
        WindowGroup {
            SettingsView(model: model, selectPhotos: Self.selectPhotos)
                .background(
                    ScreenReader { window in
                        guard let scene = window.windowScene else { return }
                        // A widget's size goes by the screen, not by the window
                        // the app happens to have on an iPad.
                        let screen = scene.screen
                        model.preview.use(screen: screen.bounds.size, scale: screen.scale)
                        Self.limit(scene, in: window, on: screen)
                    })
        }
    }

    private static let device: WidgetDevice =
        UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone

    /// Keeps an iPad's window from being dragged smaller than the screen can
    /// be used at: a small widget shown whole, the size control, the "Photos"
    /// heading with its button, and one row. Syd, 2026-10-10. The layout's own
    /// figure is for what is inside the window's margins, so those are added.
    private static func limit(_ scene: UIWindowScene, in window: UIWindow, on screen: UIScreen) {
        guard let small = WidgetSizes.size(of: .small, on: device, screen: screen.bounds.size) else { return }
        let inside = SettingsLayout.minimumWindow(forSmallWidget: small)
        let margins = window.safeAreaInsets
        scene.sizeRestrictions?.minimumSize = CGSize(
            width: inside.width + margins.left + margins.right,
            height: inside.height + margins.top + margins.bottom)
    }

    /// The system's picker for which photographs the app may see, with limited
    /// access. It comes up over the window the person is in. Syd, 2026-10-09.
    private static func selectPhotos() async {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        guard let controller = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController
        else { return }
        _ = await PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
    }

    private static let pictures = CachedPreviewPictures(directory: previewCache)

    /// Where the preview keeps its pictures: the app's own, apart from any
    /// widget's.
    private static var previewCache: URL {
        URL.cachesDirectory.appending(path: "Preview", directoryHint: .isDirectory)
    }

    /// The App Group's preferences, which the widget extension reads too. The
    /// group's name is in `Info.plist` because it differs by configuration.
    private static var shared: Preferences {
        Preferences(suiteName: Bundle.main.object(forInfoDictionaryKey: "PGRWidgetAppGroup") as? String)
    }
}
