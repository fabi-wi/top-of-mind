import Foundation

public enum BoardRepositoryError: Error, Equatable, Sendable, LocalizedError {
    case unsupportedSchema(Int)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "This task file uses unsupported format version \(version)."
        }
    }
}

/// Stores one board locally. Loading never repairs or overwrites an unreadable file.
public struct JSONBoardRepository: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() throws -> BoardSnapshot {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return BoardSnapshot()
        }

        let decoder = JSONDecoder()
        let header = try decoder.decode(SchemaHeader.self, from: data)
        try validate(version: header.schemaVersion)
        return try decoder.decode(BoardSnapshot.self, from: data)
    }

    public func save(_ snapshot: BoardSnapshot) throws {
        try validate(version: snapshot.schemaVersion)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    public func save(snapshot: BoardSnapshot) throws {
        try save(snapshot)
    }

    private func validate(version: Int) throws {
        guard version == BoardSnapshot.currentSchemaVersion else {
            throw BoardRepositoryError.unsupportedSchema(version)
        }
    }

    private struct SchemaHeader: Decodable {
        var schemaVersion: Int
    }
}
