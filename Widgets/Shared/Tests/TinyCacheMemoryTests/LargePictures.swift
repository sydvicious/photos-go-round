import CoreGraphics
import Foundation
import ImageIO
import PhotosGoRoundAgentAPI
import UniformTypeIdentifiers

/// The rows of a picture made up as they are asked for, so that a picture of
/// hundreds of millions of pixels is never held anywhere.
private final class MadeUpRows {
    let rowBytes: Int
    let total: Int
    var offset = 0

    init(width: Int, height: Int, channels: Int = 3) {
        rowBytes = width * channels
        total = rowBytes * height
    }

    /// Grain, as a scan has, so that the file is the size a scan's is: about
    /// a tenth of a byte for each pixel. A picture of one flat colour makes a
    /// file of almost nothing, and what a file's own bytes cost is then not
    /// seen.
    private static let grain: [UInt8] = {
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        return (0..<(1 << 20) + 4099).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return UInt8(118 + (state >> 58) % 12)
        }
    }()

    func fill(_ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int {
        let taken = min(count, total - offset)
        var done = 0
        Self.grain.withUnsafeBytes { grain in
            while done < taken {
                let start = (offset + done) % grain.count
                let run = min(grain.count - start, taken - done)
                memcpy(buffer + done, grain.baseAddress! + start, run)
                done += run
            }
        }
        offset += taken
        return taken
    }
}

extension ScratchFolder {
    /// Writes a JPEG of the given size at `path` inside the folder, without
    /// the picture ever being in memory whole: its rows are made up as the
    /// encoder asks for them. Grey is one channel, as a scanner writes it.
    @discardableResult
    func largePicture(
        _ path: String, width: Int, height: Int, progressive: Bool = false, grey: Bool = false
    ) throws -> URL {
        let file = url.appending(path: path)
        var callbacks = CGDataProviderSequentialCallbacks(
            version: 0,
            getBytes: { info, buffer, count in
                Unmanaged<MadeUpRows>.fromOpaque(info!).takeUnretainedValue().fill(buffer, count)
            },
            skipForward: { info, count in
                let rows = Unmanaged<MadeUpRows>.fromOpaque(info!).takeUnretainedValue()
                let skipped = min(Int(count), rows.total - rows.offset)
                rows.offset += skipped
                return off_t(skipped)
            },
            rewind: { info in
                Unmanaged<MadeUpRows>.fromOpaque(info!).takeUnretainedValue().offset = 0
            },
            releaseInfo: { info in
                Unmanaged<MadeUpRows>.fromOpaque(info!).release()
            })
        let rows = MadeUpRows(width: width, height: height, channels: grey ? 1 : 3)
        guard
            let provider = CGDataProvider(
                sequentialInfo: Unmanaged.passRetained(rows).toOpaque(), callbacks: &callbacks),
            let image = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: grey ? 8 : 24,
                bytesPerRow: rows.rowBytes,
                space: grey ? CGColorSpaceCreateDeviceGray() : CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
            let type = UTType(filenameExtension: file.pathExtension),
            let destination = CGImageDestinationCreateWithURL(
                file as CFURL, type.identifier as CFString, 1, nil)
        else { throw PictureNotWritten() }
        let properties: [CFString: Any] =
            progressive ? [kCGImagePropertyJFIFDictionary: [kCGImagePropertyJFIFIsProgressive: true]] : [:]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PictureNotWritten() }
        return file
    }
}

/// How much more the process held, at its most, while some work was done.
///
/// **Watched, not read off the kernel's peak**, which is the most the process
/// has ever held and so says nothing of work that stays under an earlier
/// mark. The footprint is read every millisecond on a thread of its own; work
/// that takes a second or more is not missed.
enum MemoryRise {
    private final class Watch: @unchecked Sendable {
        private let lock = NSLock()
        private var highest: Int64 = 0
        private var stopped = false

        var most: Int64 { lock.withLock { highest } }

        func stop() { lock.withLock { stopped = true } }

        func run() {
            while !lock.withLock({ stopped }) {
                if let now = Footprint.now()?.footprint {
                    lock.withLock { highest = max(highest, now) }
                }
                usleep(1000)
            }
        }
    }

    static func during<T>(_ work: () throws -> T) throws -> (result: T, rise: Int64) {
        guard let before = Footprint.now()?.footprint else { throw PictureNotWritten() }
        let watch = Watch()
        let done = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            watch.run()
            done.signal()
        }
        let result = Result { try work() }
        watch.stop()
        done.wait()
        return (try result.get(), max(0, watch.most - before))
    }
}
