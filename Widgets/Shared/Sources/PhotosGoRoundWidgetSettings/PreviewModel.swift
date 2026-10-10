// The preview: which face it shows, and at what size.
// `Plans/PGR Widgets - iOS.md`, *How the preview is drawn*.
//
// **A small slideshow.** Syd, 2026-10-09: its picture changes by itself every
// few seconds, and on a tap. Whoever draws it calls `advance` for each change;
// this decides what is shown after it.
//
// **Three faces without a photograph**, on iOS and iPadOS: the plain icon with
// nothing chosen, "Scanning…" while the first picture is fetched, and "No
// Photos found" when sources are chosen and no picture is to be had.

import CoreGraphics
import Foundation
import Observation
import PhotosGoRoundAgentAPI
import PhotosGoRoundWidgetFace

/// Where the preview's pictures come from.
public protocol PreviewPictures: Sendable {
    /// The next picture from `sources`, no bigger than `box` in pixels, as a
    /// file; nil when there is none to be had. May block.
    func next(from sources: [SourceSpec], fitting box: CGSize) throws -> URL?

    /// Forgets what has been learned about the sources, such as how many
    /// pictures each held, so that they are looked at afresh.
    func forget()
}

@MainActor
@Observable
public final class PreviewModel {
    public private(set) var content: WidgetFace.Content = .nothingChosen
    /// The size being previewed. Setting it is the person choosing: from then
    /// on it is theirs, and `settle` leaves it alone.
    public var family: WidgetFamily {
        get { showing }
        set {
            showing = newValue
            personChose = true
        }
    }
    /// The sizes this device's Home Screen offers.
    public let families: [WidgetFamily]

    private let pictures: any PreviewPictures
    private let device: WidgetDevice
    private var screen: CGSize?
    private var scale: CGFloat
    private var sources: [SourceSpec] = []
    /// Whether a picture is being fetched now, and whether another change was
    /// asked for meanwhile.
    private var isFetching = false
    private var askedMeanwhile = false
    private var showing: WidgetFamily
    /// Whether the person has picked a size for themselves.
    private var personChose = false

    public init(pictures: any PreviewPictures, device: WidgetDevice, screen: CGSize?, scale: CGFloat) {
        self.pictures = pictures
        self.device = device
        self.screen = screen
        self.scale = scale
        families = WidgetSizes.families(on: device)
        // The smallest, until `settle` knows what there is room for.
        showing = families.first ?? .small
    }

    /// The widget's real size on this device, in points.
    ///
    /// Nothing until the screen is known. An app finds its screen from the
    /// window it is shown in, which it does not have when it starts.
    public var size: CGSize {
        guard let screen else { return .zero }
        return WidgetSizes.size(of: family, on: device, screen: screen) ?? .zero
    }

    /// The height of the tallest size this device offers, and nothing until
    /// the screen is known.
    public var tallest: CGFloat {
        guard let screen else { return 0 }
        return families.compactMap { WidgetSizes.size(of: $0, on: device, screen: screen)?.height }
            .max() ?? 0
    }

    /// The width of the widest size this device offers, which is how wide the
    /// preview's column has to be when it has one of its own.
    public var widest: CGFloat {
        guard let screen else { return 0 }
        return families.compactMap { WidgetSizes.size(of: $0, on: device, screen: screen)?.width }
            .max() ?? 0
    }

    /// Chooses the size to show for a view this wide, until the person
    /// chooses for themselves: the largest that is not too wide, or the
    /// smallest.
    ///
    /// Syd, 2026-10-10: "the decision on which view to show by default should
    /// be the one whose width will fit". How tall the view is does not come
    /// into it: the widget is drawn whole from the top of the view, and one
    /// taller than the view runs off the bottom. It is applied each time the
    /// width changes: turning the phone, or dragging an iPad's window.
    /// Nothing happens before the screen is known, since no size is.
    ///
    /// A size the person picked is left alone, whatever the width.
    public func settle(within width: CGFloat) {
        guard !personChose, let screen else { return }
        let fits = families.last { family in
            guard let size = WidgetSizes.size(of: family, on: device, screen: screen) else { return false }
            return size.width <= width
        }
        showing = fits ?? families.first ?? .small
    }

    /// The shape that stands for a size in the bar: the widget's own
    /// proportions, scaled so that the tallest size is `height` tall. Syd,
    /// 2026-10-10: "proportionately-sized round rects for each available
    /// size".
    ///
    /// Before the screen is known the proportions are those of the smallest
    /// device in the table, so the bar is never empty.
    public func shape(of family: WidgetFamily, height: CGFloat) -> CGSize {
        let screen = screen ?? .zero
        let tallest =
            families.compactMap { WidgetSizes.size(of: $0, on: device, screen: screen)?.height }.max() ?? 0
        guard tallest > 0, let size = WidgetSizes.size(of: family, on: device, screen: screen) else {
            return .zero
        }
        return CGSize(width: size.width * height / tallest, height: size.height * height / tallest)
    }

    /// The screen the app is on, and how many pixels it has to a point.
    public func use(screen: CGSize, scale: CGFloat) {
        self.screen = screen
        self.scale = scale
    }

    /// What is chosen now. A change starts the preview over; the same sources
    /// again leave what is showing alone.
    public func show(_ sources: [SourceSpec]) {
        guard sources != self.sources else { return }
        self.sources = sources
        content = sources.isEmpty ? .nothingChosen : .scanning
    }

    /// Looks at the sources afresh, as when the app comes forward.
    ///
    /// What was learned about them is forgotten, so photographs added in
    /// Photos meanwhile are found: a collection that was empty an hour ago
    /// would otherwise go on being taken for empty. A preview that had found
    /// nothing goes back to scanning, which fetches at once; one showing a
    /// photograph keeps it until its next change.
    public func lookAgain() {
        pictures.forget()
        if content == .noPhotos {
            content = .scanning
        }
    }

    /// One change of picture.
    ///
    /// **One fetch at a time.** Two requests to Photos for a picture at the
    /// same moment do not come back: measured 2026-10-10, both threads waiting
    /// inside PhotoKit on the Photos daemon, with the preview on "Scanning…"
    /// for good. The slideshow's turn, a tap and a change of sources can all
    /// ask at once, so a change asked for while one is under way waits, and
    /// however many ask, one more fetch follows. A widget's timeline holds a
    /// lock for the same reason.
    public func advance() async {
        guard !sources.isEmpty else {
            content = .nothingChosen
            return
        }
        guard !isFetching else {
            askedMeanwhile = true
            return
        }
        isFetching = true
        await fetch()
        while askedMeanwhile {
            askedMeanwhile = false
            await fetch()
        }
        isFetching = false
    }

    private func fetch() async {
        guard !sources.isEmpty else {
            content = .nothingChosen
            return
        }
        let asked = sources
        let box = CGSize(width: size.width * scale, height: size.height * scale)
        guard box != .zero else { return }
        let pictures = pictures
        // Off the main actor, and off the cooperative pool: fetching reads
        // PhotoKit or walks a folder, and both block.
        let picture = try? await BlockingWork.run { try pictures.next(from: asked, fitting: box) }
        // Chosen again while this one was being fetched: it is not theirs.
        guard asked == sources else { return }
        content = picture.map { .picture($0) } ?? .noPhotos
    }
}
