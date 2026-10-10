import Foundation

extension Duration {
    /// Whole milliseconds, rounded down. `sqlite3_busy_timeout` takes an Int32,
    /// and a log line reads better in milliseconds than in attoseconds.
    ///
    /// Here since 2026-10-09: the database and the photo library both use it,
    /// and they are in different targets now.
    public var milliseconds: Int {
        let (seconds, attoseconds) = components
        return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
    }
}
