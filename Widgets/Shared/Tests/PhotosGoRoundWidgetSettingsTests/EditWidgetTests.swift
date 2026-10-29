import PhotosGoRoundAgentAPI
import Testing

@testable import PhotosGoRoundWidgetSettings

/// What each widget is set to in Edit Widget, on iOS and on the Mac alike, and
/// the cache it keeps for it. `Plans/Widget Settings.md`, *In Edit Widget* and
/// *On the Mac*.
@Suite("Each widget's own settings")
struct EditWidgetTests {
    // MARK: Pictures

    @Test("A widget following the app does what the app says", arguments: Framing.allCases)
    func followsTheApp(_ app: Framing) {
        #expect(WidgetFraming.asInTheApp.resolved(app: app) == app)
    }

    @Test(
        "A widget's own choice is its own, whatever the app says",
        arguments: [WidgetFraming.fit, .fill, .actualSize], Framing.allCases)
    func ownChoice(_ own: WidgetFraming, _ app: Framing) {
        #expect(own.resolved(app: app).rawValue == own.rawValue)
    }

    /// Stored in each placed widget's settings, so kept once widgets are out:
    /// a stored value of a kind that is gone is taken as the default.
    @Test("Each choice keeps its stored name")
    func framingNames() {
        #expect(WidgetFraming.allCases.map(\.rawValue) == ["as-in-the-app", "fit", "fill", "actual-size"])
    }

    @Test("Following the app is the first choice in the menu")
    func asInTheAppFirst() {
        #expect(WidgetFraming.allCases.first == .asInTheApp)
    }

    // MARK: Change Every

    @Test("Each duration keeps its stored length in seconds, and none is a minute")
    func durations() {
        #expect(ChangeEvery.allCases.map(\.rawValue) == [300, 600, 1800, 3600, 7200, 14400, 28800, 86400])
        #expect(ChangeEvery.oneHour.seconds == 3600)
    }

    // MARK: The cache

    @Test(
        "One cache for each size, duration and way of framing; Fit and Actual Size share one",
        arguments: [
            ("systemSmall", ChangeEvery.fiveMinutes, Framing.fit, "systemSmall-300"),
            ("systemSmall", .fiveMinutes, .actualSize, "systemSmall-300"),
            ("systemMedium", .fiveMinutes, .fill, "systemMedium-300-fill"),
            ("systemExtraLarge", .oneDay, .fill, "systemExtraLarge-86400-fill"),
        ])
    func folders(_ family: String, _ every: ChangeEvery, _ framing: Framing, _ name: String) {
        #expect(WidgetPictures.folder(forFamily: family, every: every, framing: framing) == name)
    }
}
