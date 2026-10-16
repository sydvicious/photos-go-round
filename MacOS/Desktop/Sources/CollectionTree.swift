import Foundation
import PhotosGoRoundAgentAPI

// `Foldered` and `FolderNode`, the builder both windows share, are in
// `PhotosGoRoundAgentAPI` since 2026-10-09, where the Widgets app's picker
// links them too. What is left here is which of this app's types are laid out
// that way.
//
// `nonisolated` throughout: this target compiles with `MainActor` as its
// default isolation, and the values being arranged are plain `Sendable`
// structs decoded off a wire.

nonisolated extension SourceService.Library.Collection: Foldered {
    var treeID: String { identifier }
    var treeTitle: String { title }
    var treeFolders: [String] { folders }
}

nonisolated extension SourceService.Source: Foldered {
    var treeID: String { uuid }
    var treeTitle: String { name }
    var treeFolders: [String] { folderPath }
}

/// One line of the Settings panel's collection list: a folder, or a source.
///
/// The panel's counterpart to `PickerNode`, over the same builder — which is
/// what makes the two windows agree about where an album sits.
typealias SourceNode = FolderNode<SourceService.Source>
