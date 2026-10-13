import Foundation
import XCTest
@testable import TopOfMindCore

final class JSONBoardRepositoryTests: XCTestCase {
    func testMissingFileReturnsBlankBoardWithoutWritingAnything() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("not-created/board.json")
            let repository = JSONBoardRepository(url: url)
            XCTAssertEqual(try repository.load(), BoardSnapshot())
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
        }
    }

    func testSaveCreatesParentAndReloadsExactTasksAndPreferences() throws {
        try withTemporaryDirectory { directory in
            let repository = JSONBoardRepository(url: directory.appendingPathComponent("nested/board.json"))
            let createdAt = Date(timeIntervalSince1970: 1_800_000_000.125)
            var engine = BoardEngine()
            let task = try XCTUnwrap(engine.add(title: "Überprüfung 👩🏽‍💻", now: createdAt))
            engine.move(id: task.id, to: .schedule, now: createdAt.addingTimeInterval(0.375))
            engine.setTheme(.dark)
            engine.setPinned(true)
            engine.setMatrixLabels(true)
            try repository.save(engine.snapshot)

            let reloaded = try JSONBoardRepository(url: repository.url).load()
            XCTAssertEqual(reloaded, engine.snapshot)
            XCTAssertEqual(reloaded.tasks.first?.id, task.id)
            XCTAssertTrue(FileManager.default.fileExists(atPath: repository.url.path))
        }
    }

    func testMalformedFileThrowsAndPreservesOriginalBytes() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("board.json")
            let original = Data("{ this is not valid JSON\n".utf8)
            try original.write(to: url)

            XCTAssertThrowsError(try JSONBoardRepository(url: url).load())
            XCTAssertEqual(try Data(contentsOf: url), original)
        }
    }

    func testFutureSchemaIsRejectedBeforeDecodingItsUnknownStructure() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("board.json")
            let original = Data(#"{"schemaVersion":2,"futureTaskFormat":{"items":[]}}"#.utf8)
            try original.write(to: url)

            XCTAssertThrowsError(try JSONBoardRepository(url: url).load()) { error in
                XCTAssertEqual(error as? BoardRepositoryError, .unsupportedSchema(2))
            }
            XCTAssertEqual(try Data(contentsOf: url), original)
        }
    }

    func testVersionOneWithoutOptionalPreferencesUsesDefaults() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("board.json")
            try Data(#"{"schemaVersion":1,"tasks":[]}"#.utf8).write(to: url)
            XCTAssertEqual(try JSONBoardRepository(url: url).load(), BoardSnapshot())
        }
    }

    func testUnsupportedSnapshotCannotOverwriteExistingFile() throws {
        try withTemporaryDirectory { directory in
            let repository = JSONBoardRepository(url: directory.appendingPathComponent("board.json"))
            try repository.save(snapshot: BoardSnapshot(theme: .dark))
            let original = try Data(contentsOf: repository.url)

            XCTAssertThrowsError(try repository.save(BoardSnapshot(schemaVersion: 42))) { error in
                XCTAssertEqual(error as? BoardRepositoryError, .unsupportedSchema(42))
            }
            XCTAssertEqual(try Data(contentsOf: repository.url), original)
            XCTAssertEqual(try repository.load().theme, .dark)
        }
    }

    func testRepeatedSaveReplacesSnapshotAndPreservesTrashForRecovery() throws {
        try withTemporaryDirectory { directory in
            let repository = JSONBoardRepository(url: directory.appendingPathComponent("board.json"))
            var engine = BoardEngine()
            let task = try XCTUnwrap(engine.add(title: "Keep recoverable"))
            engine.move(id: task.id, to: .delegate)
            try repository.save(engine.snapshot)
            engine.trash(id: task.id)
            try repository.save(engine.snapshot)

            var reopened = BoardEngine(snapshot: try repository.load())
            XCTAssertEqual(reopened.tasks(for: .delegate, lifecycle: .trashed).map(\.id), [task.id])
            XCTAssertTrue(reopened.restore(id: task.id))
            try repository.save(reopened.snapshot)
            let restored = BoardEngine(snapshot: try repository.load())
            XCTAssertEqual(restored.tasks(for: .delegate).map(\.id), [task.id])
            XCTAssertTrue(restored.tasks(for: .delegate, lifecycle: .trashed).isEmpty)
        }
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TopOfMindCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}
