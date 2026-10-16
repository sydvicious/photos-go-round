import CoreGraphics
import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundWidgetFace
import Synchronization
import Testing
import TinyCache

@testable import PhotosGoRoundWidgetSettings

/// A clock a test moves by hand.
final class TestClock: Sendable {
    private let moment = Mutex(Date(timeIntervalSinceReferenceDate: 800_000_000))

    var now: Date { moment.withLock { $0 } }

    func pass(_ seconds: TimeInterval) { moment.withLock { $0 += seconds } }
}

/// Pictures handed out from a script, with a note of what was asked for.
final class ScriptedPictures: PreviewPictures {
    /// `timeout` is Photos not answering in time.
    enum Answer { case picture(String), none, failure, timeout }

    private let script: Mutex<[Answer]>
    private let firsts: Mutex<[Answer]>
    private let lastTime: String?
    private let asked = Mutex<[CGSize]>([])
    private let called = Mutex<[String]>([])

    /// Which of its three questions it was asked, in order.
    var calls: [String] { called.withLock { $0 } }

    /// - Parameters:
    ///   - last: The picture it gave last time, if it has one kept.
    ///   - first: What it answers when asked for the first source's first
    ///     picture; with none scripted, that there is none.
    init(_ script: [Answer], last: String? = nil, first: [Answer] = []) {
        self.script = Mutex(script)
        self.firsts = Mutex(first)
        self.lastTime = last
    }

    func last(for sources: [SourceSpec], fitting box: CGSize) -> URL? {
        called.withLock { $0.append("last") }
        return lastTime.map { URL(filePath: "/pictures/\($0)") }
    }

    func first(from sources: [SourceSpec], fitting box: CGSize) throws -> URL? {
        called.withLock { $0.append("first") }
        let answer = firsts.withLock { $0.isEmpty ? Answer.none : $0.removeFirst() }
        switch answer {
        case .picture(let name): return URL(filePath: "/pictures/\(name)")
        case .none: return nil
        case .failure: throw CocoaError(.fileReadUnknown)
        case .timeout: throw TimedOut(after: .seconds(15))
        }
    }

    var boxesAsked: [CGSize] { asked.withLock { $0 } }

    func next(from sources: [SourceSpec], fitting box: CGSize) throws -> URL? {
        called.withLock { $0.append("next") }
        asked.withLock { $0.append(box) }
        let answer = script.withLock { $0.isEmpty ? Answer.none : $0.removeFirst() }
        switch answer {
        case .picture(let name): return URL(filePath: "/pictures/\(name)")
        case .none: return nil
        case .failure: throw CocoaError(.fileReadUnknown)
        case .timeout: throw TimedOut(after: .seconds(15))
        }
    }
}

/// Pictures whose first is held back until the test lets it go, so that what
/// is on screen meanwhile can be looked at.
final class HeldPictures: PreviewPictures {
    private let waiting = Mutex(false)
    private let gate = DispatchSemaphore(value: 0)

    /// Whether the first picture has been asked for and is being held.
    var isHoldingFirst: Bool { waiting.withLock { $0 } }

    func letGo() { gate.signal() }

    func last(for sources: [SourceSpec], fitting box: CGSize) -> URL? {
        URL(filePath: "/pictures/last.jpg")
    }

    func first(from sources: [SourceSpec], fitting box: CGSize) throws -> URL? {
        waiting.withLock { $0 = true }
        gate.wait()
        return URL(filePath: "/pictures/first.jpg")
    }

    func next(from sources: [SourceSpec], fitting box: CGSize) throws -> URL? {
        URL(filePath: "/pictures/next.jpg")
    }
}

/// Pictures that take a moment to fetch, and notice when two are fetched at once.
final class SlowPictures: PreviewPictures {
    private struct State {
        var running = 0
        var most = 0
        var asked = 0
    }
    private let state = Mutex(State())

    /// The most fetches that were ever under way at the same moment.
    var mostAtOnce: Int { state.withLock { $0.most } }
    var timesAsked: Int { state.withLock { $0.asked } }

    func next(from sources: [SourceSpec], fitting box: CGSize) throws -> URL? {
        let number = state.withLock { state -> Int in
            state.running += 1
            state.most = max(state.most, state.running)
            state.asked += 1
            return state.asked
        }
        Thread.sleep(forTimeInterval: 0.1)
        state.withLock { $0.running -= 1 }
        return URL(filePath: "/pictures/\(number).jpg")
    }

}

@MainActor
@Suite("The preview: which face it shows, and at what size")
struct PreviewModelTests {
    let cats = SourceSpec(kind: .photosCollection, locator: "A2")
    let iceland = SourceSpec(kind: .photosCollection, locator: "A1")
    let phone = CGSize(width: 393, height: 852)

    func preview(_ pictures: ScriptedPictures, device: WidgetDevice = .phone) -> PreviewModel {
        PreviewModel(pictures: pictures, device: device, screen: phone, scale: 3)
    }

    func picture(_ name: String) -> WidgetFace.Content { .picture(URL(filePath: "/pictures/\(name)")) }

    // MARK: When Photos does not answer

    @Test("When Photos does not answer, the picture already showing stays, with Scanning… over it")
    func timedOutKeepsThePicture() async {
        let preview = preview(ScriptedPictures([.picture("a.jpg"), .timeout]))
        preview.show([cats])

        await preview.advance()
        await preview.advance()

        #expect(preview.content == .scanningOver(URL(filePath: "/pictures/a.jpg")))
    }

    @Test("Scanning… comes off the picture when Photos answers")
    func answeredAgain() async {
        let clock = TestClock()
        let preview = PreviewModel(
            pictures: ScriptedPictures([.picture("a.jpg"), .timeout, .picture("b.jpg")]), device: .phone,
            screen: phone, scale: 3, now: { clock.now })
        preview.show([cats])
        await preview.advance()
        await preview.advance()

        clock.pass(5)
        await preview.advance()

        #expect(preview.content == picture("b.jpg"))
    }

    @Test("However long Photos has not answered, the preview asks again after a minute")
    func aMinuteAtMost() async {
        let clock = TestClock()
        let preview = PreviewModel(
            pictures: ScriptedPictures(Array(repeating: .timeout, count: 8) + [.picture("c.jpg")]),
            device: .phone, screen: phone, scale: 3, now: { clock.now })
        preview.show([cats])
        // Eight in a row: a widget would wait more than ten minutes now.
        for _ in 0..<7 {
            await preview.advance()
            clock.pass(30 * 60)
        }
        await preview.advance()

        clock.pass(59)
        await preview.advance()
        #expect(preview.content == .scanning)

        clock.pass(1)
        await preview.advance()
        #expect(preview.content == picture("c.jpg"))
    }

    @Test("When Photos does not answer and nothing is showing, it goes on saying it is scanning")
    func timedOutStillScanning() async {
        let preview = preview(ScriptedPictures([.timeout]))
        preview.show([cats])

        await preview.advance()

        #expect(preview.content == .scanning)
    }

    @Test("When Photos does not answer for the first picture, it does not go on to ask for another")
    func timedOutOnTheFirst() async {
        let pictures = ScriptedPictures([.picture("a.jpg")], first: [.timeout])
        let preview = preview(pictures)
        preview.show([cats])

        await preview.advance()

        #expect(preview.content == .scanning)
        #expect(pictures.calls == ["last", "first"])
    }

    @Test("It asks nothing more until the wait is over, and then makes a new request")
    func waitsBeforeAskingAgain() async {
        let clock = TestClock()
        let pictures = ScriptedPictures([.timeout, .picture("b.jpg")])
        let preview = PreviewModel(
            pictures: pictures, device: .phone, screen: phone, scale: 3, now: { clock.now })
        preview.show([cats])
        await preview.advance()
        let asked = pictures.calls

        clock.pass(2)
        await preview.advance()
        #expect(pictures.calls == asked)

        clock.pass(3)
        await preview.advance()
        #expect(preview.content == picture("b.jpg"))
    }

    @Test("During the wait, a picture kept from last time shows with Scanning… over it, and Photos is not asked")
    func keptPictureDuringTheWait() async {
        let clock = TestClock()
        let pictures = ScriptedPictures([], last: "kept.jpg", first: [.timeout])
        let preview = PreviewModel(
            pictures: pictures, device: .phone, screen: phone, scale: 3, now: { clock.now })
        preview.show([cats])
        await preview.advance()
        #expect(preview.content == .scanningOver(URL(filePath: "/pictures/kept.jpg")))

        // Another size is chosen: its own kept picture is looked for, and
        // nothing is asked of Photos.
        preview.family = .small
        clock.pass(1)
        await preview.advance()

        #expect(preview.content == .scanningOver(URL(filePath: "/pictures/kept.jpg")))
        #expect(pictures.calls == ["last", "first", "last"])
    }

    @Test("Other sources are asked for at once, whatever the wait")
    func otherSourcesAtOnce() async {
        let clock = TestClock()
        let preview = PreviewModel(
            pictures: ScriptedPictures([.timeout, .picture("b.jpg")]), device: .phone, screen: phone,
            scale: 3, now: { clock.now })
        preview.show([cats])
        await preview.advance()

        preview.show([iceland])
        await preview.advance()

        #expect(preview.content == picture("b.jpg"))
    }

    // MARK: -

    @Test("With nothing chosen it shows the plain icon, and asks for no picture")
    func nothingChosen() async {
        let pictures = ScriptedPictures([.picture("a.jpg")])
        let preview = preview(pictures)

        await preview.advance()

        #expect(preview.content == .nothingChosen)
        #expect(pictures.boxesAsked.isEmpty)
    }

    @Test("With sources chosen and no picture yet it says it is scanning")
    func scanning() {
        let preview = preview(ScriptedPictures([]))

        preview.show([cats])

        #expect(preview.content == .scanning)
    }

    @Test("Each change brings the next picture")
    func slideshow() async {
        let preview = preview(ScriptedPictures([.picture("a.jpg"), .picture("b.jpg")]))
        preview.show([cats])

        await preview.advance()
        #expect(preview.content == picture("a.jpg"))

        await preview.advance()
        #expect(preview.content == picture("b.jpg"))
    }

    @Test("Sources chosen and no picture to be had: No Photos found")
    func noPhotos() async {
        let preview = preview(ScriptedPictures([.none]))
        preview.show([cats])

        await preview.advance()

        #expect(preview.content == .noPhotos)
    }

    @Test("A picture that cannot be fetched is no picture")
    func failure() async {
        let preview = preview(ScriptedPictures([.failure]))
        preview.show([cats])

        await preview.advance()

        #expect(preview.content == .noPhotos)
    }

    @Test("A picture stays up until the change that finds nothing to follow it")
    func runsOut() async {
        let preview = preview(ScriptedPictures([.picture("a.jpg"), .none]))
        preview.show([cats])
        await preview.advance()
        #expect(preview.content == picture("a.jpg"))

        await preview.advance()

        #expect(preview.content == .noPhotos)
    }

    @Test("Taking the last source away goes back to the plain icon")
    func sourcesRemoved() async {
        let preview = preview(ScriptedPictures([.picture("a.jpg")]))
        preview.show([cats])
        await preview.advance()

        preview.show([])

        #expect(preview.content == .nothingChosen)
    }

    @Test("Changing what is chosen starts over; being told the same sources again does not")
    func sourcesChanged() async {
        let preview = preview(ScriptedPictures([.picture("a.jpg")]))
        preview.show([cats])
        await preview.advance()

        preview.show([cats])
        #expect(preview.content == picture("a.jpg"))

        preview.show([cats, iceland])
        #expect(preview.content == .scanning)
    }

    @Test("A phone offers its four sizes from the start, and is on the smallest until it knows its room")
    func phoneSizes() {
        let preview = preview(ScriptedPictures([]))

        #expect(preview.families == [.small, .medium, .large, .extraLargePortrait])
        #expect(preview.family == .small)
        #expect(preview.size == CGSize(width: 158, height: 158))
    }

    @Test("It starts on the largest size that fits its bounds")
    func startsOnTheLargestThatFits() {
        let roomy = preview(ScriptedPictures([]))
        roomy.settle(within: CGSize(width: 361, height: 400))
        #expect(roomy.family == .large)

        let narrow = preview(ScriptedPictures([]))
        narrow.settle(within: CGSize(width: 300, height: 400))
        #expect(narrow.family == .small)
    }

    @Test("On an iPad it is the extra large when that is not too wide, and the large when it is")
    func padSizes() {
        let wide = PreviewModel(
            pictures: ScriptedPictures([]), device: .pad, screen: CGSize(width: 820, height: 1180), scale: 2)
        wide.settle(within: CGSize(width: 820, height: 400))
        #expect(wide.family == .extraLarge)

        let narrow = PreviewModel(
            pictures: ScriptedPictures([]), device: .pad, screen: CGSize(width: 820, height: 1180), scale: 2)
        narrow.settle(within: CGSize(width: 373, height: 400))
        #expect(narrow.family == .large)
    }

    @Test("A size too tall for its bounds is passed over: it starts on the largest that needs no scrolling")
    func tooTall() {
        let short = preview(ScriptedPictures([]))
        short.settle(within: CGSize(width: 361, height: 300))
        #expect(short.family == .medium)

        let shortAndNarrow = preview(ScriptedPictures([]))
        shortAndNarrow.settle(within: CGSize(width: 300, height: 300))
        #expect(shortAndNarrow.family == .small)

        let nothingFits = preview(ScriptedPictures([]))
        nothingFits.settle(within: CGSize(width: 361, height: 100))
        #expect(nothingFits.family == .small)
    }

    @Test("A size that fits exactly is not cropped, so it fits")
    func fitsExactly() {
        let preview = preview(ScriptedPictures([]))

        preview.settle(within: CGSize(width: 338, height: 400))

        #expect(preview.family == .large)
    }

    @Test("When nothing fits it starts on the smallest")
    func nothingFits() {
        let preview = preview(ScriptedPictures([]))

        preview.settle(within: CGSize(width: 100, height: 400))

        #expect(preview.family == .small)
    }

    @Test("Until the person chooses, it follows its bounds: the largest that fits, each time they change")
    func followsTheRoom() {
        let preview = preview(ScriptedPictures([]))
        preview.settle(within: CGSize(width: 300, height: 400))
        #expect(preview.family == .small)

        preview.settle(within: CGSize(width: 361, height: 400))
        #expect(preview.family == .large)

        preview.settle(within: CGSize(width: 200, height: 400))
        #expect(preview.family == .small)
    }

    @Test("A size the person chose stays when the room changes, even when it no longer shows whole")
    func theirChoiceStaysThroughResizing() {
        let preview = preview(ScriptedPictures([]))
        preview.settle(within: CGSize(width: 361, height: 400))
        preview.family = .large

        preview.settle(within: CGSize(width: 200, height: 400))

        #expect(preview.family == .large)
    }

    @Test("A size the person chose is never changed for them")
    func theirChoiceStands() {
        let preview = preview(ScriptedPictures([]))
        preview.family = .small

        preview.settle(within: CGSize(width: 361, height: 400))

        #expect(preview.family == .small)
    }

    @Test("Before the screen is known there is nothing to fit, and it still gets its start later")
    func settledOnlyOnceTheScreenIsKnown() {
        let preview = PreviewModel(pictures: ScriptedPictures([]), device: .phone, screen: nil, scale: 1)
        preview.settle(within: CGSize(width: 361, height: 400))
        #expect(preview.family == .small)

        preview.use(screen: phone, scale: 3)
        preview.settle(within: CGSize(width: 361, height: 400))

        #expect(preview.family == .large)
    }

    @Test("Choosing a size changes the preview's size")
    func choosingASize() {
        let preview = preview(ScriptedPictures([]))

        preview.family = .large

        #expect(preview.size == CGSize(width: 338, height: 354))
    }

    @Test("Until the screen is known the preview has no size and asks for no picture")
    func screenNotKnownYet() async {
        let pictures = ScriptedPictures([.picture("a.jpg")])
        let preview = PreviewModel(pictures: pictures, device: .phone, screen: nil, scale: 1)
        preview.show([cats])

        await preview.advance()

        #expect(preview.size == .zero)
        #expect(pictures.boxesAsked.isEmpty)
        #expect(preview.content == .scanning)
    }

    @Test("Once it is told the screen it has that screen's sizes, in that screen's pixels")
    func toldTheScreen() async {
        let pictures = ScriptedPictures([.picture("a.jpg")])
        let preview = PreviewModel(pictures: pictures, device: .phone, screen: nil, scale: 1)
        preview.show([cats])

        preview.use(screen: CGSize(width: 430, height: 932), scale: 3)
        preview.family = .medium
        await preview.advance()

        #expect(preview.size == CGSize(width: 364, height: 170))
        #expect(pictures.boxesAsked == [CGSize(width: 1092, height: 510)])
        #expect(preview.content == picture("a.jpg"))
    }

    @Test("The bounds are as tall as the large size, whichever size is chosen")
    func tallestWhicheverIsChosen() {
        let preview = preview(ScriptedPictures([]))
        #expect(preview.boundsHeight == 354)

        preview.family = .small

        #expect(preview.size == CGSize(width: 158, height: 158))
        #expect(preview.boundsHeight == 354)
    }

    @Test("Two changes asked for at once fetch one after the other, never together")
    func oneFetchAtATime() async {
        let pictures = SlowPictures()
        let preview = PreviewModel(pictures: pictures, device: .phone, screen: phone, scale: 3)
        preview.show([cats])

        async let first: Void = preview.advance()
        async let second: Void = preview.advance()
        async let third: Void = preview.advance()
        _ = await (first, second, third)

        #expect(pictures.mostAtOnce == 1)
    }

    @Test("A change asked for while one is under way is not lost: one more follows it")
    func askedMeanwhile() async {
        let pictures = SlowPictures()
        let preview = PreviewModel(pictures: pictures, device: .phone, screen: phone, scale: 3)
        preview.show([cats])

        async let first: Void = preview.advance()
        async let second: Void = preview.advance()
        async let third: Void = preview.advance()
        _ = await (first, second, third)

        // The first, and one more for however many asked while it ran.
        #expect(pictures.timesAsked == 2)
        #expect(preview.content == .picture(URL(filePath: "/pictures/2.jpg")))
    }

    // MARK: When nothing is found

    /// A source whose only picture no widget could show was asked for every
    /// five seconds, for as long as the app was open: on an iPad, 2026-10-16.
    /// Nothing found may also be pictures still coming down from iCloud,
    /// which a later look finds, so it waits rather than stopping. Syd, the
    /// same day: "1". `Plans/PGR Widgets - iOS.md`, *The guard*.
    @Test("After finding nothing it waits before looking again, twice as long each time")
    func nothingFoundWaits() async {
        let clock = TestClock()
        let pictures = ScriptedPictures([.none, .none, .none, .picture("a.jpg")])
        let preview = PreviewModel(pictures: pictures, device: .phone, screen: phone, scale: 3, now: { clock.now })
        preview.show([cats])
        func looked() -> Int { pictures.calls.filter { $0 == "next" }.count }

        await preview.advance()
        #expect(preview.content == .noPhotos)
        #expect(looked() == 1)

        clock.pass(4)
        await preview.advance()
        #expect(looked() == 1)
        clock.pass(1)
        await preview.advance()
        #expect(looked() == 2)

        clock.pass(9)
        await preview.advance()
        #expect(looked() == 2)
        clock.pass(1)
        await preview.advance()
        #expect(looked() == 3)

        clock.pass(20)
        await preview.advance()
        #expect(looked() == 4)
        #expect(preview.content == picture("a.jpg"))
    }

    @Test("However long nothing has been found, it looks again after a minute")
    func nothingFoundAMinuteAtMost() async {
        let clock = TestClock()
        let pictures = ScriptedPictures(Array(repeating: .none, count: 10))
        let preview = PreviewModel(pictures: pictures, device: .phone, screen: phone, scale: 3, now: { clock.now })
        preview.show([cats])
        for _ in 0..<8 {
            await preview.advance()
            clock.pass(30 * 60)
        }
        let before = pictures.calls.filter { $0 == "next" }.count
        await preview.advance()

        clock.pass(59)
        await preview.advance()
        #expect(pictures.calls.filter { $0 == "next" }.count == before + 1)

        clock.pass(1)
        await preview.advance()
        #expect(pictures.calls.filter { $0 == "next" }.count == before + 2)
    }

    @Test("Other sources are looked at at once, whatever the wait for nothing found")
    func nothingFoundOtherSources() async {
        let clock = TestClock()
        let pictures = ScriptedPictures([.none, .picture("b.jpg")])
        let preview = PreviewModel(pictures: pictures, device: .phone, screen: phone, scale: 3, now: { clock.now })
        preview.show([cats])
        await preview.advance()
        #expect(preview.content == .noPhotos)

        preview.show([iceland])
        await preview.advance()

        #expect(preview.content == picture("b.jpg"))
    }

    @Test("Looking again, a preview that found nothing looks afresh")
    func lookingAgain() async {
        let clock = TestClock()
        let pictures = ScriptedPictures([.none, .picture("a.jpg")])
        let preview = PreviewModel(pictures: pictures, device: .phone, screen: phone, scale: 3, now: { clock.now })
        preview.show([cats])
        await preview.advance()
        #expect(preview.content == .noPhotos)

        preview.lookAgain()

        #expect(preview.content == .scanning)
        await preview.advance()
        #expect(preview.content == picture("a.jpg"))
    }

    @Test("Looking again leaves a photograph that is showing where it is")
    func lookingAgainWithAPicture() async {
        let pictures = ScriptedPictures([.picture("a.jpg")])
        let preview = preview(pictures)
        preview.show([cats])
        await preview.advance()

        preview.lookAgain()

        #expect(preview.content == picture("a.jpg"))
    }

    @Test("With nothing chosen, looking again shows nothing new")
    func lookingAgainWithNothingChosen() {
        let preview = preview(ScriptedPictures([]))

        preview.lookAgain()

        #expect(preview.content == .nothingChosen)
    }

    @Test("The widest size says how wide a column of its own has to be")
    func widest() {
        #expect(preview(ScriptedPictures([])).widest == 338)
        #expect(PreviewModel(pictures: ScriptedPictures([]), device: .pad, screen: CGSize(width: 820, height: 1180), scale: 2).widest == 628)
        #expect(PreviewModel(pictures: ScriptedPictures([]), device: .phone, screen: nil, scale: 1).widest == 0)
    }

    @Test("Each size has a shape in its own proportions, the large as tall as asked")
    func shapes() {
        let preview = preview(ScriptedPictures([]))

        let small = preview.shape(of: .small, height: 24)
        let medium = preview.shape(of: .medium, height: 24)
        let large = preview.shape(of: .large, height: 24)

        #expect(large.height == 24)
        #expect(abs(large.width - 338.0 * 24 / 354) < 0.001)
        #expect(medium.width == large.width)
        #expect(medium.height == small.height)
        #expect(small.width == small.height)
        #expect(abs(small.height - 158.0 * 24 / 354) < 0.001)
    }

    @Test("The shapes are there before the screen is known")
    func shapesBeforeTheScreen() {
        let preview = PreviewModel(pictures: ScriptedPictures([]), device: .phone, screen: nil, scale: 1)

        #expect(preview.shape(of: .large, height: 24).height == 24)
        #expect(preview.shape(of: .small, height: 24).width > 0)
    }

    @Test("Until the screen is known no space is kept")
    func noSpaceYet() {
        let preview = PreviewModel(pictures: ScriptedPictures([]), device: .phone, screen: nil, scale: 1)

        #expect(preview.boundsHeight == 0)
    }

    @Test("With nothing to show yet, last time's picture is up while the first is fetched")
    func lastTimeMeanwhile() async {
        let pictures = HeldPictures()
        let preview = PreviewModel(pictures: pictures, device: .phone, screen: phone, scale: 3)
        preview.show([.folder("/pictures")])

        let advancing = Task { await preview.advance() }
        // Two seconds at most: a preview that never asks for the first
        // picture fails this test and does not hang it.
        var waits = 0
        while !pictures.isHoldingFirst, waits < 400 {
            try? await Task.sleep(for: .milliseconds(5))
            waits += 1
        }
        #expect(pictures.isHoldingFirst)
        #expect(preview.content == picture("last.jpg"))

        pictures.letGo()
        await advancing.value
        #expect(preview.content == picture("first.jpg"))
    }

    @Test("The first picture is the first source's own, and the usual pick is not made for it")
    func firstPictureFirst() async {
        let pictures = ScriptedPictures([.picture("weighted.jpg")], first: [.picture("first.jpg")])
        let preview = preview(pictures)
        preview.show([.folder("/pictures")])

        await preview.advance()
        #expect(preview.content == picture("first.jpg"))
        #expect(pictures.calls == ["last", "first"])

        await preview.advance()
        #expect(preview.content == picture("weighted.jpg"))
        #expect(pictures.calls == ["last", "first", "next"])
    }

    @Test("When no source has a first picture to give, the usual pick follows at once")
    func noFirstPicture() async {
        let pictures = ScriptedPictures([.picture("weighted.jpg")])
        let preview = preview(pictures)
        preview.show([.folder("/pictures")])

        await preview.advance()

        #expect(preview.content == picture("weighted.jpg"))
        #expect(pictures.calls == ["last", "first", "next"])
    }

    @Test("When no picture can be had now, last time's does not stay up")
    func lastTimeDoesNotStay() async {
        let pictures = ScriptedPictures([], last: "last.jpg")
        let preview = preview(pictures)
        preview.show([.folder("/pictures")])

        await preview.advance()

        #expect(preview.content == .noPhotos)
    }

    @Test("After the sources change it starts over: last time's, then the first")
    func startsOverForNewSources() async {
        let pictures = ScriptedPictures([], first: [.picture("a.jpg"), .picture("b.jpg")])
        let preview = preview(pictures)
        preview.show([.folder("/pictures")])
        await preview.advance()

        preview.show([.folder("/other")])
        await preview.advance()

        #expect(preview.content == picture("b.jpg"))
        #expect(pictures.calls == ["last", "first", "last", "first"])
    }

    @Test("Coming forward again with a picture up does not start over")
    func comingForwardKeepsGoing() async {
        let pictures = ScriptedPictures([.picture("weighted.jpg")], first: [.picture("first.jpg")])
        let preview = preview(pictures)
        preview.show([.folder("/pictures")])
        await preview.advance()

        preview.lookAgain()
        await preview.advance()

        #expect(preview.content == picture("weighted.jpg"))
        #expect(pictures.calls == ["last", "first", "next"])
    }

    func recorded(_ sizes: [String: CGSize]) -> RecordedWidgetSizes {
        let recorded = RecordedWidgetSizes(suiteName: scratchSuiteName("preview-sizes"))
        for (family, size) in sizes { recorded.record(size, forFamily: family) }
        return recorded
    }

    func preview(recorded: RecordedWidgetSizes) -> PreviewModel {
        PreviewModel(
            pictures: ScriptedPictures([]), device: .phone, screen: phone, scale: 3, recorded: recorded)
    }

    @Test("A size a widget was handed is used in place of the table's")
    func recordedSize() {
        let preview = preview(recorded: recorded(["systemSmall": CGSize(width: 164, height: 164)]))

        preview.family = .small
        #expect(preview.size == CGSize(width: 164, height: 164))

        preview.family = .medium
        #expect(preview.size == CGSize(width: 338, height: 158))
    }

    @Test("The tall size is offered before any widget has been handed it, at a size reckoned for the screen, and at the handed size after")
    func fourthSize() {
        let sizes = recorded([:])
        let preview = preview(recorded: sizes)
        #expect(preview.families == [.small, .medium, .large, .extraLargePortrait])
        preview.family = .extraLargePortrait
        #expect(preview.size == CGSize(width: 338, height: 550))

        sizes.record(CGSize(width: 338, height: 740), forFamily: "systemExtraLargePortrait")
        preview.lookAgain()

        #expect(preview.families == [.small, .medium, .large, .extraLargePortrait])
        #expect(preview.size == CGSize(width: 338, height: 740))
    }

    @Test("With a large and a medium handed and no tall one, the tall size is reckoned from those and not from the table")
    func fourthSizeFromWhatWasHanded() {
        let preview = preview(
            recorded: recorded([
                "systemMedium": CGSize(width: 350, height: 164), "systemLarge": CGSize(width: 350, height: 366),
            ]))

        preview.family = .extraLargePortrait

        #expect(preview.size == CGSize(width: 350, height: 568))
    }

    @Test("An iPad is not offered the tall size")
    func noTallOnAnIPad() {
        let preview = preview(ScriptedPictures([]), device: .pad)

        #expect(preview.families == [.small, .medium, .large, .extraLarge])
    }

    @Test("On a device with two screens, the preview shows the sizes of the screen the app is on")
    func twoScreens() {
        let sizes = recorded([:])
        sizes.record(CGSize(width: 402, height: 190), forFamily: "systemMedium")
        sizes.record(CGSize(width: 334, height: 158), forFamily: "systemMedium")
        let preview = PreviewModel(
            pictures: ScriptedPictures([]), device: .phone, screen: CGSize(width: 466, height: 678), scale: 3,
            recorded: sizes)
        preview.family = .medium
        #expect(preview.size == CGSize(width: 334, height: 158))

        preview.use(screen: CGSize(width: 669, height: 951), scale: 3)

        #expect(preview.size == CGSize(width: 402, height: 190))
    }

    @Test("The bounds are as tall as the large size, however tall the fourth is")
    func boundsAreTheLarge() {
        let preview = preview(
            recorded: recorded(["systemExtraLargePortrait": CGSize(width: 338, height: 740)]))

        #expect(preview.boundsHeight == 354)
    }

    @Test("It does not start on a size taller than its bounds")
    func doesNotStartOnTheTallOne() {
        let preview = preview(
            recorded: recorded(["systemExtraLargePortrait": CGSize(width: 338, height: 740)]))

        preview.settle(within: CGSize(width: 400, height: 400))

        #expect(preview.family == .large)
    }

    @Test("A size taller than the large has a shape a little taller than the large's, and no more")
    func tallShape() {
        let preview = preview(
            recorded: recorded(["systemExtraLargePortrait": CGSize(width: 338, height: 740)]))

        let large = preview.shape(of: .large, height: 24)
        let tall = preview.shape(of: .extraLargePortrait, height: 24)

        #expect(large.height == 24)
        #expect(tall.width == large.width)
        #expect(abs(tall.height - 24 * 1.3) < 0.001)
    }

    @Test("A picture is asked for at the widget's size in pixels")
    func pixels() async {
        let pictures = ScriptedPictures([.picture("a.jpg"), .picture("b.jpg")])
        let preview = preview(pictures)
        preview.show([cats])

        preview.family = .medium
        await preview.advance()
        preview.family = .small
        await preview.advance()

        #expect(pictures.boxesAsked == [CGSize(width: 1014, height: 474), CGSize(width: 474, height: 474)])
    }
}
