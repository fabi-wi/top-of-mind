import Foundation
import XCTest
@testable import TopOfMindCore

final class BoardEngineTests: XCTestCase {
    private let timestamp = Date(timeIntervalSince1970: 1_800_000_000.125)

    func testCaptureUsesInboxAndNormalizesUnicodeWhitespaceWithoutLosingText() throws {
        var engine = BoardEngine()
        let task = try XCTUnwrap(engine.add(
            title: "\u{2003}  Überprüfung\tfür\n Zürich\u{00A0} 👩🏽‍💻 \r\n",
            now: timestamp
        ))

        XCTAssertEqual(task.title, "Überprüfung für Zürich 👩🏽‍💻")
        XCTAssertEqual(task.destination, .inbox)
        XCTAssertEqual(task.lifecycle, .active)
        XCTAssertEqual(task.createdAt, timestamp)
        XCTAssertEqual(task.updatedAt, timestamp)
        XCTAssertEqual(engine.tasks(for: .inbox), [task])
    }

    func testWhitespaceOnlyCaptureLeavesBoardUnchanged() {
        var engine = BoardEngine()
        let original = engine.snapshot
        XCTAssertNil(engine.add(title: " \t\n\u{00A0}\u{2003}", now: timestamp))
        XCTAssertEqual(engine.snapshot, original)
    }

    func testDuplicateTitlesRemainIndependentTasks() throws {
        var engine = BoardEngine()
        let first = try XCTUnwrap(engine.add(title: "Buy milk", now: timestamp))
        let second = try XCTUnwrap(engine.add(title: "Buy milk", now: timestamp))
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.id), [first.id, second.id])
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.order), [0, 1])

        engine.complete(id: first.id)
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.id), [second.id])
    }

    func testMoveAppendsToDestinationAndCompactsSourceOrder() throws {
        var engine = BoardEngine()
        let first = try XCTUnwrap(engine.add(title: "First", now: timestamp))
        let second = try XCTUnwrap(engine.add(title: "Second", now: timestamp))
        let existing = try XCTUnwrap(engine.add(title: "Already planned", now: timestamp))
        engine.move(id: existing.id, to: .schedule, now: timestamp)
        let changedAt = timestamp.addingTimeInterval(30)

        XCTAssertTrue(engine.move(id: first.id, to: .schedule, now: changedAt))
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.id), [second.id])
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.order), [0])
        XCTAssertEqual(engine.tasks(for: .schedule).map(\.id), [existing.id, first.id])
        let moved = try XCTUnwrap(engine.tasks(for: .schedule).last)
        XCTAssertEqual(moved.createdAt, timestamp)
        XCTAssertEqual(moved.updatedAt, changedAt)
        XCTAssertFalse(engine.move(id: first.id, to: .schedule, now: timestamp))
    }

    func testCompleteAndRestoreKeepDestinationAndAppendToActiveList() throws {
        var engine = BoardEngine()
        let first = try XCTUnwrap(engine.add(title: "Plan study session", now: timestamp))
        let second = try XCTUnwrap(engine.add(title: "Read chapter", now: timestamp))
        engine.move(id: first.id, to: .schedule)
        engine.move(id: second.id, to: .schedule)

        XCTAssertTrue(engine.complete(id: first.id))
        XCTAssertEqual(engine.tasks(for: .schedule).map(\.id), [second.id])
        XCTAssertEqual(engine.tasks(for: .schedule, lifecycle: .completed).map(\.id), [first.id])
        XCTAssertFalse(engine.complete(id: first.id))
        XCTAssertTrue(engine.restore(id: first.id))
        XCTAssertEqual(engine.tasks(for: .schedule).map(\.id), [second.id, first.id])
        XCTAssertTrue(engine.tasks(for: .schedule, lifecycle: .completed).isEmpty)
        XCTAssertFalse(engine.restore(id: first.id))
    }

    func testTrashCanBeRecoveredWithoutLosingTaskOrDestination() throws {
        var engine = BoardEngine()
        let task = try XCTUnwrap(engine.add(title: "Ask for a hand", now: timestamp))
        engine.move(id: task.id, to: .delegate)
        XCTAssertTrue(engine.trash(id: task.id))
        XCTAssertTrue(engine.tasks(for: .delegate).isEmpty)
        XCTAssertEqual(engine.tasks(for: .delegate, lifecycle: .trashed).map(\.id), [task.id])

        XCTAssertTrue(engine.restore(id: task.id))
        let restored = try XCTUnwrap(engine.tasks(for: .delegate).first)
        XCTAssertEqual(restored.id, task.id)
        XCTAssertEqual(restored.title, task.title)
        XCTAssertEqual(restored.destination, .delegate)
        XCTAssertEqual(restored.createdAt, task.createdAt)
        XCTAssertTrue(engine.tasks(for: .delegate, lifecycle: .trashed).isEmpty)
    }

    func testMovingArchivedTaskReactivatesItInSelectedDestination() throws {
        var engine = BoardEngine()
        let completed = try XCTUnwrap(engine.add(title: "Completed", now: timestamp))
        let trashed = try XCTUnwrap(engine.add(title: "Trashed", now: timestamp))
        engine.complete(id: completed.id)
        engine.trash(id: trashed.id)

        XCTAssertTrue(engine.move(id: completed.id, to: .doNow))
        XCTAssertTrue(engine.move(id: trashed.id, to: .discard))
        XCTAssertEqual(engine.tasks(for: .doNow).map(\.id), [completed.id])
        XCTAssertEqual(engine.tasks(for: .discard).map(\.id), [trashed.id])
        XCTAssertTrue(engine.tasks(for: .inbox, lifecycle: .completed).isEmpty)
        XCTAssertTrue(engine.tasks(for: .inbox, lifecycle: .trashed).isEmpty)
    }

    func testDiscardQuadrantDoesNotTrashTask() throws {
        var engine = BoardEngine()
        let task = try XCTUnwrap(engine.add(title: "Maybe later", now: timestamp))
        engine.move(id: task.id, to: .discard)
        XCTAssertEqual(engine.tasks(for: .discard).first?.lifecycle, .active)
        XCTAssertTrue(engine.snapshot.tasks.filter { $0.lifecycle == .trashed }.isEmpty)
        engine.move(id: task.id, to: .inbox)
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.id), [task.id])
    }

    func testRenameNormalizesTitleAndRejectsEmptyOrUnchangedInput() throws {
        var engine = BoardEngine()
        let task = try XCTUnwrap(engine.add(title: "Original", now: timestamp))
        let original = engine.snapshot
        XCTAssertFalse(engine.rename(id: task.id, title: " \n\t "))
        XCTAssertFalse(engine.rename(id: task.id, title: "  Original  "))
        XCTAssertEqual(engine.snapshot, original)

        let changedAt = timestamp.addingTimeInterval(10)
        XCTAssertTrue(engine.rename(id: task.id, title: "  New\nname  ", now: changedAt))
        XCTAssertEqual(engine.snapshot.tasks.first?.title, "New name")
        XCTAssertEqual(engine.snapshot.tasks.first?.updatedAt, changedAt)
        XCTAssertEqual(engine.snapshot.tasks.first?.createdAt, timestamp)
    }

    func testReorderWithinListPreservesUnaffectedRelativeOrder() throws {
        var engine = BoardEngine()
        let first = try XCTUnwrap(engine.add(title: "First", now: timestamp))
        let second = try XCTUnwrap(engine.add(title: "Second", now: timestamp))
        let third = try XCTUnwrap(engine.add(title: "Third", now: timestamp))

        XCTAssertTrue(engine.reorder(id: third.id, beforeID: first.id, destination: .inbox))
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.id), [third.id, first.id, second.id])
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.order), [0, 1, 2])
        XCTAssertFalse(engine.reorder(id: first.id, beforeID: second.id, destination: .inbox))
        XCTAssertTrue(engine.reorder(id: third.id, beforeID: nil, destination: .inbox))
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.id), [first.id, second.id, third.id])
    }

    func testReorderAcrossDestinationsInsertsAtRequestedPosition() throws {
        var engine = BoardEngine()
        let inboxFirst = try XCTUnwrap(engine.add(title: "Inbox first", now: timestamp))
        let incoming = try XCTUnwrap(engine.add(title: "Incoming", now: timestamp))
        let scheduledFirst = try XCTUnwrap(engine.add(title: "Scheduled first", now: timestamp))
        let scheduledLast = try XCTUnwrap(engine.add(title: "Scheduled last", now: timestamp))
        engine.move(id: scheduledFirst.id, to: .schedule)
        engine.move(id: scheduledLast.id, to: .schedule)

        XCTAssertTrue(engine.reorder(id: incoming.id, beforeID: scheduledLast.id, destination: .schedule))
        XCTAssertEqual(engine.tasks(for: .schedule).map(\.id), [scheduledFirst.id, incoming.id, scheduledLast.id])
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.id), [inboxFirst.id])
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.order), [0])
    }

    func testMissingOrWrongListAnchorAppendsAndSelfAnchorDoesNothing() throws {
        var engine = BoardEngine()
        let first = try XCTUnwrap(engine.add(title: "First", now: timestamp))
        let second = try XCTUnwrap(engine.add(title: "Second", now: timestamp))
        let elsewhere = try XCTUnwrap(engine.add(title: "Elsewhere", now: timestamp))
        engine.move(id: elsewhere.id, to: .delegate)

        XCTAssertTrue(engine.reorder(id: first.id, beforeID: elsewhere.id, destination: .inbox))
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.id), [second.id, first.id])
        let unchanged = engine.snapshot
        XCTAssertFalse(engine.reorder(id: first.id, beforeID: first.id, destination: .inbox))
        XCTAssertEqual(engine.snapshot, unchanged)
        XCTAssertTrue(engine.reorder(id: second.id, beforeID: UUID(), destination: .inbox))
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.id), [first.id, second.id])
    }

    func testOrderingTiesUseCreationTimeThenIDAndLargeOrdersAreCompacted() throws {
        let lowID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let highID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let older = TaskItem(title: "Older", createdAt: timestamp.addingTimeInterval(-1), order: Int.max)
        let first = TaskItem(id: lowID, title: "First tie", createdAt: timestamp, order: Int.max)
        let second = TaskItem(id: highID, title: "Second tie", createdAt: timestamp, order: Int.max)
        var engine = BoardEngine(snapshot: BoardSnapshot(tasks: [second, first, older]))

        XCTAssertEqual(engine.tasks(for: .inbox).map(\.id), [older.id, first.id, second.id])
        let added = try XCTUnwrap(engine.add(title: "Last", now: timestamp))
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.id), [older.id, first.id, second.id, added.id])
        XCTAssertEqual(engine.tasks(for: .inbox).map(\.order), [0, 1, 2, 3])
    }

    func testUnknownIDsCannotMutateBoard() {
        var engine = BoardEngine()
        let original = engine.snapshot
        let unknown = UUID()
        XCTAssertFalse(engine.move(id: unknown, to: .doNow))
        XCTAssertFalse(engine.complete(id: unknown))
        XCTAssertFalse(engine.restore(id: unknown))
        XCTAssertFalse(engine.trash(id: unknown))
        XCTAssertFalse(engine.rename(id: unknown, title: "New title"))
        XCTAssertFalse(engine.reorder(id: unknown, beforeID: nil, destination: .inbox))
        XCTAssertEqual(engine.snapshot, original)
    }

    func testArchivingAppendsEvenWhenLoadedArchiveOrdersHaveGaps() {
        let earlier = TaskItem(title: "Earlier completed", lifecycle: .completed, createdAt: timestamp, order: 100)
        let incoming = TaskItem(title: "Newly completed", createdAt: timestamp, order: 0)
        var engine = BoardEngine(snapshot: BoardSnapshot(tasks: [earlier, incoming]))

        XCTAssertTrue(engine.complete(id: incoming.id))
        XCTAssertEqual(engine.tasks(for: .inbox, lifecycle: .completed).map(\.id), [earlier.id, incoming.id])
        XCTAssertEqual(engine.tasks(for: .inbox, lifecycle: .completed).map(\.order), [0, 1])
    }

    func testPreferencesHaveExplicitDefaultsAndCanBeChanged() {
        var engine = BoardEngine()
        XCTAssertEqual(engine.snapshot.theme, .light)
        XCTAssertFalse(engine.snapshot.isPinned)
        XCTAssertFalse(engine.snapshot.showsMatrixLabels)
        XCTAssertTrue(engine.setTheme(.dark))
        XCTAssertTrue(engine.setPinned(true))
        XCTAssertTrue(engine.setMatrixLabels(true))
        XCTAssertFalse(engine.setTheme(.dark))
        XCTAssertFalse(engine.setPinned(true))
        XCTAssertFalse(engine.setMatrixLabels(true))
        XCTAssertEqual(engine.snapshot.theme, .dark)
        XCTAssertTrue(engine.snapshot.isPinned)
        XCTAssertTrue(engine.snapshot.showsMatrixLabels)
    }
}
