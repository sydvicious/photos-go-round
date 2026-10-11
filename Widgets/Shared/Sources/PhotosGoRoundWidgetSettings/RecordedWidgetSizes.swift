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
    /// system's own name for the family. Every different size is kept, the
    /// latest last: a device with two screens, or one that is turned, hands a
    /// family more than one. A family the app does not offer, and a size of
    /// nothing, are passed over.
    public func record(_ size: CGSize, forFamily name: String) {
        guard size.width > 0, size.height > 0, WidgetFamily(kitName: name) != nil else { return }
        let defaults = defaults
        var stored = defaults.dictionary(forKey: Self.key) as? [String: [Double]] ?? [:]
        var sizes = Self.sizes(in: stored[name] ?? [])
        // A widget is asked often, and nearly always for the size it had last.
        guard sizes.last != size else { return }
        sizes.removeAll { $0 == size }
        sizes.append(size)
        stored[name] = sizes.suffix(Self.most).flatMap { [Double($0.width), Double($0.height)] }
        defaults.set(stored, forKey: Self.key)
    }

    /// The least a screen keeps beside its widgets, across and down, for its
    /// margins, its dock and a side column. Fitted to the Duo: where a set is
    /// used it leaves 119 points or more, and where it is not it would leave
    /// 64 or fewer.
    private static let room: CGFloat = 100

    /// As many sizes as are kept for one family. A device has a screen or
    /// two, each upright or on its side.
    private static let most = 8

    /// Widths and heights by turns, which is how a family's sizes are stored.
    private static func sizes(in numbers: [Double]) -> [CGSize] {
        stride(from: 0, to: numbers.count - 1, by: 2).map {
            CGSize(width: numbers[$0], height: numbers[$0 + 1])
        }
    }

    /// Every size that has been recorded for each family, the latest last.
    public var all: [WidgetFamily: [CGSize]] {
        let stored = defaults.dictionary(forKey: Self.key) as? [String: [Double]] ?? [:]
        var all: [WidgetFamily: [CGSize]] = [:]
        for (name, numbers) in stored {
            guard let family = WidgetFamily(kitName: name) else { continue }
            let sizes = Self.sizes(in: numbers)
            if !sizes.isEmpty { all[family] = sizes }
        }
        return all
    }

    /// The latest size a family was handed.
    public func size(of family: WidgetFamily) -> CGSize? {
        all[family]?.last
    }

    /// Of the sizes each family has been handed, the one that belongs to the
    /// screen the app is on.
    ///
    /// **The system does not say which screen a size is for**, so it is worked
    /// out. The sizes handed for one screen share their figures: medium, large
    /// and the tall size are one width, small is as tall as medium, and extra
    /// large as tall as large. So one family is settled first, by its width,
    /// and the others follow it.
    ///
    /// - **A phone:** the widest set that leaves room on the screen as it is
    ///   turned, across and down, and the narrowest when none does. The
    ///   iPhone Duo's widgets were handed two sets on 2026-10-10, 334 points
    ///   wide and 402, both at once whichever screen was in use. Syd's
    ///   pictures that day show where each is used:
    ///   - the cover, 466 by 678: the 334 set. It keeps a column at the right
    ///     for the clock and the dock, so 402 is too wide. Its Home Screen
    ///     does not turn.
    ///   - the inner screen upright, 669 by 951: the 402 set.
    ///   - the inner screen on its side, 951 by 669: the 334 set. The 402
    ///     set's tall size is 662 points high, which does not go in 669.
    /// - **An iPad:** the narrower for upright and the wider for on its side.
    ///   From Apple's table. The one iPad there are figures for, the iPad
    ///   mini's simulator on 2026-10-10, handed its widgets the same sizes
    ///   both ways up, so there the rule has nothing to choose between.
    ///
    /// Both rules are Claude's, 2026-10-10.
    public static func chosen(
        from all: [WidgetFamily: [CGSize]], for screen: CGSize?, on device: WidgetDevice
    ) -> [WidgetFamily: CGSize] {
        let latest = all.compactMapValues(\.last)
        guard let screen,
            let lead = [WidgetFamily.medium, .large, .extraLargePortrait].first(where: { all[$0] != nil }),
            let candidates = all[lead]
        else { return latest }

        let leading: CGSize?
        switch device {
        case .phone:
            /// How tall the tallest widget of the set this wide is: its tall
            /// size when that was handed, and otherwise reckoned from its
            /// large and medium, which the tall size is one of each and the
            /// gap between two mediums.
            func tallest(ofSetAsWideAs width: CGFloat) -> CGFloat? {
                func ofThisSet(_ family: WidgetFamily) -> CGSize? {
                    all[family]?.first { abs($0.width - width) < 1 }
                }
                if let tall = ofThisSet(.extraLargePortrait) { return tall.height }
                guard let large = ofThisSet(.large), let medium = ofThisSet(.medium) else { return nil }
                return 2 * large.height - medium.height
            }
            // A phone with one screen has one set, and it is the one whatever
            // it leaves; that is the narrowest when none leaves room.
            let leaveRoom = candidates.filter { size in
                guard screen.width - size.width >= Self.room else { return false }
                guard let tall = tallest(ofSetAsWideAs: size.width) else { return true }
                return screen.height - tall >= Self.room
            }
            leading =
                leaveRoom.max { $0.width < $1.width } ?? candidates.min { $0.width < $1.width }
        case .pad:
            leading =
                screen.height > screen.width
                ? candidates.min { $0.width < $1.width } : candidates.max { $0.width < $1.width }
        }
        guard let leading else { return latest }

        /// The latest of `sizes` nearest `figure` in the dimension `side` reads.
        func nearest(_ sizes: [CGSize]?, to figure: CGFloat, by side: (CGSize) -> CGFloat) -> CGSize? {
            sizes?.reversed().min { abs(side($0) - figure) < abs(side($1) - figure) }
        }

        var chosen: [WidgetFamily: CGSize] = [lead: leading]
        for family in [WidgetFamily.medium, .large, .extraLargePortrait] where family != lead {
            chosen[family] = nearest(all[family], to: leading.width) { $0.width }
        }
        // Small is as tall as medium, and extra large as tall as large.
        if let medium = chosen[.medium] {
            chosen[.small] = nearest(all[.small], to: medium.height) { $0.height }
        } else {
            chosen[.small] = latest[.small]
        }
        if let large = chosen[.large] {
            chosen[.extraLarge] = nearest(all[.extraLarge], to: large.height) { $0.height }
        } else {
            chosen[.extraLarge] = latest[.extraLarge]
        }
        return chosen
    }
}
