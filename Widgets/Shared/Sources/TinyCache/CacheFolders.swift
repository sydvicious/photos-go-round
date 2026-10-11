// Where a widget's TinyCache lives, given what it is showing.
// `Plans/Photos-Go-Round Widgets.md`, *Next: the app's sources, then Photos*.
//
// **A change of sources starts the cache again.** Measured 2026-10-08: Syd
// removed a folder from the app's sources and the widgets went on showing its
// pictures, because up to twenty were already cached and nothing cleared them.
// A picture does not say which source it came from, so the cache is kept per
// list of sources, and a list that is no longer the one in force is deleted.

import Foundation

public enum CacheFolders {
    /// What the folder for a cache showing exactly these sources is called,
    /// wherever it is.
    ///
    /// - Parameter names: One string per source, saying all that makes it that
    ///   source. Their order does not matter.
    public static func name(forSources names: [String]) -> String {
        // FNV-1a, 64 bits. Not Swift's `Hasher`, which is seeded afresh in
        // every process: the folder has to be found again by the next one.
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in names.sorted().joined(separator: "\n").utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return "sources-" + String(hash, radix: 16)
    }

    /// The folder under `base` for a cache showing exactly these sources, with
    /// everything else under `base` removed. `base` is one widget's own, and
    /// holds nothing but its caches.
    public static func folder(in base: URL, forSources names: [String]) throws -> URL {
        let name = name(forSources: names)

        let manager = FileManager.default
        if manager.fileExists(atPath: base.path(percentEncoded: false)) {
            for other in try manager.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)
            where other.lastPathComponent != name {
                try manager.removeItem(at: other)
            }
        }
        return base.appending(path: name, directoryHint: .isDirectory)
    }
}
