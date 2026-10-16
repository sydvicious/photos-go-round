import Foundation
import Testing

@testable import PhotosGoRoundAgentAPI

/// What a service says about the memory it is holding.
///
/// Syd, 2026-09-18: "what we should be doing is logging the RAM usage every five
/// minutes", and "for all three of the permanent services".
/// `Plans/Track RAM Usage.md`, Phase 3.
@Suite("Footprint")
struct FootprintTests {

    /// **The reading is the whole point**, so a kernel that would not answer is
    /// worth knowing about rather than a zero that reads like an empty process.
    @Test("The kernel answers, with a footprint no larger than resident size")
    func theReadingIsPlausible() throws {
        let reading = try #require(Footprint.now(), "the kernel refused TASK_VM_INFO")

        #expect(reading.footprint > 0)
        #expect(reading.resident > 0)
        // Footprint excludes what the allocator is holding to hand back, so it
        // is the smaller of the two — which is the reason it is the one
        // reported. Measured 2026-09-18: 299 MB against 531 MB resident.
        #expect(reading.footprint <= reading.resident)
    }

    @Test("Every reading raises the high-water mark, and nothing lowers it")
    func thePeakOnlyRises() {
        _ = Footprint.now()
        let peak = Footprint.peak

        #expect(peak > 0)
        _ = Footprint.now()
        #expect(Footprint.peak >= peak)
    }

    /// The line every service writes, so one `grep MEMORY:` reads all three.
    @Test("The line names both numbers and the uptime")
    func theLineReads() {
        let reading = Footprint.Reading(footprint: 299 * 1_048_576, resident: 531 * 1_048_576)

        let line = Footprint.line(reading, up: .seconds(6 * 3600 + 59 * 60))

        #expect(line.hasPrefix("MEMORY: footprint "))
        #expect(line.contains("resident "))
        #expect(line.hasSuffix("up 6h 59m"))
    }

    @Test("Under an hour is minutes alone")
    func shortUptimesAreMinutes() {
        #expect(Footprint.spoken(.seconds(59)) == "0m")
        #expect(Footprint.spoken(.seconds(300)) == "5m")
        #expect(Footprint.spoken(.seconds(3600)) == "1h 0m")
        #expect(Footprint.spoken(.seconds(3660)) == "1h 1m")
    }

    // MARK: Against a limit

    static let megabyte: Int64 = 1_048_576

    /// Memory that has been written to, which is what a footprint counts.
    private final class Held {
        let bytes: UnsafeMutableRawPointer

        init(megabytes: Int) {
            let count = megabytes * Int(FootprintTests.megabyte)
            bytes = UnsafeMutableRawPointer.allocate(byteCount: count, alignment: 16)
            memset(bytes, 0x5A, count)
        }

        deinit { bytes.deallocate() }
    }

    /// What a widget extension ends its lines with, since it is the one
    /// process here that is held to a limit. `Plans/PGR Widgets - iOS.md`,
    /// *Reading the logs*.
    @Test("Against a limit, it says what is held now, the most ever held, and what is left")
    func theSentenceAgainstALimit() {
        let reading = Footprint.Reading(
            footprint: 11 * Self.megabyte + Self.megabyte / 2, resident: 40 * Self.megabyte,
            lifetimePeak: 14 * Self.megabyte, left: 18 * Self.megabyte + Self.megabyte / 2)

        #expect(reading.limit == 30 * Self.megabyte)
        #expect(Footprint.againstLimit(reading) == "memory now 11.5 MB, peak 14.0 MB, 18.5 MB left of 30.0 MB")
    }

    @Test("Where the kernel tells of no limit, it says only what is held")
    func theSentenceWithoutALimit() {
        let reading = Footprint.Reading(
            footprint: 11 * Self.megabyte, resident: 40 * Self.megabyte, lifetimePeak: 14 * Self.megabyte)

        #expect(reading.limit == nil)
        #expect(Footprint.againstLimit(reading) == "memory now 11.0 MB, peak 14.0 MB")
    }

    /// A quarter of a gigabyte, and half of it looked for: the other tests
    /// in this process take and let go of memory while this one runs, and
    /// with 32 MB held that was enough to hide it once.
    @Test("A reading goes up by what the process takes hold of")
    func theReadingCountsWhatIsHeld() throws {
        let before = try #require(Footprint.now())
        let held = Held(megabytes: 256)
        let during = try #require(Footprint.now())

        #expect(during.footprint >= before.footprint + 128 * Self.megabyte)
        withExtendedLifetime(held) {}
    }

    /// The kernel's own mark, and not the one kept here from readings: a
    /// fetch's worst moment is between two lines of the log.
    @Test("The kernel's peak is the most the process has ever held, and stays when that is let go")
    func theKernelsPeakStays() throws {
        var held: Held? = Held(megabytes: 32)
        let during = try #require(Footprint.now())
        held = nil
        let after = try #require(Footprint.now())

        #expect(held == nil)
        let most = try #require(during.lifetimePeak)
        #expect(most >= during.footprint)
        #expect(try #require(after.lifetimePeak) >= during.footprint)
    }

    /// Five minutes, because that is what was asked for and because a curve
    /// read any coarser misses the shape.
    @Test("The interval is five minutes")
    func theIntervalIsFiveMinutes() {
        #expect(Footprint.interval == .seconds(300))
    }
}
