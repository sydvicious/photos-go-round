import Foundation
import Testing

@testable import Photos_Go_Round

/// What a collection's row says about where it stands.
///
/// **The state a person most needs is the one this window could not show.**
/// Until 2026-09-07 the chosen collections were a comma-joined list of names,
/// so an album the agent could not reach looked exactly like one that was fine
/// — and on a machine whose photo library had stopped answering, every album
/// looked fine while none of them were.
///
/// The rule these hold to is the one the folder rows and the missing-albums
/// line already follow: **the words carry the meaning and the colour only
/// underlines it.** Nothing here is legible only as a colour.
@Suite("What a collection's row says")
@MainActor
struct SourceStandingWordsTests {

    private func collection(
        available: Bool = true, reason: String? = nil, missing: Bool? = nil,
        photos: Int = 40, scanned: Bool = true
    ) -> SourceService.Source {
        SourceService.Source(
            uuid: "S1", kind: "photos_collection", locator: "LIB/L0/040",
            recursive: nil, enabled: true, available: available,
            unavailableReason: reason, title: "Sunsets", missing: missing,
            reconnectable: nil, photos: photos,
            scannedAt: scanned ? Date(timeIntervalSince1970: 0) : nil)
    }

    @Test("A counted collection says how many photographs it holds")
    func aCountedCollectionSaysSo() {
        let standing = SourcesSettingsView.standing(of: collection(photos: 1284))
        #expect(standing.words == "1,284 photos")
        #expect(!standing.isTrouble)
    }

    /// Saying "0 photos" about an album nobody has walked yet would be a claim
    /// rather than a delay — the same reason a freshly added folder says this.
    @Test("A collection nobody has walked yet says so rather than claiming zero")
    func anUnscannedCollectionDoesNotClaimZero() {
        let standing = SourcesSettingsView.standing(of: collection(photos: 0, scanned: false))
        #expect(standing.words == "scanning…")
        #expect(!standing.isTrouble)
    }

    /// **The case this was built for.** The agent's own sentence, verbatim,
    /// because it names what went wrong and which call it was.
    @Test("An unreachable collection shows the agent's own reason")
    func anUnreachableCollectionGivesTheReason() {
        let reason = "the photo library did not answer enumerateImages within 10.0 seconds"
        let standing = SourcesSettingsView.standing(
            of: collection(available: false, reason: reason))
        #expect(standing.words == reason)
        #expect(standing.isTrouble)
    }

    // MARK: - Photos permission, as the app knows it

    /// Syd, 2026-10-09: "since the app has to ask the permissions, the app
    /// should have the state of permissions. That red string should be based
    /// on that value."
    @Test("With access not yet given, an album says so, whatever the agent's row says")
    func notGrantedSaysSo() {
        let standing = SourcesSettingsView.standing(
            of: collection(photos: 1284), photoAccess: "notDetermined")
        #expect(standing.words == "Photos access has not been granted yet")
        #expect(standing.isTrouble)
    }

    @Test("With access denied, an album says where to change it")
    func deniedSaysWhere() {
        let standing = SourcesSettingsView.standing(of: collection(), photoAccess: "denied")
        #expect(standing.words.contains("System Settings"))
        #expect(standing.isTrouble)
    }

    @Test("With access restricted, an album says so")
    func restrictedSaysSo() {
        let standing = SourcesSettingsView.standing(of: collection(), photoAccess: "restricted")
        #expect(standing.words == "Photos access is restricted on this Mac")
        #expect(standing.isTrouble)
    }

    /// **The case Syd saw.** Access had just been given, the agent's row still
    /// carried the refusal from its last scan, and the list went on saying so
    /// in red. The count is not there yet, and that is fine.
    @Test("With access given, an album the agent still has down as refused is only waiting to be read")
    func grantedOutranksAStaleRefusal() {
        let stale = collection(
            available: false, reason: "Photos access has not been granted yet", photos: 0)
        for access in ["authorized", "limited"] {
            let standing = SourcesSettingsView.standing(of: stale, photoAccess: access)
            #expect(standing.words == "scanning…")
            #expect(!standing.isTrouble)
        }
    }

    @Test("With access given, trouble of another kind is still said")
    func otherTroubleStillShows() {
        let silent = collection(
            available: false, reason: "the photo library did not answer within 10.0 seconds")
        let standing = SourcesSettingsView.standing(of: silent, photoAccess: "authorized")
        #expect(standing.words == "the photo library did not answer within 10.0 seconds")
        #expect(standing.isTrouble)
    }

    @Test("With access given, a counted album says how many photographs it holds")
    func grantedAndCounted() {
        let standing = SourcesSettingsView.standing(
            of: collection(photos: 1284), photoAccess: "authorized")
        #expect(standing.words == "1,284 photos")
        #expect(!standing.isTrouble)
    }

    /// Before the agent has said what the permission is, the row is all there
    /// is to go on.
    @Test("With the permission not yet known, an album says what the agent's row says")
    func unknownPermissionUsesTheRow() {
        let refused = collection(available: false, reason: "Photos access has not been granted yet")
        let standing = SourcesSettingsView.standing(of: refused, photoAccess: nil)
        #expect(standing.words == "Photos access has not been granted yet")
        #expect(standing.isTrouble)
    }

    @Test("A missing album says it is missing, whatever the permission")
    func missingOutranksPermission() {
        let standing = SourcesSettingsView.standing(
            of: collection(available: false, missing: true), photoAccess: "notDetermined")
        #expect(standing.words == "not in this library")
    }

    /// Unavailable with nothing said about why still has to say *something* —
    /// a blank column reads as fine.
    @Test("An unreachable collection with no reason still says it is unreachable")
    func anUnreachableCollectionAlwaysSaysSomething() {
        let standing = SourcesSettingsView.standing(of: collection(available: false))
        #expect(standing.words == "unavailable")
        #expect(standing.isTrouble)
    }

    /// Missing outranks the generic unavailable, because it is the one a person
    /// can act on — Reconnect and Remove are offered for exactly this.
    @Test("A missing album is named as missing rather than merely unavailable")
    func missingOutranksUnavailable() {
        let standing = SourcesSettingsView.standing(
            of: collection(available: false, reason: "offline", missing: true))
        #expect(standing.words == "not in this library")
        #expect(standing.isTrouble)
    }

    /// Every state says words. A row whose meaning lived in its tint would be
    /// unreadable to anyone who cannot separate the two colours.
    @Test("Every state has words of its own, so none of them is only a colour")
    func nothingIsCarriedByColourAlone() {
        let states = [
            collection(),
            collection(scanned: false),
            collection(available: false, reason: "offline"),
            collection(available: false, missing: true),
        ]
        for source in states {
            #expect(!SourcesSettingsView.standing(of: source).words.isEmpty)
        }
    }
}
