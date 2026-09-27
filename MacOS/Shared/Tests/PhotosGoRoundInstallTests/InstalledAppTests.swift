import Foundation
import Testing

@testable import PhotosGoRoundAgentAPI
@testable import PhotosGoRoundInstall

/// Which app the uninstaller would move to the Trash.
///
/// **The failure this guards against is trashing the wrong app** — a Debug
/// build in DerivedData, say, which shares the Release app's identifier.
@Suite("Which app is this build's installed one")
struct InstalledAppTests {

    private let agentPath =
        "/Applications/Photos-Go-Round.app/Contents/Helpers/Photos-Go-Round Server.app/Contents/MacOS/Photos-Go-Round Server"

    @Test("The app is the one the agent's program is inside")
    func containing() {
        #expect(
            InstalledApp.containing(program: agentPath)?.path(percentEncoded: false)
                == "/Applications/Photos-Go-Round.app/")
    }

    @Test("An agent that is not inside an app names none")
    func notInsideAnApp() {
        #expect(
            InstalledApp.containing(
                program: "/Users/me/DerivedData/Build/Products/Debug/Photos-Go-Round Server.app/Contents/MacOS/Photos-Go-Round Server")
                == nil)
    }

    @Test("A LaunchAgent plist is read for its program")
    func fromPlist() throws {
        let job = JobDescription(
            label: BuildVariant.release.agentLabel, program: URL(filePath: agentPath))
        let app = InstalledApp.fromAgentPlist(try job.encodedPlist())
        #expect(app?.lastPathComponent == "Photos-Go-Round.app")
    }

    @Test("Only an app directly in /Applications may be trashed")
    func trashable() {
        #expect(InstalledApp.isTrashable(URL(filePath: "/Applications/Photos-Go-Round.app")))
        #expect(!InstalledApp.isTrashable(URL(filePath: "/Users/me/DerivedData/Build/Products/Debug/Photos-Go-Round.app")))
        #expect(!InstalledApp.isTrashable(URL(filePath: "/Applications/Tools/Photos-Go-Round.app")))
    }

    @Test("Something that is not a plist names no app")
    func notAPlist() {
        #expect(InstalledApp.fromAgentPlist(Data("not a plist".utf8)) == nil)
    }
}
