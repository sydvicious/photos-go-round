// Photos-Go-Round Widgets on iOS and iPadOS: the app that carries the widgets,
// and where a person says which photographs they show.
// `Plans/PGR Widgets - iOS.md`.

import PhotosGoRoundAgentAPI
import PhotosGoRoundPhotoLibrary
import PhotosGoRoundWidgetSettings
import PhotosUI
import SwiftUI
import WidgetKit

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

    @Environment(\.scenePhase) private var scenePhase

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
        // When a person leaves the app, the widgets look at what is chosen
        // now. A widget with nothing to show otherwise waits a quarter of an
        // hour before it asks again.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                WidgetCenter.shared.reloadAllTimelines()
            }
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
    ///
    /// **The target links PhotosUI by name** (`OTHER_LDFLAGS`). The picker is
    /// an Objective-C category in that framework, reached by a message and
    /// not by a symbol, so the linker saw nothing of PhotosUI in use and left
    /// it out. It worked where something else had loaded the framework, and
    /// on the iPhone Duo simulator, 2026-10-10, it was an unrecognized
    /// selector.
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
