import Foundation
import Testing

@testable import PhotosGoRoundInstall

/// Reading what `lsregister -dump Plugin` prints.
///
/// **The failure this guards against is a widget left on the desktop.** The
/// system keeps a placed widget while LaunchServices holds any record of its
/// extension, and a record of a build that has been deleted is one `pluginkit`
/// does not list. So the uninstaller reads them here.
/// `Plans/Photos-Go-Round Widgets.md`, *Uninstalling the widgets*.
@Suite("What LaunchServices holds a record of")
struct LaunchServicesTests {

    /// Two records, cut down from a dump taken 2026-10-09 to the lines that
    /// matter and a few that must not: a record's own fields start a line, and
    /// its `Info.plist` is printed beneath them, indented.
    private static let dump = """
        --------------------------------------------------------------------------------
        plugin id:                  DrawerButtonExtension (0x4fd8)
        container:                  / (0x4)
        path:                       /Applications/Default Folder X.app/Contents/PlugIns/DrawerButtonExtension.appex (0xf3a4)
        directory:                  /Applications
        name:                       DrawerButtonExtension
        identifier:                 com.stclairsoft.DefaultFolderX5.DrawerButtonExtension
        codeInfoID:                 com.stclairsoft.DefaultFolderX5.DrawerButtonExtension
        infoDictionary:             2 values (1234 (0x4d2))
                                    {
                                        CFBundleIdentifier = "com.stclairsoft.DefaultFolderX5.DrawerButtonExtension";
                                        path = "/not/a/record's/path";
                                    }
        --------------------------------------------------------------------------------
        plugin id:                  Photos-Go-Round Widget (Debug) (0x96d8)
        container:                  / (0x4)
        path:                       /Users/syd/DerivedData/Build/Products/Debug/Photos-Go-Round.app/Contents/PlugIns/Photos-Go-Round Widget.appex (0x1c680)
        directory:                  ~/Library
        name:                       Photos-Go-Round Widget
        identifier:                 com.sydpolk.photosgoround.widget.debug
        codeInfoID:                 com.sydpolk.photosgoround.widget.debug
        """

    @Test("Each record gives its identifier and its path, without the number after the path")
    func recordsAreRead() {
        #expect(LaunchServices.parseExtensionRecords(Self.dump) == [
            .init(
                identifier: "com.stclairsoft.DefaultFolderX5.DrawerButtonExtension",
                path: "/Applications/Default Folder X.app/Contents/PlugIns/DrawerButtonExtension.appex"),
            .init(
                identifier: "com.sydpolk.photosgoround.widget.debug",
                path: "/Users/syd/DerivedData/Build/Products/Debug/Photos-Go-Round.app/Contents/PlugIns/Photos-Go-Round Widget.appex"),
        ])
    }

    @Test("A record with no path or no identifier is left out")
    func halfARecordIsLeftOut() {
        let dump = """
            --------------------------------------------------------------------------------
            plugin id:                  No path (0x1)
            identifier:                 com.example.nopath
            --------------------------------------------------------------------------------
            plugin id:                  No identifier (0x2)
            path:                       /Applications/Example.app/Contents/PlugIns/Example.appex (0x3)
            """
        #expect(LaunchServices.parseExtensionRecords(dump).isEmpty)
    }

    @Test("Nothing printed gives no records")
    func nothingPrinted() {
        #expect(LaunchServices.parseExtensionRecords("").isEmpty)
    }

    /// `lsregister -u` on the app is what was measured to remove a deleted
    /// build's extension record, 2026-10-09.
    @Test("An extension inside an app is forgotten by forgetting the app")
    func theAppHoldingAnExtension() {
        #expect(
            LaunchServices.registeredBundle(
                holding: "/Applications/Photos-Go-Round.app/Contents/PlugIns/Photos-Go-Round Widget.appex")
                == "/Applications/Photos-Go-Round.app")
        #expect(
            LaunchServices.registeredBundle(
                holding: "/Applications/Host.app/Contents/Extensions/Wallpaper.appex")
                == "/Applications/Host.app")
    }

    @Test("An extension that is in no app is forgotten by its own path")
    func anExtensionOnItsOwn() {
        #expect(
            LaunchServices.registeredBundle(holding: "/Users/syd/Build/Photos-Go-Round Widget.appex")
                == "/Users/syd/Build/Photos-Go-Round Widget.appex")
    }
}
