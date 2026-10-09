// The Photos permission as the app knows it, and what to say about it.
//
// **The app holds the state, because the app is what asks.** Syd, 2026-10-09:
// "since the app has to ask the permissions, the app should have the state of
// permissions. That red string should be based on that value." The agent's row
// for an album keeps what its last scan concluded, which may be minutes old;
// the permission changes the moment a person answers the prompt. So the words
// beside an album come from here, and the agent goes on updating its sources
// as it always has.

import Foundation

nonisolated enum PhotoAccess {
    /// Whether the agent may read the library, from the name it gives its
    /// permission: `authorized` and `limited` may.
    static func isReadable(_ authorization: String?) -> Bool {
        authorization == "authorized" || authorization == "limited"
    }

    /// What to say beside an album when the permission stands in the way, and
    /// nil when it does not or is not yet known. The sentences are the agent's
    /// own, so a row reads the same whichever of the two it came from.
    static func refusal(_ authorization: String?) -> String? {
        switch authorization {
        case "notDetermined": "Photos access has not been granted yet"
        case "denied": "Photos access was denied — System Settings › Privacy & Security › Photos"
        case "restricted": "Photos access is restricted on this Mac"
        default: nil
        }
    }

    /// Whether a reason the agent gave for an album being unavailable is one
    /// of the sentences above: a refusal recorded by a scan, which the
    /// permission the app now holds may have overtaken.
    static func isRefusal(_ reason: String?) -> Bool {
        guard let reason else { return false }
        return ["notDetermined", "denied", "restricted"].contains { refusal($0) == reason }
    }
}
