import Foundation
import PhotosGoRoundAgentAPI
import Testing

@testable import PhotosGoRoundWidgetSettings

/// Syd, 2026-10-31: "try to display the same pic in a widget when changing
/// widget fit/fill/actual size settings". A wake is not told why it came, so
/// which setting a widget had before is worked out from the settings woken
/// before and the ones placed now.
@Suite("Which setting a widget had before its settings were changed")
struct WokenSettingsTests {
    func setting(_ framing: Framing, family: String = "systemSmall", every: ChangeEvery = .fiveMinutes)
        -> WidgetSetting
    {
        WidgetSetting(family: family, every: every, framing: framing)
    }

    @Test("A setting's first wake, with nothing woken before, replaced nothing")
    func firstWake() throws {
        let root = try ScratchFolder()
        let woken = WokenSettings(in: root.url)

        #expect(woken.woke(setting(.fit), placed: [setting(.fit)]) == nil)
    }

    @Test("A setting woken in place of one no widget has now replaced that one, once")
    func replaced() throws {
        let root = try ScratchFolder()
        let woken = WokenSettings(in: root.url)
        _ = woken.woke(setting(.fit), placed: [setting(.fit)])

        #expect(woken.woke(setting(.fill), placed: [setting(.fill)]) == setting(.fit))
        #expect(woken.woke(setting(.fill), placed: [setting(.fill)]) == nil)
    }

    @Test("A setting another widget still has was not replaced: a new widget beside it is new")
    func stillPlaced() throws {
        let root = try ScratchFolder()
        let woken = WokenSettings(in: root.url)
        _ = woken.woke(setting(.fit), placed: [setting(.fit)])

        #expect(woken.woke(setting(.fill), placed: [setting(.fit), setting(.fill)]) == nil)
    }

    /// The system gives two widgets with the same settings one timeline, so
    /// the other widget changes to the changed one's picture. Syd,
    /// 2026-11-01, over the changed widget taking the other's.
    @Test("A widget changed to the setting another widget of its size has replaced the one it had")
    func changedToAnothersSetting() throws {
        let root = try ScratchFolder()
        let woken = WokenSettings(in: root.url)
        let before: Set = [setting(.fit), setting(.fill)]
        _ = woken.woke(setting(.fit), placed: before)
        _ = woken.woke(setting(.fill), placed: before)

        #expect(woken.woke(setting(.fill), placed: [setting(.fill)]) == setting(.fit))
        #expect(woken.woke(setting(.fill), placed: [setting(.fill)]) == nil)
    }

    @Test("A setting woken again, with nothing of its size changed, replaced nothing")
    func wokenAgain() throws {
        let root = try ScratchFolder()
        let woken = WokenSettings(in: root.url)
        let placed: Set = [setting(.fit), setting(.fill)]
        _ = woken.woke(setting(.fit), placed: placed)
        _ = woken.woke(setting(.fill), placed: placed)

        #expect(woken.woke(setting(.fill), placed: placed) == nil)
    }

    @Test("Only a setting of the same size is replaced")
    func sameSize() throws {
        let root = try ScratchFolder()
        let woken = WokenSettings(in: root.url)
        _ = woken.woke(setting(.fit, family: "systemLarge"), placed: [setting(.fit, family: "systemLarge")])

        #expect(
            woken.woke(setting(.fill), placed: [setting(.fill), setting(.fill, family: "systemLarge")]) == nil)
    }

    /// Syd, 2026-11-01: "please make it where changing the interval keeps
    /// the same picture as well".
    @Test("A widget given another interval replaced the setting it had")
    func anotherInterval() throws {
        let root = try ScratchFolder()
        let woken = WokenSettings(in: root.url)
        _ = woken.woke(setting(.fit), placed: [setting(.fit)])

        #expect(woken.woke(setting(.fit, every: .oneHour), placed: [setting(.fit, every: .oneHour)]) == setting(.fit))
    }

    @Test("A widget given another interval and another framing at once replaced the setting it had")
    func anotherIntervalAndFraming() throws {
        let root = try ScratchFolder()
        let woken = WokenSettings(in: root.url)
        _ = woken.woke(setting(.fit), placed: [setting(.fit)])

        #expect(
            woken.woke(setting(.fill, every: .oneHour), placed: [setting(.fill, every: .oneHour)]) == setting(.fit))
    }

    /// The app's own Fit, Fill or Actual Size changed, and every widget
    /// following it was reloaded at once.
    @Test("Two widgets changed at once each find the setting they had, by its interval")
    func twoAtOnce() throws {
        let root = try ScratchFolder()
        let woken = WokenSettings(in: root.url)
        let before: Set = [setting(.fit), setting(.fit, every: .oneHour)]
        _ = woken.woke(setting(.fit), placed: before)
        _ = woken.woke(setting(.fit, every: .oneHour), placed: before)
        let after: Set = [setting(.fill), setting(.fill, every: .oneHour)]

        #expect(woken.woke(setting(.fill, every: .oneHour), placed: after) == setting(.fit, every: .oneHour))
        #expect(woken.woke(setting(.fill), placed: after) == setting(.fit))
    }

    @Test("It is kept from one wake to the next, which may be another process")
    func kept() throws {
        let root = try ScratchFolder()
        _ = WokenSettings(in: root.url).woke(setting(.fit), placed: [setting(.fit)])

        #expect(WokenSettings(in: root.url).woke(setting(.fill), placed: [setting(.fill)]) == setting(.fit))
    }

    @Test("The caches kept are the placed settings', and those of settings not yet replaced")
    func folders() throws {
        let root = try ScratchFolder()
        let woken = WokenSettings(in: root.url)
        _ = woken.woke(setting(.fit), placed: [setting(.fit)])
        let changed: Set = [setting(.fill)]

        #expect(woken.folders(placed: changed) == [setting(.fit).folder, setting(.fill).folder])

        _ = woken.woke(setting(.fill), placed: changed)
        #expect(woken.folders(placed: changed) == [setting(.fill).folder])
    }

    @Test("A size no widget has any more is forgotten, so its cache is cleared away")
    func sizeGone() throws {
        let root = try ScratchFolder()
        let woken = WokenSettings(in: root.url)
        _ = woken.woke(setting(.fit), placed: [setting(.fit)])

        #expect(woken.folders(placed: [setting(.fit, family: "systemLarge")]) == [setting(.fit, family: "systemLarge").folder])
    }

    @Test("A setting's cache is the widget's own folder")
    func folder() {
        #expect(setting(.fill).folder == WidgetPictures.folder(forFamily: "systemSmall", every: .fiveMinutes, framing: .fill))
    }
}
