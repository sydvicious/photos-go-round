// Where a filled picture is cropped: toward its faces, or else its subject, or
// else about its middle. `Plans/Widget Settings.md`, *Fit or fill*.
//
// **Faces first, holding as many as the crop can, centred on them. With none,
// the subject, centred on its bounds. With neither, the middle.** Syd,
// 2026-10-25, over cropping about the middle alone.
//
// **The crop is kept inside the picture**, so a face at an edge takes the crop
// to that edge and no further.

import CoreGraphics
import CoreML
import OSLog
import PhotosGoRoundAgentAPI
import Vision

/// What a filled picture is cropped toward, in its own pixels counted from its
/// top left.
public enum CropFocus: Equatable, Sendable {
    case faces([CGRect])
    case subject(CGRect)
    case middle

    /// What Vision finds in `image`: its faces, or else the bounds of what
    /// draws the eye, or else neither.
    ///
    /// **Asked of the picture made to cover the box, not the original, and
    /// that shrunk again**: `shownToVision`. Vision answers in fractions of
    /// what it is shown, so its answer lies on `image` as it is. **The
    /// subject is asked for only when there are no faces.** **Vision failing
    /// is the middle**, not a picture passed over.
    public static func found(in image: CGImage) -> CropFocus {
        guard let shown = shownToVision(image) else { return .middle }
        let handler = VNImageRequestHandler(cgImage: shown, options: [:])
        let faces = VNDetectFaceRectanglesRequest()
        onTheCPUInASimulator(faces)
        do { try handler.perform([faces]) } catch { return failed(error, asking: "faces") }
        let found = (faces.results ?? []).map { pixels(of: $0.boundingBox, in: image) }
        if !found.isEmpty { return .faces(found) }

        let attention = VNGenerateAttentionBasedSaliencyImageRequest()
        onTheCPUInASimulator(attention)
        do { try handler.perform([attention]) } catch { return failed(error, asking: "the subject") }
        guard let salient = attention.results?.first?.salientObjects, !salient.isEmpty else { return .middle }
        let bounds = salient.map(\.boundingBox).reduce(CGRect.null) { $0.union($1) }
        return .subject(pixels(of: bounds, in: image))
    }

    /// The longest side of what Vision is shown.
    static let shownSide = 512

    /// `image` no more than `shownSide` pixels on its long side, and never
    /// enlarged.
    ///
    /// **Vision held 8 to 23 MB in a widget** on Syd's phone, 2026-10-25,
    /// asked of the whole covering picture, up to 1049 by 1095. Syd, the same
    /// day: ask it of a smaller one. Shrunk, it costs a bitmap of a megabyte
    /// at most.
    static func shownToVision(_ image: CGImage) -> CGImage? {
        let scale = min(1, Double(shownSide) / Double(max(image.width, image.height)))
        guard scale < 1 else { return image }
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// **In a simulator, Vision runs on the CPU.** Left to choose, it failed
    /// on *Claude iPhone*, 2026-10-25: "Could not create inference context".
    private static func onTheCPUInASimulator(_ request: VNRequest) {
        #if targetEnvironment(simulator)
            guard let stages = try? request.supportedComputeStageDevices else { return }
            for (stage, devices) in stages {
                if let cpu = devices.first(where: { if case .cpu = $0 { true } else { false } }) {
                    request.setComputeDevice(cpu, for: stage)
                }
            }
        #endif
    }

    /// The middle, with a line saying Vision failed: in the log, the middle
    /// is otherwise a picture where nothing was found.
    private static func failed(_ error: any Error, asking: String) -> CropFocus {
        Log.widget.error(
            """
            \(Log.widgetsTag, privacy: .public) Vision failed asking for \(asking, privacy: .public): \
            \(String(describing: error), privacy: .public)
            """)
        return .middle
    }

    /// A rectangle of Vision's, in fractions of the picture counted from its
    /// bottom left, in the picture's pixels counted from its top left.
    private static func pixels(of normalized: CGRect, in image: CGImage) -> CGRect {
        let width = Double(image.width)
        let height = Double(image.height)
        return CGRect(
            x: normalized.minX * width, y: (1 - normalized.maxY) * height, width: normalized.width * width,
            height: normalized.height * height)
    }

    /// For the log: `2 faces`, `the subject at 67,167 66x66`, `the middle`.
    var said: String {
        switch self {
        case .faces(let faces): faces.count == 1 ? "1 face" : "\(faces.count) faces"
        case .subject(let bounds):
            "the subject at \(Int(bounds.minX)),\(Int(bounds.minY)) \(Int(bounds.width))x\(Int(bounds.height))"
        case .middle: "the middle"
        }
    }
}

extension PictureResizer {
    /// The largest part of a picture `width` by `height` that is the shape of
    /// `box`, placed toward `focus`, in whole pixels counted from the top left.
    ///
    /// **It slides one way only.** The crop is as long as the picture one way
    /// and shorter the other, so where it goes is how far along the other.
    ///
    /// **As many faces as it can hold.** Where it cannot hold them all, it
    /// holds the most it can, and of as many, the larger. Where it cannot hold
    /// even one, it is centred on the largest.
    static func crop(ofWidth width: Int, height: Int, shapedLike box: CGSize, toward focus: CropFocus) -> CGRect {
        let middle = middle(ofWidth: width, height: height, shapedLike: box)
        let across = middle.width < Double(width)
        let length = across ? middle.width : middle.height
        let extent = Double(across ? width : height)
        guard length < extent else { return middle }

        func span(_ rect: CGRect) -> (from: Double, to: Double) {
            across ? (rect.minX, rect.maxX) : (rect.minY, rect.maxY)
        }
        func area(_ rects: [CGRect]) -> Double { rects.reduce(0) { $0 + $1.width * $1.height } }
        func placed(_ start: Double) -> Double { min(max(0, start), extent - length) }

        let around: [CGRect]
        switch focus {
        case .middle: return middle
        case .subject(let subject): around = [subject]
        case .faces(let faces):
            guard let largest = faces.max(by: { area([$0]) < area([$1]) }) else { return middle }
            // Each place that puts a face at one end of the crop, and the
            // faces wholly inside it there.
            var held: [CGRect] = []
            for face in faces {
                for start in [placed(span(face).from), placed(span(face).to - length)] {
                    let inside = faces.filter { span($0).from >= start && span($0).to <= start + length }
                    if inside.count > held.count || (inside.count == held.count && area(inside) > area(held)) {
                        held = inside
                    }
                }
            }
            around = held.isEmpty ? [largest] : held
        }
        let from = around.map { span($0).from }.min()!
        let to = around.map { span($0).to }.max()!
        let start = placed(((from + to) / 2 - length / 2).rounded())
        return across
            ? CGRect(x: start, y: middle.minY, width: length, height: middle.height)
            : CGRect(x: middle.minX, y: start, width: middle.width, height: length)
    }
}
