// How big a widget is, on which device. `Plans/PGR Widgets - iOS.md`, *How the
// preview is drawn*.
//
// **Apple's table, as a stand-in.** Syd, 2026-10-09, chose the real sizes to
// come from the system: the widget extension records each size it is handed
// and the preview reads them. Until there is an extension, and on a device
// where the widget gallery has not yet asked, the preview uses the table in
// Apple's design guidelines, read 2026-10-10. Widgets differ in size from one
// phone to the next, so a single set of sizes would be wrong on most of them.
//
// **Home Screen sizes only.** The Lock Screen's own sizes are not built.

import CoreGraphics

public enum WidgetFamily: String, CaseIterable, Identifiable, Sendable {
    case small, medium, large, extraLarge

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }
}

public enum WidgetDevice: Sendable { case phone, pad }

public enum WidgetSizes {
    /// The sizes a device's Home Screen offers. The really big ones are not on
    /// a phone.
    public static func families(on device: WidgetDevice) -> [WidgetFamily] {
        switch device {
        case .phone: [.small, .medium, .large]
        case .pad: [.small, .medium, .large, .extraLarge]
        }
    }

    /// A widget's size in points on a device with this screen, or nil when the
    /// device has no widget of that size.
    ///
    /// A screen the table does not list gets the row for the nearest one, and
    /// may be a few points out. The screen may be given either way up.
    public static func size(of family: WidgetFamily, on device: WidgetDevice, screen: CGSize) -> CGSize? {
        let short = min(screen.width, screen.height)
        let long = max(screen.width, screen.height)
        let rows = device == .phone ? phones : pads
        let row = rows.min { a, b in
            abs(a.short - short) + abs(a.long - long) < abs(b.short - short) + abs(b.long - long)
        }
        guard let row else { return nil }
        switch family {
        case .small: return CGSize(width: row.small, height: row.small)
        case .medium: return CGSize(width: row.wide, height: row.mediumHeight)
        case .large: return CGSize(width: row.wide, height: row.largeHeight)
        case .extraLarge: return row.extraWide.map { CGSize(width: $0, height: row.largeHeight) }
        }
    }

    /// One screen's widgets. Small is square; medium and large are as wide as
    /// each other; extra large is as tall as large.
    private struct Row {
        let short: CGFloat
        let long: CGFloat
        let small: CGFloat
        let wide: CGFloat
        let mediumHeight: CGFloat
        let largeHeight: CGFloat
        let extraWide: CGFloat?
    }

    private static func phone(
        _ short: CGFloat, _ long: CGFloat, small: CGFloat, medium: (CGFloat, CGFloat), large: CGFloat
    ) -> Row {
        Row(
            short: short, long: long, small: small, wide: medium.0, mediumHeight: medium.1,
            largeHeight: large, extraWide: nil)
    }

    private static func pad(
        _ short: CGFloat, _ long: CGFloat, small: CGFloat, wide: CGFloat, extraWide: CGFloat
    ) -> Row {
        Row(
            short: short, long: long, small: small, wide: wide, mediumHeight: small,
            largeHeight: wide, extraWide: extraWide)
    }

    private static let phones: [Row] = [
        phone(430, 932, small: 170, medium: (364, 170), large: 382),
        phone(428, 926, small: 170, medium: (364, 170), large: 382),
        phone(414, 896, small: 169, medium: (360, 169), large: 379),
        phone(414, 736, small: 159, medium: (348, 157), large: 357),
        phone(393, 852, small: 158, medium: (338, 158), large: 354),
        phone(390, 844, small: 158, medium: (338, 158), large: 354),
        phone(375, 812, small: 155, medium: (329, 155), large: 345),
        phone(375, 667, small: 148, medium: (321, 148), large: 324),
        phone(360, 780, small: 155, medium: (329, 155), large: 345),
        phone(320, 568, small: 141, medium: (292, 141), large: 311),
    ]

    /// The table's *Device* rows. It gives an iPad's sizes upright only.
    private static let pads: [Row] = [
        pad(768, 1024, small: 120, wide: 260, extraWide: 540),
        pad(744, 1133, small: 120, wide: 260, extraWide: 540),
        pad(810, 1080, small: 124, wide: 272, extraWide: 568),
        pad(820, 1180, small: 136, wide: 300, extraWide: 628),
        pad(834, 1112, small: 132, wide: 288, extraWide: 600),
        pad(834, 1194, small: 136, wide: 300, extraWide: 628),
        pad(954, 1373, small: 162, wide: 350, extraWide: 726),
        pad(970, 1389, small: 162, wide: 350, extraWide: 726),
        pad(1024, 1366, small: 160, wide: 356, extraWide: 748),
        pad(1192, 1590, small: 188, wide: 412, extraWide: 860),
    ]
}
