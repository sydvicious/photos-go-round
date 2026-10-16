import Foundation
import PhotosGoRoundAgentAPI
import Testing

/// How collections are filed under the folders Photos keeps them in.
///
/// One builder draws the tree in every window that shows one, on the Mac and
/// in the Widgets app, so where an album sits is decided here and nowhere else.
@Suite("Collections, filed under their folders")
struct CollectionTreeTests {
    struct Album: Foldered {
        let name: String
        let folders: [String]

        var id: String { name }
        var treeID: String { "ID-\(name)" }
        var treeTitle: String { name }
        var treeFolders: [String] { folders }
    }

    typealias Node = FolderNode<Album>

    func album(_ name: String, in folders: [String] = []) -> Album {
        Album(name: name, folders: folders)
    }

    @Test("With no collections there is no tree")
    func empty() {
        #expect(Node.tree(of: []).isEmpty)
    }

    @Test("A collection in no folder is a row at the top, keyed by its identifier")
    func topLevel() {
        let tree = Node.tree(of: [album("Cats")])

        #expect(tree.map(\.id) == ["ID-Cats"])
        #expect(tree.map(\.title) == ["Cats"])
        #expect(tree.map(\.depth) == [0])
        #expect(tree[0].item == album("Cats"))
        #expect(tree[0].isLeaf)
    }

    @Test("A collection in a folder sits under a row for the folder, one step in")
    func inAFolder() {
        let iceland = album("Iceland", in: ["Trips"])

        let tree = Node.tree(of: [iceland])

        #expect(tree.map(\.title) == ["Trips"])
        #expect(tree[0].item == nil)
        #expect(!tree[0].isLeaf)
        #expect(tree[0].children.map(\.title) == ["Iceland"])
        #expect(tree[0].children.map(\.depth) == [1])
    }

    @Test("Folders come before collections, and each is sorted by name as a person reads it")
    func ordering() {
        let tree = Node.tree(of: [
            album("Zebras"), album("album 10"), album("album 9"),
            album("Iceland", in: ["Trips"]), album("Garden", in: ["Home"]),
        ])

        #expect(tree.map(\.title) == ["Home", "Trips", "album 9", "album 10", "Zebras"])
    }

    @Test("A folder inside a folder is keyed by the path to it, so two of one name stay apart")
    func nestedFolders() {
        let tree = Node.tree(of: [
            album("Iceland", in: ["Trips", "2019"]), album("Norway", in: ["Work", "2019"]),
        ])

        #expect(tree.map(\.id) == ["/Trips", "/Work"])
        #expect(tree[0].children.map(\.id) == ["/Trips/2019"])
        #expect(tree[1].children.map(\.id) == ["/Work/2019"])
        #expect(tree[0].children[0].children.map(\.depth) == [2])
    }

    @Test("A folder knows every collection beneath it, however deep")
    func itemsBeneath() {
        let tree = Node.tree(of: [
            album("Iceland", in: ["Trips", "2019"]), album("Norway", in: ["Trips"]),
        ])

        #expect(Set(tree[0].items.map(\.name)) == ["Iceland", "Norway"])
    }

    @Test("The rows to draw are the tree flattened, top to bottom")
    func rows() {
        let tree = Node.tree(of: [
            album("Cats"), album("Iceland", in: ["Trips", "2019"]), album("Norway", in: ["Trips"]),
        ])

        #expect(Node.rows(under: tree).map(\.title) == ["Trips", "2019", "Iceland", "Norway", "Cats"])
    }

    @Test("A folder that is shut contributes its own row and nothing under it")
    func collapsed() {
        let tree = Node.tree(of: [album("Cats"), album("Iceland", in: ["Trips", "2019"])])

        let rows = Node.rows(under: tree) { $0 == "/Trips" }

        #expect(rows.map(\.title) == ["Trips", "Cats"])
    }
}
