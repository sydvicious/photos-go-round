// Which chosen sources have had a picture passed over by a widget, kept where
// the app can read it. `Plans/PGR Widgets - iOS.md`, *The guard*.
//
// **A widget cannot show every picture.** One that would take more memory to
// shrink than an extension is held to is passed over for another, and the
// person is told by a note in the app. Syd, 2026-10-12: "if the guard is ever
// triggered, we should add a note at the bottom of the apps windows that says
// that some of the pictures in your choices may not be able to appear in
// widgets", which stays "until that source goes away".
//
// **In the App Group's preferences**, which the extension writes and the app
// reads, each in its own process. `RecordedWidgetSizes` is kept the same way.

import Foundation
import PhotosGoRoundAgentAPI

public struct SkippedPictures: Sendable {
    private let suiteName: String?

    private static let key = "PGRWidgetSkippedPictures"

    /// - Parameter suiteName: The App Group's preferences domain.
    public init(suiteName: String?) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    /// A folder is the same source with its subfolders or without.
    private static func name(of source: SourceSpec) -> String {
        "\(source.kind.rawValue)|\(source.locator)"
    }

    private var recorded: [String] { defaults.stringArray(forKey: Self.key) ?? [] }

    /// Notes that a picture in this source was passed over.
    public func record(_ source: SourceSpec) {
        let name = Self.name(of: source)
        let recorded = recorded
        // A widget passes the same picture over each time it comes up.
        guard !recorded.contains(name) else { return }
        defaults.set(recorded + [name], forKey: Self.key)
    }

    /// Whether this source has had a picture passed over.
    public func holds(_ source: SourceSpec) -> Bool {
        recorded.contains(Self.name(of: source))
    }

    /// Whether any of these has had a picture passed over.
    public func holds(anyOf sources: [SourceSpec]) -> Bool {
        let recorded = Set(recorded)
        return sources.contains { recorded.contains(Self.name(of: $0)) }
    }

    /// Forgets every source but these: one that is no longer chosen takes
    /// its record with it.
    public func keep(only sources: [SourceSpec]) {
        let chosen = Set(sources.map(Self.name))
        let recorded = recorded
        let kept = recorded.filter(chosen.contains)
        guard kept.count != recorded.count else { return }
        defaults.set(kept, forKey: Self.key)
    }
}
