// What the settings screen's two lists show. `Plans/PGR Widgets - iOS.md`.
//
// **Rows, not sources.** A row is a source with what the screen needs to draw
// it: what it is called and which kind it is. The lists are read from what is
// stored and read again after every change, so the screen never shows a change
// that did not take.

import Foundation
import Observation
import PhotosGoRoundAgentAPI

@MainActor
@Observable
public final class SettingsModel {
    public struct Row: Identifiable, Equatable, Sendable {
        public enum Kind: Sendable { case collection, folder, file }

        public let source: SourceSpec
        public let kind: Kind
        public let title: String

        public var id: String { source.locator }

        init(_ source: SourceSpec) {
            self.source = source
            switch source.kind {
            case .photosCollection:
                kind = .collection
                // An entry written without its description has only the
                // identifier Photos gave it.
                title = source.description?.title ?? source.locator
            case .folder:
                kind = .folder
                title = URL(filePath: source.locator).lastPathComponent
            default:
                kind = .file
                title = URL(filePath: source.locator).lastPathComponent
            }
        }
    }

    public private(set) var collections: [Row] = []
    public private(set) var filesAndFolders: [Row] = []

    private let sources: ChosenSources

    public init(sources: ChosenSources) {
        self.sources = sources
        reload()
    }

    /// Reads both lists again from what is stored.
    public func reload() {
        collections = sources.collections.map(Row.init)
        filesAndFolders = sources.filesAndFolders.map(Row.init)
    }

    /// Done in the collections sheet.
    public func chooseCollections(_ ticked: [SourceSpec]) {
        sources.chooseCollections(ticked)
        reload()
    }

    public func remove(_ row: Row) {
        sources.remove(row.source)
        reload()
    }
}
