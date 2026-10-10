import CoreGraphics
import Foundation
import PhotosGoRoundAgentAPI
import PhotosGoRoundWidgetFace
import Synchronization
import Testing

@testable import PhotosGoRoundWidgetSettings

/// Pictures handed out from a script, with a note of what was asked for.
final class ScriptedPictures: PreviewPictures {
    enum Answer { case picture(String), none, failure }

    private let script: Mutex<[Answer]>
    private let asked = Mutex<[CGSize]>([])
    private let forgotten = Mutex(0)

    /// How many times it was told to forget what it had learned.
    var timesForgotten: Int { forgotten.withLock { $0 } }

    func forget() { forgotten.withLock { $0 += 1 } }

    init(_ script: [Answer]) { self.script = Mutex(script) }

    var boxesAsked: [CGSize] { asked.withLock { $0 } }

    func next(from sources: [SourceSpec], fitting box: CGSize) throws -> URL? {
        asked.withLock { $0.append(box) }
        let answer = script.withLock { $0.isEmpty ? Answer.none : $0.removeFirst() }
        switch answer {
        case .picture(let name): return URL(filePath: "/pictures/\(name)")
        case .none: return nil
        case .failure: throw CocoaError(.fileReadUnknown)
        }
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

    func forget() {}
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

    @Test("A phone offers small, medium and large, and is on the smallest until it knows its room")
    func phoneSizes() {
        let preview = preview(ScriptedPictures([]))

        #expect(preview.families == [.small, .medium, .large])
        #expect(preview.family == .small)
        #expect(preview.size == CGSize(width: 158, height: 158))
    }

    @Test("It starts on the largest size that fits its room without cropping")
    func startsOnTheLargestThatFits() {
        let roomy = preview(ScriptedPictures([]))
        roomy.settle(within: CGSize(width: 361, height: 400))
        #expect(roomy.family == .large)

        let short = preview(ScriptedPictures([]))
        short.settle(within: CGSize(width: 361, height: 300))
        #expect(short.family == .medium)

        let narrow = preview(ScriptedPictures([]))
        narrow.settle(within: CGSize(width: 300, height: 400))
        #expect(narrow.family == .small)
    }

    @Test("A size that fits exactly is not cropped, so it fits")
    func fitsExactly() {
        let preview = preview(ScriptedPictures([]))

        preview.settle(within: CGSize(width: 338, height: 354))

        #expect(preview.family == .large)
    }

    @Test("When nothing fits it starts on the smallest")
    func nothingFits() {
        let preview = preview(ScriptedPictures([]))

        preview.settle(within: CGSize(width: 100, height: 100))

        #expect(preview.family == .small)
    }

    @Test("Until the person chooses, it follows the room: the largest that shows whole, each time the room changes")
    func followsTheRoom() {
        let preview = preview(ScriptedPictures([]))
        preview.settle(within: CGSize(width: 361, height: 300))
        #expect(preview.family == .medium)

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

        preview.settle(within: CGSize(width: 200, height: 200))

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

    @Test("The space kept for the preview is as tall as the tallest size, whichever is chosen")
    func spaceKept() {
        let preview = preview(ScriptedPictures([]))
        #expect(preview.tallest == 354)

        preview.family = .small

        #expect(preview.size == CGSize(width: 158, height: 158))
        #expect(preview.tallest == 354)
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

    @Test("Looking again forgets what was learned, and a preview that found nothing looks afresh")
    func lookingAgain() async {
        let pictures = ScriptedPictures([.none, .picture("a.jpg")])
        let preview = preview(pictures)
        preview.show([cats])
        await preview.advance()
        #expect(preview.content == .noPhotos)

        preview.lookAgain()

        #expect(pictures.timesForgotten == 1)
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

        #expect(pictures.timesForgotten == 1)
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

    @Test("With room to spare, the preview's space is as tall as the tallest size")
    func roomToSpare() {
        #expect(preview(ScriptedPictures([])).space(within: 500) == 354)
    }

    @Test("With less room than the tallest size needs, the space is the room there is")
    func lessRoom() {
        let preview = preview(ScriptedPictures([]))

        #expect(preview.space(within: 300) == 300)
        #expect(preview.space(within: 354) == 354)
    }

    @Test("With no room at all there is no space, and never less than none")
    func noRoom() {
        let preview = preview(ScriptedPictures([]))

        #expect(preview.space(within: 0) == 0)
        #expect(preview.space(within: -40) == 0)
    }

    @Test("Until the screen is known there is no space, however much room there is")
    func noSpaceBeforeTheScreen() {
        let preview = PreviewModel(pictures: ScriptedPictures([]), device: .phone, screen: nil, scale: 1)

        #expect(preview.space(within: 500) == 0)
    }

    @Test("Until the screen is known no space is kept")
    func noSpaceYet() {
        let preview = PreviewModel(pictures: ScriptedPictures([]), device: .phone, screen: nil, scale: 1)

        #expect(preview.tallest == 0)
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
