import Foundation

/// How a photograph sits in the place it is shown. `Plans/Widget Settings.md`,
/// *Fit or fill*.
///
/// **Three, and Fit is the default.** Syd, 2026-10-25: "Fit and fill are better
/// terms" than "crop vs fill", and Fit, as everywhere in Photos-Go-Round until
/// then, is what a place shows until someone changes it. Then, the same day:
/// "we should also have an option not to expand the picture at all of it
/// fits", as a third choice.
///
/// Stored by its raw value, so the names are kept once anything has been
/// written with them.
public enum Framing: String, CaseIterable, Sendable, Equatable {
    /// The whole photograph, as large as it fits, with black around it.
    case fit
    /// No black: the photograph covers the place, and what is over is cropped.
    case fill
    /// The whole photograph, never made larger than it is: one that fits is
    /// shown at its own size, with black around it, and one that does not is
    /// shrunk to fit.
    case actualSize = "actual-size"

    /// What a person is shown for it.
    public var title: String {
        switch self {
        case .fit: "Fit"
        case .fill: "Fill"
        case .actualSize: "Actual Size"
        }
    }

    /// Whether a picture smaller than its place is drawn larger to meet it.
    public var enlarges: Bool { self != .actualSize }
}
