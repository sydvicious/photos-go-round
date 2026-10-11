// The sizes the system has handed the widgets, kept where the app can read
// them. `Plans/PGR Widgets - iOS.md`, *The sizes the preview can take*.
//
// **The only place a widget's real size can be learned.** Apple's table has no
// row for some devices, the iPhone Duo among them, and no figure at all for
// the tall fourth size. The system tells a widget its size each time it asks
// for a timeline or a snapshot, so the extension writes that down, and the
// preview uses it in place of the table.
//
// **In the App Group's preferences**, which the extension writes and the app
// reads, each in its own process.

import CoreGraphics
import Foundation

public struct RecordedWidgetSizes: Sendable {
    private let suiteName: String?

    private static let key = "PGRWidgetSizes"

    /// - Parameter suiteName: The App Group's preferences domain.
    public init(suiteName: String?) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    /// Keeps the size the system handed a widget of this family, under the
    /// system's own name for the family. The latest is the one kept. A family
    /// the app does not offer, and a size of nothing, are passed over.
    public func record(_ size: CGSize, forFamily name: String) {
        guard size.width > 0, size.height > 0, WidgetFamily(kitName: name) != nil else { return }
        let defaults = defaults
        var stored = defaults.dictionary(forKey: Self.key) as? [String: [Double]] ?? [:]
        let value = [Double(size.width), Double(size.height)]
        // A widget is asked often, and nearly always for the size it had.
        guard stored[name] != value else { return }
        stored[name] = value
        defaults.set(stored, forKey: Self.key)
    }

    /// Every size that has been recorded.
    public var all: [WidgetFamily: CGSize] {
        let stored = defaults.dictionary(forKey: Self.key) as? [String: [Double]] ?? [:]
        var sizes: [WidgetFamily: CGSize] = [:]
        for (name, value) in stored {
            guard let family = WidgetFamily(kitName: name), value.count == 2 else { continue }
            sizes[family] = CGSize(width: value[0], height: value[1])
        }
        return sizes
    }

    public func size(of family: WidgetFamily) -> CGSize? {
        all[family]
    }
}
