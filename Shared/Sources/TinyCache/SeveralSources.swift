// Every source the app has set, as one. `Plans/Photos-Go-Round Widgets.md`,
// *Next: the app's sources, then Photos*.
//
// **Each source has an equal chance, whatever it holds.** An album of ten
// photographs is asked as often as a library of twenty thousand. That is the
// simplest thing that shows pictures from all of them; weighing a source by
// how much is in it would mean counting, and nothing here counts.

import CoreGraphics
import Foundation

public struct SeveralSources: PictureSource {
    private let sources: [any PictureSource]

    public init(_ sources: [any PictureSource]) {
        self.sources = sources
    }

    /// A picture from one of the sources, tried in a random order until one
    /// has a picture to give.
    ///
    /// **One source's trouble does not stop the others.** A folder that cannot
    /// be read is passed over for a source that can. Its error is thrown only
    /// when no source gave a picture, so that a widget with nothing to show
    /// can say why instead of saying there are no pictures.
    public func writePicture(fitting box: CGSize, to destination: URL) throws -> PictureResizer.Resize? {
        var trouble: (any Error)?
        for source in sources.shuffled() {
            do {
                if let resize = try source.writePicture(fitting: box, to: destination) { return resize }
            } catch {
                trouble = trouble ?? error
            }
        }
        if let trouble { throw trouble }
        return nil
    }
}
